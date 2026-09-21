"""School-project DPS-QKD engineering model. See THEORY.md for assumptions.

All probabilities are per valid adjacent-pulse slot. A rate estimate is NOT a
security certificate. The notebook contains these same function definitions.
"""
from pathlib import Path
import json
import math
import copy
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.special import erf
from scipy.stats import ncx2
from scipy.integrate import trapezoid

SCHEMA = json.loads(Path(__file__).with_name('parameters.json').read_text(encoding='utf-8'))

# %% Parameters and small mathematical helpers
def default_parameters():
    """Return a fresh flat dictionary; every editable value comes from the shared catalogue."""
    return {row['key']: row['default'] for row in SCHEMA}


def validate(p):
    """Reject missing/unknown keys, invalid choices, nonfinite values and inconsistent units."""
    if set(p) != {r['key'] for r in SCHEMA}:
        raise ValueError('Configuration must contain exactly the keys in parameters.json.')
    for row in SCHEMA:
        key, value = row['key'], p[row['key']]
        if row['choices']:
            if value not in row['choices']:
                raise ValueError(f'{key}: choose from {row["choices"]}')
        elif isinstance(row['default'], str):
            if not isinstance(value, str):
                raise ValueError(f'{key} must be text')
        else:
            if not isinstance(value, (int, float, np.number)) or not np.isfinite(value):
                raise ValueError(f'{key} must be a finite number')
            if row['integer'] and int(value) != value:
                raise ValueError(f'{key} must be an integer')
            if row['minimum'] is not None and value < row['minimum']:
                raise ValueError(f'{key} must be >= {row["minimum"]}')
            if row['maximum'] is not None and value > row['maximum']:
                raise ValueError(f'{key} must be <= {row["maximum"]}')
    parse_hex(p['sample_hex'])
    if p['gate_ns'] * 1e-9 > 1 / p['clock_hz'] * (1+1e-12):
        raise ValueError('gate_ns must be <= 1e9/clock_hz: adjacent detector gates cannot overlap.')
    if p['ground_altitude_m'] >= min(p['atmosphere_top_m'], p['sat_altitude_km']*1000):
        raise ValueError('Ground altitude must lie below the atmosphere top and satellite.')


def parse_hex(text):
    """Convert space-separated hexadecimal bytes to integers without silently truncating."""
    tokens = text.split()
    if not tokens or any(len(t) > 2 or any(c not in '0123456789abcdefABCDEF' for c in t) for t in tokens):
        raise ValueError('sample_hex: use bytes such as A5 3C 00 FF, separated by spaces.')
    return np.array([int(t, 16) for t in tokens], dtype=np.uint8)


def encode_bytes(text):
    """Bytes -> MSB-first pulse phase bits a_i -> phases pi*a_i -> adjacent XOR key bits."""
    byte_values = parse_hex(text)
    bits = np.unpackbits(byte_values).astype(int)
    key = np.bitwise_xor(bits[:-1], bits[1:])
    return pd.DataFrame({'slot': np.arange(1, len(bits)), 'previous_phase_bit': bits[:-1],
                         'current_phase_bit': bits[1:], 'Alice_key_bit': key,
                         'phase_difference_mod_2pi_rad': np.pi*key,
                         'ideal_detector': key})


def h2(q):
    """Binary entropy in bits: -q log2(q)-(1-q)log2(1-q), with h2(0)=h2(1)=0."""
    x = np.clip(np.asarray(q, dtype=float), 1e-15, 1-1e-15)
    result = -x*np.log2(x) - (1-x)*np.log2(1-x)
    return np.where((np.asarray(q)==0) | (np.asarray(q)==1), 0.0, result)


def wilson(errors, count):
    """95% binomial Wilson interval; NaNs for zero trials. Descriptive, not a finite-key bound."""
    if count == 0:
        return (float('nan'), float('nan'))
    z, q = 1.959963984540054, errors/count
    d = 1+z*z/count
    mid = (q+z*z/(2*count))/d
    half = z*np.sqrt(q*(1-q)/count+z*z/(4*count**2))/d
    return (max(0.0, mid-half), min(1.0, mid+half))


def hv_profile(h, p):
    """Hufnagel-Valley Cn^2(h) in m^(-2/3), with absolute altitude h in metres."""
    return p['hv_scale']*(0.00594*(p['hv_wind_m_s']/27)**2*(1e-5*h)**10*np.exp(-h/1000)
                          + 2.7e-16*np.exp(-h/1500) + p['hv_A']*np.exp(-h/100))


def turbulence_parameters(s):
    """Map Rytov variance s=σ_R² (NOT σ_R) to gamma-gamma shapes and scintillation index."""
    if s < 1e-12:
        return np.inf, np.inf, 0.0
    alpha = 1/np.expm1(0.49*s/(1+1.11*s**(6/5))**(7/6))
    beta = 1/np.expm1(0.51*s/(1+0.69*s**(6/5))**(5/6))
    return alpha, beta, 1/alpha+1/beta+1/(alpha*beta)

