function result = dps_qkd_simulator(varargin)
% Detailed DPS-QKD school project. No add-on Octave packages required.
% Read THEORY.md for equations, worked examples and approximation limits.
% dps_qkd_simulator()                  Full runtime parameter editor
% p = dps_qkd_simulator('defaults')    Get all editable parameters
% r = dps_qkd_simulator(p, false)      Run + detailed report, no plots
% r = dps_qkd_simulator(p, true)       Run + detailed report + plots
% r = dps_qkd_simulator('quiet', p)    Run silently for experiments
% t = dps_qkd_simulator('sweeps', p)   Five parameter/Eve studies + plots
% dps_qkd_simulator('export', p, dir)  Save configuration, tables and PNG
% dps_qkd_simulator('console')        Text-only all-parameter editor
% dps_qkd_simulator('selftest')       Verify physical limiting cases
% Legacy: dps_qkd_simulator('Fiber',20,0.2,false)
% Legacy Satellite-Ground distance now explicitly means ALTITUDE in km.
  if nargin==0, open_editor(); result=[]; return; end
  arg=varargin{1};
  if isstruct(arg)
    result=simulate(arg); print_report(result);
    if nargin<2 || varargin{2}, plot_result(result); end
  elseif strcmp(arg,'defaults'), result=defaults();
  elseif strcmp(arg,'quiet'), result=simulate(varargin{2});
  elseif strcmp(arg,'channel'), result=channel_model(varargin{2});
  elseif strcmp(arg,'encode'), result=encode_bytes(varargin{2});
  elseif strcmp(arg,'atmosphere'), result=plot_atmosphere(varargin{2});
  elseif strcmp(arg,'console'), result=console_editor();
  elseif strcmp(arg,'selftest'), result=selftest();
  elseif strcmp(arg,'sweeps')
    result=run_sweeps(varargin{2}); disp(result); plot_sweeps(result);
  elseif strcmp(arg,'export-sweeps')
    result=run_sweeps(varargin{2}); folder=varargin{3};
    if ~exist(folder,'dir'), mkdir(folder); end
    write_numeric_csv(fullfile(folder,'sweeps.csv'),{'group','x','qber_model','sifted_rate_model_bps','illustrative_postprocessing_bps','nominal_loss_db','rytov_variance','outage_fraction'},result);
    fig=plot_sweeps(result); print(fig,fullfile(folder,'sweeps.png'),'-dpng','-r120'); close(fig);
  elseif strcmp(arg,'export')
    result=simulate(varargin{2}); export_result(result,varargin{3});
  elseif nargin==4
    p=defaults(); p.channel=arg;
    if strcmpi(arg,'Terrestrial FSO'), p.channel='FSO-Terrestrial'; end
    if strcmp(p.channel,'Fiber'), p.fiber_km=varargin{2};
    elseif strcmp(p.channel,'FSO-Terrestrial'), p.fso_km=varargin{2};
    elseif strcmp(p.channel,'Satellite-Ground'), p.sat_altitude_km=varargin{2}; end
    p.eve_fraction=varargin{3}; if p.eve_fraction>0, p.eve_mode='phase-resend'; end
    result=simulate(p); print_report(result); if varargin{4}, plot_result(result); end
  else, error('Unknown command. Type help dps_qkd_simulator.'); end
end

% ================= STEP 0: PARAMETERS AND SMALL HELPERS =================
function s=schema()
% Read the shared catalogue: parameter groups, units, help text and limits.
  s=jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')),'parameters.json')));
end

function p=defaults()
% Return a fresh configuration; experiments can modify it independently.
  s=schema(); p=struct();
  for i=1:numel(s), p.(s(i).key)=s(i).default; end
end

function validate(p)
% Reject invalid values and inconsistent detector timing before calculation.
  s=schema();
  if numel(fieldnames(p))~=numel(s), error('Configuration keys must match parameters.json.'); end
  for i=1:numel(s)
    row=s(i); key=row.key;
    if ~isfield(p,key), error('Missing parameter: %s',key); end
    v=p.(key);
    if ~isempty(row.choices)
      if ~ischar(v) || ~any(strcmp(v,row.choices)), error('Invalid selection for %s.',key); end
    elseif ischar(row.default)
      if ~ischar(v), error('%s must be text.',key); end
    else
      if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v), error('%s must be finite numeric scalar.',key); end
      if row.integer && fix(v)~=v, error('%s must be an integer.',key); end
      if ~isempty(row.minimum) && v<row.minimum, error('%s must be >= %g.',key,row.minimum); end
      if ~isempty(row.maximum) && v>row.maximum, error('%s must be <= %g.',key,row.maximum); end
    end
  end
  parse_hex(p.sample_hex);
  if p.gate_ns*1e-9>(1/p.clock_hz)*(1+1e-12), error('gate_ns must be <= 1e9/clock_hz.'); end
  if p.ground_altitude_m>=min(p.atmosphere_top_m,p.sat_altitude_km*1000)
    error('Ground altitude must be below atmosphere top and satellite.');
  end
end

function b=parse_hex(txt)
% Read space-separated hexadecimal bytes without silently truncating input.
  tokens=strsplit(strtrim(txt)); b=zeros(1,numel(tokens));
  for i=1:numel(tokens)
    if isempty(regexp(tokens{i},'^[0-9a-fA-F]{1,2}$','once')), error('Use hex bytes such as A5 3C 00 FF.'); end
    b(i)=hex2dec(tokens{i});
  end
end

function frame=encode_bytes(txt)
% Bytes become MSB-first PULSE PHASE bits; adjacent XORs become DPS key bits.
% Columns: slot, previous phase bit, current phase bit, key, delta_rad, D.
  bytes=parse_hex(txt); bits=zeros(1,8*numel(bytes));
  for i=1:numel(bytes)
    for j=1:8, bits((i-1)*8+j)=bitget(uint8(bytes(i)),9-j); end
  end
  key=xor(bits(1:end-1),bits(2:end));
  frame=[(1:numel(key))' bits(1:end-1)' bits(2:end)' double(key)' pi*double(key)' double(key)'];
