function [x,w] = dps_hermgauss(n)
  % Normalized 48-node Gauss-Hermite rule, same Jacobi matrix as notebook.
  off = sqrt((1:n-1)/2);
  J = diag(off,1) + diag(off,-1);
  [V,D] = eig(J);
  [x,idx] = sort(diag(D));
  w = (V(1,idx)').^2;
  x = x(:)'; w = w(:)';
endfunction