# %% Step 1: three independent channel calculations
def channel_model(p):
    """Compute link geometry, named dB losses, Rytov/Fried turbulence and a calculation ledger.

    Atmospheric coefficients are input assumptions, not a weather prediction.
    Satellite is a downlink, with curved-Earth range and a flat slant atmosphere.
    """
    validate(p)
    ledger = []
    def record(name, formula, value, unit='-'):
        ledger.append(dict(quantity=name, formula=formula, value=float(value), unit=unit))
        return value
    lam = record('wavelength', 'wavelength_nm * 1e-9', p['wavelength_nm']*1e-9, 'm')
    k = record('wavenumber', '2*pi/lambda', 2*np.pi/lam, 'rad/m')
    period = record('pulse separation', '1/clock_hz', 1/p['clock_hz'], 's')
    record('interferometer free-space path difference', 'c/clock_hz; divide by group index in material', 299792458*period, 'm')
    c = dict(ledger=ledger, losses={}, profile_h=np.array([]), profile_cn2=np.array([]), warnings=[])
    sigma_ps = p['pulse_sigma_ps']
    if p['channel'] == 'Fiber':
        L = p['fiber_km']*1000
        losses = {'attenuation': p['fiber_alpha_db_km']*p['fiber_km'],
                  'connectors': p['connector_db'], 'splices': p['splice_count']*p['splice_db'],
                  'other fiber': p['fiber_misc_db']}
        for name, value in losses.items():
            record(name+' loss', {'attenuation':'alpha_dB_per_km * L_km', 'splices':'splice_count * splice_db'}.get(name,'input loss'), value, 'dB')
        broaden = record('dispersion RMS broadening', 'abs(D)*L_km*spectral_sigma_nm', abs(p['dispersion_ps_nm_km'])*p['fiber_km']*p['spectral_sigma_nm'], 'ps')
        sigma_ps = record('received pulse RMS width', 'sqrt(sigma_initial^2 + broadening^2)', np.hypot(sigma_ps, broaden), 'ps')
        s, r0 = 0.0, np.inf
        c.update(w=0.0, aperture_radius=0.0, pointing_sigma=0.0, geom=1.0)
    else:
        sat = p['channel'] == 'Satellite-Ground'
        pre = 'sat' if sat else 'fso'
        if sat:
            e = np.deg2rad(p['elevation_deg'])
            Rg = p['earth_radius_km']*1000+p['ground_altitude_m']
            Rs = (p['earth_radius_km']+p['sat_altitude_km'])*1000
            L = record('slant range', 'sqrt(Rs^2-Rg^2*cos(e)^2)-Rg*sin(e)', np.sqrt(Rs**2-Rg**2*np.cos(e)**2)-Rg*np.sin(e), 'm')
            h = np.linspace(p['ground_altitude_m'], min(p['atmosphere_top_m'], p['sat_altitude_km']*1000), 2001)
            cn = hv_profile(h, p)
            integ = record('weighted turbulence integral', 'trapz(h, Cn2(h)*(h-h_ground)^(5/6))', trapezoid(cn*(h-h[0])**(5/6), h), 'm^(7/6)')
            s = record('Rytov variance', '2.25*k^(7/6)*sin(e)^(-11/6)*weighted_integral', 2.25*k**(7/6)*np.sin(e)**(-11/6)*integ)
            j = record('slant Cn2 integral', 'trapz(h,Cn2)/sin(e)', trapezoid(cn,h)/np.sin(e), 'm^(1/3)')
            record('atmospheric path approximation', '(h_top-h_ground)/sin(e)', (h[-1]-h[0])/np.sin(e), 'm')
            extinction = p['sat_zenith_extinction_db']/np.sin(e)
            c.update(profile_h=h, profile_cn2=cn)
        else:
            L = p['fso_km']*1000
            s = record('Rytov variance', '1.23*Cn2*k^(7/6)*L^(11/6)', 1.23*p['fso_cn2']*k**(7/6)*L**(11/6))
            j = p['fso_cn2']*L
            extinction = p['fso_extinction_db_km']*p['fso_km']
        r0 = record('Fried coherence diameter', '(0.423*k^2*integral(Cn2 ds))^(-3/5)', (0.423*k*k*j)**(-3/5) if j>0 else np.inf, 'm')
        theta = record('effective divergence half-angle', 'max(input_urad*1e-6, lambda/(pi*w0))', max(p[pre+'_divergence_urad']*1e-6,lam/(np.pi*p[pre+'_waist_m'])), 'rad')
        w = record('beam radius at receiver', 'sqrt(w0^2 + (theta*L)^2)', np.hypot(p[pre+'_waist_m'],theta*L), 'm')
        a = p[pre+'_aperture_m']/2
        geom = record('centered Gaussian aperture capture', '1-exp(-2*a^2/w^2)', -np.expm1(-2*(a/w)**2))
        record('per-axis spot jitter', 'L * pointing_urad * 1e-6', L*p[pre+'_pointing_urad']*1e-6, 'm')
        losses = {'aperture': -10*np.log10(geom), 'extinction': extinction, 'optics': p[pre+'_optics_db']}
        for name,value in losses.items():
            record(name+' loss', 'power loss in dB; extinction scales with path/airmass', value, 'dB')
        c.update(w=w, aperture_radius=a, pointing_sigma=L*p[pre+'_pointing_urad']*1e-6, geom=geom)
        c['warnings'].append('Scintillation uses a point-receiver approximation; aperture averaging, beam wander from turbulence, and adaptive optics are not modeled.')
        if p['fading_model']=='lognormal' and s>=1:
            c['warnings'].append('Forced lognormal outside weak turbulence: distribution is an illustrative extrapolation.')
    capture = record('temporal gate capture', 'erf(gate_seconds/(2*sqrt(2)*sigma_seconds))', erf(p['gate_ns']*1e-9/(2*np.sqrt(2)*sigma_ps*1e-12)))
    if sigma_ps*1e-12 > period/6:
        c['warnings'].append('Pulse width exceeds T/6: intersymbol interference may matter; the model includes gate loss only.')
    record('channel length', 'selected physical propagation length', L, 'm')
    total_db = record('nominal channel loss', 'sum(named losses); excludes random pointing/cloud/scintillation', sum(losses.values()), 'dB')
    eta0 = record('nominal channel transmission', '10^(-loss_dB/10)', 10**(-total_db/10))
    alpha,beta,si = turbulence_parameters(s)
    record('gamma-gamma alpha', '1/expm1(0.49*s/(1+1.11*s^(6/5))^(7/6))', alpha)
    record('gamma-gamma beta', '1/expm1(0.51*s/(1+0.69*s^(6/5))^(5/6))', beta)
    record('gamma-gamma scintillation index', '1/alpha+1/beta+1/(alpha*beta)', si)
    c.update(length_m=L, losses=losses, total_loss_db=total_db, eta0=eta0,
             gate_capture=capture, rytov=s, r0=r0, alpha=alpha, beta=beta, si=si)
    return c