end

function y=h2(q)
% Binary entropy in bits. Endpoint convention: 0*log2(0)=0.
  x=min(max(q,1e-15),1-1e-15); y=-x.*log2(x)-(1-x).*log2(1-x);
  y(q==0 | q==1)=0; y(isnan(q))=NaN;
end

function ci=wilson(errors,count)
% Descriptive 95% binomial interval; NOT a DPS finite-key security bound.
  if count==0, ci=[NaN NaN]; return; end
  z=1.959963984540054; q=errors/count; d=1+z*z/count;
  mid=(q+z*z/(2*count))/d; half=z*sqrt(q*(1-q)/count+z*z/(4*count^2))/d;
  ci=[max(0,mid-half) min(1,mid+half)];
end

function y=hv_profile(h,p)
% Altitude h in metres above sea level; Cn2 output has units m^(-2/3).
  y=p.hv_scale*(0.00594*(p.hv_wind_m_s/27)^2*(1e-5*h).^10.*exp(-h/1000) ...
     +2.7e-16*exp(-h/1500)+p.hv_A*exp(-h/100));
end

function [alpha,beta,si]=turbulence_parameters(s)
% s means Rytov VARIANCE sigma_R^2, so sigma_R^(12/5) means s^(6/5).
  if s<1e-12, alpha=Inf; beta=Inf; si=0; return; end
  alpha=1/expm1(0.49*s/(1+1.11*s^(6/5))^(7/6));
  beta=1/expm1(0.51*s/(1+0.69*s^(6/5))^(5/6));
  si=1/alpha+1/beta+1/(alpha*beta);
end

% ================= STEP 1: THREE CHANNEL CALCULATIONS ===================
function c=channel_model(p)
% Independent Fiber, terrestrial FSO and satellite DOWNLINK physics sections.
% rec() records each formula, substituted numerical result and unit.
  validate(p); ledger=cell(0,4); notes={};
  lam=rec('wavelength','wavelength_nm * 1e-9',p.wavelength_nm*1e-9,'m');
  k=rec('wavenumber','2*pi/lambda',2*pi/lam,'rad/m');
  period=rec('pulse separation','1/clock_hz',1/p.clock_hz,'s');
  rec('interferometer free-space path difference','c/clock; divide by group index in material',299792458*period,'m');
  c.profile_h=[]; c.profile_cn2=[]; sigma_ps=p.pulse_sigma_ps;
  if strcmp(p.channel,'Fiber')
    % Fiber: power loss in dB adds; broadening reduces temporal gate capture.
    L=p.fiber_km*1000;
    names={'attenuation','connectors','splices','other fiber'};
    values=[p.fiber_alpha_db_km*p.fiber_km,p.connector_db,p.splice_count*p.splice_db,p.fiber_misc_db];
    formulas={'alpha_dB_per_km*L_km','connector_db','splice_count*splice_db','fiber_misc_db'};
    for i=1:numel(values), rec([names{i} ' loss'],formulas{i},values(i),'dB'); end
    broaden=rec('dispersion RMS broadening','abs(D)*L_km*spectral_sigma_nm',abs(p.dispersion_ps_nm_km)*p.fiber_km*p.spectral_sigma_nm,'ps');
    sigma_ps=rec('received pulse RMS width','sqrt(sigma_initial^2 + broadening^2)',hypot(sigma_ps,broaden),'ps');
    s=0; r0=Inf; c.w=0; c.aperture_radius=0; c.pointing_sigma=0; c.geom=1;
  else
    sat=strcmp(p.channel,'Satellite-Ground');
    if sat
      % Curved Earth sets optical range; only the atmosphere contributes Cn2.
      pre='sat'; e=p.elevation_deg*pi/180;
      Rg=p.earth_radius_km*1000+p.ground_altitude_m;
      Rs=(p.earth_radius_km+p.sat_altitude_km)*1000;
      L=rec('slant range','sqrt(Rs^2-Rg^2*cos(e)^2)-Rg*sin(e)',sqrt(Rs^2-Rg^2*cos(e)^2)-Rg*sin(e),'m');
      h=linspace(p.ground_altitude_m,min(p.atmosphere_top_m,p.sat_altitude_km*1000),2001);
      cn=hv_profile(h,p);
      integral_weighted=rec('weighted turbulence integral','trapz(h,Cn2(h)*(h-h_ground)^(5/6))',trapz(h,cn.*(h-h(1)).^(5/6)),'m^(7/6)');
      s=rec('Rytov variance','2.25*k^(7/6)*sin(e)^(-11/6)*weighted_integral',2.25*k^(7/6)*sin(e)^(-11/6)*integral_weighted,'-');
      j=rec('slant Cn2 integral','trapz(h,Cn2)/sin(e)',trapz(h,cn)/sin(e),'m^(1/3)');
      rec('atmospheric path approximation','(h_top-h_ground)/sin(e)',(h(end)-h(1))/sin(e),'m');
      extinction=p.sat_zenith_extinction_db/sin(e); c.profile_h=h; c.profile_cn2=cn;
    else
      % Uniform horizontal atmosphere: Rytov variance grows as L^(11/6).
      pre='fso'; L=p.fso_km*1000;
      s=rec('Rytov variance','1.23*Cn2*k^(7/6)*L^(11/6)',1.23*p.fso_cn2*k^(7/6)*L^(11/6),'-');
      j=p.fso_cn2*L; extinction=p.fso_extinction_db_km*p.fso_km;
    end
    if j>0, r0=(0.423*k*k*j)^(-3/5); else, r0=Inf; end
    rec('Fried coherence diameter','(0.423*k^2*integral(Cn2 ds))^(-3/5)',r0,'m');
    theta=rec('effective divergence half-angle','max(input_urad*1e-6,lambda/(pi*w0))',max(p.([pre '_divergence_urad'])*1e-6,lam/(pi*p.([pre '_waist_m']))),'rad');
    w=rec('beam radius at receiver','sqrt(w0^2+(theta*L)^2)',hypot(p.([pre '_waist_m']),theta*L),'m');
    a=p.([pre '_aperture_m'])/2;
    geom=rec('centered Gaussian aperture capture','1-exp(-2*a^2/w^2)',-expm1(-2*(a/w)^2),'-');
    ps=rec('per-axis spot jitter','L*pointing_urad*1e-6',L*p.([pre '_pointing_urad'])*1e-6,'m');
    names={'aperture','extinction','optics'}; values=[-10*log10(geom),extinction,p.([pre '_optics_db'])];
    for i=1:3, rec([names{i} ' loss'],'power loss dB; extinction scales with path/airmass',values(i),'dB'); end
    c.w=w; c.aperture_radius=a; c.pointing_sigma=ps; c.geom=geom;
    notes{end+1}='Point-receiver scintillation: aperture averaging, turbulence beam wander and adaptive optics are not modeled.';
    if strcmp(p.fading_model,'lognormal') && s>=1, notes{end+1}='Forced lognormal beyond weak turbulence is an illustrative extrapolation.'; end
  end
  capture=rec('temporal gate capture','erf(gate_s/(2*sqrt(2)*sigma_s))',erf(p.gate_ns*1e-9/(2*sqrt(2)*sigma_ps*1e-12)),'-');
  if sigma_ps*1e-12>period/6, notes{end+1}='Pulse width > T/6: intersymbol interference may matter; only gate loss is modeled.'; end
  rec('channel length','physical propagation length',L,'m');
  total=rec('nominal channel loss','sum(named losses), excluding random pointing/cloud/fading',sum(values),'dB');
  eta0=rec('nominal channel transmission','10^(-loss_dB/10)',10^(-total/10),'-');
  [alpha,beta,si]=turbulence_parameters(s);
  rec('gamma-gamma alpha','1/expm1(0.49*s/(1+1.11*s^(6/5))^(7/6))',alpha,'-');
  rec('gamma-gamma beta','1/expm1(0.51*s/(1+0.69*s^(6/5))^(5/6))',beta,'-');
  rec('gamma-gamma scintillation index','1/alpha+1/beta+1/(alpha*beta)',si,'-');
  c.length_m=L; c.loss_names=names; c.loss_values=values; c.total_loss_db=total;
  c.eta0=eta0; c.gate_capture=capture; c.rytov=s; c.r0=r0; c.alpha=alpha; c.beta=beta; c.si=si;
  c.ledger=ledger; c.warnings=notes;
  function value=rec(name,formula,value,unit)
  % Nested recorder captures the ledger without global variables.
    ledger(end+1,:)={name,formula,value,unit};
  end
