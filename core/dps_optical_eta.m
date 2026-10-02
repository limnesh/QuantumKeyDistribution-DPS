function eta = dps_optical_eta(distance_m, divergence, aperture, w0, atmosphere, pointing_db, optics, detector)
  w = hypot(w0, divergence .* distance_m);
  collection = -expm1(-2 .* (aperture ./ w).^2);
  eta = collection .* atmosphere .* 10.^(-pointing_db/10) .* optics .* detector;
  eta = min(1, max(0, eta));
endfunction
