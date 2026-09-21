"""Build a self-contained, fully explained notebook from the reviewed Python model.

Run this after changing dps_qkd.py / THEORY.md, then run execute_notebook.py.
Every function is an ordinary visible notebook code cell, not a hidden import.
"""
from pathlib import Path
import ast
import re
import nbformat as nb
import dps_qkd as model

ROOT=Path(__file__).resolve().parent
cells=[]
def md(text): cells.append(nb.v4.new_markdown_cell(text))
def code(text): cells.append(nb.v4.new_code_cell(text))

md('''# Differential Phase-Shift Quantum Key Distribution
## Fiber • Terrestrial FSO • Satellite-to-Ground

**A detailed, editable school-project simulation in Python and GNU Octave.**

Read Part I for the derivations, Part II for every function, and Part III for executed experiments. Part IV contains live runtime controls for all parameters. The saved version includes outputs, so you can inspect the calculations without first executing code.

**How to use:** select **Run → Run All Cells**, then change settings in the last widget panel and press **Run selected**, **Compare all three**, or **Run parameter/Eve sweeps**. Alternatively edit the `P` dictionary and rerun the experiment cells. Source code, parameters and explanations are embedded in this notebook. An exported `configuration.json` can be loaded by either language.

The notebook creates reproducible result tables and PNG charts under `outputs/examples/python/`. Its rate called *illustrative post-processing* is a classroom entropy-budget calculation. A certified DPS secret-key rate is **not computed**.

The matching Octave files are `dps_qkd_simulator.m` (functions and runtime interface) and `DPS_QKD_walkthrough.m` (sequential experiment script).
''')
md('## Part I — Read the model one step at a time')
theory=(ROOT/'THEORY.md').read_text(encoding='utf-8')
for section in re.split(r'(?=^## \d+\.)',theory,flags=re.M)[1:]: md(section)
md('''## Part II — All computational functions, with explanations

Execute these cells in order once. They define functions; the experiments below call them. `numpy` handles arrays and random draws, `scipy` supplies special functions and integration, `pandas` displays tables, and `matplotlib` draws charts. `copy.deepcopy` prevents one experiment from accidentally changing another's settings. `Path` writes outputs in platform-independent paths.
''')
code('''%matplotlib inline
from pathlib import Path
import json, math, copy
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.special import erf
from scipy.stats import ncx2
from scipy.integrate import trapezoid
from IPython.display import display
pd.set_option('display.max_rows', 100)
pd.set_option('display.max_columns', 20)
plt.rcParams.update({'figure.dpi': 105, 'font.size': 10})
print('Numerical libraries loaded. All parameter values and code appear below.')
''')
md('''### Shared parameter catalogue

Each dictionary below contains a default value and its meaning. The same catalogue is in `parameters.json` for Octave. Integer values count discrete objects; numerical bounds catch input mistakes. `choices` lists valid selections. This cell embeds a snapshot for notebook portability.
''')
code('SCHEMA = [\n'+''.join('    '+repr(row)+',\n' for row in model.SCHEMA)+']')

source=(ROOT/'dps_qkd.py').read_text(encoding='utf-8')
tree=ast.parse(source)
functions=[node for node in tree.body if isinstance(node,ast.FunctionDef)]
reference=['# Function reference','',
           'All Python definitions are also visible in the notebook. Octave equivalents are local functions in `dps_qkd_simulator.m`.', '',
           '| Python function | Inputs | Purpose / returned object |','|---|---|---|']
for node in functions:
    doc=ast.get_docstring(node) or 'See implementation.'
    args=', '.join(a.arg for a in node.args.args)
    md(f'### Function `{node.name}({args})`\n\n'+doc.replace('\n\n','\n\n')+
       '\n\nThe implementation below is part of this notebook and can be inspected or edited directly.')
    code(ast.get_source_segment(source,node))
    reference.append(f"| `{node.name}` | `{args}` | {doc.splitlines()[0].replace('|','/')} |")