end

% ================= STEP 2: ATMOSPHERIC FADING AND POINTING ===============
function capture=displaced_aperture(a,w,r)
% Exact aperture integral of a displaced Gaussian: equivalent to ncx2 CDF.
% Spot sigma=w/2. Radius is Rice distributed. Scaled besseli avoids overflow.
% Integrate within 10 standard deviations; omitted probability is negligible.
  capture=zeros(size(r)); upper=2*a/w;
  for i=1:numel(r)
    rho=2*r(i)/w;
    if rho==0, capture(i)=-expm1(-2*(a/w)^2);
    elseif upper>=rho+10, capture(i)=1;
    elseif upper<=rho-10, capture(i)=0;
    else
      lo=max(0,rho-10); hi=min(upper,rho+10);
      fun=@(z) z.*exp(-0.5*(z-rho).^2).*besseli(0,z*rho,1);
      capture(i)=quadgk(fun,lo,hi,'AbsTol',1e-13,'RelTol',1e-9);
    end
  end
  capture=min(max(capture,0),1);
end

function f=draw_channel(p,c)
% Unit-mean intensity per block, pointing jitter and opaque clouds.
% Clamp final transmission at 1 and report how often clipping was necessary.
  n=p.n_slots+1; nb=ceil(n/p.block_slots); mode=p.fading_model;
  if strcmp(p.channel,'Fiber') || c.rytov<1e-12, mode='none';
  elseif strcmp(mode,'auto')
    if c.rytov<1, mode='lognormal'; else, mode='gamma-gamma'; end
  end
  if strcmp(mode,'none'), fade=ones(1,nb); theory=0;
  elseif strcmp(mode,'lognormal'), fade=exp(sqrt(c.rytov)*randn(1,nb)-c.rytov/2); theory=expm1(c.rytov);
  else, fade=(randg(c.alpha,1,nb)/c.alpha).*(randg(c.beta,1,nb)/c.beta); theory=c.si; end
  pointing=ones(1,nb); offset=zeros(1,nb); cloud=false(1,nb);
  if ~strcmp(p.channel,'Fiber')
    offset=hypot(c.pointing_sigma*randn(1,nb),c.pointing_sigma*randn(1,nb));
    pointing=min(max(displaced_aperture(c.aperture_radius,c.w,offset)/c.geom,0),1);
    cloud=rand(1,nb)<p.cloud_probability;
  end
  raw=c.eta0*fade.*pointing.*(~cloud); eb=min(max(raw,0),1);
  eta=repelem(eb,p.block_slots); eta=eta(1:n);
  f=struct('eta',eta,'eta_blocks',eb,'fade',fade,'pointing',pointing,'offset',offset, ...
    'cloud',cloud,'mode',mode,'theoretical_si',theory,'clip_fraction',mean(raw>1));
end

