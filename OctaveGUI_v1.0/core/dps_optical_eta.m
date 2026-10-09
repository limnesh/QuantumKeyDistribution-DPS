function eta = dps_optical_eta(distance_m, divergence, aperture, w0, atmosphere, pointing_db, optics, detector, coupling, interferometer)
  % Matches notebook optical_eta: geometric * atm * pointing * optics * coupling * MZI * detector.
  if nargin < 9, coupling = 1; endif
  if nargin < 10, interferometer = 1; endif
  w = hypot(w0, divergence .* distance_m);
  collection = -expm1(-2 .* (aperture ./ w).^2);
  eta = collection .* atmosphere .* 10.^(-pointing_db./10) .* ...
        optics .* coupling .* interferometer .* detector;
  eta = min(1, max(0, eta));
endfunction
