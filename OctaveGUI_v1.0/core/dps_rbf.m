function K = dps_rbf(A,B,length_scale)
  a2 = sum(A.^2,2); b2 = sum(B.^2,2)';
  d2 = max(0,a2+b2-2*A*B');
  K = exp(-d2/(2*length_scale^2));
endfunction