% ================= STEP 3: TWO EXPLICIT EVE ATTACKS ======================
function eve=eve_attack(phases,p)
% Phase-resend: Helstrom discrimination with a perfect external optical phase
% reference, followed by equal-intensity coherent pulse re-preparation.
% Beam-split: ideal DPS detector on tapped power t, Bob receives (1-t).
% Neither attack model is a general DPS security analysis.
  n=numel(phases); key=xor(phases(1:end-1),phases(2:end));
  e=(1-sqrt(-expm1(-4*p.mu*p.eve_eta)))/2;
  attacked=false(1,n); estimates=-ones(1,n); known=false(1,n-1);
  evekey=-ones(1,n-1); flips=false(1,n); multiplier=1; expected=0;
  if strcmp(p.eve_mode,'phase-resend')
    attacked=rand(1,n)<p.eve_fraction; guess_error=rand(1,n)<e;
    estimates(attacked)=xor(phases(attacked),guess_error(attacked)); flips=attacked & guess_error;
    known=attacked(1:end-1)&attacked(2:end);
    guesses=xor(estimates(1:end-1)>0,estimates(2:end)>0); evekey(known)=guesses(known);
    expected=2*p.eve_fraction*e*(1-p.eve_fraction*e);
  elseif strcmp(p.eve_mode,'beam-split')
    multiplier=1-p.eve_tap; known=rand(1,n-1)<-expm1(-p.mu*p.eve_tap*p.eve_eta);
    evekey(known)=key(known);
  end
  eve=struct('forwarded',xor(phases,flips),'flips',flips,'attacked',attacked, ...
    'estimates',estimates,'known',known,'key',evekey,'multiplier',multiplier, ...
    'helstrom_error',e,'expected_signal_qber',expected);
end

