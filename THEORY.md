# DPS-QKD: calculation-by-calculation project guide

## 1. Aim and scope

We simulate Alice transmitting weak coherent optical pulses, Bob comparing adjacent pulse phases, and Eve trying to learn the resulting bits. The three links are **guided fiber**, **horizontal terrestrial free-space optics**, and a **satellite-to-ground downlink**. Run identical source and receiver settings to compare propagation effects, then change one parameter at a time.

The project produces pulse examples, channel budgets, atmospheric samples, detector events, sifted bits, QBER, parameter studies, and a clearly labeled **illustrative post-processing budget**. It does not claim to generate a cryptographically certified secret key. Actual DPS privacy amplification requires a compatible security proof, authentication, error reconciliation, and finite-size analysis. The random generators used here are reproducible scientific generators, not cryptographic randomness.

## 2. Units and runtime parameters

`parameters.json` is a catalogue of 62 parameters. Each row contains its group, key, default, unit, explanation, limits, integer requirement, and allowed choices. Both languages read this catalogue; the notebook also embeds a copy so its computational cells can run independently. `build_parameters.py` is the editable source of the catalogue.

Lengths are converted to metres for wave propagation; fiber attenuation uses kilometres. Wavelength enters in nanometres and becomes metres. Beam divergence and pointing jitter enter in microradians. Apertures are **diameters**; Gaussian beam waists and receiver spot sizes are **radii**. The Gaussian radius is where intensity has fallen to exp(-2) of its central value. Pulse widths and spectral widths are **RMS**, not FWHM. One dB value describes power, so transmission is 10^(-loss/10).

Use the notebook's grouped widgets or edit `P`, then rerun the experiment cells. Octave offers a scrollable parameter table, a text editor, and a plain structure `p`. All settings remain editable during a session. A run rejects invalid choices, NaNs, negative lengths and overlapping detector gates. Fields for inactive channels remain stored but do not affect the active channel.

## 3. Step A — source and DPS encoding

Let a_i be Alice's random pulse-phase bit, either 0 or 1. Pulse i is a coherent state with amplitude sqrt(mu) exp(j pi a_i), and mean photon number mu. Poisson photon statistics imply:

$$P(n)=e^{-\mu}\frac{\mu^n}{n!},\quad E_{ph}=\frac{hc}{\lambda},\quad P_{opt}=\mu E_{ph}f_{clock}.$$

For mu=0.2, P(0)=0.81873 and P(1)=0.16375; approximately 1.752% of emitted pulses have two or more photons. A weak coherent source is not a deterministic single-photon source.

The key candidate in an interior detection slot is:

$$b_i=a_{i-1}\oplus a_i,\qquad \Delta\phi_i=\pi b_i \pmod{2\pi}.$$

Bob's unequal-arm interferometer delays one path by T=1/f_clock so neighboring pulses overlap. The free-space path difference is cT; in a medium it is cT/n_g. Detector D0 corresponds to a phase difference of zero; D1 corresponds to pi. DPS uses time announcements, with no BB84-style random basis comparison. There is **no extra 1/2 basis-sifting multiplier**. Finite trains have boundary slots without two-pulse interference. This implementation sends N+1 pulses, keeps N interior slots, and discards both noninterfering end slots.

For a hand example, byte A5 becomes phase bits `1 0 1 0 0 1 0 1`, phases `pi 0 pi 0 0 pi 0 pi`, and differential key bits `1 1 1 0 1 1 1`. The visible byte exercise is separate from the random pulse sequence used for statistical trials. The notebook prints both. This convention follows the pulse-phase principle of [Inoue, Waks and Yamamoto, PRL 89, 037902](https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.89.037902).

## 4. Step B1 — fiber calculations

With length L_km, attenuation alpha_f, connector loss A_c, n_s splices, per-splice loss A_s, and other insertion loss A_m:

$$A_f=\alpha_fL_{km}+A_c+n_sA_s+A_m,\qquad\eta_f=10^{-A_f/10}.$$

Default worked example: 0.2×20 + 1 + 2×0.05 + 0.9 = **6 dB**, giving eta_f = **0.25118864** before detector and interferometer losses.

The simplified RMS dispersion calculation is:

$$\sigma_{disp}=|D|L_{km}\sigma_\lambda,\qquad
\sigma_t=\sqrt{\sigma_{t0}^2+\sigma_{disp}^2}.$$

