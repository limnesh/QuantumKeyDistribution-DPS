function dps_validate(p)
  positive = {'clock','distance_km','mu','w0','divergence','aperture', ...
              'optics','detector','fec','earth_km','altitude_km', ...
              'shell_km','sat_divergence','sat_aperture', ...
              'inter_divergence','inter_aperture'};
  for k = 1:numel(positive)
    v = p.(positive{k});
    if !isscalar(v) || !isfinite(v) || v <= 0
      error('%s must be a finite positive number.', positive{k});
    endif
  endfor
  nonnegative = {'alpha_db_km','pointing_db','dark','phase_sigma', ...
                 'sigma_log','zenith_loss_db','cutoff_deg','outage_threshold'};
  for k = 1:numel(nonnegative)
    v = p.(nonnegative{k});
    if !isscalar(v) || !isfinite(v) || v < 0
      error('%s must be a finite nonnegative number.', nonnegative{k});
    endif
  endfor
  if p.visibility > 1 || p.visibility < 0 || p.dark >= 1 || ...
     p.optics > 1 || p.detector > 1 || p.rho < 0 || p.rho >= 1 || ...
     p.cutoff_deg >= 90 || p.fec < 1
    error('Visibility, efficiencies, dark probability, rho, cutoff or fEC outside physical range.');
  endif
  if p.fade_count < 2 || p.fade_count != round(p.fade_count) || ...
     p.fade_dt <= 0 || p.station_offset_deg < 0 || p.station_offset_deg >= 90
    error('Invalid fading sample count, sample interval or station offset.');
  endif
endfunction
