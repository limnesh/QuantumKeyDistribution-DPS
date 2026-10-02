function eta = dps_ground_eta(p, distance_km, aperture)
  if nargin < 3, aperture = p.aperture; endif
  eta = dps_optical_eta(distance_km.*1000, p.divergence, aperture, p.w0, ...
          10.^(-p.alpha_db_km.*distance_km/10), p.pointing_db, p.optics, p.detector);
endfunction