# %% Step 2: atmospheric fading and pointing
def draw_channel(p, c, rng):
    """Draw unit-mean intensity fading, exact displaced-Gaussian aperture capture and clouds.

    A Gaussian spot integrated over a circular aperture is a noncentral chi-square
    CDF with 2 degrees of freedom. Normalize by centered capture to avoid counting
    aperture loss twice. Clamp physical transmission at one and report clipping.
    """
    n = int(p['n_slots'])+1
    b = int(p['block_slots'])
    nb = (n+b-1)//b
    mode = p['fading_model']
    if p['channel']=='Fiber' or c['rytov']<1e-12:
        mode='none'
    elif mode=='auto':
        mode='lognormal' if c['rytov']<1 else 'gamma-gamma'
    if mode=='none':
        fade=np.ones(nb); theoretical_si=0.0
    elif mode=='lognormal':
        fade=np.exp(np.sqrt(c['rytov'])*rng.standard_normal(nb)-c['rytov']/2)
        theoretical_si=np.expm1(c['rytov']) if c['rytov']<700 else np.inf
    else:
        fade=rng.gamma(c['alpha'],1/c['alpha'],nb)*rng.gamma(c['beta'],1/c['beta'],nb)
        theoretical_si=c['si']
    point=np.ones(nb); blocked=np.zeros(nb,dtype=bool); offset=np.zeros(nb)
    if p['channel']!='Fiber':
        offset=np.hypot(rng.normal(0,c['pointing_sigma'],nb),rng.normal(0,c['pointing_sigma'],nb))
        aperture=ncx2.cdf(4*c['aperture_radius']**2/c['w']**2, 2, 4*offset**2/c['w']**2)
        point=np.clip(aperture/c['geom'],0,1)
        blocked=rng.random(nb)<p['cloud_probability']
    raw=c['eta0']*fade*point*(~blocked)
    eta_blocks=np.clip(raw,0,1)
    eta=np.repeat(eta_blocks,b)[:n]
    return dict(eta=eta, eta_blocks=eta_blocks, fade=fade, pointing=point, offset=offset,
                cloud=blocked, mode=mode, theoretical_si=theoretical_si,
                clip_fraction=float(np.mean(raw>1)))

