function r = dps_compact(eta, mu, visibility, dark, phase_sigma, fec)
  pd = 1-(1-dark).^2;
  p1 = eta .* mu .* exp(-mu);
  pm = eta .* (-expm1(-mu)-mu.*exp(-mu));
  ed = (1-visibility)/2 - 0.5*expm1(-phase_sigma.^2/2);
  bit_den = p1 + pd + pm;
  r.qber = (0.5*pd + ed.*p1 + 0.25*pm) ./ max(bit_den,realmin);
  r.g0 = exp(-mu).*pd + zeros(size(eta));
  r.g1 = p1;
  r.gmulti = max(0,-expm1(-mu.*eta)-p1);
  r.gain = r.g0 + r.g1 + r.gmulti;
  r.phase = (0.5*r.g0 + r.g1.*r.qber + 0.25*r.gmulti) ./ max(r.gain,realmin);
  r.rate_per_gate = max(0,0.5*(r.g1.*(1-dps_h2(r.phase)) ...
                                      -r.gain.*fec.*dps_h2(r.qber)));
endfunction
