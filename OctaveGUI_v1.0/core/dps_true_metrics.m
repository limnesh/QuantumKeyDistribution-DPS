function [raw,qber,skr] = dps_true_metrics(features,p)
  % Section 12 six-feature order:
  % [mu, receiver_radius_m, pointing_loss_db, sigma_log, visibility, log10_dark].
  % All features vary by candidate, including mu and pointing loss.
  if columns(features) != 6 || any(!isfinite(features(:)))
    error('Expected finite N-by-6 input features.');
  endif
  if any(features(:,1) < 0) || any(features(:,2) <= 0) || ...
     any(features(:,3) < 0) || any(features(:,4) < 0) || ...
     any(features(:,5) < 0 | features(:,5) > 1)
    error('Invalid physics features.');
  endif
  eta = dps_ground_eta(p,20,features(:,2),features(:,3));
  m = dps_fading(eta,features(:,1),features(:,5),10.^features(:,6), ...
                 p.phase_sigma,p.fec,features(:,4),p.clock,p.q_sift);
  raw = m.raw_rate(:); qber = m.qber(:); skr = m.pooled_rate(:);
endfunction
