# Python–Octave verification

Octave executable: `D:\AntennaSimulations\Octave-10.3.0\mingw64\bin\octave-cli.exe`

Deterministic channel and receiver quantities agree within relative tolerance 1e-10 (absolute 1e-12).

| Channel | Nominal loss (dB) | Rytov variance | Single-click probability |
|---|---:|---:|---:|
| Fiber | 6 | 0 | 0.01926642367 |
| FSO-Terrestrial | 2.689970815 | 0.7094954838 | 0.0408312774 |
| Satellite-Ground | 24.13797511 | 0.1172803518 | 0.0002992955938 |

Exact displaced-Gaussian aperture integration: maximum absolute difference = 4.44e-16 across 201 offsets.

Monte Carlo streams differ between languages. Matching formulas and statistically compatible outcomes are expected, not identical bit arrays.
