# Detailed DPS-QKD school project

Start with **[DPS_QKD_model.ipynb](DPS_QKD_model.ipynb)** for the executed Python notebook, or **[DPS_QKD_walkthrough.m](DPS_QKD_walkthrough.m)** for the section-by-section Octave project. Both implement **Fiber**, **FSO-Terrestrial**, and **Satellite-Ground downlink** with the same parameter catalogue and physical conventions.

The notebook contains **88 cells**, including **35 executed code cells**, with formulas, worked examples, visible function definitions, calculation tables, bit traces and saved charts. Both interfaces expose **all 62 parameters during runtime**, grouped by source, receiver, channels, atmosphere, Eve, post-processing and sweeps.

## Run the notebook

Open `DPS_QKD_model.ipynb` in JupyterLab or VS Code. The saved outputs can be read immediately. To change settings, run all cells, then use the grouped controls near the end. The `P` dictionary also exposes every setting without widgets.

From PowerShell in this folder:

```powershell
python -m pip install -r requirements.txt
python -m jupyterlab DPS_QKD_model.ipynb
```

Or run `.\run_notebook.ps1` once dependencies are installed. Static notebook previews cannot execute widget buttons; open a live Python kernel for runtime changes.

## Run in your installed Octave 10.3.0

For the graphical parameter table and charts:

```powershell
& 'D:\AntennaSimulations\Octave-10.3.0\mingw64\bin\octave-gui.exe' --persist --eval "addpath(pwd); dps_qkd_simulator();"
```

Or run `.\run_octave.ps1`. Edit the **Value** column, including selections such as `channel`, `fading_model` and `eve_mode`. Their valid choices appear in the explanation column. Buttons run the selected channel, compare all three, run parameter/Eve sweeps, or export the current result. Scroll to see all parameter groups.

For the classroom walkthrough, open `DPS_QKD_walkthrough.m` in Octave's editor and run its sections in order. It shows the parameter structure, byte encoding, each channel budget, atmospheric profile, actual detector events, sifted strings, Eve experiments and sweeps.

Text-only editing works in the CLI:

```powershell
& 'D:\AntennaSimulations\Octave-10.3.0\mingw64\bin\octave-cli.exe' --quiet --eval "addpath(pwd); dps_qkd_simulator('console');"
```

No Octave add-on packages are required. `octave-cli.exe` lacks the Qt table interface; the no-argument call falls back to its console editor. Use `octave-gui.exe` for the graphical table. Batch PNG export works with either executable.

## Change settings programmatically

Python:

```python
from dps_qkd import default_parameters, simulate, print_report, plot_result, export_result
p = default_parameters()
p.update(channel='Satellite-Ground', elevation_deg=30,
         eve_mode='phase-resend', eve_fraction=0.5, n_slots=1000000)
r = simulate(p)
print_report(r)
plot_result(r)
export_result(r)
```

Octave:

```octave
p = dps_qkd_simulator('defaults');
p.channel = 'Satellite-Ground';
p.elevation_deg = 30;
p.eve_mode = 'phase-resend';
p.eve_fraction = 0.5;
p.n_slots = 1000000;
r = dps_qkd_simulator(p, true);
dps_qkd_simulator('export', p, 'outputs/runtime/octave');
dps_qkd_simulator('export-sweeps', p, 'outputs/runtime/octave');
```

Both languages can load the same exported `configuration.json`:

```python
import json
from pathlib import Path
p = json.loads(Path('outputs/runtime/octave/configuration.json').read_text())
```

```octave
p = jsondecode(fileread('outputs/runtime/python/configuration.json'));
```

Use the function entry point `dps_qkd_simulator(...)`; do not execute its function body as a script. The separate walkthrough is intended for script/section execution.

## What is calculated