% ================= STEP 4: INTERFERENCE AND PHOTON COUNTING ==============
function r=simulate(p)
% Explicit two-port events, double-click rejection and shared receiver holdoff.
% Model rates average ALL opportunities. No BB84 1/2 basis-sifting factor.
  validate(p); rng(p.seed,'twister'); randg('state',p.seed);
  c=channel_model(p); f=draw_channel(p,c); n=p.n_slots;
  phases=rand(1,n+1)<0.5; alice=xor(phases(1:end-1),phases(2:end));
  eve=eve_attack(phases,p); eta=f.eta*eve.multiplier;
  common=p.mu*p.detector_eta*p.coupling_eta*10^(-p.interferometer_loss_db/10)*c.gate_capture/4;
  delta=p.phase_sigma_rad*randn(1,n); forwarded=xor(eve.forwarded(1:end-1),eve.forwarded(2:end));
  cross=2*p.visibility*sqrt(eta(1:end-1).*eta(2:end)).*cos(pi*double(forwarded)+delta);
  nu0=max(0,common*(eta(1:end-1)+eta(2:end)+cross));
  nu1=max(0,common*(eta(1:end-1)+eta(2:end)-cross));
  noise=(p.dark_hz+p.background_hz)*p.gate_ns*1e-9;
  p0=-expm1(-(nu0+noise)); p1=-expm1(-(nu1+noise));
  only0=p0.*(1-p1); only1=p1.*(1-p0); psingle=only0+only1; pdouble=p0.*p1;
  pany=psingle+pdouble; perror=only1; perror(alice)=only0(alice);
  hold=ceil(p.dead_time_ns*1e-9*p.clock_hz);
  live=1./(1+hold*pany); expected_single=mean(psingle.*live); expected_error=mean(perror.*live);
  qm=NaN; if expected_single>0, qm=expected_error/expected_single; end
  click0=rand(1,n)<p0; click1=rand(1,n)<p1; live_mask=true(1,n);
  if hold>0
    last=-hold-1;
    for i=find(click0|click1)
      if i-last<=hold, live_mask(i)=false; else, last=i; end
    end
  end
  single=xor(click0,click1)&live_mask; doubles=click0&click1&live_mask;
  bob=click1; indices=find(single); errors=(bob~=alice)&single;
  count=sum(single); nerr=sum(errors); qo=NaN; if count>0, qo=nerr/count; end
  duration=(n+1)/p.clock_hz; model_rate=n*expected_single/duration; observed_rate=count/duration;
  nt=floor(count*p.test_fraction); test_indices=[];
  if nt>0, test_indices=indices(randperm(count,nt)); end
  test_errors=sum(errors(test_indices)); test_q=NaN; if nt>0, test_q=test_errors/nt; end
  ci=wilson(nerr,count); tci=wilson(test_errors,nt); status='INSUFFICIENT TEST DATA';
  if nt>0 && test_q>p.abort_qber, status='ABORT: test QBER above classroom threshold';
  elseif nt>0 && tci(2)<=p.abort_qber, status='PASS classroom QBER check (not security certification)'; end
  budget=0; if isfinite(qm) && qm<=p.abort_qber, budget=max(0,1-(1+p.ec_efficiency)*h2(qm)); end
  heuristic=model_rate*(1-p.test_fraction)*budget;
  known=single&eve.known; known_count=sum(known); agreement=NaN;
  if known_count>0, agreement=mean(eve.key(known)==alice(known)); end
  s=struct('channel',p.channel,'fading',f.mode,'length_km',c.length_m/1000, ...
    'nominal_loss_db',c.total_loss_db,'rytov_variance',c.rytov,'fried_r0_m',c.r0, ...
    'fading_blocks',numel(f.fade),'block_duration_s',p.block_slots/p.clock_hz, ...
    'duration_s',duration,'fading_mean',mean(f.fade),'fading_si_sample',var(f.fade,1)/mean(f.fade)^2, ...
    'fading_si_theory',f.theoretical_si,'mean_channel_eta',mean(f.eta), ...
    'outage_fraction',mean(f.eta<p.outage_eta),'transmission_clip_fraction',f.clip_fraction, ...
    'click_probability_before_holdoff',mean(pany),'expected_single_probability',expected_single, ...
    'detected_sifted_bits',count,'errors',nerr,'double_clicks',sum(doubles), ...
    'qber_model',qm,'qber_observed',qo,'qber_wilson_low',ci(1),'qber_wilson_high',ci(2), ...
    'sifted_rate_model_bps',model_rate,'sifted_rate_observed_bps',observed_rate, ...
    'test_bits',nt,'test_qber',test_q,'test_wilson_low',tci(1),'test_wilson_high',tci(2), ...
    'unrevealed_bits',count-nt,'classroom_status',status,'eve_mode',p.eve_mode, ...
    'eve_single_phase_error',eve.helstrom_error,'eve_signal_qber_expected',eve.expected_signal_qber, ...
    'eve_estimated_sifted_bits',known_count,'eve_estimate_agreement',agreement, ...
    'toy_retained_fraction',budget,'illustrative_postprocessing_bps',heuristic, ...
    'certified_secret_key_bps','NOT COMPUTED: no DPS security proof / finite-key analysis');
  ledger=c.ledger;
  rec('source photon energy','h*c/lambda',6.62607015e-34*299792458/(p.wavelength_nm*1e-9),'J');
  rec('mean emitted optical power','mu*h*c/lambda*clock',p.mu*6.62607015e-34*299792458/(p.wavelength_nm*1e-9)*p.clock_hz,'W');
  rec('noise mean per port/gate','(dark_hz+background_hz)*gate_ns*1e-9',noise,'counts/gate');
  rec('noise click probability per port','1-exp(-noise_mean)',-expm1(-noise),'-');
  rec('mean residual phase visibility','visibility*exp(-phase_sigma_rad^2/2)',p.visibility*exp(-p.phase_sigma_rad^2/2),'-');
  rec('Eve single-pulse discrimination error','(1-sqrt(1-exp(-4*mu*eve_eta)))/2',eve.helstrom_error,'-');
  rec('Eve-only expected differential error','2*f*e*(1-f*e); zero for none/beam-split',eve.expected_signal_qber,'-');
  rec('mean single click probability','mean((p0*(1-p1)+p1*(1-p0))*live)',expected_single,'-');
  rec('expected error probability','mean(wrong_port_only_probability*live)',expected_error,'-');
  rec('model QBER','expected_error / expected_single',qm,'-');
  rec('model sifted rate','N/(N+1)*clock*expected_single',model_rate,'bits/s');
  rec('observed QBER','wrong accepted bits / accepted singles',qo,'-');
  rec('observed sifted rate','accepted_singles/((N+1)/clock)',observed_rate,'bits/s');
  rec('toy entropy cost','h2(model_QBER)',h2(qm),'-');
  rec('illustrative retained fraction','max(0,1-(1+fEC)*h2(Q)); zero above threshold',budget,'-');
  rec('illustrative postprocessing rate','model_sifted_rate*(1-test_fraction)*toy_fraction',heuristic,'bits/s');
  c.ledger=ledger;
  trace_names={'slot','alice_phase_previous','alice_phase_current','alice_bit','forwarded_bit', ...
    'eta_previous','eta_current','phase_noise_rad','nu0','nu1','p0','p1','click0','click1','accepted','bob_bit','error','eve_estimate'};
  bob_out=double(bob); bob_out(~single)=-1;
  trace=[(1:n)' double(phases(1:end-1))' double(phases(2:end))' double(alice)' double(forwarded)' ...
    eta(1:end-1)' eta(2:end)' delta' nu0' nu1' p0' p1' double(click0)' double(click1)' ...
    double(single)' bob_out' double(errors)' eve.key'];
  if numel(f.fade)<100 && ~strcmp(p.channel,'Fiber'), c.warnings{end+1}='Fewer than 100 independent fading blocks: sample moments/curves can be noisy.'; end
  if hold>0, c.warnings{end+1}='Event holdoff is explicit; model rate uses a local stationary approximation.'; end
  if f.clip_fraction>0, c.warnings{end+1}='Unbounded fading exceeded transmission 1; physical clipping changes the mean.'; end
  r=struct('parameters',p,'summary',s,'channel',c,'fading',f,'eve',eve,'trace',trace, ...
    'trace_names',{trace_names},'calculations',{ledger},'teaching_frame',encode_bytes(p.sample_hex), ...
    'alice_sifted',double(alice(indices)),'bob_sifted',double(bob(indices)),'test_indices',test_indices);
  function rec(name,formula,value,unit)
  % Append detector/post-processing calculations to the channel ledger.
    ledger(end+1,:)={name,formula,value,unit};
  end
end

% ================= STEP 5: REPORTS AND GRAPHICAL OUTPUT ==================
function lines=report_lines(r)
% Convert the complete calculation ledger and result structure to readable text.
  lines={sprintf('DPS-QKD | %s | Eve: %s',r.parameters.channel,r.parameters.eve_mode)};
  for i=1:size(r.calculations,1)
    row=r.calculations(i,:); lines{end+1}=sprintf('%s = %.10g %s ; %s',row{1},row{3},row{4},row{2});
  end
  lines{end+1}='RESULTS: engineering estimates, not certified secret keys'; names=fieldnames(r.summary);
  for i=1:numel(names)
    v=r.summary.(names{i}); if isnumeric(v), txt=sprintf('%.10g',v); else, txt=v; end
    lines{end+1}=sprintf('%s: %s',names{i},txt);
  end
  for i=1:numel(r.channel.warnings), lines{end+1}=['Model note: ' r.channel.warnings{i}]; end
end

function print_report(r)
% Include byte conversion and real detection events so each stage is inspectable.
  lines=report_lines(r); for i=1:numel(lines), fprintf('%s\n',lines{i}); end
  fprintf('\nByte example: slot, previous phase, current phase, key, delta_rad, detector\n'); disp(r.teaching_frame);
  fprintf('First 12 slots: %s\n',strjoin(r.trace_names,', ')); disp(r.trace(1:min(12,end),:));
  fprintf('First 12 retained detections (if any):\n'); idx=find(r.trace(:,15)); disp(r.trace(idx(1:min(12,end)),:));
