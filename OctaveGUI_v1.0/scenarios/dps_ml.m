function r = dps_ml(p)
  % Mirrors notebook 12.1--12.5 at the level of physics assumptions,
  % six feature bounds, RBF objective, same-budget comparison and figures.
  % Numerical random samples differ from NumPy/SciPy, so point estimates may differ.
  dps_validate(p);
  ntrain = p.ml_n_train; ntest = p.ml_n_test;
  nverify = p.ml_n_verify; ndirect = p.ml_n_direct;
  ncand = p.ml_n_candidates; qlimit = p.ml_qber_limit;
  assert(ntrain+ntest+nverify == ndirect);
  lo = [.05,.10,1.5,.15,.950,-6.0];
  hi = [.50,.25,5.0,.65,.985,-5.0];
  r.name = 'Equal-budget six-feature ML vs physics, modeled DPS SKR proxy';
  r.p = p; r.feature_low = lo; r.feature_high = hi;
  r.feature_names = {'mu','receiver_radius_m','pointing_loss_db', ...
                     'sigma_log','visibility','log10_dark'};
  r.n_train=ntrain; r.n_test=ntest; r.n_verify=nverify;
  r.n_direct=ndirect; r.n_ml_candidates=ncand;

  % ML preparation: 150 train + 100 INDEPENDENT holdout by default.
  tic();
  train = dps_lhs(ntrain,lo,hi,3602);
  test = dps_lhs(ntest,lo,hi,3603);
  [traw,tq,tskr] = dps_true_metrics(train,p);
  [vraw,vq,vskr] = dps_true_metrics(test,p);
  Xt = bsxfun(@rdivide,bsxfun(@minus,train,lo),hi-lo);
  raw_scale = max(1,max(traw)); qber_scale = max(1e-3,max(tq));
  Y = [traw/raw_scale,tq/qber_scale];
  kernel = dps_rbf(Xt,Xt,p.ml_length);
  W = (kernel+p.ml_regularization*eye(ntrain))\Y;
  [pvraw,pvq,pvskr] = dps_ml_predict(test,Xt,W,lo,hi, ...
                                    raw_scale,qber_scale,p.ml_length,p);
  r.t_ml_train_s=toc();
  r.test_true_raw=vraw; r.test_pred_raw=pvraw;
  r.test_true_qber=vq; r.test_pred_qber=pvq;
  r.test_true_skr=vskr; r.test_pred_skr=pvskr;
  [r.mae_raw,r.rmse_raw,r.r2_raw] = dps_scores(vraw,pvraw);
  [r.mae_qber,r.rmse_qber,r.r2_qber] = dps_scores(vq,pvq);
  [r.mae_skr,r.rmse_skr,r.r2_skr] = dps_scores(vskr,pvskr);

  % Physics-only: exactly ndirect direct physics calls.
  tic();
  direct = dps_lhs(ndirect,lo,hi,3604);
  [draw,dq,dskr] = dps_true_metrics(direct,p);
  dok = isfinite(dskr) & isfinite(dq) & dskr>=0 & dq>=0 & dq<qlimit;
  if !any(dok), error('No feasible direct-physics candidate.'); endif
  candidate_idxs=find(dok);
  [~,bestpos] = max(dskr(candidate_idxs));
  direct_idx = candidate_idxs(bestpos);
  r.t_direct_s = toc();
  r.direct_best_design=direct(direct_idx,:);
  r.direct_best_raw=draw(direct_idx);
  r.direct_best_qber=dq(direct_idx);
  r.direct_best_skr=dskr(direct_idx);
  r.direct_runbest=cummax_feasible(dskr,dok);

  % ML candidate screening: ONE MILLION predictions, not physics calls.
  % Keep only globally strongest 50 proposals in memory. Chunks avoid
  % materializing a 1,000,000 x 150 RBF kernel all at once.
  tic();
  candidates = dps_lhs(ncand,lo,hi,42);
  shortlist_scores = -inf(nverify,1);
  shortlist_designs = zeros(nverify,6);
  feasible_count = 0;
  for start=1:p.ml_batch_size:ncand
    stop = min(start+p.ml_batch_size-1,ncand);
    block = candidates(start:stop,:);
    [pr,pq,ps] = dps_ml_predict(block,Xt,W,lo,hi, ...
                                 raw_scale,qber_scale,p.ml_length,p);
    ok = isfinite(ps)&isfinite(pq)&ps>=0&pq>=0&pq<qlimit;
    feasible_count = feasible_count + sum(ok);
    viable = find(ok);
    if !isempty(viable)
      [ordered,perm] = sort(ps(viable),'descend');
      nkeep=min(nverify,numel(ordered));
      inds=viable(perm(1:nkeep));
      combined_scores=[shortlist_scores;ps(inds)];
      combined_designs=[shortlist_designs;block(inds,:)];
      [sorted_scores,order] = sort(combined_scores,'descend');
      shortlist_scores=sorted_scores(1:nverify);
      shortlist_designs=combined_designs(order(1:nverify),:);
    endif
  endfor
  r.t_ml_search_s=toc();
  clear candidates;
  if feasible_count < nverify || any(!isfinite(shortlist_scores))
    error('Fewer than n_verify surrogate-feasible proposals.');
  endif
  r.feasible_ml_count=feasible_count;
  r.ml_predicted_shortlist_skr=shortlist_scores;
  r.ml_shortlist_designs=shortlist_designs;

  % Verify exactly nverify ML proposals with the same direct physics model.
  tic();
  [verify_raw,verify_q,verify_skr] = dps_true_metrics(shortlist_designs,p);
  r.t_ml_verify_s=toc();
  r.verify_truth_skr=verify_skr;
  r.verify_truth_qber=verify_q;
  r.verify_truth_raw=verify_raw;
  verify_ok=isfinite(verify_skr)&isfinite(verify_q)& ...
            verify_skr>=0&verify_q>=0&verify_q<qlimit;

  % All ML-route measured points may win: train + test + verification.
  all_x=[train;test;shortlist_designs];
  all_raw=[traw;vraw;verify_raw];
  all_q=[tq;vq;verify_q];
  all_skr=[tskr;vskr;verify_skr];
  all_ok=isfinite(all_skr)&isfinite(all_q)& ...
         all_skr>=0&all_q>=0&all_q<qlimit;
  if !any(all_ok), error('No physics-feasible ML-route observations.'); endif
  valid=find(all_ok);[~,ix]=max(all_skr(valid));best=valid(ix);
  r.ml_best_design=all_x(best,:);
  r.ml_best_raw=all_raw(best);
  r.ml_best_qber=all_q(best);
  r.ml_best_skr=all_skr(best);
  r.ml_best_stage='verification';
  if best<=ntrain, r.ml_best_stage='training';
  elseif best<=ntrain+ntest, r.ml_best_stage='hold-out'; endif
  r.ml_runbest=cummax_feasible(all_skr,all_ok);
  r.t_ml_total_s=r.t_ml_train_s+r.t_ml_search_s+r.t_ml_verify_s;
  r.percent_gain=100*(r.ml_best_skr/max(r.direct_best_skr,realmin)-1);
  r.qber_limit=qlimit;

  % Conditional surrogate SKR map (mu vs receiver radius), at the four
  % remaining ML-winner coordinates; the physics-only marker is a projection.
  [MU,A] = meshgrid(linspace(lo(1),hi(1),120), ...
                     linspace(lo(2),hi(2),110));
  n=numel(MU);fix=r.ml_best_design;
  surface=[MU(:),A(:),repmat(fix(3:6),n,1)];
  sr=zeros(n,1);sq=zeros(n,1);ss=zeros(n,1);
  for start=1:p.ml_batch_size:n
    stop=min(start+p.ml_batch_size-1,n);
    [sr(start:stop),sq(start:stop),ss(start:stop)] = ...
      dps_ml_predict(surface(start:stop,:),Xt,W,lo,hi, ...
                     raw_scale,qber_scale,p.ml_length,p);
  endfor
  r.mu_grid=MU; r.aperture_grid=A;
  r.predicted_raw_grid=reshape(sr,size(MU));
  r.predicted_qber_grid=reshape(sq,size(MU));
  r.predicted_skr_grid=reshape(ss,size(MU));
endfunction

function a = cummax_feasible(values,feasible)
  a=nan(numel(values),1);best=-inf;
  for k=1:numel(values)
    if feasible(k), best=max(best,values(k)); endif
    if isfinite(best), a(k)=best; endif
  endfor
endfunction
