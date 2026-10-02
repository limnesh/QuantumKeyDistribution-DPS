function r = dps_satellite(p)
  dps_validate(p);
  r.name = 'Single LEO satellite DPS-QKD downlink'; r.p = p;
  r.t_s = p.pass_time_s;
  r.omega = sqrt(p.grav_km3_s2/(p.earth_km+p.altitude_km)^3);
  r.link = dps_satellite_link(p,r.omega*r.t_s,0);
  r.contact_minutes = sum(r.link.open)*median(diff(r.t_s))/60;
  r.zenith_eta = r.link.eta(r.t_s == 0);
  r.zenith_raw_per_s = r.link.raw_per_s(r.t_s == 0);
  r.zenith_proxy_per_s = r.link.rate_per_s(r.t_s == 0);
endfunction
