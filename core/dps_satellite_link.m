function r = dps_satellite_link(p, sat_angle, ground_angle)
  [r.distance_km,r.elevation_deg,r.shell_km] = ...
      dps_satellite_geometry(p,sat_angle,ground_angle);
  atm = 10.^(-p.zenith_loss_db.*(r.shell_km./p.shell_km)/10);
  r.eta = dps_optical_eta(r.distance_km*1000,p.sat_divergence, ...
          p.sat_aperture,p.w0,atm,p.pointing_db,p.optics,p.detector);
  r.open = r.elevation_deg >= p.cutoff_deg;
  r.eta(!r.open) = 0;
  r.physical = dps_click(r.eta,p.mu,p.visibility,p.dark);
  r.proxy = dps_compact(r.eta,p.mu,p.visibility,p.dark,p.phase_sigma,p.fec);
  r.raw_per_s = p.clock.*r.physical.gain.*r.open;
  r.rate_per_s = p.clock.*r.proxy.rate_per_gate.*r.open;
  r.raw_budget = sum(r.raw_per_s).*median(diff(p.pass_time_s));
  r.proxy_budget = sum(r.rate_per_s).*median(diff(p.pass_time_s));
endfunction