# %% Step 3: Eve acts on optical pulses
def eve_attack(phases, p, rng):
    """Return forwarded phase bits, Eve's estimates, known-mask and Bob power multiplier.

    Phase-resend: discriminate |+sqrt(mu)> and |-sqrt(mu)> with a perfect external
    phase reference. Helstrom error e=(1-sqrt(1-exp(-4*mu*eta_E)))/2. Intercept
    each pulse with probability f and resend an equal-intensity coherent pulse.
    This is ONE assumed attack; it is not optimal DPS security analysis.

    Beam-split: pass power (1-t), send fraction t to Eve's ideal DPS receiver.
    Her conclusive adjacent-slot probability is 1-exp(-mu*t*eta_E).
    """
    n=len(phases)
    key=phases[:-1]^phases[1:]
    e=(1-np.sqrt(-np.expm1(-4*p['mu']*p['eve_eta'])))/2
    attacked=np.zeros(n,dtype=bool)
    estimates=np.full(n,-1,dtype=int)
    known=np.zeros(n-1,dtype=bool)
    eve_key=np.full(n-1,-1,dtype=int)
    flips=np.zeros(n,dtype=int)
    multiplier=1.0
    if p['eve_mode']=='phase-resend':
        attacked=rng.random(n)<p['eve_fraction']
        guess_error=rng.random(n)<e
        estimates[attacked]=phases[attacked]^guess_error[attacked].astype(int)
        flips=(attacked & guess_error).astype(int)
        known=attacked[:-1]&attacked[1:]
        eve_key[known]=estimates[:-1][known]^estimates[1:][known]
    elif p['eve_mode']=='beam-split':
        multiplier=1-p['eve_tap']
        known=rng.random(n-1)<-np.expm1(-p['mu']*p['eve_tap']*p['eve_eta'])
        eve_key[known]=key[known]
    return dict(forwarded=phases^flips, flips=flips, attacked=attacked,
                estimates=estimates, known=known, key=eve_key,
                multiplier=multiplier, helstrom_error=e,
                expected_signal_qber=2*p['eve_fraction']*e*(1-p['eve_fraction']*e)
                    if p['eve_mode']=='phase-resend' else 0.0)

