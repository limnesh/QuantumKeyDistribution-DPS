function r = dps_network(p)
  dps_validate(p);
  r.name = 'Three satellite trusted network and route budgets'; r.p = p;
  r.t_s = p.pass_time_s;
  step = median(diff(r.t_s));
  omega = sqrt(p.grav_km3_s2/(p.earth_km+p.altitude_km)^3);
  theta = omega*r.t_s(:) + (p.satellite_offsets_deg(:)'*pi/180);
  offset = p.station_offset_deg*pi/180;
  r.A = cell(1,3); r.B = cell(1,3);
  for k = 1:3
    r.A{k} = dps_satellite_link(p,theta(:,k),-offset);
    r.B{k} = dps_satellite_link(p,theta(:,k),+offset);
  endfor
  r.IS = cell(3,3);
  for k = 1:3
   for j = k+1:3
    sep = theta(:,j)-theta(:,k);
    slant_km = 2*(p.earth_km+p.altitude_km)*abs(sin(sep/2));
    visible = (p.earth_km+p.altitude_km)*abs(cos(sep/2)) > p.earth_km;
    eta = dps_optical_eta(slant_km*1000,p.inter_divergence, ...
          p.inter_aperture,p.w0,1,p.sat_pointing_db,p.sat_optics,p.sat_detector);
    link = dps_compact(eta,p.mu,p.visibility,p.dark,p.phase_sigma,p.fec,p.q_sift);
    click = dps_click(eta,p.mu,p.visibility,p.dark,0,p.phase_sigma);
    r.IS{k,j}.rate_per_s = p.clock*link.rate_per_gate.*visible;
    r.IS{k,j}.proxy_budget = sum(r.IS{k,j}.rate_per_s)*step;
    r.IS{k,j}.raw_per_s = p.clock*click.gain.*visible;
    r.IS{k,j}.raw_budget = sum(r.IS{k,j}.raw_per_s)*step;
    r.IS{k,j}.distance_km = slant_km;
    r.IS{k,j}.visible = visible;
   endfor
  endfor
  r.route_names = {'A-S0-B','A-S0-S2-B','A-S0-S1-S2-B'};
  r.route_proxy_bits = [min(r.A{1}.proxy_budget,r.B{1}.proxy_budget), ...
                        min([r.A{1}.proxy_budget,r.IS{1,3}.proxy_budget, ...
                             r.B{3}.proxy_budget]), ...
                        min([r.A{1}.proxy_budget,r.IS{1,2}.proxy_budget, ...
                             r.IS{2,3}.proxy_budget,r.B{3}.proxy_budget])];
  r.route_raw_click_equivalent = [min(r.A{1}.raw_budget,r.B{1}.raw_budget), ...
                         min([r.A{1}.raw_budget,r.IS{1,3}.raw_budget,r.B{3}.raw_budget]), ...
                         min([r.A{1}.raw_budget,r.IS{1,2}.raw_budget, ...
                              r.IS{2,3}.raw_budget,r.B{3}.raw_budget])];
endfunction
