function r = dps_fading(eta, mu, visibility, dark, phase_sigma, fec, sigma_log, clock, q_sift)
  % Notebook fading_moments: 48-node GH, unit-mean lognormal, click-weighted
  % pooled QBER, then generic post-processing ONCE (not averaged SKR first).
  if nargin < 9, q_sift = 1; endif
  [x,w] = dps_hermgauss(48);
  shape = size(eta);
  [e,mu,vis,dark,sigma] = dps_broadcast_vectors(eta,mu,visibility,dark,sigma_log);
  factors = exp(-0.5.*sigma.^2 + sqrt(2).*(sigma*x));
  et = min(1, bsxfun(@times,e,factors));
  click = dps_click(et,mu,vis,dark,0,phase_sigma);
  gain = click.gain * w';
  pooled_qber = (click.error_gain * w') ./ max(gain,realmin);
  pooled = dps_skr(gain,pooled_qber,fec,q_sift);
  instantaneous = dps_skr(click.gain,click.qber,fec,q_sift);
  r.gain = reshape(gain,shape);
  r.qber = reshape(pooled_qber,shape);
  r.physical_gain = r.gain;
  r.physical_qber = r.qber;
  r.pooled_secret_fraction = reshape(pooled.secret_fraction,shape);
  r.pooled_rate = reshape(clock.*pooled.skr,shape);
  r.raw_rate = reshape(clock.*gain,shape);
  r.mean_node_rate = reshape(clock.*(instantaneous.skr*w'),shape);
  r.phase = r.qber;  % Compatibility alias only.
endfunction
