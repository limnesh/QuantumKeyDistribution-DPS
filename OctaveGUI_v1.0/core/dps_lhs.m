function X = dps_lhs(n, lo, hi, seed)
  % Latin hypercube with independent Octave RNG streams. Matches notebook
  % sampling METHOD, not its NumPy/SciPy PCG64 sample coordinates.
  state = rand('state');
  unwind_protect
    rand('state', seed);
    d = numel(lo); U = zeros(n,d);
    for j=1:d
      perm = randperm(n);
      U(:,j) = (perm(:)-rand(n,1))./n;
    endfor
    X = bsxfun(@plus,lo,bsxfun(@times,U,hi-lo));
  unwind_protect_cleanup
    rand('state',state);
  end_unwind_protect
endfunction
