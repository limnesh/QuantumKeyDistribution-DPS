function r = dps_compact(eta, mu, visibility, dark, phase_sigma, fec, q_sift)
  % Compatibility wrapper. Replaces legacy single/multi-photon heuristic
  % with the notebook's detector gain/QBER and generic modeled SKR proxy.
  if nargin < 7, q_sift = 1; endif
  click = dps_click(eta,mu,visibility,dark,0,phase_sigma);
  sec = dps_skr(click.gain,click.qber,fec,q_sift);
  r.gain = click.gain;
  r.qber = click.qber;
  r.secret_fraction = sec.secret_fraction;
  r.rate_per_gate = sec.skr;
  r.phase = click.qber;  % Legacy GUI alias, NOT a separate phase-error estimate.
endfunction
