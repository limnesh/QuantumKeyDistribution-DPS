function r = dps_skr(raw_rate, qber, fec, q_sift)
  % Generic asymptotic engineering proxy only; NOT a DPS security proof.
  % Match Section 8 and 12: SKR = raw*q_sift*max(0,1-(fec+1)*h2(Q)).
  if nargin < 4, q_sift = 1; endif
  ent = dps_h2(min(1,max(0,qber)));
  r.raw_rate = raw_rate;
  r.qber = qber;
  r.secret_fraction = q_sift .* max(0,1-fec.*ent-ent);
  r.skr = raw_rate .* r.secret_fraction;
  r.ec_leakage = q_sift .* raw_rate .* fec .* ent;
  r.pa_allowance = q_sift .* raw_rate .* ent;
endfunction