Here D=17 ps/(nm km), spectral RMS width=0.02 nm, and initial temporal RMS width=30 ps. At 20 km, broadening is 6.8 ps and received width is approximately 30.76 ps. A centered gate of width t_g captures the Gaussian intensity fraction:

$$g_t=\operatorname{erf}\left(\frac{t_g}{2\sqrt{2}\sigma_t}\right).$$

The model includes gate loss from broadening, but not coherent dispersion dynamics or intersymbol interference. A width larger than T/6 produces a model note. Guided fiber has no atmospheric scintillation; receiver phase noise remains an independent setting.

## 5. Step B2 — terrestrial free-space optics

First calculate the optical wavenumber k=2pi/lambda. Use an effective divergence half-angle theta=max(theta_input, lambda/(pi w0)); this prevents a user setting a Gaussian beam below its diffraction limit. A simplified broadened Gaussian has:

$$w(L)=\sqrt{w_0^2+(\theta L)^2},\qquad
\eta_{ap}=1-\exp\left(-\frac{2a^2}{w(L)^2}\right),\quad a=D_{rx}/2.$$

The aperture expression follows by integrating the normalized radial intensity 2 exp(-2r²/w²)/(pi w²) over a disk. The nominal loss budget is:

$$A_{FSO}=-10\log_{10}(\eta_{ap})+\alpha_{atm}L_{km}+A_{optics}.$$

Weather extinction is a user-entered coefficient, not a meteorological prediction. Try 0.2, 2 and 20 dB/km to represent progressively harsher assumed conditions. These are scenario inputs, not universal weather classifications. Absorption/scattering removes average power. Turbulence changes its spatial and temporal distribution; the two effects have separate controls.

For a uniform horizontal plane-wave approximation:

$$s=\sigma_R^2=1.23 C_n^2 k^{7/6}L^{11/6}.$$

