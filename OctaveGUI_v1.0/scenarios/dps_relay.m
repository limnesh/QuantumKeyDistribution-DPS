function r = dps_relay(p)
  dps_validate(p);
  r.name = 'Trusted satellite relay between two ground stations'; r.p = p;
  r.t_s = p.pass_time_s;
  r.omega = sqrt(p.grav_km3_s2/(p.earth_km+p.altitude_km)^3);
  theta = r.omega*r.t_s;
  offset = p.station_offset_deg*pi/180;
  r.A = dps_satellite_link(p,theta,-offset);
  r.B = dps_satellite_link(p,theta,+offset);
  r.overlap_seconds = sum(r.A.open & r.B.open)*median(diff(r.t_s));
  r.trusted_relay_proxy_bits = min(r.A.proxy_budget,r.B.proxy_budget);
  r.raw_click_equivalent = min(r.A.raw_budget,r.B.raw_budget);
endfunction