end

function fig=plot_result(r)
% Six separate diagnostic plots; quantities with different units have separate axes.
  fig=new_figure('Name',['DPS-QKD | ' r.parameters.channel ' | ' r.parameters.eve_mode], ...
    'NumberTitle','off','Position',[40 40 1400 800]);
  c=r.channel; f=r.fading; s=r.summary; p=r.parameters;
  labels=c.loss_names;
  if strcmp(p.channel,'Fiber'), labels={'Fiber','Connectors','Splices','Other'}; end
  subplot(2,3,1); bar(c.loss_values); set(gca,'xtick',1:numel(labels),'xticklabel',labels);
  ylabel('Power loss (dB)'); title('Nominal link budget'); grid on;
  set(gca,'xticklabelrotation',20);
  subplot(2,3,2); plot(f.eta_blocks(1:min(500,end))); hold on;
  plot([1 max(2,min(500,numel(f.eta_blocks)))],[p.outage_eta p.outage_eta],'r--');
  xlabel('Independent block index'); ylabel('Channel transmission'); title('Atmospheric transmission'); grid on;
  subplot(2,3,3);
  if all(f.fade==1), bar(1,numel(f.fade)); xlim([.5 1.5]); else, hist(f.fade,35); end
  xlabel('Normalized intensity I'); ylabel('Block count'); title([f.mode ' fading']); grid on;
  subplot(2,3,4); t=r.teaching_frame(1:min(24,end),:); stairs(t(:,1),t(:,4)); ylim([-0.1 1.1]);
  xlabel('Valid slot'); ylabel('Ideal key bit'); title('Separate DPS byte example'); grid on;
  subplot(2,3,5); bar(100*[s.qber_model s.qber_observed]); hold on;
  if isfinite(s.qber_observed)
    h=errorbar(2,100*s.qber_observed,100*max(0,s.qber_observed-s.qber_wilson_low),100*max(0,s.qber_wilson_high-s.qber_observed));
    set(h,'linestyle','none','color','k');
  end
  plot([0.5 2.5],100*[p.abort_qber p.abort_qber],'r--');
  set(gca,'xtick',[1 2],'xticklabel',{'Model','Observed'}); ylabel('Errors (%)'); title('QBER: descriptive Wilson interval'); grid on;
  subplot(2,3,6); bar([s.sifted_rate_model_bps s.sifted_rate_observed_bps s.illustrative_postprocessing_bps]);
  set(gca,'xtick',[1 2 3],'xticklabel',{'Sifted model','Observed','Toy budget'});
  set(gca,'xticklabelrotation',20);
  ylabel('bits/s'); title('No certified secret key rate'); grid on;
end

function t=run_sweeps(p)
% Columns: group, x, QBER, sifted bps, toy bps, loss dB, Rytov, outage.
% Restart seed per point; rates average probabilities, not selected detections.
  points=p.sweep_points; t=zeros(5*points,8); row=0;
  for group=1:5
    if group==1, values=linspace(0,p.fiber_sweep_max_km,points);
    elseif group==2, values=linspace(.1,p.fso_sweep_max_km,points);
    elseif group==3, values=linspace(10,90,points);
    else, values=linspace(0,1,points); end
    for x=values
      q=p; q.n_slots=p.sweep_slots;
      if group==1, q.channel='Fiber'; q.fiber_km=x;
      elseif group==2, q.channel='FSO-Terrestrial'; q.fso_km=x;
      elseif group==3, q.channel='Satellite-Ground'; q.elevation_deg=x;
      elseif group==4, q.eve_mode='phase-resend'; q.eve_fraction=x;
      else, q.eve_mode='beam-split'; q.eve_tap=x; end
      r=simulate(q); s=r.summary; row=row+1;
      t(row,:)=[group,x,s.qber_model,s.sifted_rate_model_bps,s.illustrative_postprocessing_bps,s.nominal_loss_db,s.rytov_variance,s.outage_fraction];
    end
  end
end

function fig=plot_sweeps(t)
% Satellite horizontal axis is elevation, explicitly distinct from fiber distance.
  fig=new_figure('Name','DPS parameter studies: engineering estimates','Position',[20 20 1600 750]);
  titles={'Fiber','FSO-Terrestrial','Satellite-Ground','Eve phase-resend','Eve beam-split'};
  xlabels={'Length (km)','Length (km)','Elevation (degrees)','Intercept probability','Power tap fraction'};
  for i=1:5
    d=t(t(:,1)==i,:);
    subplot(2,5,i); plot(d(:,2),100*d(:,3),'o-'); title(titles{i}); xlabel(xlabels{i}); ylabel('QBER (%)'); grid on;
    subplot(2,5,i+5); plot(d(:,2),d(:,4)); hold on; plot(d(:,2),d(:,5));
    xlabel(xlabels{i}); ylabel('bits/s'); legend('Sifted','Toy budget'); grid on;
  end
end

function write_numeric_csv(path,names,data)
% Write headers and 17-digit numbers for reproducible external comparisons.
  fid=fopen(path,'w'); if fid<0, error('Cannot write %s',path); end
  fprintf(fid,'%s\n',strjoin(names,',')); fclose(fid);
  dlmwrite(path,data,'-append','delimiter',',','precision','%.17g');
end

