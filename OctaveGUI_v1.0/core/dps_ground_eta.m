function eta = dps_ground_eta(p, distance_km, aperture, pointing_db)
  if nargin < 3 || isempty(aperture), aperture = p.aperture; endif
  if nargin < 4 || isempty(pointing_db), pointing_db = p.pointing_db; endif
  eta = dps_optical_eta(distance_km.*1000, p.divergence, aperture, p.w0, ...
          10.^(-p.alpha_db_km.*distance_km/10), pointing_db, ...
          p.optics, p.detector, p.coupling, p.interferometer);
endfunction
