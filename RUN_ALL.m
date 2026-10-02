% CLI entry point. Execute: run('RUN_ALL.m') in the project directory.
project_root = fileparts(mfilename('fullpath'));
addpath(genpath(project_root));
p = dps_defaults();
ground = dps_ground(p); satellite = dps_satellite(p);
relay = dps_relay(p); network = dps_network(p);
fprintf('Ground: eta %.7f, physical click %.1f/s, physical QBER %.3f%%, modeled QBER %.3f%%, modeled rate %.1f bit/s\n', ...
  ground.eta,p.clock*ground.physical.gain,100*ground.physical.qber,100*ground.proxy.qber,p.clock*ground.proxy.rate_per_gate);
fprintf('Fading: pooled modeled rate %.1f bit/s; outage sample %.2f%%\n', ...
  ground.fading.pooled_rate,100*ground.outage_fraction);
fprintf('LEO: contact %.2f min, pass proxy %.0f bits\n',satellite.contact_minutes,satellite.link.proxy_budget);
fprintf('Relay: trusted budget %.0f bits; simultaneous contact %.0f s\n', ...
  relay.trusted_relay_proxy_bits,relay.overlap_seconds);
for k = 1:numel(network.route_names)
  fprintf('Network %s: %.0f proxy bits\n',network.route_names{k},network.route_proxy_bits(k));
endfor
fprintf('Training the notebook-matched RBF surrogate and evaluating the 14,000-point design grid...\n');
ml = dps_ml(p);
fprintf('ML holdout MAE %.1f bit/s, QBER %.3f percentage points\n',ml.mae_rate,100*ml.mae_qber);
fprintf('ML proposal: mu %.4f, aperture %.4f m; physics recheck %.1f bit/s, QBER %.3f%%\n', ...
 ml.ml_choice(1),ml.ml_choice(2),ml.recheck_rate,100*ml.recheck_qber);
