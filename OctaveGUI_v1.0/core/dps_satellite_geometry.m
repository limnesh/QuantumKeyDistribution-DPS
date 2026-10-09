function [distance_km,elevation_deg,shell_km] = dps_satellite_geometry(p, sat_angle, ground_angle)
  R = p.earth_km; H = p.altitude_km;
  vx = (R+H).*cos(sat_angle) - R*cos(ground_angle);
  vy = (R+H).*sin(sat_angle) - R*sin(ground_angle);
  distance_km = hypot(vx,vy);
  projection = (vx.*cos(ground_angle)+vy.*sin(ground_angle))./distance_km;
  elevation_deg = asind(projection);
  ground_projection = R.*projection;
  shell_km = -ground_projection + sqrt(ground_projection.^2 + (R+p.shell_km).^2-R.^2);
  shell_km = min(distance_km,max(0,shell_km));
endfunction
