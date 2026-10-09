function r = dps_ground(p)
  dps_validate(p);
  r.name='Ground 20 km DPS-QKD FSO: raw, QBER, modeled SKR'; r.p=p;
  r.eta=dps_ground_eta(p,p.distance_km);
  r.physical=dps_click(r.eta,p.mu,p.visibility,p.dark,0,p.phase_sigma);
  r.proxy=dps_compact(r.eta,p.mu,p.visibility,p.dark,p.phase_sigma,p.fec,p.q_sift);
  r.fading=dps_fading(r.eta,p.mu,p.visibility,p.dark,p.phase_sigma, ...
                     p.fec,p.sigma_log,p.clock,p.q_sift);
  r.distance_km=linspace(1,50,250);
  sweep_eta=dps_ground_eta(p,r.distance_km);
  r.sweep=dps_compact(sweep_eta,p.mu,p.visibility,p.dark,p.phase_sigma,p.fec,p.q_sift);
  r.sweep_rate=p.clock*r.sweep.rate_per_gate;
  r.mu_grid=linspace(.05,.50,140);
  eta_vec=repmat(r.eta,1,numel(r.mu_grid));
  f=dps_fading(eta_vec,r.mu_grid,p.visibility,p.dark,p.phase_sigma, ...
               p.fec,p.sigma_log,p.clock,p.q_sift);
  r.mu_rate=f.pooled_rate; r.mu_qber=f.qber;
  % AR(1) illustrative fading; RNG differs from the notebook's PCG64.
  randn('seed',991);
  z=randn(p.fade_count,1); corr_z=zeros(size(z));corr_z(1)=z(1);
  for k=2:p.fade_count
    corr_z(k)=p.rho*corr_z(k-1)+sqrt(1-p.rho^2)*z(k);
  endfor
  r.fade_t_s=(0:p.fade_count-1)'*p.fade_dt;
  r.fade_factor=exp(p.sigma_log*corr_z-.5*p.sigma_log^2);
  fade=dps_compact(min(1,r.eta*r.fade_factor),p.mu,p.visibility, ...
                   p.dark,p.phase_sigma,p.fec,p.q_sift);
  r.fade_rate=p.clock*fade.rate_per_gate;
  r.outage_fraction=mean(r.fade_rate<p.outage_threshold);
endfunction
