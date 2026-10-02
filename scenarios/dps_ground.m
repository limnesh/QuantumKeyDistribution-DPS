function r = dps_ground(p)
  dps_validate(p);
  r.name = 'Ground DPS-QKD FSO'; r.p = p;
  r.eta = dps_ground_eta(p,p.distance_km);
  r.physical = dps_click(r.eta,p.mu,p.visibility,p.dark);
  r.proxy = dps_compact(r.eta,p.mu,p.visibility,p.dark,p.phase_sigma,p.fec);
  r.fading = dps_fading(r.eta,p.mu,p.visibility,p.dark,p.phase_sigma, ...
                        p.fec,p.sigma_log,p.clock);
  r.distance_km = linspace(1,50,250);
  eta_sweep = dps_ground_eta(p,r.distance_km);
  r.sweep = dps_compact(eta_sweep,p.mu,p.visibility,p.dark,p.phase_sigma,p.fec);
  r.sweep_rate = r.sweep.rate_per_gate*p.clock;
  r.mu_grid = linspace(0.03,0.38,140);
  mu_rate = zeros(size(r.mu_grid)); mu_qber = mu_rate;
  for k = 1:numel(r.mu_grid)
    m = dps_fading(r.eta,r.mu_grid(k),p.visibility,p.dark, ...
                   p.phase_sigma,p.fec,p.sigma_log,p.clock);
    mu_rate(k) = m.pooled_rate; mu_qber(k) = m.qber;
  endfor
  r.mu_rate = mu_rate; r.mu_qber = mu_qber;
  % A reproducible Octave seed; sample paths need not equal NumPy PCG64.
  randn('seed',991);
  z = randn(p.fade_count,1); corr_z = zeros(size(z));
  corr_z(1) = z(1);
  for k = 2:p.fade_count
    corr_z(k) = p.rho*corr_z(k-1) + sqrt(1-p.rho^2)*z(k);
  endfor
  r.fade_t_s = (0:p.fade_count-1)'*p.fade_dt;
  r.fade_factor = exp(p.sigma_log*corr_z-0.5*p.sigma_log^2);
  fade = dps_compact(min(1,r.eta*r.fade_factor),p.mu,p.visibility, ...
                     p.dark,p.phase_sigma,p.fec);
  r.fade_rate = p.clock*fade.rate_per_gate;
  r.outage_fraction = mean(r.fade_rate < p.outage_threshold);
endfunction
