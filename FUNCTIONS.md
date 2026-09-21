# Function reference

All Python definitions are also visible in the notebook. Octave equivalents are local functions in `dps_qkd_simulator.m`.

| Python function | Inputs | Purpose / returned object |
|---|---|---|
| `default_parameters` | `` | Return a fresh flat dictionary; every editable value comes from the shared catalogue. |
| `validate` | `p` | Reject missing/unknown keys, invalid choices, nonfinite values and inconsistent units. |
| `parse_hex` | `text` | Convert space-separated hexadecimal bytes to integers without silently truncating. |
| `encode_bytes` | `text` | Bytes -> MSB-first pulse phase bits a_i -> phases pi*a_i -> adjacent XOR key bits. |
| `h2` | `q` | Binary entropy in bits: -q log2(q)-(1-q)log2(1-q), with h2(0)=h2(1)=0. |
| `wilson` | `errors, count` | 95% binomial Wilson interval; NaNs for zero trials. Descriptive, not a finite-key bound. |
| `hv_profile` | `h, p` | Hufnagel-Valley Cn^2(h) in m^(-2/3), with absolute altitude h in metres. |
| `turbulence_parameters` | `s` | Map Rytov variance s=σ_R² (NOT σ_R) to gamma-gamma shapes and scintillation index. |
| `channel_model` | `p` | Compute link geometry, named dB losses, Rytov/Fried turbulence and a calculation ledger. |
| `draw_channel` | `p, c, rng` | Draw unit-mean intensity fading, exact displaced-Gaussian aperture capture and clouds. |
| `eve_attack` | `phases, p, rng` | Return forwarded phase bits, Eve's estimates, known-mask and Bob power multiplier. |
| `simulate` | `p` | Run all stages, preserving intermediate arrays and calculation tables for inspection. |
| `print_report` | `r` | Print every formula/value, summary field and warnings, followed by a small real event trace. |
| `plot_result` | `r` | Build six diagnostic plots with separate axes for quantities having different units. |
| `run_sweeps` | `p` | Sweep fiber length, horizontal length, satellite elevation, and both Eve attack strengths. |
| `plot_sweeps` | `table` | Five sweep columns, showing QBER and rate separately; satellite x-axis is elevation. |
| `plot_atmosphere` | `p` | Explain turbulence using HV altitude, horizontal length, elevation and SI curves. |
| `export_result` | `r, directory, sweeps` | Save reproducible configuration, summary, all calculations, bit examples, events and plots. |
| `runtime_controls` | `initial` | Create grouped widgets for EVERY parameter, with validation, run-all, sweeps and export. |

## Octave equivalents

| Octave function / command | Purpose |
|---|---|
| `dps_qkd_simulator` | Entry point; dispatches defaults, runtime editor, simulations, plots, exports and tests. |
| `schema`, `defaults`, `validate` | Shared catalogue, parameter structure and input checks. |
| `parse_hex`, `encode_bytes` | Hex bytes to phase bits and adjacent differential key table. |
| `h2`, `wilson` | Entropy and descriptive binomial interval. |
| `hv_profile`, `turbulence_parameters` | Cn² altitude profile and gamma-gamma distribution parameters. |
| `channel_model`, nested `rec` | Geometry, loss, dispersion, turbulence and calculation ledger. |
| `displaced_aperture` | Rice-density quadrature for exact displaced Gaussian collection. |
| `draw_channel` | Random fading, pointing, clouds and per-pulse transmission. |
| `eve_attack` | Forwarded phases, Eve estimates and power-tap factor. |
| `simulate`, nested `rec` | Full event simulation, probabilities, sifting, statistics and intermediate arrays. |
| `report_lines`, `print_report` | Formula/value/unit report and bit/event tables. |
| `plot_result`, `plot_atmosphere` | Six result charts and four turbulence calculation charts. |
| `run_sweeps`, `plot_sweeps` | Five parameter studies, QBER and throughput curves. |
| `write_numeric_csv`, `export_result` | Reproducible CSV, configuration, report and PNG output. |
| `new_figure` | Explicit Qt/gnuplot renderer selection and readable export dimensions. |
| `console_editor`, `open_editor`, nested `action` | Change all settings during execution and rerun experiments. |
| `selftest` | Check independent physics limits and invalid-input handling. |

Python `r["trace"]` is a DataFrame. Octave `r.trace` is a numeric matrix whose column names are `r.trace_names`. A Bob bit of -1 means the slot was not retained. The byte example is separate from the random key sequence.

Random primitives: `random` / `rand` draw uniform [0,1), `standard_normal` / `randn` draw normal samples, `gamma` / `randg` draw gamma variates (Octave randg uses unit scale before division), `choice` / `randperm` select test bits without replacement.

Numerical primitives: `expm1(x)` computes exp(x)-1 accurately near zero; `hypot` calculates a stable Euclidean norm; `trapezoid` / `trapz` integrate a sampled profile; `erf` integrates a centered Gaussian; `ncx2.cdf` / scaled-Bessel quadrature calculate circular aperture capture. `xor` / `bitwise_xor` implement differential encoding, not a cryptographic cipher.