reference+=['','## Octave equivalents','',
            '| Octave function / command | Purpose |','|---|---|',
            '| `dps_qkd_simulator` | Entry point; dispatches defaults, runtime editor, simulations, plots, exports and tests. |',
            '| `schema`, `defaults`, `validate` | Shared catalogue, parameter structure and input checks. |',
            '| `parse_hex`, `encode_bytes` | Hex bytes to phase bits and adjacent differential key table. |',
            '| `h2`, `wilson` | Entropy and descriptive binomial interval. |',
            '| `hv_profile`, `turbulence_parameters` | Cn² altitude profile and gamma-gamma distribution parameters. |',
            '| `channel_model`, nested `rec` | Geometry, loss, dispersion, turbulence and calculation ledger. |',
            '| `displaced_aperture` | Rice-density quadrature for exact displaced Gaussian collection. |',
            '| `draw_channel` | Random fading, pointing, clouds and per-pulse transmission. |',
            '| `eve_attack` | Forwarded phases, Eve estimates and power-tap factor. |',
            '| `simulate`, nested `rec` | Full event simulation, probabilities, sifting, statistics and intermediate arrays. |',
            '| `report_lines`, `print_report` | Formula/value/unit report and bit/event tables. |',
            '| `plot_result`, `plot_atmosphere` | Six result charts and four turbulence calculation charts. |',
            '| `run_sweeps`, `plot_sweeps` | Five parameter studies, QBER and throughput curves. |',
            '| `write_numeric_csv`, `export_result` | Reproducible CSV, configuration, report and PNG output. |',
            '| `new_figure` | Explicit Qt/gnuplot renderer selection and readable export dimensions. |',
            '| `console_editor`, `open_editor`, nested `action` | Change all settings during execution and rerun experiments. |',
            '| `selftest` | Check independent physics limits and invalid-input handling. |','',
            'Python `r["trace"]` is a DataFrame. Octave `r.trace` is a numeric matrix whose column names are `r.trace_names`. A Bob bit of -1 means the slot was not retained. The byte example is separate from the random key sequence.', '',
            'Random primitives: `random` / `rand` draw uniform [0,1), `standard_normal` / `randn` draw normal samples, `gamma` / `randg` draw gamma variates (Octave randg uses unit scale before division), `choice` / `randperm` select test bits without replacement.', '',
            'Numerical primitives: `expm1(x)` computes exp(x)-1 accurately near zero; `hypot` calculates a stable Euclidean norm; `trapezoid` / `trapz` integrate a sampled profile; `erf` integrates a centered Gaussian; `ncx2.cdf` / scaled-Bessel quadrature calculate circular aperture capture. `xor` / `bitwise_xor` implement differential encoding, not a cryptographic cipher.']
(ROOT/'FUNCTIONS.md').write_text('\n'.join(reference)+'\n',encoding='utf-8')

md('''## Part III — Execute the school-project experiments

### Experiment 1: edit the configuration and inspect every parameter

This is the central editable dictionary. A complete configuration is independent of runtime widgets. For example, set `P['channel']='Satellite-Ground'`, `P['elevation_deg']=30`, or `P['eve_mode']='phase-resend'`. Rerun dependent experiment cells after edits. Each named channel experiment below overrides only `channel` so its section always studies the indicated link.
''')
code('''P = default_parameters()
# Edit any values here. Examples (remove # to activate):
# P['n_slots'] = 1000000
# P['clock_hz'] = 1e6        # With block_slots=1000, atmospheric blocks last 1 ms.
# P['eve_mode'] = 'phase-resend'
# P['eve_fraction'] = 0.5
# P['fading_model'] = 'gamma-gamma'
validate(P)
parameter_table = pd.DataFrame(SCHEMA)[['group','key','default','unit','description']]
display(parameter_table)
''')
md('''### Experiment 2: bytes → phases → adjacent XOR → ideal detector

Read one row aloud: if previous and current phases differ, their XOR is 1, their phase difference modulo 2π is π, and ideal D1 fires if a photon is detected. A byte is only a teaching aid; the simulated key uses random phase choices.
''')
code('''print('Hex bytes:', P['sample_hex'])
print('MSB-first phase bits:', np.unpackbits(parse_hex(P['sample_hex'])))
print('Phase angles (radians):', np.pi*np.unpackbits(parse_hex(P['sample_hex'])))
display(encode_bytes(P['sample_hex']))
poisson_n = np.arange(7)
poisson_p = np.array([np.exp(-P['mu'])*P['mu']**int(n)/math.factorial(int(n)) for n in poisson_n])
display(pd.DataFrame({'photons_per_pulse':poisson_n,'probability':poisson_p}))
fig, ax = plt.subplots(figsize=(7,3)); ax.bar(poisson_n, poisson_p)
ax.set(xlabel='Photons in one emitted pulse',ylabel='Probability',title='Weak coherent source: Poisson statistics')
plt.show()
''')