function fig=plot_atmosphere(p)
% Deterministic turbulence diagrams explain how altitude/path/elevation affect s.
  validate(p); fig=new_figure('Name','Atmospheric turbulence calculations','Position',[40 40 1200 800]);
  h=linspace(p.ground_altitude_m,p.atmosphere_top_m,1001); cn=hv_profile(h,p);
  k=2*pi/(p.wavelength_nm*1e-9);
  subplot(2,2,1); semilogx(max(cn,1e-25),h/1000); xlabel('Cn2 (m^{-2/3}; display floor 1e-25)');
  ylabel('Altitude above sea level (km)'); title('Hufnagel-Valley profile'); grid on;
  L=linspace(.1,p.fso_sweep_max_km,100);
  subplot(2,2,2); plot(L,1.23*p.fso_cn2*k^(7/6)*(1000*L).^(11/6));
  xlabel('Distance (km)'); ylabel('Rytov variance'); title('Horizontal turbulence'); grid on;
  e=linspace(10,90,81); j=trapz(h,cn.*(h-h(1)).^(5/6));
  subplot(2,2,3); plot(e,2.25*k^(7/6)*sin(e*pi/180).^(-11/6)*j);
  xlabel('Elevation (degrees)'); ylabel('Rytov variance'); title('Satellite downlink turbulence'); grid on;
  ss=logspace(-3,2,200); si=zeros(size(ss));
  for i=1:numel(ss), [a,b,si(i)]=turbulence_parameters(ss(i)); end
  subplot(2,2,4); loglog(ss,si); hold on; weak=ss<1; loglog(ss(weak),expm1(ss(weak)),'--');
  xlabel('Rytov variance'); ylabel('Scintillation index'); title('Fading distribution comparison');
  legend('Gamma-gamma','Lognormal (weak range)'); grid on;
end

