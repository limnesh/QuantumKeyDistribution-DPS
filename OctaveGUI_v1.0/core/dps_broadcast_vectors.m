function [a,b,c,d,e] = dps_broadcast_vectors(a,b,c,d,e)
  % Inputs are scalars or vectors; return equal-size column vectors.
  n = max([numel(a),numel(b),numel(c),numel(d),numel(e)]);
  vals = {a,b,c,d,e};
  for j=1:5
    v=vals{j};
    if numel(v)==1, vals{j}=repmat(v,n,1);
    elseif numel(v)==n, vals{j}=v(:);
    else, error('Incompatible parameter sizes in fading integration.'); endif
  endfor
  a=vals{1};b=vals{2};c=vals{3};d=vals{4};e=vals{5};
endfunction