# %% Step 4: interferometer, photon counting, sifting and statistics
def simulate(p=None):
    """Run all stages, preserving intermediate arrays and calculation tables for inspection.

    Poisson threshold-detector port clicks are sampled independently conditional
    on phase and transmission. Double clicks are discarded but trigger holdoff.
    The phase noise is sampled, so nonlinear click probabilities are averaged
    after detection calculations. All N valid slots contribute to rate estimates.
    """
    p=default_parameters() if p is None else copy.deepcopy(p)
    validate(p)
    rng=np.random.default_rng(int(p['seed']))
    c=channel_model(p); f=draw_channel(p,c,rng)
    n=int(p['n_slots']); phases=rng.integers(0,2,n+1)
    alice=phases[:-1]^phases[1:]
    eve=eve_attack(phases,p,rng)
    eta=f['eta']*eve['multiplier']
    common=p['mu']*p['detector_eta']*p['coupling_eta']*10**(-p['interferometer_loss_db']/10)*c['gate_capture']/4
    delta=p['phase_sigma_rad']*rng.standard_normal(n)
    forwarded_key=eve['forwarded'][:-1]^eve['forwarded'][1:]
    cross=2*p['visibility']*np.sqrt(eta[:-1]*eta[1:])*np.cos(np.pi*forwarded_key+delta)
    nu0=np.maximum(0,common*(eta[:-1]+eta[1:]+cross))
    nu1=np.maximum(0,common*(eta[:-1]+eta[1:]-cross))
    noise=(p['dark_hz']+p['background_hz'])*p['gate_ns']*1e-9
    p0=-np.expm1(-(nu0+noise)); p1=-np.expm1(-(nu1+noise))
    only0=p0*(1-p1); only1=p1*(1-p0)
    psingle=only0+only1; pdouble=p0*p1; pany=psingle+pdouble
    perror=np.where(alice==0,only1,only0)
    hold=int(np.ceil(p['dead_time_ns']*1e-9*p['clock_hz']))
    live=1/(1+hold*pany)  # stationary local approximation, exact for constant probabilities
    expected_single=float(np.mean(psingle*live))
    expected_error=float(np.mean(perror*live))
    qmodel=expected_error/expected_single if expected_single>0 else np.nan
    click0=rng.random(n)<p0; click1=rng.random(n)<p1
    live_mask=np.ones(n,dtype=bool)
    if hold:
        last=-hold-1
        for i in np.flatnonzero(click0|click1):
            if i-last<=hold:
                live_mask[i]=False
            else:
                last=i
    anyclick=(click0|click1)&live_mask
    single=(click0^click1)&live_mask
    doubles=click0&click1&live_mask
    bob=click1.astype(int)
    indices=np.flatnonzero(single)
    errors=(bob!=alice)&single
    count=int(single.sum()); nerr=int(errors.sum())
    qobserved=nerr/count if count else np.nan
    duration=(n+1)/p['clock_hz']
    model_rate=n*expected_single/duration
    observed_rate=count/duration
    nt=int(np.floor(count*p['test_fraction']))
    test_indices=rng.choice(indices,nt,replace=False) if nt else np.array([],dtype=int)
    test_errors=int(errors[test_indices].sum()); test_q=test_errors/nt if nt else np.nan
    interval=wilson(nerr,count); test_interval=wilson(test_errors,nt)
    status='INSUFFICIENT TEST DATA'
    if nt and test_q>p['abort_qber']:
        status='ABORT: test QBER above classroom threshold'
    elif nt and test_interval[1]<=p['abort_qber']:
        status='PASS classroom QBER check (not security certification)'
    budget=max(0.0,1-(1+p['ec_efficiency'])*float(h2(qmodel))) if np.isfinite(qmodel) else 0.0
    if not np.isfinite(qmodel) or qmodel>p['abort_qber']:
        budget=0.0
    heuristic=model_rate*(1-p['test_fraction'])*budget
    known=single&eve['known']; known_count=int(known.sum())
    eve_agreement=float(np.mean(eve['key'][known]==alice[known])) if known_count else np.nan
    summary=dict(channel=p['channel'], fading=f['mode'], length_km=c['length_m']/1000,
        nominal_loss_db=c['total_loss_db'], rytov_variance=c['rytov'], fried_r0_m=c['r0'],
        fading_blocks=len(f['fade']), block_duration_s=p['block_slots']/p['clock_hz'],
        duration_s=duration, fading_mean=float(np.mean(f['fade'])),
        fading_si_sample=float(np.var(f['fade'])/np.mean(f['fade'])**2) if np.mean(f['fade'])>0 else np.nan,
        fading_si_theory=f['theoretical_si'], mean_channel_eta=float(np.mean(f['eta'])),
        outage_fraction=float(np.mean(f['eta']<p['outage_eta'])), transmission_clip_fraction=f['clip_fraction'],
        click_probability_before_holdoff=float(np.mean(pany)), expected_single_probability=expected_single,
        detected_sifted_bits=count, errors=nerr, double_clicks=int(doubles.sum()),
        qber_model=qmodel, qber_observed=qobserved, qber_wilson_low=interval[0], qber_wilson_high=interval[1],
        sifted_rate_model_bps=model_rate, sifted_rate_observed_bps=observed_rate,
        test_bits=nt, test_qber=test_q, test_wilson_low=test_interval[0], test_wilson_high=test_interval[1],
        unrevealed_bits=count-nt, classroom_status=status, eve_mode=p['eve_mode'],
        eve_single_phase_error=eve['helstrom_error'], eve_signal_qber_expected=eve['expected_signal_qber'],
        eve_estimated_sifted_bits=known_count, eve_estimate_agreement=eve_agreement,
        toy_retained_fraction=budget, illustrative_postprocessing_bps=heuristic,
        certified_secret_key_bps='NOT COMPUTED: no DPS security proof / finite-key analysis')
    def calc(name, formula, value, unit='-'):
        c['ledger'].append(dict(quantity=name,formula=formula,value=float(value),unit=unit))
    calc('source photon energy','h*c/lambda',6.62607015e-34*299792458/(p['wavelength_nm']*1e-9),'J')
    calc('mean emitted optical power','mu*h*c/lambda*clock',p['mu']*6.62607015e-34*299792458/(p['wavelength_nm']*1e-9)*p['clock_hz'],'W')
    calc('noise mean per port/gate','(dark_hz+background_hz)*gate_ns*1e-9',noise,'counts/gate')
    calc('noise click probability per port','1-exp(-noise_mean)',-np.expm1(-noise))
    calc('mean residual phase visibility','visibility*exp(-phase_sigma_rad^2/2)',p['visibility']*np.exp(-p['phase_sigma_rad']**2/2))
    calc('Eve single-pulse discrimination error','(1-sqrt(1-exp(-4*mu*eve_eta)))/2',eve['helstrom_error'])
    calc('Eve-only expected differential error','2*f*e*(1-f*e); zero for none or beam-split',eve['expected_signal_qber'])
    calc('mean single click probability','mean((p0*(1-p1)+p1*(1-p0))*live)',expected_single)
    calc('expected error probability','mean(wrong_port_only_probability*live)',expected_error)
    calc('model QBER','expected_error / expected_single',qmodel)
    calc('model sifted rate','N/(N+1)*clock*expected_single',model_rate,'bits/s')
    calc('observed QBER','count(wrong accepted detector)/count(accepted singles)',qobserved)
    calc('observed sifted rate','accepted_singles / ((N+1)/clock)',observed_rate,'bits/s')
    calc('toy entropy cost','h2(model_QBER)',float(h2(qmodel)))
    calc('illustrative retained fraction','max(0,1-(1+fEC)*h2(Q)); zero above classroom threshold',budget)
    calc('illustrative postprocessing rate','model_sifted_rate*(1-test_fraction)*toy_fraction',heuristic,'bits/s')
    trace=pd.DataFrame(dict(slot=np.arange(1,n+1),alice_phase_previous=phases[:-1],alice_phase_current=phases[1:],
        alice_bit=alice,forwarded_bit=forwarded_key,eta_previous=eta[:-1],eta_current=eta[1:],
        phase_noise_rad=delta,nu0=nu0,nu1=nu1,p0=p0,p1=p1,click0=click0,click1=click1,
        accepted=single,bob_bit=np.where(single,bob,-1),error=errors,eve_estimate=eve['key']))
    if len(f['fade'])<100 and p['channel']!='Fiber':
        c['warnings'].append('Fewer than 100 independent fading blocks: sample moments and sweep curves can be noisy.')
    if hold:
        c['warnings'].append('Event holdoff is explicit; model rate uses a local stationary approximation which may differ for rapidly changing channels.')
    if f['clip_fraction']>0:
        c['warnings'].append('Some unbounded fading samples exceeded physical transmission 1 and were clipped; unit-mean fading does not imply unit-mean clipped transmission.')
    return dict(parameters=p,summary=summary,channel=c,fading=f,eve=eve,trace=trace,
                calculations=pd.DataFrame(c['ledger']),teaching_frame=encode_bytes(p['sample_hex']),
                alice_sifted=alice[indices],bob_sifted=bob[indices],test_indices=test_indices)