function export_result(r,folder)
% Save active configuration, full report, calculation/event tables and PNG chart.
  if ~exist(folder,'dir'), mkdir(folder); end
  fid=fopen(fullfile(folder,'configuration.json'),'w'); fprintf(fid,'%s',jsonencode(r.parameters)); fclose(fid);
  lines=report_lines(r); fid=fopen(fullfile(folder,'report.txt'),'w');
  for i=1:numel(lines), fprintf(fid,'%s\n',lines{i}); end; fclose(fid);
  fid=fopen(fullfile(folder,'summary.json'),'w'); fprintf(fid,'%s',jsonencode(r.summary)); fclose(fid);
  fid=fopen(fullfile(folder,'calculations.csv'),'w'); fprintf(fid,'quantity,formula,value,unit\n');
  for i=1:size(r.calculations,1)
    a=r.calculations(i,:); fprintf(fid,'"%s","%s",%.17g,"%s"\n',a{1},a{2},a{3},a{4});
  end; fclose(fid);
  write_numeric_csv(fullfile(folder,'dps_byte_example.csv'),{'slot','previous_phase_bit','current_phase_bit','Alice_key_bit','phase_difference_mod_2pi_rad','ideal_detector'},r.teaching_frame);
  write_numeric_csv(fullfile(folder,'first_200_slots.csv'),r.trace_names,r.trace(1:min(200,end),:));
  idx=find(r.trace(:,15)); write_numeric_csv(fullfile(folder,'first_200_detections.csv'),r.trace_names,r.trace(idx(1:min(200,end)),:));
  f=r.fading; write_numeric_csv(fullfile(folder,'fading_blocks.csv'),{'eta_blocks','fade','pointing','offset','cloud'},[f.eta_blocks' f.fade' f.pointing' f.offset' double(f.cloud)']);
  fig=plot_result(r); print(fig,fullfile(folder,'diagnostics.png'),'-dpng','-r120'); close(fig);
  fig=plot_atmosphere(r.parameters); print(fig,fullfile(folder,'atmosphere.png'),'-dpng','-r120'); close(fig);
  fprintf('Saved current result to %s\n',folder);
end

function fig=new_figure(varargin)
% Select a renderer explicitly: Windows octave-cli can silently switch an
% implicit gnuplot figure to FLTK, which cannot print an invisible figure.
% Qt is preferred when available; gnuplot supports CLI-only PNG exports.
  if any(strcmp(available_graphics_toolkits(),'qt')), toolkit='qt'; else, toolkit='gnuplot'; end
  graphics_toolkit(toolkit);
  fig=figure('__graphics_toolkit__',toolkit,varargin{:});
  dimensions=get(fig,'position');
  set(fig,'paperunits','inches','paperposition',[0 0 dimensions(3)/100 dimensions(4)/100], ...
    'papersize',dimensions(3:4)/100);
end

% ================= STEP 6: RUNTIME EDITORS ===============================
function p=console_editor()
% Text interface works in octave-cli and exposes every parameter and choice.
  p=defaults(); s=schema();
  while true
    fprintf('\nEDITABLE PARAMETERS\n');
    for i=1:numel(s)
      v=p.(s(i).key); if isnumeric(v), txt=num2str(v,12); else, txt=v; end
      fprintf('%2d [%s] %s = %s %s\n   %s\n',i,s(i).group,s(i).key,txt,s(i).unit,s(i).description);
      if ~isempty(s(i).choices), fprintf('   choices: %s\n',strjoin(s(i).choices,', ')); end
    end
    choice=input('Parameter number, r=run, a=all, s=sweeps, e=export, q=quit: ','s');
    try
      if strcmp(choice,'q'), return;
      elseif strcmp(choice,'r'), r=simulate(p); print_report(r); plot_result(r);
      elseif strcmp(choice,'a')
        for ch={'Fiber','FSO-Terrestrial','Satellite-Ground'}
          q=p; q.channel=ch{1}; r=simulate(q); print_report(r); plot_result(r);
        end
      elseif strcmp(choice,'s'), t=run_sweeps(p); disp(t); plot_sweeps(t);
      elseif strcmp(choice,'e'), export_result(simulate(p),'outputs/runtime/octave');
      else
        i=str2double(choice);
        if ~isfinite(i) || fix(i)~=i || i<1 || i>numel(s), error('Enter a valid parameter number.'); end
        value=input(['New value for ' s(i).key ': '],'s');
        if isnumeric(s(i).default), value=str2double(value); end
        p.(s(i).key)=value;
      end
    catch err, fprintf('Input/model error: %s\n',err.message); end
  end
end

function open_editor()
% Scrollable GUI table: every value is editable, with units and explanations.
  if any(strcmp(available_graphics_toolkits(),'qt')), graphics_toolkit('qt');
  else, fprintf('Qt GUI unavailable in this executable. Starting console editor; use octave-gui.exe for the table.\n'); console_editor(); return; end
  p=defaults(); s=schema(); data=cell(numel(s),5);
  for i=1:numel(s)
    v=p.(s(i).key); if isnumeric(v), v=num2str(v,15); end
    helptext=s(i).description;
    if ~isempty(s(i).choices), helptext=[helptext ' Choices: ' strjoin(s(i).choices,' | ')]; end
    data(i,:)={s(i).group,s(i).key,v,s(i).unit,helptext};
  end
  fig=figure('__graphics_toolkit__','qt','Name','DPS-QKD school project: all runtime parameters','NumberTitle','off', ...
    'Position',[50 50 1450 850],'MenuBar','none');
  uicontrol(fig,'Style','text','String','Edit Value cells; scientific notation accepted. Scroll to view every group.', ...
    'Units','normalized','Position',[.02 .95 .96 .035],'FontSize',12);
  tab=uitable(fig,'Data',data,'ColumnName',{'Group','Parameter','Value (edit)','Unit','Explanation / choices'}, ...
    'ColumnEditable',[false false true false false],'ColumnWidth',{140 210 130 145 720}, ...
    'Units','normalized','Position',[.02 .48 .96 .46]);
  output=uicontrol(fig,'Style','listbox','Max',2,'Min',0,'FontName','Courier New', ...
    'Units','normalized','Position',[.02 .02 .96 .38]);
  labels={'Run selected','Compare all three','Parameter / Eve sweeps','Export current result'};
  for j=1:4
    uicontrol(fig,'Style','pushbutton','String',labels{j},'Units','normalized', ...
      'Position',[.02+(j-1)*.245 .42 .23 .045],'Callback',@(src,event) action(j));
  end
  function action(kind)
  % Parse every table value, validate, then perform the chosen runtime action.
    try
      d=get(tab,'Data'); q=defaults();
      for ii=1:numel(s)
        v=d{ii,3}; if isnumeric(s(ii).default) && ischar(v), v=str2double(v); end
        q.(s(ii).key)=v;
      end
      validate(q); set(output,'String',{'Calculating...'}); drawnow();
      if kind==3
        t=run_sweeps(q); plot_sweeps(t);
        set(output,'String',[{'Columns: group, x, QBER, sifted bps, toy bps, loss dB, Rytov, outage.'};cellstr(num2str(t))]);
      elseif kind==4
        rr=simulate(q); export_result(rr,'outputs/runtime/octave');
        set(output,'String',[report_lines(rr),{'Saved to outputs/runtime/octave'}]);
      else
        channels={q.channel}; if kind==2, channels={'Fiber','FSO-Terrestrial','Satellite-Ground'}; end
        lines={};
        for jj=1:numel(channels)
          cfg=q; cfg.channel=channels{jj}; rr=simulate(cfg); print_report(rr); plot_result(rr);
          lines=[lines,report_lines(rr)];
        end
        set(output,'String',lines);
        plot_atmosphere(q);
      end
    catch err, set(output,'String',{['Error: ' err.message]}); end
  end
end

% ================= VERIFICATION: PHYSICS LIMITS =========================
function ok=selftest()
% Independent physical limits catch convention errors such as false 1/2 sifting.
  p=defaults(); p.n_slots=10000; p.visibility=1; p.phase_sigma_rad=0;
  p.dark_hz=0; p.background_hz=0; p.dead_time_ns=0;
  r=simulate(p); assert(r.summary.qber_model<1e-14);
  eta=r.channel.eta0*p.detector_eta*p.coupling_eta*10^(-p.interferometer_loss_db/10)*r.channel.gate_capture;
  assert(abs(r.summary.expected_single_probability-(-expm1(-p.mu*eta)))<1e-12);
  r2=simulate(p); assert(isequal(r.trace,r2.trace));
  p.mu=0; r=simulate(p); assert(r.summary.detected_sifted_bits==0); assert(isnan(r.summary.qber_observed));
  p.dark_hz=1e7; r=simulate(p); assert(abs(r.summary.qber_model-.5)<1e-12);
  p=defaults(); p.n_slots=10000; p.channel='Satellite-Ground'; p.elevation_deg=90;
  r=simulate(p); assert(abs(r.channel.length_m-p.sat_altitude_km*1000)<1e-6);
  p.cloud_probability=1; r=simulate(p); assert(all(r.fading.eta==0)); assert(abs(r.summary.qber_model-.5)<1e-12);
  p.channel='FSO-Terrestrial'; p.cloud_probability=0; p.fso_cn2=0;
  r=simulate(p); assert(all(r.fading.fade==1));
  p=defaults(); p.n_slots=200000; p.visibility=1; p.phase_sigma_rad=0;
  p.dark_hz=0; p.background_hz=0; p.eve_mode='phase-resend'; p.eve_fraction=1;
  r=simulate(p); assert(abs(r.summary.qber_model-r.eve.expected_signal_qber)<.005);
  p.eve_mode='beam-split'; p.eve_tap=1; r=simulate(p); assert(r.summary.detected_sifted_bits==0);
  p=defaults(); p.channel='Bad'; caught=false;
  try, simulate(p); catch, caught=true; end; assert(caught);
  assert(abs(displaced_aperture(.1,.2,0)-(-expm1(-.5)))<1e-12);
  fprintf('Octave self-tests passed: ideal DPS rate, zero/noise signal, repeatability, geometry, clouds, turbulence off, Eve and validation.\n');
  ok=true;
end
