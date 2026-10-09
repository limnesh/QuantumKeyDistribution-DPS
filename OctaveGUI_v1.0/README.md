# DPS-QKD FSO — GNU Octave GUI aligned to notebook v1.8

**Reference:** `DPS_QKD_FSO_v1.8_Section12_SKR.ipynb` (latest revised Section 12 with explicit raw rate, QBER, and modeled SKR).

## Launch

Open GNU Octave in this directory:

```octave
run('SELF_CHECK.m')     % fast smoke test before GUI
run('START_PROJECT.m') % graphical launcher
% or run('RUN_ALL.m')  % all scenarios incl. 1 million ML candidates
```

In the GUI select **Ground FSO + turbulence + ML**, then the **ML vs physics** or **ML convergence** page. The million-candidate search runs lazily when opening the ML page. On slow PCs, change `ML candidate predictions` under **Section 12 ML experiment** to a smaller count first. A full run can take significantly longer than NumPy depending on Octave/BLAS performance.

## Exact Section 12 setup

- Input order: `[mu, receiver_radius_m, pointing_loss_db, sigma_log, visibility, log10_dark]`.
- Ranges: `mu 0.05–0.50; radius 0.10–0.25 m; pointing 1.5–5 dB; sigma 0.15–0.65; visibility 0.950–0.985; log10(dark) −6 to −5`.
- 48-point Gauss–Hermite lognormal fading, detection-weighted pooled QBER, 10 MHz gate clock.
- Two-output RBF (raw detections/s, QBER); modeled SKR is **derived**, never learned as an independent unconstrained target.
- `SKR_model = raw_click_rate * q_sift * max(0, 1 - 1.16*h2(QBER) - h2(QBER))`; `q_sift=1` by default.
- Training 150 physics samples; independent test 100; physics verification 50; equal physics-only budget 300; 1,000,000 ML-only candidate predictions.
- Gaussian RBF length scale 0.55, regularization 1e-4; QBER constraint 5%.
- Screening is done in batches to bound Octave memory. For the conditional design map, four features are fixed at the ML-route best design. The direct-physics marker displays a **projection** into `(mu, aperture)`; its true SKR is shown separately.

## Baselines and satellite modes

Ground baseline in Sections 9–12: 20 km, beam divergence 100 µrad, receiver radius 0.20 m, atmospheric coefficient 0.20 dB/km, 3 dB pointing loss, 0.50 optics, 0.80 coupling, 0.50 MZI transmission, 0.30 detector, mu=0.24. The satellite/relay/network tabs retain their own study assumptions (500 km, 10° elevation cutoff, etc.) and use the same detector-plus-generic-SKR proxy, not a protocol-certified SKR.

## Methodology and limits

**Critical:** This is the notebook's generic asymptotic entropy **modeled SKR proxy**, not a DPS-QKD finite-key security proof or deployment-grade certified key rate. QBER <5% alone cannot certify DPS security. Training and predictions come from the same analytical model, not optical field measurements.

Python `scipy.stats.qmc.LatinHypercube` and Octave have distinct random-number generators. The **physics equations, features, budget, ML method and metrics** are aligned; the **candidate values, selected optimum, and timings will not be numerically identical** across languages.

The two approaches are compared at equal budgets of direct physics evaluations; the very inexpensive analytical physics model may be much faster than the ML surrogate even when ML finds a better *sampled* candidate. The GUI calculates total elapsed time, including training and verification, not just prediction time.

## Files and export

- `core/` — detector, optical and lognormal models; generic modeled-SKR function; six-feature physics targets and RBF helpers.
- `scenarios/` — ground, satellite, relay, network and new budgeted ML comparison.
- `ui/` — launcher and dashboards. Export results with the **Export results** button; Section 12 exports holdout raw/SKR/QBER CSV, verified shortlist CSV and winner comparison CSV.
- `SELF_CHECK.m` — deterministic ground baseline checks + small-budget ML smoke test.
- `RUN_ALL.m` — CLI computation of all four scenarios with full benchmark; can take time.

Requirements: GNU Octave with desktop graphics for GUI; the calculation functions use base Octave only. No old five-feature CSV data is required.


## Graphics navigation fix (v1.8.1)

`ui/dps_dashboard.m` no longer creates auto-updating `legend()` graphics objects. These triggered `dellistener: invalid graphics object` when the page selector called `cla()` while Octave's legend listeners were still active. The plots now have static color-coded labels and explicitly remove previous colorbars before clearing plot axes. No scientific or ML computation routines were modified.

Restart Octave (or run `close all; clear functions;`) before opening the patched dashboard; existing figure windows may still have the old callbacks. For an additional on-computer page-switching test, run `run('GUI_GRAPHICS_SMOKE_TEST.m')`. This needs a desktop graphics toolkit and intentionally uses a tiny ML candidate budget; `SELF_CHECK.m` continues to validate the numerical model separately.
