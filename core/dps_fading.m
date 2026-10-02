function r = dps_fading(eta, mu, visibility, dark, phase_sigma, fec, sigma_log, clock)
  % Vectorized pooling: each eta entry gets the same 48 log-normal nodes.
  [x,w] = dps_hermgauss(48);
  factor = exp(-0.5*sigma_log(:).^2 + sqrt(2)*sigma_log(:)*x);
  shape = size(eta);
  et = min(1, eta(:).*factor);
  physical = dps_click(et,mu,visibility,dark);
  proxy = dps_compact(et,mu,visibility,dark,phase_sigma,fec);
  r.physical_gain = reshape(physical.gain*w',shape);
  r.physical_qber = reshape((physical.error_gain*w') ./ ...
                    max(physical.gain*w',realmin),shape);
  g = proxy.gain*w'; g1 = proxy.g1*w';
  qb = (proxy.gain.*proxy.qber)*w' ./ max(g,realmin);
  qp = (proxy.gain.*proxy.phase)*w' ./ max(g,realmin);
  r.gain = reshape(g,shape); r.g1 = reshape(g1,shape);
  r.qber = reshape(qb,shape); r.phase = reshape(qp,shape);
  r.pooled_rate = reshape(clock*max(0,0.5*(g1.*(1-dps_h2(qp)) ...
                               -g.*fec.*dps_h2(qb))),shape);
  r.mean_node_rate = reshape(clock*(proxy.rate_per_gate*w'),shape);
endfunction
