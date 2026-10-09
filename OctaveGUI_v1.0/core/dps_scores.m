function [mae,rmse,r2] = dps_scores(y,pred)
  y=y(:);pred=pred(:);
  mae=mean(abs(y-pred));
  rmse=sqrt(mean((y-pred).^2));
  denom=sum((y-mean(y)).^2);
  if denom>0, r2=1-sum((y-pred).^2)/denom;
  else, r2=NaN; endif
endfunction
