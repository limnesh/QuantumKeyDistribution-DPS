% Self-check against the reference notebook's deterministic equations.
% Run in Octave: run('SELF_CHECK.m'). Numerical simulation uses different RNGs.
project_root=fileparts(mfilename('fullpath'));
addpath(genpath(project_root));
p=dps_defaults();
g=dps_ground(p);
assert(abs(g.eta-0.00023690645481702264)<1e-12);
assert(abs(p.clock*g.physical.gain-608.55701373)<.005);
assert(abs(g.proxy.qber-.0474438002)<1e-6);
assert(abs(p.clock*g.proxy.rate_per_gate-246.49901934)<.02);
assert(abs(g.fading.raw_rate-608.55338585)<.02);
assert(abs(g.fading.qber-.04744399001)<1e-6);
assert(abs(g.fading.pooled_rate-246.49647013)<.03);
assert(abs(g.proxy.rate_per_gate <= g.physical.gain));
% Six parameters, including mu and pointing loss, must affect the model.
X = [.1,.20,3,.45,.97,log10(2e-6); ...
     .4,.20,3,.45,.97,log10(2e-6); ...
     .1,.20,5,.45,.97,log10(2e-6)];
[raw,q,skr]=dps_true_metrics(X,p);
assert(numel(raw)==3 && all(isfinite(raw)) && all(isfinite(q)));
assert(all(skr>=0) && all(skr<=raw+1e-10));
assert(abs(raw(1)-raw(2))>1 && abs(raw(1)-raw(3))>1);
% Small-budget smoke test, avoiding a million predictions.
p.ml_n_train=12;p.ml_n_test=8;p.ml_n_verify=5;
p.ml_n_direct=25;p.ml_n_candidates=250;p.ml_batch_size=100;
m=dps_ml(p);
assert(m.n_direct==25 && m.n_ml_candidates==250);
assert(m.ml_best_qber < p.ml_qber_limit);
assert(m.direct_best_qber < p.ml_qber_limit);
assert(m.ml_best_skr <= m.ml_best_raw + 1e-8);
assert(m.direct_best_skr <= m.direct_best_raw + 1e-8);
fprintf('PASS: ground, 48-node fading, six features, SKR, small-budget ML benchmark.\n');
