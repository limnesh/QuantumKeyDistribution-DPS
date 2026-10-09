function [raw,qber,skr] = dps_ml_predict(Z, train_scaled, W, lo, hi, raw_scale, q_scale, length_scale, p)
  % Batched use supported by caller. Two learned outputs, SKR is DERIVED.
  scaled = bsxfun(@rdivide,bsxfun(@minus,Z,lo),hi-lo);
  pred = dps_rbf(scaled,train_scaled,length_scale)*W;
  raw = max(0,pred(:,1)*raw_scale);
  qber = min(.5,max(0,pred(:,2)*q_scale));
  parts = dps_skr(raw,qber,p.fec,p.q_sift);
  skr = parts.skr;
endfunction