# %% Step 5: readable reports and charts
def print_report(r):
    """Print every formula/value, summary field and warnings, followed by a small real event trace."""
    print('\nDPS-QKD: '+r['parameters']['channel']+' | '+r['parameters']['eve_mode'])
    print(r['calculations'].to_string(index=False))
    print('\nRESULTS (rates are engineering estimates)')
    for key,value in r['summary'].items():
        print(f'{key:38s}: {value}')
    for note in r['channel']['warnings']:
        print('Model note:',note)
    print('\nFirst 12 detection opportunities (-1 means no retained bit):')
    print(r['trace'].head(12).to_string(index=False))


def plot_result(r):
    """Build six diagnostic plots with separate axes for quantities having different units."""
    fig,axs=plt.subplots(2,3,figsize=(16,9),constrained_layout=True)
    p,s,c,f=r['parameters'],r['summary'],r['channel'],r['fading']
    fig.suptitle(f"DPS-QKD | {p['channel']} | Eve: {p['eve_mode']} | illustrative engineering model")
    names=list(c['losses']); axs[0,0].bar(names,list(c['losses'].values()),color='#3477aa')
    axs[0,0].set(title='Nominal link budget',ylabel='Power loss (dB)')
    axs[0,0].tick_params(axis='x',rotation=25)
    axs[0,1].plot(f['eta_blocks'][:500],lw=1)
    axs[0,1].axhline(p['outage_eta'],color='red',ls='--',label='Outage threshold')
    axs[0,1].set(title='Atmospheric transmission blocks',xlabel='Independent block index',ylabel='Channel transmission')
    axs[0,1].legend()
    axs[0,2].hist(f['fade'],bins=35,density=True,color='#45a088')
    axs[0,2].set(title=f"{f['mode']} intensity fading",xlabel='Normalized intensity I',ylabel='Empirical density')
    t=r['teaching_frame'].head(24)
    axs[1,0].step(t.slot,t.Alice_key_bit,where='mid',label='Adjacent XOR = detector number')
    axs[1,0].set(title='DPS byte example (separate from random key)',xlabel='Valid slot',ylabel='Ideal key bit',yticks=[0,1])
    axs[1,1].bar(['Model','Observed'],[100*s['qber_model'],100*s['qber_observed']],color=['#3477aa','#45a088'])
    if np.isfinite(s['qber_observed']):
        q=s['qber_observed']
        axs[1,1].errorbar([1],[100*q],yerr=[[100*max(0,q-s['qber_wilson_low'])],[100*max(0,s['qber_wilson_high']-q)]],color='black',capsize=5)
    axs[1,1].axhline(100*p['abort_qber'],color='red',ls='--')
    axs[1,1].set(title='QBER (Wilson interval is descriptive)',ylabel='Errors (%)')
    axs[1,2].bar(['Sifted model','Sifted observed','Illustrative\npost-processing'],
                 [s['sifted_rate_model_bps'],s['sifted_rate_observed_bps'],s['illustrative_postprocessing_bps']])
    axs[1,2].set(title='Rates — no certified secret key',ylabel='bits/s')
    for ax in axs.flat:
        ax.grid(alpha=.2)
    return fig


