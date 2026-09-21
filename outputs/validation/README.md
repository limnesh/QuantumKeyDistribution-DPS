# Validation record

Verified in this workspace on 22 September 2026 using Python 3.11.9 and the supplied GNU Octave 10.3.0 installation.

| Check | Result |
|---|---|
| Executed notebook | All 35 code cells completed; 88 total cells; no error outputs or stderr outputs; 7 embedded chart images |
| Notebook/module synchronization | Every visible notebook function has the same parsed Python definition as `dps_qkd.py` |
| Python physical/statistical checks | All 15 tests in `test_physics.py` passed |
| Octave physical checks | `dps_qkd_simulator('selftest')` passed |
| Cross-language deterministic calculations | All three channels agree within relative tolerance 1e-10, absolute 1e-12 |
| Independent aperture integration | Octave Rice quadrature and Python noncentral chi-square CDF agree to maximum absolute error 4.44e-16 over 201 displacements |
| Runtime GUI | All 62 editable rows and all four action callbacks exercised successfully with `verify_octave_ui.m` |
| Sequential Octave project | `DPS_QKD_walkthrough.m` ran from start to finish, including Eve, sweeps, exports and final self-tests |
| PNG exports | Verified with both `octave-gui.exe` (Qt) and `octave-cli.exe` (gnuplot) |
| Chart review | Python and Octave diagnostic PNGs visually inspected; export dimensions adjusted for readability |

[VERIFICATION.md](VERIFICATION.md) contains numerical comparisons. `octave_ui.log` and `octave_walkthrough.log` record runtime execution. These checks establish consistency of the implemented engineering model; they do not validate a cryptographic security proof or calibrate the atmospheric approximations against a field experiment.
