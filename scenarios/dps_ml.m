function r = dps_ml(p)
  dps_validate(p);
  r.name = 'Five-feature RBF kernel-ridge DPS-FSO surrogate'; r.p = p;
  root = fileparts(fileparts(mfilename('fullpath')));
  train = csvread(fullfile(root,'data','ml_train_features.csv'));
  test = csvread(fullfile(root,'data','ml_test_features.csv'));
  lo = [.03,.06,0,.940,-7]; hi = [.38,.18,.85,.995,-4.7];
  Xt = (train-lo)./(hi-lo); Xv = (test-lo)./(hi-lo);
  [yt,qt] = dps_true_metrics(train,p);
  [yv,qv] = dps_true_metrics(test,p);
  rate_scale = max(1,max(yt)); qber_scale = max(1e-3,max(qt));
  length_scale = .42; lambda = .001;
  K = dps_rbf(Xt,Xt,length_scale);
  W = (K+lambda*eye(rows(Xt)))\[yt/rate_scale,qt/qber_scale];
  prediction = dps_rbf(Xv,Xt,length_scale)*W;
  pv = max(0,prediction(:,1)*rate_scale);
  pq = min(.5,max(0,prediction(:,2)*qber_scale));
  r.test_true_rate = yv; r.test_pred_rate = pv;
  r.test_true_qber = qv; r.test_pred_qber = pq;
  r.mae_rate = mean(abs(pv-yv));
  r.mae_qber = mean(abs(pq-qv));
  r.r2_rate = 1-sum((pv-yv).^2)/sum((yv-mean(yv)).^2);
  r.r2_qber = 1-sum((pq-qv).^2)/sum((qv-mean(qv)).^2);
  [MU,A] = meshgrid(linspace(.03,.38,140),linspace(.06,.18,100));
  candidate = [MU(:),A(:),.45*ones(numel(MU),1), ...
               .98*ones(numel(MU),1),log10(2e-6)*ones(numel(MU),1)];
  pred = dps_rbf((candidate-lo)./(hi-lo),Xt,length_scale)*W;
  predicted_rate = max(0,pred(:,1)*rate_scale);
  predicted_qber = min(.5,max(0,pred(:,2)*qber_scale));
  feasible = find(predicted_qber < .05);
  if isempty(feasible), error('No feasible ML design at QBER < 5%%.'); endif
  [~,idx] = max(predicted_rate(feasible)); ml_idx = feasible(idx);
  r.ml_choice = candidate(ml_idx,:);
  r.ml_rate = predicted_rate(ml_idx); r.ml_qber = predicted_qber(ml_idx);
  [r.recheck_rate,r.recheck_qber] = dps_true_metrics(r.ml_choice,p);
  [true_rate,true_qber] = dps_true_metrics(candidate,p);
  feasible = find(true_qber < .05);
  if isempty(feasible), error('No feasible physics design at QBER < 5%%.'); endif
  [~,idx] = max(true_rate(feasible)); truth_idx = feasible(idx);
  r.truth_choice = candidate(truth_idx,:);
  r.truth_rate = true_rate(truth_idx); r.truth_qber = true_qber(truth_idx);
  r.mu_grid = MU; r.aperture_grid = A;
  r.predicted_rate_grid = reshape(predicted_rate,size(MU));
  r.predicted_qber_grid = reshape(predicted_qber,size(MU));
endfunction
