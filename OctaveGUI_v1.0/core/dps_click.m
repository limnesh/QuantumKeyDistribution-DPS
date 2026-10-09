function r = dps_click(eta, mu, visibility, dark, phase_offset, phase_sigma)
  % Notebook dps_detection: two threshold detectors and Gaussian phase jitter.
  if nargin < 5, phase_offset = 0; endif
  if nargin < 6, phase_sigma = 0.05; endif
  lam = mu .* eta;
  coherence = exp(-0.5 .* phase_sigma.^2);
  e_opt = (1 - visibility .* coherence .* cos(phase_offset)) ./ 2;
  pc = 1 - (1-dark) .* exp(-lam .* (1-e_opt));
  pw = 1 - (1-dark) .* exp(-lam .* e_opt);
  r.gain = pc + pw - pc .* pw;
  r.error_gain = pw .* (1-pc) + 0.5 .* pc .* pw;
  r.qber = r.error_gain ./ max(r.gain, realmin);
  r.pc = pc; r.pw = pw; r.e_opt = e_opt;
endfunction