for i,(channel,label) in enumerate([('Fiber','fiber'),('FSO-Terrestrial','terrestrial'),('Satellite-Ground','satellite')],3):
    md(f'''### Experiment {i}: {channel}, all calculations visible

The ledger shows the formula, numerical result and unit for every stage. The summary then distinguishes model probabilities from simulated event counts. The sample arrays are available in `results['{channel}']`; no intermediate propagation or detector calculation is hidden.
''')
    if i==3: code('results = {}')
    code(f'''cfg = copy.deepcopy(P)
cfg['channel'] = {channel!r}
r = simulate(cfg)
results[{channel!r}] = r
print_report(r)
display(r['calculations'])
display(pd.DataFrame([r['summary']]).T.rename(columns={{0:'value'}}))
fig = plot_result(r)
plt.show()
export_result(r, 'outputs/examples/python/{label}')
''')
    if i==5:
        md('''The ground profile is sampled in altitude before integration. The next table makes the profile available for independent hand/trapezoidal checks; the entire 2001-point array is retained in the result.''')
        code('''sat = results['Satellite-Ground']['channel']
display(pd.DataFrame({'altitude_m':sat['profile_h'], 'Cn2_m_minus_2over3':sat['profile_cn2']}).iloc[::100])
fig = plot_atmosphere(P)
plt.show()
''')

