"""Check deterministic physics and aperture integrals in installed GNU Octave.

Different random generators must not be expected to produce identical trials.
This test compares deterministic budgets and click probabilities, then uses
Octave's own random pointing offsets to cross-check its numerical aperture integral.
"""
from pathlib import Path
import json
import subprocess
import numpy as np
from scipy.stats import ncx2
import dps_qkd as d

ROOT=Path(__file__).resolve().parent
OCTAVE=Path(r'D:\AntennaSimulations\Octave-10.3.0\mingw64\bin\octave-cli.exe')


def main():
    folder=ROOT/'outputs'/'validation'; folder.mkdir(parents=True,exist_ok=True)
    cases=[]
    for channel in ['Fiber','FSO-Terrestrial','Satellite-Ground']:
        p=d.default_parameters()
        p.update(channel=channel,n_slots=10000,visibility=1.0,phase_sigma_rad=0.0,
                 fading_model='none',fso_pointing_urad=0.0,sat_pointing_urad=0.0)
        cases.append(p)
    (folder/'cases.json').write_text(json.dumps(cases),encoding='utf-8')
    script="""addpath(pwd);
cases=jsondecode(fileread('outputs/validation/cases.json'));
rows=cell(1,numel(cases));
for i=1:numel(cases)
  r=dps_qkd_simulator('quiet',cases(i));
  rows{i}=struct('summary',r.summary,'ledger',{r.calculations});
end
p=dps_qkd_simulator('defaults'); p.channel='FSO-Terrestrial'; p.n_slots=10000;
p.block_slots=50; p.fso_pointing_urad=30;
r=dps_qkd_simulator('quiet',p);
point=struct('radius',r.channel.aperture_radius,'width',r.channel.w, ...
  'offset',r.fading.offset,'capture',r.fading.pointing*r.channel.geom);
fid=fopen('outputs/validation/octave_deterministic.json','w');
fprintf(fid,'%s',jsonencode(struct('cases',{rows},'pointing',point))); fclose(fid);
"""
    (folder/'cross_language_check.m').write_text(script,encoding='utf-8')
    proc=subprocess.run([str(OCTAVE),'--no-gui','--quiet',str(folder/'cross_language_check.m')],cwd=ROOT,capture_output=True,text=True,timeout=120)
    if proc.returncode: raise RuntimeError(proc.stdout+proc.stderr)
    actual=json.loads((folder/'octave_deterministic.json').read_text())
    lines=['# Python–Octave verification','',f'Octave executable: `{OCTAVE}`','',
           'Deterministic channel and receiver quantities agree within relative tolerance 1e-10 (absolute 1e-12).','',
           '| Channel | Nominal loss (dB) | Rytov variance | Single-click probability |',
           '|---|---:|---:|---:|']
    keys=['length_km','nominal_loss_db','rytov_variance','mean_channel_eta','expected_single_probability','qber_model','sifted_rate_model_bps']
    for p,octave in zip(cases,actual['cases']):
        py=d.simulate(p)['summary']; oc=octave['summary']
        for key in keys:
            np.testing.assert_allclose(py[key],oc[key],rtol=1e-10,atol=1e-12,err_msg=p['channel']+': '+key)
        lines.append(f"| {p['channel']} | {py['nominal_loss_db']:.10g} | {py['rytov_variance']:.10g} | {py['expected_single_probability']:.10g} |")
    x=actual['pointing']; a,w=x['radius'],x['width']; offset=np.array(x['offset'])
    target=ncx2.cdf(4*a*a/(w*w),2,4*offset**2/(w*w))
    np.testing.assert_allclose(target,x['capture'],rtol=1e-8,atol=1e-12)
    err=np.max(np.abs(target-np.array(x['capture'])))
    lines+=['',f'Exact displaced-Gaussian aperture integration: maximum absolute difference = {err:.3g} across {len(offset)} offsets.',
            '', 'Monte Carlo streams differ between languages. Matching formulas and statistically compatible outcomes are expected, not identical bit arrays.']
    (folder/'VERIFICATION.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print('\n'.join(lines))


if __name__=='__main__': main()
