function [rate,qber] = dps_true_metrics(features,p)
  % Feature columns: mu, receiver radius, sigma_log, V, log10(dark).
  eta = dps_ground_eta(p,20,features(:,2));
  m = dps_fading(eta,features(:,1),features(:,4),10.^features(:,5), ...
                 p.phase_sigma,p.fec,features(:,3),p.clock);
  rate = m.pooled_rate(:); qber = m.qber(:);
endfunction
