# Formula and parameter mapping

The final notebook's pulse clock is `1e7` slots/s. Baseline: distance 20 km,
waist 0.05 m, divergence 50 microradians, receiver radius 0.10 m, attenuation
0.1 dB/km, pointing loss 1 dB, optics efficiency 0.7, detector efficiency
0.5, mean photons 0.15, visibility 0.98, dark probability `2e-6` **per
detector per gate**, phase sigma 0.04 rad and error correction factor 1.16.

| Notebook definition | Octave implementation | Meaning |
|---|---|---|
| `optical_eta` | `core/dps_optical_eta.m` | Gaussian beam collection times atmosphere, pointing, optics, detector |
| `dps_detection` | `core/dps_click.m` | Exclusive and double-click error allocation; physical QBER |
| `dps_qber_skr_model` | `core/dps_compact.m` | Single/multi/dark components, compact QBER, phase term, asymptotic rate proxy |
| `fading_moments` | `core/dps_fading.m` | 48 Gauss-Hermite log-normal nodes, gain-weighted pooled QBER and rate |
| `true_fso_metrics` | `core/dps_true_metrics.m` | Five ML feature columns evaluated with 20 km pooled physics |
| RBF kernel ridge | `scenarios/dps_ml.m` | Feature min-max scaling, length 0.42, ridge 0.001, separate target scales |
| `ground_geometry` | `core/dps_satellite_geometry.m` | Earth/orbit slant range, elevation, 20 km atmosphere shell |
| Satellite/relay/network cells | `scenarios/dps_*.m` | 5 s pass integration and trusted bottleneck edge budgets |

For beam radius `w = hypot(w0, divergence * distance)`, collection is
`1-exp(-2*(radius/w)^2)`. The detector efficiency appears **once** in eta.
The ground atmosphere is `10^(-alpha_db_km*distance_km/10)`.

Physical correct/wrong click probabilities use signal intensity `mu*eta`,
visibility error `(1-V*cos(phase_offset))/2`, and independent detector dark
probability. The physical raw gain is `pc+pw-pc*pw`; error gain is
`pw*(1-pc)+0.5*pc*pw`.

The compact model uses dark union `Pd=1-(1-d)^2`, `P1=eta*mu*exp(-mu)`,
`Pm=eta*(1-exp(-mu)-mu*exp(-mu))`, and device error
`(1-V)/2 + (1-exp(-phase_sigma^2/2))/2`. Compact bit QBER is
`(Pd/2 + P1*e_device + Pm/4)/(P1+Pd+Pm)`. Define `G0=exp(-mu)*Pd`,
`G1=P1`, `Gm=max(0,1-exp(-mu*eta)-G1)` and `G=G0+G1+Gm`. Phase error is
`(G0/2 + G1*Qbit + Gm/4)/G`. Rate per gate is
`max(0,(G1*(1-h2(Qphase))-G*fEC*h2(Qbit))/2)`.

For fading, `F=exp(-sigma_log^2/2+sqrt(2)*sigma_log*x)` on 48 normalized
Gauss-Hermite nodes. Gain and the gain-weighted bit/phase QBER are pooled
before applying the same rate equation. The temporal AR(1) sample uses
`rho=0.96`, 10 s/sample, 2,400 samples and a 2,000 modeled bit/s outage
threshold; its Octave normal draw stream differs from NumPy's.

Satellite defaults: Earth radius 6,371 km, altitude 500 km, Earth `GM`
398,600.4418 km³/s², `-950:5:950` s, 10 degree elevation cutoff, 20 km
shell with 2 dB zenith attenuation, 10 microradian downlink divergence and
0.5 m receiver radius. Relay stations have ground angles ±17 degrees.
Network satellite offsets are `[-12,0,12]` degrees with all three candidate
inter-satellite links, 8 microradian divergence and 0.35 m receiver radius.
Earth blocks the direct S0-S2 link at the default 24 degree separation.

Reference baseline outputs (rounded): eta 0.003464884, raw physical clicks
5,236/s, physical QBER 1.374%, compact QBER 3.180%, fixed modeled rate
843.5 bit/s; pooled log-normal rate 843.7 modeled bit/s. The LEO pass lasts
about 7.42 min above cutoff and integrates about 95,195 modeled proxy bits.