def run_sweeps(p):
    """Sweep fiber length, horizontal length, satellite elevation, and both Eve attack strengths.

    Each point restarts the same seed to reduce unrelated Monte Carlo differences.
    Model rates average slot probabilities, so rare satellite clicks do not produce
    misleading zero-count curves. Curves still have finite fading-sample noise.
    """
    rows=[]; points=int(p['sweep_points'])
    setups=[('Fiber','fiber_km',np.linspace(0,p['fiber_sweep_max_km'],points)),
            ('FSO-Terrestrial','fso_km',np.linspace(.1,p['fso_sweep_max_km'],points)),
            ('Satellite-Ground','elevation_deg',np.linspace(10,90,points))]
    for channel,key,values in setups:
        for x in values:
            q=copy.deepcopy(p); q.update(channel=channel,n_slots=int(p['sweep_slots']))
            q[key]=float(x)
            r=simulate(q)
            rows.append(dict(sweep=channel,x=x,x_parameter=key,**{k:r['summary'][k] for k in
                ['qber_model','sifted_rate_model_bps','illustrative_postprocessing_bps','nominal_loss_db','rytov_variance','outage_fraction']}))
    for mode,key in [('phase-resend','eve_fraction'),('beam-split','eve_tap')]:
        for x in np.linspace(0,1,points):
            q=copy.deepcopy(p); q.update(eve_mode=mode,n_slots=int(p['sweep_slots']))
            q[key]=float(x); r=simulate(q)
            rows.append(dict(sweep='Eve '+mode,x=x,x_parameter=key,**{k:r['summary'][k] for k in
                ['qber_model','sifted_rate_model_bps','illustrative_postprocessing_bps','nominal_loss_db','rytov_variance','outage_fraction']}))
    return pd.DataFrame(rows)


def plot_sweeps(table):
    """Five sweep columns, showing QBER and rate separately; satellite x-axis is elevation."""
    groups=list(table.sweep.unique())
    fig,axs=plt.subplots(2,len(groups),figsize=(20,8),constrained_layout=True)
    for i,name in enumerate(groups):
        d=table[table.sweep==name]
        axs[0,i].plot(d.x,100*d.qber_model,'o-',ms=3)
        axs[0,i].set(title=name,ylabel='Model QBER (%)',xlabel=d.x_parameter.iloc[0])
        axs[1,i].plot(d.x,d.sifted_rate_model_bps,label='Sifted')
        axs[1,i].plot(d.x,d.illustrative_postprocessing_bps,label='Illustrative budget')
        axs[1,i].set(yscale='symlog',ylabel='bits/s (symlog)',xlabel=d.x_parameter.iloc[0])
        axs[1,i].legend(fontsize=8)
    for ax in axs.flat: ax.grid(alpha=.25)
    fig.suptitle('Parameter studies: finite atmospheric averaging; illustrative budget is not a secure-key bound')
    return fig


def plot_atmosphere(p):
    """Explain turbulence using HV altitude, horizontal length, elevation and SI curves.

    Each curve is deterministic. The SI plot compares two distribution models;
    lognormal is drawn only inside its weak-turbulence range.
    """
    fig,axs=plt.subplots(2,2,figsize=(12,8),constrained_layout=True)
    heights=np.linspace(p['ground_altitude_m'],p['atmosphere_top_m'],1001)
    axs[0,0].plot(hv_profile(heights,p),heights/1000)
    axs[0,0].set_xscale('symlog',linthresh=1e-20)
    axs[0,0].set(title='Hufnagel–Valley atmospheric profile',xlabel='Cn² (m⁻²ᐟ³)',ylabel='Altitude above sea level (km)')
    k=2*np.pi/(p['wavelength_nm']*1e-9)
    distances=np.linspace(.1,p['fso_sweep_max_km'],100)
    axs[0,1].plot(distances,1.23*p['fso_cn2']*k**(7/6)*(1000*distances)**(11/6))
    axs[0,1].axhline(1,color='red',ls='--')
    axs[0,1].set(title='Horizontal plane-wave Rytov variance',xlabel='Distance (km)',ylabel='σ_R² (dimensionless)')
    elevations=np.linspace(10,90,81)
    integ=trapezoid(hv_profile(heights,p)*(heights-heights[0])**(5/6),heights)
    axs[1,0].plot(elevations,2.25*k**(7/6)*np.sin(np.deg2rad(elevations))**(-11/6)*integ)
    axs[1,0].set(title='Satellite downlink Rytov variance',xlabel='Elevation (degrees)',ylabel='σ_R² (dimensionless)')
    ss=np.geomspace(.001,100,200)
    si=[turbulence_parameters(s)[2] for s in ss]
    axs[1,1].loglog(ss,si,label='Gamma-gamma')
    weak=ss<1
    axs[1,1].loglog(ss[weak],np.expm1(ss[weak]),'--',label='Lognormal (weak range)')
    axs[1,1].set(title='Distribution scintillation indices',xlabel='Rytov variance σ_R²',ylabel='SI = variance / mean²')
    axs[1,1].legend()
    for ax in axs.flat: ax.grid(alpha=.25)
    return fig