Cn² has units m^(-2/3), while s is dimensionless. Zero Cn² gives no scintillation. s below roughly 1 is commonly treated as weak turbulence; the boundary is a modeling convention, not an exact switch in nature. The approximation is a surrogate for a finite Gaussian beam, not a full wave-optics propagation solver. See the propagation discussion in [Atmospheric modeling of free-space optical transmission](https://link.springer.com/article/10.1007/s11082-025-08505-5).

## 6. Step B3 — satellite-to-ground geometry

This project models a **downlink**. Uplinks experience different beam-wander and propagation weighting and must not be obtained by merely swapping endpoints.

Let Rg=Earth radius + ground altitude, Rs=Earth radius + satellite altitude, and e=ground elevation angle. A spherical-Earth triangle gives the slant range:

$$L=\sqrt{R_s^2-R_g^2\cos^2 e}-R_g\sin e.$$

At 90 degrees, this becomes satellite altitude minus station altitude. For a 500 km satellite over a sea-level station at 45 degrees, L is approximately **683.069 km**. Beam spread uses the full L. Atmospheric extinction is A_zenith/sin(e), and the atmosphere-only path is approximately (h_top-h_ground)/sin(e). Vacuum beyond that atmospheric layer does not contribute turbulence. The plane-parallel atmosphere is restricted to elevations of at least 10 degrees; refraction and accurate low-elevation air-mass models are outside the scope.

The satellite beam/aperture equations are those in Step B2, with separate satellite parameters. There is no orbit/pass tracking or Doppler compensation in this fixed-geometry study.

## 7. Step C — altitude-dependent turbulence and Fried parameter

The Hufnagel–Valley profile uses h in metres above sea level:

$$C_n^2(h)=S\left[0.00594(v/27)^2(10^{-5}h)^{10}e^{-h/1000}
+2.7\times10^{-16}e^{-h/1500}+Ae^{-h/100}\right].$$

S is an added scenario scale (`hv_scale`); setting it to zero disables the entire profile. A and v control the near-ground and high-altitude terms. At an elevated station, integrate from its absolute altitude. Default upper altitude is 20 km. A 2001-point trapezoidal integration computes the downlink approximation:

$$s=2.25k^{7/6}\sin(e)^{-11/6}
\int_{h_g}^{h_{top}}C_n^2(h)(h-h_g)^{5/6}\,dh.$$

The HV profile, downlink integral and gamma-gamma parameter equations below are documented in [Lim et al., JASS 37(1), 11–18, equations 10–13](https://www.janss.kr/archive/view_article?pid=jass-37-1-11). That paper studies classical optical communication; only its atmospheric propagation equations are used here, not its classical receiver BER expression.

For diagnostic wavefront coherence, calculate:

$$r_0=\left[0.423k^2\int_{path}C_n^2(s)\,ds\right]^{-3/5}.$$

The horizontal integral is Cn² L; the downlink integral is trapz(Cn²,h)/sin(e). No turbulence gives r0=infinity. r0 describes a spatial scale, **not adjacent-pulse differential phase variance**. It is displayed but is not directly inserted into QBER. This distinction avoids confusing absolute wavefront distortion with the phase difference across two time bins. A primary example of r0/profile use is [Tibetan Plateau balloon turbulence measurements](https://academic.oup.com/mnras/article/508/3/4096/6370608).

## 8. Step D — lognormal and gamma-gamma intensity fading

The random variable I multiplies irradiance and has theoretical mean one before physical transmission clipping. A weak-turbulence lognormal model is:

$$I=\exp(\sqrt{s}Z-s/2),\quad Z\sim N(0,1),\quad
E[I]=1,\quad SI=\operatorname{Var}(I)/E[I]^2=e^s-1.$$

For gamma-gamma fading define:

$$\alpha=\left[\exp\left(\frac{0.49s}{(1+1.11s^{6/5})^{7/6}}\right)-1\right]^{-1},$$
$$\beta=\left[\exp\left(\frac{0.51s}{(1+0.69s^{6/5})^{5/6}}\right)-1\right]^{-1}.$$

Draw X~Gamma(alpha, scale=1/alpha) and Y~Gamma(beta, scale=1/beta), independently; then I=XY and SI=1/alpha+1/beta+1/(alpha beta). The input s is already sigma_R², so the exponent is **s^(6/5)**, not s^(12/5). `auto` selects lognormal when s<1, gamma-gamma otherwise. `none` turns off scintillation but preserves extinction, pointing and clouds. These point-receiver models omit aperture averaging; a large ground telescope generally collects a smoother signal than this approximation predicts.

The physical transmission is eta=clip(eta_nominal × I × pointing × clear, 0, 1). Clipping prevents passive gain greater than one and is counted in the output. It alters mean transmission and can signal a poor regime for the multiplicative approximation. Samples are never renormalized to force their finite-sample mean to one.

Each random atmospheric realization lasts `block_slots` pulse slots. Adjacent pulses usually share it; at a boundary the interference calculation uses both transmissions. The default block length is chosen for visibly sampled classroom statistics, **not fitted to a site-specific turbulence coherence time**. At the default 1 GHz clock, 1000 slots represent only 1 microsecond. To study a nominal 1 ms coherence time, use `block_slots=1000000`, or lower the classroom pulse clock to 1 MHz while keeping 1000 slots. Increase observation time to sample more blocks. A short high-clock simulation is not a long satellite pass. Independent blocks have sharp boundaries and do not reproduce a Kolmogorov temporal spectrum.

## 9. Step E — pointing and opaque clouds

Tracking errors x and y are independent zero-mean Gaussians with per-axis standard deviation L sigma_theta. The radial displacement is r=sqrt(x²+y²). The exact displaced Gaussian aperture capture is the noncentral chi-square CDF:

$$\eta_{ap}(r)=F_{\chi'^2_2(4r^2/w^2)}(4a^2/w^2).$$

Divide this by centered capture eta_ap(0), already counted in the nominal link budget. Python evaluates the CDF directly. Octave integrates the equivalent Rice radial density using scaled Bessel I0; this avoids requiring the Statistics package. At zero displacement both reduce to 1-exp(-2a²/w²).

An opaque cloud blocks an entire atmospheric block with probability `cloud_probability`; background and dark counts still occur at Bob. This is a binary availability model, not a cloud microphysics model. No cloud or pointing effects apply inside guided fiber. `outage_fraction` counts slots whose channel transmission falls below `outage_eta`, regardless of whether a background click occurs.

## 10. Step F — Eve's selectable experiments

`none` forwards pulses unchanged.

`phase-resend` intercepts each pulse with probability f. Eve has a perfect external optical phase reference and performs minimum-error discrimination of the two coherent phase states. With her efficiency eta_E, use the Helstrom error:

$$e_E=\frac{1-\sqrt{1-e^{-4\mu\eta_E}}}{2}.$$

She prepares a new coherent pulse of the original mean intensity with her estimated phase and sends it through the same channel to Bob. A differential bit flips when exactly one of its two phases flips, so:

$$Q_{E,signal}=2fe_E(1-fe_E).$$

For mu=0.2 and eta_E=1, e_E≈0.128964; full interception gives Q_E≈0.224664. The resulting error is derived from pulse measurements, not imposed as an assumed universal 25% DPS QBER. Eve reports a two-phase bit estimate only when she intercepted both phases. Receiver errors and double-click selection can change the detected QBER from this source-only expression. Adjacent errors can be correlated. The phase-reference assumption matters, especially for a globally randomized source. See [NASA JPL's binary coherent-state receiver analysis](https://tda.jpl.nasa.gov/progress_report/42-189/189A.pdf) for the coherent-state overlap and discrimination bound.

`beam-split` taps fraction t from every pulse before the channel. Bob receives fraction 1-t. Eve uses an ideal noiseless DPS interferometer. Her conclusive probability per valid slot is 1-exp(-mu t eta_E); when conclusive she learns that differential bit. At t=0 she gets nothing; at t=1 Bob gets no source photons. This attack need not raise optical phase QBER: it causes extra attenuation, while background can raise Bob's total QBER as the source becomes weaker. A low observed QBER alone cannot demonstrate secrecy. Eve's observed agreement with sifted bits is a simulation statistic, not a bound on all possible information she could obtain.

## 11. Step G — derive the two detector intensities

Let eta_- and eta_+ be transmissions of the two overlapping pulses after any Eve power tap. Let V be static visibility, delta a sampled zero-mean Gaussian differential phase error, and b'_i the forwarded relative-phase bit. Define:

$$K=\mu\eta_{det}\eta_{coupling}\eta_{MZI}g_t/4,$$
$$\nu_{0,1}=K\left[\eta_-+\eta_+\ \pm\ 2V\sqrt{\eta_-\eta_+}\cos(\pi b'_i+\delta)\right].$$

The factors of 1/4 arise from field splitting through two balanced beam splitters. When eta_-=eta_+=eta, V=1 and delta=0, all interior-slot signal reaches the appropriate detector and the total mean is mu eta eta_det eta_coupling eta_MZI g_t. This directly checks the absence of an extra 1/2 loss.

Equal fading on adjacent pulses lowers counts without itself reducing visibility. Unequal amplitudes at block boundaries do reduce contrast through 2sqrt(eta_- eta_+)/(eta_-+eta_+). Residual differential phase noise is separately configurable; its mean contrast multiplier is exp(-sigma_delta²/2). The code samples delta first, then computes nonlinear detector probabilities, rather than replacing all fluctuations by an average visibility prematurely.

## 12. Step H — Poisson detector clicks and holdoff

The detected noise mean per port per gate is n_b=(dark_hz+background_hz)t_g. These rates are already detector counts per open-gate second; do not multiply them by detector efficiency again. Each threshold detector clicks with probability:

$$p_j=1-e^{-(\nu_j+n_b)}.$$

Conditional on the intensities, port clicks are independent. The exclusive-event probabilities are p_only0=p0(1-p1), p_only1=p1(1-p0), and p_double=p0p1. Double clicks are discarded. A single D0 gives bit 0; a single D1 gives bit 1. A no-click slot gives no bit. We never infer QBER from undetected pulses.

For optional shared receiver dead time, a registered event blocks the next H=ceil(t_dead f_clock) **whole slots**; lost events do not extend the block (nonparalyzable holdoff). Even discarded double clicks initiate holdoff. The event simulation enforces this rule exactly. The model-rate calculation uses a stationary local approximation live=1/(1+H p_any); it is exact for constant independent event probabilities, approximate for rapidly changing fading. Zero holdoff is the default.

## 13. Step I — sifting, QBER and uncertainty

Bob announces the accepted interior time slots. Alice selects their adjacent XOR values; Bob retains the detector-number bits. If M bits survive and E disagree:

$$Q_{observed}=E/M,\qquad R_{observed}=M/((N+1)/f_{clock}).$$

If M=0, QBER is **undefined (NaN)**, not zero and not an invented 50%. Background-only *expected* QBER is 50% whenever there is a nonzero single-click probability.

The model estimate averages the conditional probabilities over all simulated slots:

$$Q_{model}=\frac{\sum_i p_{wrong,i}\,live_i}{\sum_i p_{single,i}\,live_i},\qquad
R_{model}=\frac{N}{N+1} f_{clock}\,\overline{p_{single}\,live}.$$

This ratio weights brighter atmospheric realizations by their detection probability. Taking an unweighted average of per-block QBER, or averaging click probability only over detected slots, would produce bias.

The plots include a descriptive 95% Wilson binomial interval around observed QBER. Correlated fading, overlapping Eve errors and dead time can violate independent-identical-trial assumptions. Thus the interval is a classroom uncertainty indicator, not a rigorous finite-key confidence region. Zero observed errors with ten detections is much weaker evidence than zero errors with a million detections.

## 14. Step J — reveal a test sample and estimate a budget

Randomly reveal floor(M × test_fraction) sifted bits and remove them. The report distinguishes all-sifted simulation QBER (available to the simulator) from the QBER Alice and Bob could estimate from this public test sample. The displayed classroom threshold is configurable. An upper Wilson limit below it passes the classroom check; a sample mean above it aborts; other cases have insufficient test evidence. These statuses are not cryptographic certification.

To illustrate why error correction and privacy amplification cost bits, define binary entropy:

$$h_2(Q)=-Q\log_2 Q-(1-Q)\log_2(1-Q).$$

The toy retained fraction is max(0,1-(1+f_EC)h2(Q_model)), set to zero above the classroom threshold. Multiply by R_model(1-test_fraction) to show an illustrative post-processing throughput. This is a **generic entropy-cost exercise, not a DPS secret fraction**. It can remain positive in the beam-split experiment even while Eve has information; that is precisely why it must not be interpreted as secrecy. It is not conditioned on the observed test passing and is not an actually extracted key length.

No LDPC/Cascade exchange, authentication tags, Toeplitz hashing, decoy analysis, composable epsilon accounting, or actual final key extraction is implemented. The `certified_secret_key_bps` field explicitly says “NOT COMPUTED.” A restricted DPS security analysis exists in [Waks, Takesue and Yamamoto, PRA 73, 012344](https://arxiv.org/abs/quant-ph/0508112); using it requires matching its assumptions rather than substituting a BB84-like entropy formula.

## 15. Step K — charts and school experiments

Each selected run shows a nominal dB loss budget, transmission blocks, a fading distribution, the DPS byte example, model/observed QBER, and model/observed/illustrative rates. An additional atmosphere study plots the HV profile, horizontal Rytov variance, satellite Rytov variance against elevation, and scintillation strength. Sweeps cover fiber length, terrestrial distance, satellite elevation, Eve interception probability, and Eve tap fraction.

Suggested experiment sequence:

1. Run all defaults and record model and observed quantities separately.
2. Set visibility=1, phase_sigma_rad=0 and both noise rates=0. Verify ideal fiber QBER=0.
3. Increase fiber length. Explain power loss and temporal gate capture separately.
4. Set FSO Cn² to 0, 1e-16, 1e-15, 1e-14 and 1e-13. Record Rytov variance, fading SI, clipping and QBER.
5. Compare `none`, `lognormal`, `gamma-gamma` and `auto`; explain the weak-turbulence restriction.
6. Increase pointing jitter and weather extinction separately. Do not combine their units on one axis.
7. Run satellite elevations 10, 30, 60 and 90 degrees; compare slant range, loss, HV integral and rates.
8. Set cloud_probability=1 and verify that only background/dark detections survive.
9. Compare both Eve attacks. Explain why some attacks reduce transmission without directly changing the signal phase error.
10. Change the seed and sample size. Compare Monte Carlo uncertainty rather than expecting identical cross-language bitstreams.
11. Change block duration and observation time. Explain why too few atmospheric realizations give unreliable ensemble statistics.
12. Export the chosen configuration with the results so another student can repeat the experiment.

## 16. Reading the functions

Every Python function has a docstring; every Octave function has adjacent explanatory comments. `FUNCTIONS.md` lists their purpose, inputs and returned objects. The notebook shows its own function definitions rather than hiding the model inside an imported binary or external service. `simulate` orchestrates the stages; `channel_model`, `draw_channel` and `eve_attack` expose their intermediate quantities. All trial columns are retained in memory; the default CSV exports keep the first 200 trials and first 200 detections to keep files manageable. Save the complete `trace` explicitly if needed.

Use the tests to check limiting behavior before interpreting plots. Identical parameters must give matching deterministic channel budgets and ideal click rates in Python and Octave. Random samples need not match because the generators differ. The supplied comparison report checks formulas directly and the statistical tests check meaningful physical limits.
