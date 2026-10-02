function p = dps_defaults()
  % Values and units match the final DPS-QKD FSO notebook.
  p.clock = 1e7; p.distance_km = 20; p.mu = 0.15;
  p.w0 = 0.05; p.divergence = 50e-6; p.aperture = 0.10;
  p.alpha_db_km = 0.1; p.pointing_db = 1;
  p.optics = 0.7; p.detector = 0.5;
  p.visibility = 0.98; p.dark = 2e-6;
  p.phase_sigma = 0.04; p.fec = 1.16;
  p.sigma_log = 0.45; p.rho = 0.96;
  p.fade_count = 2400; p.fade_dt = 10; p.outage_threshold = 2000;
  p.earth_km = 6371; p.altitude_km = 500;
  p.grav_km3_s2 = 398600.4418;
  p.cutoff_deg = 10; p.shell_km = 20; p.zenith_loss_db = 2;
  p.sat_divergence = 10e-6; p.sat_aperture = 0.5;
  p.station_offset_deg = 17;
  p.inter_divergence = 8e-6; p.inter_aperture = 0.35;
  p.satellite_offsets_deg = [-12, 0, 12];
  p.pass_time_s = -950:5:950;
endfunction
