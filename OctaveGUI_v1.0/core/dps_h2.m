function h = dps_h2(x)
  if any(x(:) < 0) || any(x(:) > 1)
    error('Binary entropy arguments must be between 0 and 1.');
  endif
  h = zeros(size(x));
  keep = (x > 0 & x < 1);
  y = x(keep);
  h(keep) = -y .* log2(y) - (1-y) .* log2(1-y);
endfunction
