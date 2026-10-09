function p = dps_defaults()
  % Notebook reference: DPS_QKD_FSO_v1.8_Section12_SKR.ipynb.
  % 20 km ground baseline, Sections 9-12; 10 MHz DPS gate approximation.
  p.clock = 1e7; p.distance_km = 20; p.mu = 0.24;
  p.w0 = 0.05; p.divergence = 100e-6; p.aperture = 0.20;
  p.alpha_db_km = 0.20; p.pointing_db = 3.0;
  p.optics = 0.50; p.coupling = 0.80; p.interferometer = 0.50;
  p.detector = 0.30;
  p.visibility = 0.97; p.dark = 2e-6;
  p.phase_sigma = 0.05; p.fec = 1.16; p.q_sift = 1.0;
  p.sigma_log = 0.45; p.rho = 0.96;
  p.fade_count = 2400; p.fade_dt = 10; p.outage_threshold = 2000;
  % Notebook Sections 13-15: satellite study assumptions are distinct
  % from the 20 km ground receiver assumptions.
  p.earth_km = 6371; p.altitude_km = 500;
  p.grav_km3_s2 = 398600.4418;
  p.cutoff_deg = 10; p.shell_km = 20; p.zenith_loss_db = 2;
  p.sat_divergence = 10e-6; p.sat_aperture = 0.5;
  p.sat_optics = 0.7; p.sat_detector = 0.5; p.sat_pointing_db = 1.0;
  p.station_offset_deg = 17;
  p.inter_divergence = 8e-6; p.inter_aperture = 0.35;
  p.satellite_offsets_deg = [-12, 0, 12];
  p.pass_time_s = -950:5:950;
  % Equal-budget Section 12 comparison
  p.ml_n_train = 150; p.ml_n_test = 100;
  p.ml_n_verify = 50; p.ml_n_direct = 300;
  p.ml_n_candidates = 1000000; p.ml_qber_limit = 0.05;
  p.ml_length = 0.55; p.ml_regularization = 1e-4;
  p.ml_batch_size = 4096;
endfunction