md('''### Experiment 6: compare all three channels

These default scenarios have different physical distances and apertures; the table compares their stated settings, not identical hardware. Never compare raw bit counts without accounting for simulated duration. A no-error low-count result still has a nonzero uncertainty interval.
''')
code('''comparison = pd.DataFrame([r['summary'] for r in results.values()])
display(comparison[['channel','length_km','nominal_loss_db','rytov_variance','mean_channel_eta',
                    'detected_sifted_bits','qber_model','qber_observed','sifted_rate_model_bps',
                    'illustrative_postprocessing_bps','classroom_status']])
fig, axes = plt.subplots(1,2,figsize=(12,4),constrained_layout=True)
axes[0].bar(comparison.channel,100*comparison.qber_model)
axes[0].set(ylabel='Model QBER (%)',title='Same source/receiver settings, different channels')
axes[1].bar(comparison.channel,comparison.sifted_rate_model_bps)
axes[1].set(yscale='log',ylabel='Model sifted bits/s (log)',title='Retained detector events before test reveal')
for ax in axes: ax.tick_params(axis='x',rotation=15); ax.grid(alpha=.2)
plt.show()
comparison.to_csv('outputs/examples/python/channel_comparison.csv',index=False)
''')
md('''### Experiment 7: inspect real detector events and sifted strings

`nu0` and `nu1` are mean detected **signal** photons before adding gate noise. `p0` and `p1` are click probabilities after noise. The boolean click columns are random realizations; a retained `bob_bit=-1` means no usable bit. Double clicks are discarded. Bob's retained detector numbers should largely agree with Alice's selected XOR bits.
''')
code('''r = results[P['channel']]
display(r['trace'].head(20))
display(r['trace'].loc[r['trace'].accepted].head(20))
print('First 80 Alice sifted bits:', ''.join(map(str,r['alice_sifted'][:80])))
print('First 80 Bob sifted bits:  ', ''.join(map(str,r['bob_sifted'][:80])))
print('Test sample indices (zero-based Python array indices):',r['test_indices'][:20])
print('Public test size:',r['summary']['test_bits'])
print('Public test QBER:',r['summary']['test_qber'])
print('Test decision:',r['summary']['classroom_status'])
''')
md('''### Experiment 8: compare Eve absent, phase-resend, and beam-split

Use the currently selected channel. Interception is applied to actual pulse phases; beam splitting is applied to optical power. The reported Eve estimate agreement is conditional on her having an estimate and Bob retaining that slot. It is not a security bound.
''')
code('''eve_rows = []
eve_results = {}
for mode in ['none','phase-resend','beam-split']:
    cfg=copy.deepcopy(P); cfg['eve_mode']=mode
    cfg['eve_fraction']=0.7; cfg['eve_tap']=0.7
    er=simulate(cfg); eve_results[mode]=er; eve_rows.append(er['summary'])
display(pd.DataFrame(eve_rows)[['eve_mode','qber_model','qber_observed','sifted_rate_model_bps',
    'eve_signal_qber_expected','eve_estimated_sifted_bits','eve_estimate_agreement']])
er=eve_results['phase-resend']
display(er['trace'][['slot','alice_bit','forwarded_bit','eve_estimate','accepted','bob_bit']].head(30))
''')
md('''### Experiment 9: length, elevation and Eve sweeps

Fiber and terrestrial FSO sweep their own path lengths. The satellite sweep changes elevation at fixed altitude. Both Eve sweeps use the selected channel. The other current settings are retained. Curves average probabilities even when few detector events occur, but finite atmospheric sampling still produces fluctuations. For smoother results increase `sweep_slots` and obtain more independent fading blocks.
''')
code('''sweep_table = run_sweeps(P)
display(sweep_table)
fig = plot_sweeps(sweep_table)
plt.show()
export_result(results[P['channel']], 'outputs/examples/python/selected_with_sweeps', sweep_table)
''')
md('''### Experiment 10: limiting-case checks you can explain by hand

These short assertions verify the model independently of the charts. With no light and no noise, QBER is undefined. With background only it is 50%. With ideal equal-amplitude interference, there are no wrong-port photons and the signal-click probability is 1-exp(-detected mean photons). They also check the satellite geometry at zenith.
''')
code('''ideal=default_parameters()
ideal.update(n_slots=10000,visibility=1.0,phase_sigma_rad=0.0,dark_hz=0.0,background_hz=0.0)
ir=simulate(ideal); c=ir['channel']
detected_mean=ideal['mu']*c['eta0']*ideal['detector_eta']*ideal['coupling_eta']*10**(-ideal['interferometer_loss_db']/10)*c['gate_capture']
assert ir['summary']['qber_model']==0
assert np.isclose(ir['summary']['expected_single_probability'],-np.expm1(-detected_mean))
ideal['mu']=0
assert np.isnan(simulate(ideal)['summary']['qber_observed'])
ideal['dark_hz']=1e7
assert np.isclose(simulate(ideal)['summary']['qber_model'],0.5)
ideal.update(channel='Satellite-Ground',elevation_deg=90.0)
assert np.isclose(channel_model(ideal)['length_m'],ideal['sat_altitude_km']*1000)
print('All notebook limiting-case checks passed. See test_physics.py for the extended checks.')
''')
md('''## Part IV — Live runtime controls for every parameter

Click a tab, edit a value, then press a run button. **Run selected** prints every calculation and updates the charts. **Compare all three** runs all propagation models using the current source/receiver settings. **Run parameter/Eve sweeps** updates all five studies. **Export current result** reruns the currently entered configuration and saves CSV/JSON/PNG under `outputs/runtime/python/`.

To use the saved notebook interactively, execute this cell in a live Jupyter kernel. Static previews show saved output but cannot run widget callbacks. If widgets are unavailable, the dictionary examples above provide every setting without a GUI.
''')
code('''controls = runtime_controls(P)
''')
md('''### Load an exported configuration or save all trial rows

These are optional examples. Remove the leading comments when needed. Load a configuration, validate it, rerun the model, and build a fresh control panel to display its settings. Exported configuration files are compatible with the Octave structure loader.
''')
code('''# P = json.loads(Path('outputs/runtime/python/configuration.json').read_text())
# validate(P)
# current = simulate(P)
# print_report(current)
# controls = runtime_controls(P)
# current['trace'].to_csv('all_detector_trials.csv', index=False)
''')
md('''### Questions for your project discussion

1. Why does common fading primarily reduce counts while differential phase noise increases wrong-port counts?
2. Why is the optical path through the atmosphere much shorter than the satellite slant range?
3. Why does reducing elevation simultaneously change geometric loss, extinction and turbulence?
4. Why can Eve learn information from a beam splitter without directly changing the optical phase error?
5. Why are zero observed errors, a small Wilson interval, and a certified secret key three different claims?
6. How do sample count, block duration, and source clock change what observation period the simulation represents?

Include the exported configuration, assumptions, charts and uncertainty discussion in your submitted report. The source references are linked beside their associated equations in Part I.
''')
book=nb.v4.new_notebook(cells=cells,metadata={'kernelspec':{'name':'python3','display_name':'Python 3','language':'python'},
    'language_info':{'name':'python','version':'3.11'},'title':'Detailed DPS-QKD: Fiber, Terrestrial FSO and Satellite Downlink'})
nb.validate(book)
nb.write(book,ROOT/'DPS_QKD_model.ipynb')
print(f'Built {len(cells)} cells; {sum(c.cell_type=="code" for c in cells)} code cells.')
