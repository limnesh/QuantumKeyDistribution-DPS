# DPS-QKD FSO — GNU Octave project

A start screen and four parameter-driven dashboards matching the final
`DPS_QKD_FSO_Final.ipynb` notebook. This project requires **GNU Octave with a
desktop graphics toolkit**. Run from an extracted directory; no Python package
is required when using the Octave project.

## Start

1. Open `START_PROJECT.m` in GNU Octave and press **F5** (or enter
   `run('START_PROJECT.m')` from this directory).
2. Select one of the four scenarios. Change parameter groups on the left,
   press **Run simulation**, and choose a plot page at the top.
3. **Export results** saves a `.mat` snapshot, CSV data, summary, and dashboard
   image under `results/scenarioN_YYYYMMDD_HHMMSS/`.

In command-line Octave, `run('SELF_CHECK.m')` checks reference outputs, and
`run('RUN_ALL.m')` computes all four scenarios plus the ML module. The ML
training/design scan is also available as the last page of scenario 1 and can
take longer than the other pages.

The ML study holds the link distance at 20 km and uses the notebook's fixed
design-search settings, even if the separate ground-baseline page has a
different edited distance.

| Start screen | Notebook-matched content | Dashboard pages |
|---|---|---|
| 01 Ground FSO | Fixed link, log-normal fading, correlated outage, five-feature ML | Baseline; distance and mu; fading and outage; ML surrogate |
| 02 Single LEO | Orbital pass, atmospheric shell, elevation cutoff, click and rate proxy | Geometry; rate and QBER |
| 03 Trusted relay | Two separated stations and a key-holding satellite | Two hop geometry; contact and budgets |
| 04 Network | Three satellites, inter-satellite visibility, route bottlenecks | Link windows; route budgets |

`data/ml_train_features.csv` and `data/ml_test_features.csv` contain the exact
520/180 feature samples generated with the final notebook's NumPy seed 3602.
Octave refits the kernel from its own physics outputs; floating-point solver
differences can lead to small differences in ML metrics. The 2,400 point
correlated-fade example uses Octave's seeded normal generator; it is
reproducible in Octave but need not match NumPy's exact sample path or outage
fraction. All four scenarios accept edited device and geometry parameters.

## Interpretation

The physical two-detector click/QBER model and compact modeled QBER are
separate. The asymptotic modeled bit-rate is an **illustrative engineering
proxy**, not certified secret key material. The trusted relay assumes that
the satellite knows the key; integrated hop budgets ignore scheduling,
finite-key penalties, buffer limits and end-to-end untrusted security. A 5%
QBER design constraint is only the notebook's optimization condition.

See `MODEL_MAPPING.md` for the precise formulas and notebook defaults.