def export_result(r, directory='outputs/runtime/python', sweeps=None):
    """Save reproducible configuration, summary, all calculations, bit examples, events and plots."""
    folder=Path(directory); folder.mkdir(parents=True,exist_ok=True)
    (folder/'configuration.json').write_text(json.dumps(r['parameters'],indent=2),encoding='utf-8')
    pd.DataFrame([r['summary']]).to_csv(folder/'summary.csv',index=False)
    r['calculations'].to_csv(folder/'calculations.csv',index=False)
    r['teaching_frame'].to_csv(folder/'dps_byte_example.csv',index=False)
    r['trace'].head(200).to_csv(folder/'first_200_slots.csv',index=False)
    r['trace'][r['trace'].accepted].head(200).to_csv(folder/'first_200_detections.csv',index=False)
    pd.DataFrame({k:r['fading'][k] for k in ['eta_blocks','fade','pointing','offset','cloud']}).to_csv(folder/'fading_blocks.csv',index=False)
    fig=plot_result(r); fig.savefig(folder/'diagnostics.png',dpi=140); plt.close(fig)
    fig=plot_atmosphere(r['parameters']); fig.savefig(folder/'atmosphere.png',dpi=140); plt.close(fig)
    if sweeps is not None:
        sweeps.to_csv(folder/'sweeps.csv',index=False)
        fig=plot_sweeps(sweeps); fig.savefig(folder/'sweeps.png',dpi=140); plt.close(fig)
    return folder.resolve()

# %% Step 6: all-parameter runtime notebook controls
def runtime_controls(initial=None):
    """Create grouped widgets for EVERY parameter, with validation, run-all, sweeps and export.

    Also usable without widgets: edit the parameter dictionary and call simulate(p).
    No hidden callback state is required to reproduce an exported configuration.
    """
    import ipywidgets as widgets
    from IPython.display import display, clear_output
    p=default_parameters() if initial is None else copy.deepcopy(initial)
    controls={}; groups=list(dict.fromkeys(row['group'] for row in SCHEMA)); panels=[]
    for group in groups:
        children=[]
        for row in [r for r in SCHEMA if r['group']==group]:
            key=row['key']; value=p[key]
            if row['choices']:
                w=widgets.Dropdown(options=row['choices'],value=value)
            elif isinstance(value,str):
                w=widgets.Text(value=value)
            elif row['integer']:
                w=widgets.IntText(value=int(value))
            else:
                w=widgets.FloatText(value=float(value))
            w.layout.width='250px'; controls[key]=w
            children.append(widgets.HBox([widgets.HTML(f'<b>{key}</b><br>{row["unit"]}',layout=widgets.Layout(width='225px')),w,
                                          widgets.HTML(row['description'],layout=widgets.Layout(width='550px'))]))
        panels.append(widgets.VBox(children))
    tabs=widgets.Tab(children=panels)
    for i,group in enumerate(groups): tabs.set_title(i,group)
    out=widgets.Output(); state={}
    def action(kind):
        with out:
            clear_output(wait=True)
            try:
                q={key:w.value for key,w in controls.items()}; validate(q)
                if kind=='sweeps':
                    state['sweeps']=run_sweeps(q); display(state['sweeps']); fig=plot_sweeps(state['sweeps']); display(fig); plt.close(fig)
                elif kind=='export':
                    r=simulate(q)
                    print('Saved current configuration and result to',export_result(r))
                else:
                    for ch in (['Fiber','FSO-Terrestrial','Satellite-Ground'] if kind=='all' else [q['channel']]):
                        cfg=copy.deepcopy(q); cfg['channel']=ch; r=simulate(cfg); state['result']=r
                        print_report(r); display(r['teaching_frame'].head(16))
                        fig=plot_result(r); display(fig); plt.close(fig)
                    fig=plot_atmosphere(q); display(fig); plt.close(fig)
            except Exception as exc:
                print(type(exc).__name__+': '+str(exc))
    buttons=[]
    for label,kind in [('Run selected','selected'),('Compare all three','all'),('Run parameter/Eve sweeps','sweeps'),('Export current result','export')]:
        button=widgets.Button(description=label,layout=widgets.Layout(width='210px'))
        button.on_click(lambda _,kind=kind: action(kind)); buttons.append(button)
    display(tabs,widgets.HBox(buttons),out)
    return dict(controls=controls,state=state)


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config',help='Complete configuration JSON (see export_result)')
    parser.add_argument('--channel',choices=['Fiber','FSO-Terrestrial','Satellite-Ground'])
    parser.add_argument('--output',default='outputs/runtime/python')
    parser.add_argument('--sweeps',action='store_true')
    args=parser.parse_args()
    cfg=json.loads(Path(args.config).read_text()) if args.config else default_parameters()
    if args.channel: cfg['channel']=args.channel
    result=simulate(cfg); print_report(result)
    sweep_table=run_sweeps(cfg) if args.sweeps else None
    print('Saved:',export_result(result,args.output,sweep_table))