| Stage | Included calculations |
|---|---|
| Source / DPS | Poisson photon statistics; bytes → phase bits → relative phases; one-bin-delay interference; actual random key sequence |
| Fiber | Attenuation, connectors, splices, RMS dispersion broadening and temporal gate capture |
| Terrestrial FSO | Gaussian beam spread, circular aperture collection, weather extinction, Rytov variance and Fried coherence diameter |
| Satellite downlink | Spherical-Earth slant range, elevation/airmass, Hufnagel–Valley altitude profile and numerical turbulence integrals |
| Atmosphere | Lognormal / gamma-gamma / automatic / disabled scintillation; block fading; exact displaced-beam pointing collection; opaque cloud outages |
| Eve | Pulse-level phase measurement/resend with explicit optical-reference assumptions; beam-split tap with Eve's own ideal DPS detection |
| Receiver | Separate detector ports, differential phase noise, Poisson threshold clicks, dark/background counts, rejected double clicks and optional shared dead time |
| Results | Actual sifted bits, model/observed QBER and rates, descriptive Wilson intervals, public test sample, classroom decision and illustrative entropy budget |
| Charts | Six per-run diagnostic panels, four atmosphere plots, channel comparison, five parameter/Eve studies |

All formulas, units, numerical substitutions and limits are explained in **[THEORY.md](THEORY.md)** and inside the notebook. **[FUNCTIONS.md](FUNCTIONS.md)** explains every function and the numerical primitives. Every function also has a docstring or Octave comment block.

The physical references are linked beside their equations: the [original DPS proposal](https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.89.037902), [atmospheric propagation equations](https://www.janss.kr/archive/view_article?pid=jass-37-1-11), and [restricted DPS security analysis](https://arxiv.org/abs/quant-ph/0508112).

## Interpreting the results correctly

- **The reported post-processing throughput is illustrative, not a proven DPS secret-key rate.** The project does not implement actual error reconciliation, privacy amplification or finite-key security. `certified_secret_key_bps` explicitly says that it is not computed.
- DPS has no automatic 50% random-basis sifting penalty. This implementation discards only noninterfering train boundaries, no-click slots, double clicks and the revealed test bits.
- A zero-count QBER is undefined. Low-count satellite results show uncertainty; the conditional probability estimate remains available even when observed counts are small.
- Satellite geometry is a fixed **downlink**. Altitude is distinct from slant range. Uplink wave optics and orbital tracking are outside this model.
- Atmospheric statistics use point-receiver approximations; aperture averaging, adaptive optics and a physical temporal turbulence spectrum are not included. Extinction and cloud settings are scenario inputs.
- The default 1000-slot block at a 1 GHz clock is a classroom sampling choice (1 microsecond), not a calibrated atmospheric coherence time. For a 1 ms block, use a 1 MHz clock with 1000 slots, or a 1 GHz clock with 1000000 slots and a longer observation. See the detailed discussion in `THEORY.md`.
- Both languages repeat their own seeded runs. Their random bitstreams differ; deterministic formulas and distributions are what should agree.

## Saved results and verification

`outputs/examples/python/` and `outputs/examples/octave/` contain runnable default configurations, result tables, event examples and PNG charts. Interactive exports use `outputs/runtime/`. The result object retains **all** trial rows; routine exports limit event tables to the first 200 slots and first 200 accepted detections.

Run the meaningful checks:

```powershell
python -m unittest -v test_physics
python verify_cross_language.py
& 'D:\AntennaSimulations\Octave-10.3.0\mingw64\bin\octave-cli.exe' --quiet --eval "addpath(pwd); dps_qkd_simulator('selftest');"
```

The checked limits include ideal interference, the correct click-rate normalization, no signal, background-only QBER, deterministic repeatability, atmospheric moments, satellite geometry, cloud blocking, both Eve attacks and holdoff spacing. The cross-language comparison uses independently computed pointing integrals as well as all three deterministic link models. See **[the verification report](outputs/validation/VERIFICATION.md)**.

For maintainers: after changing the model or explanations, regenerate with `python build_notebook.py`, then execute/save with `python execute_notebook.py`. If catalogue definitions change, run `python build_parameters.py` first. The existing input notebook, Octave file and README were preserved under `.project_backups/`; the existing `Diagrams/` folder was retained.
