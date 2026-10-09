function dps_dashboard(stage,p)
  if nargin<2, p=dps_defaults(); endif
  names = {'Ground FSO + turbulence + ML','LEO satellite downlink', ...
           'Trusted satellite relay','Three satellite network'};
  pages = {{'Baseline','Distance and mu','Fading and outage','ML vs physics','ML convergence'}, ...
           {'Pass geometry','Rates and QBER'}, ...
           {'Two hop geometry','Contact and budgets'}, ...
           {'Link windows','Route budgets'}};
  f = figure('Name',['DPS-QKD FSO | ',names{stage}], ...
      'NumberTitle','off','MenuBar','none','ToolBar','figure', ...
      'Position',[90,50,1190,740],'Color',[.96,.98,1]);
  S.stage=stage; S.p=p; S.result=[]; S.ml=[]; S.group=1;
  S.root=fileparts(fileparts(mfilename('fullpath')));
  S.groups=group_definitions(stage);
  uicontrol(f,'Style','text','String',names{stage},'Units','normalized', ...
      'Position',[.025,.92,.95,.06],'FontSize',18,'FontWeight','bold', ...
      'BackgroundColor',[.96,.98,1],'ForegroundColor',[.05,.22,.34]);
  uicontrol(f,'Style','text','String','Parameter group','Units','normalized', ...
      'Position',[.03,.86,.25,.04],'BackgroundColor',[.96,.98,1], ...
      'HorizontalAlignment','left');
  S.group_popup=uicontrol(f,'Style','popupmenu','String',S.groups(:,1), ...
      'Units','normalized','Position',[.03,.81,.27,.05], ...
      'Callback',@(src,evt) dashboard_action(f,'group'));
  S.param_panel=uipanel(f,'Title','Notebook parameters and units', ...
      'Units','normalized','Position',[.02,.33,.29,.47]);
  S.page_popup=uicontrol(f,'Style','popupmenu','String',pages{stage}, ...
      'Units','normalized','Position',[.35,.84,.29,.055], ...
      'Callback',@(src,evt) dashboard_action(f,'page'));
  S.ax1=axes('Parent',f,'Units','normalized','Position',[.36,.43,.275,.34]);
  S.ax2=axes('Parent',f,'Units','normalized','Position',[.69,.43,.275,.34]);
  S.summary=uicontrol(f,'Style','edit','Max',20,'Min',0, ...
      'Enable','inactive','HorizontalAlignment','left', ...
      'Units','normalized','Position',[.35,.10,.62,.24], ...
      'BackgroundColor',[1,1,1],'FontName','monospace','FontSize',10);
  buttons={'Run simulation','Reset defaults','Export results','Start screen'};
  actions={'run','reset','export','back'};
  for k=1:4
    uicontrol(f,'Style','pushbutton','String',buttons{k},'Units','normalized', ...
      'Position',[.03,.25-(k-1)*.058,.27,.052], ...
      'BackgroundColor',[.11,.32,.48],'ForegroundColor',[1,1,1], ...
      'Callback',@(src,evt) dashboard_action(f,actions{k}));
  endfor
  guidata(f,S); show_group(f); dashboard_action(f,'run');
endfunction

function groups = group_definitions(stage)
  common = {'Source and detector', ...
    {'mu','visibility','dark','phase_sigma','fec','q_sift','clock'}, ...
    {'Mean photons / pulse','Visibility','Dark / detector / gate','Phase sigma (rad)', ...
     'Error correction fEC','QKD sifting factor','Clock (slots/s)'}};
  switch stage
    case 1
      ground = {'Ground optical link', ...
        {'distance_km','w0','divergence','aperture','alpha_db_km','pointing_db'}, ...
        {'Distance (km)','Waist w0 (m)','Divergence (rad)','Radius (m)', ...
         'Attenuation (dB/km)','Pointing loss (dB)'}};
      receiver = {'Ground receiver factors', ...
        {'optics','coupling','interferometer','detector'}, ...
        {'Optics efficiency','Mode coupling','MZI transmission','Detector efficiency'}};
      turbulence = {'Turbulence and outage', ...
        {'sigma_log','rho','fade_count','fade_dt','outage_threshold'}, ...
        {'Log-normal sigma','Temporal AR(1) rho','Number of samples', ...
         'Sample step (s)','Outage threshold (bit/s)'}};
      mlbudget = {'Section 12 ML experiment', ...
        {'ml_n_train','ml_n_test','ml_n_verify','ml_n_direct', ...
         'ml_n_candidates','ml_qber_limit'}, ...
        {'Train physics samples','Hold-out physics samples', ...
         'Shortlist physics checks','Physics-only evaluations', ...
         'ML-only candidate predictions','QBER constraint (fraction)'}};
      groups = [ground;receiver;common;turbulence;mlbudget];
    case 2
      orbit = {'Orbit and aperture', ...
        {'altitude_km','cutoff_deg','sat_divergence','sat_aperture','shell_km','zenith_loss_db'}, ...
        {'Altitude (km)','Elevation cutoff (deg)','Divergence (rad)', ...
         'Receiver radius (m)','Atmosphere shell (km)','Zenith loss (dB)'}};
      satfactors={'Satellite optical factors', ...
        {'sat_optics','sat_detector','sat_pointing_db'}, ...
        {'Sat optics efficiency','Sat detector efficiency','Sat pointing loss (dB)'}};
      groups = [orbit;satfactors;common];
    case 3
      relay = {'Two-station geometry', ...
        {'altitude_km','station_offset_deg','cutoff_deg','sat_divergence','sat_aperture','zenith_loss_db'}, ...
        {'Altitude (km)','Station angle +/- (deg)','Elevation cutoff (deg)', ...
         'Divergence (rad)','Receiver radius (m)','Zenith loss (dB)'}};
      satfactors={'Satellite optical factors', ...
        {'sat_optics','sat_detector','sat_pointing_db'}, ...
        {'Sat optics efficiency','Sat detector efficiency','Sat pointing loss (dB)'}};
      groups = [relay;satfactors;common];
    case 4
      network = {'Network geometry', ...
        {'altitude_km','station_offset_deg','cutoff_deg','inter_divergence','inter_aperture'}, ...
        {'Altitude (km)','Station angle +/- (deg)','Elevation cutoff (deg)', ...
         'Inter-satellite divergence (rad)','Inter-satellite radius (m)'}};
      downlink = {'Downlink optical link', ...
        {'sat_divergence','sat_aperture','zenith_loss_db','shell_km','sat_optics','sat_detector','sat_pointing_db'}, ...
        {'Downlink divergence (rad)','Receiver radius (m)','Zenith loss (dB)', ...
         'Atmosphere shell (km)','Sat optics efficiency','Sat detector efficiency','Sat pointing loss (dB)'}};
      groups = [network;downlink;common];
  endswitch
endfunction

function show_group(f)
  S=guidata(f); children=get(S.param_panel,'Children');
  if !isempty(children), delete(children); endif
  fields=S.groups{S.group,2}; labels=S.groups{S.group,3};
  S.edit_handles=[];
  for k=1:numel(fields)
    y=.91-(k-1)*.125;
    uicontrol(S.param_panel,'Style','text','String',labels{k}, ...
      'Units','normalized','Position',[.04,y,.62,.07], ...
      'BackgroundColor',[.96,.98,1],'HorizontalAlignment','left');
    S.edit_handles(k)=uicontrol(S.param_panel,'Style','edit', ...
      'String',sprintf('%.10g',S.p.(fields{k})), ...
      'Units','normalized','Position',[.68,y,.28,.082], ...
      'BackgroundColor',[1,1,1]);
  endfor
  guidata(f,S);
endfunction

function [S,ok] = read_group(S)
  ok=true; fields=S.groups{S.group,2};
  for k=1:numel(fields)
    v=str2double(get(S.edit_handles(k),'String'));
    if !isscalar(v) || !isfinite(v)
      errordlg(['Enter a finite number for ',fields{k},'.'],'Invalid parameter');
      ok=false; return;
    endif
    S.p.(fields{k})=v;
  endfor
endfunction

function dashboard_action(f,action)
  if !ishandle(f), return; endif
  S=guidata(f);
  if strcmp(action,'reset')
    S.p=dps_defaults(); S.result=[]; S.ml=[]; S.group=1;
    set(S.group_popup,'Value',1); set(S.page_popup,'Value',1);
    guidata(f,S); show_group(f); dashboard_action(f,'run'); return;
  endif
  if strcmp(action,'back')
    close(f); dps_launcher(); return;
  endif
  [S,ok]=read_group(S); if !ok, return; endif
  if strcmp(action,'group')
    S.group=get(S.group_popup,'Value'); guidata(f,S); show_group(f); return;
  endif
  try
    dps_validate(S.p);
    if strcmp(action,'run')
      set(S.summary,'String','Computing scenario...'); drawnow();
      switch S.stage
        case 1, S.result=dps_ground(S.p); S.ml=[];
        case 2, S.result=dps_satellite(S.p);
        case 3, S.result=dps_relay(S.p);
        case 4, S.result=dps_network(S.p);
      endswitch
    endif
    if isempty(S.result)
      errordlg('Run the scenario first.','No result'); return;
    endif
    if S.stage==1 && get(S.page_popup,'Value')>=4 && isempty(S.ml)
      set(S.summary,'String','Running 300 physics calls and 1,000,000 ML predictions. Please wait...'); drawnow();
      S.ml=dps_ml(S.p);
    endif
    guidata(f,S);
    if strcmp(action,'export')
      export_result(S,f);
    else
      draw_page(S);
    endif
  catch ex
    errordlg(ex.message,'Simulation error');
  end_try_catch
endfunction

function draw_page(S)
  r=S.result; p=S.p; a=S.ax1; b=S.ax2;
  % Remove the previous page's colorbars BEFORE clearing axes.  Legends are
  % deliberately not used because Octave's legend autoupdate callbacks can
  % retain invalid graphics listeners after cla() on repeated page changes.
  dps_clear_plot_axis(a);
  dps_clear_plot_axis(b);
  page=get(S.page_popup,'Value');
  switch S.stage
    case 1
      switch page
        case 1
          bar(a,[p.clock*r.physical.gain,p.clock*r.proxy.rate_per_gate, ...
                 r.fading.pooled_rate]);
          set(a,'XTick',1:3,'XTickLabel',{'Raw clicks','Static SKR','Faded SKR'});
          ylabel(a,'Counts/s or bit/s'); title(a,'20 km ground baseline');
          bar(b,100*[r.physical.qber,r.proxy.qber,r.fading.qber]);
          set(b,'XTick',1:3,'XTickLabel',{'Click QBER','Static model','Pooled fading'});
          ylabel(b,'QBER (%)'); title(b,'Consistent detector model');
        case 2
          plot(a,r.distance_km,r.sweep_rate,'LineWidth',1.6); grid(a,'on');
          xlabel(a,'Distance (km)'); ylabel(a,'Modeled SKR (bit/s)'); title(a,'Ground range sweep');
          plot(b,r.mu_grid,r.mu_rate,'LineWidth',1.6); grid(b,'on');
          xlabel(b,'Mean photons / pulse'); ylabel(b,'Faded SKR (bit/s)'); title(b,'Photon sweep');
        case 3
          plot(a,r.fade_t_s/3600,r.fade_rate,'LineWidth',.7); hold(a,'on');
          plot(a,[0,max(r.fade_t_s)/3600],p.outage_threshold*[1,1],'r--');hold(a,'off');
          xlabel(a,'Elapsed hours'); ylabel(a,'Modeled SKR (bit/s)'); title(a,'Correlated fading samples');
          hist(b,r.fade_rate,35);
          xlabel(b,'Modeled SKR (bit/s)'); ylabel(b,'Samples'); title(b,'SKR distribution');
        case 4
          m=S.ml;
          scatter(a,m.test_true_skr,m.test_pred_skr,14,'filled');
          hold(a,'on'); lim=max([m.test_true_skr;m.test_pred_skr]);
          plot(a,[0 lim],[0 lim],'k--'); hold(a,'off');
          xlabel(a,'Physics modeled SKR (bit/s)'); ylabel(a,'ML predicted SKR (bit/s)');
          title(a,sprintf('%d held-out samples',m.n_test)); grid(a,'on');
          imagesc(b,m.mu_grid(1,:),m.aperture_grid(:,1),m.predicted_skr_grid);
          set(b,'YDir','normal');hold(b,'on');
          contour(b,m.mu_grid,m.aperture_grid,m.predicted_qber_grid, ...
                  [m.qber_limit m.qber_limit], 'LineColor',[1 .84 .2],'LineWidth',1.7);
          plot(b,m.ml_best_design(1),m.ml_best_design(2),'p', ...
                'MarkerSize',12,'MarkerEdgeColor',[.08 .10 .18], ...
                'MarkerFaceColor',[1 .89 .3]);
          plot(b,m.direct_best_design(1),m.direct_best_design(2),'x', ...
                'MarkerSize',12,'LineWidth',2,'Color',[1 .35 .18]);
          hold(b,'off');
          xlabel(b,'Mean photons / pulse'); ylabel(b,'Receiver radius (m)');
          title(b,'Conditional SKR; physics best is projection'); colorbar(b);
        case 5
          m=S.ml;
          plot(a,1:m.n_direct,m.direct_runbest,'LineWidth',1.7, ...
               'Color',[.83 .42 .16]);hold(a,'on');
          plot(a,1:m.n_direct,m.ml_runbest,'LineWidth',1.9, ...
               'Color',[.05 .50 .45]); hold(a,'off');
          xlabel(a,'Physics evaluations (equal budget)');
          ylabel(a,'Best verified modeled SKR (bit/s)');
          dps_plot_key(a,{'Direct physics','ML route'}, ...
              [.83 .42 .16; .05 .50 .45], 'southeast');
          title(a,'Best observed SKR');grid(a,'on');
          hb = bar(b,[m.t_direct_s,0,0; ...
                 m.t_ml_train_s,m.t_ml_search_s,m.t_ml_verify_s],'stacked');
          bar_colors = [.22 .44 .66; .88 .52 .19; .23 .58 .47];
          for ki=1:min(numel(hb),3)
            set(hb(ki),'FaceColor',bar_colors(ki,:));
          endfor
          set(b,'XTick',1:2,'XTickLabel',{'Physics','ML'});
          ylabel(b,'Compute time (s)'); title(b,'Including ML training');
          dps_plot_key(b,{'Direct / train','Search','Verify'}, ...
              bar_colors,'northeast'); grid(b,'on');
      endswitch
      if page>=4
        m=S.ml;
        msg=sprintf(['Six-feature RBF; %d train + %d held-out + %d verify = %d physics calls.\n', ...
          '%d ML predictions; predicted-feasible: %d; QBER constraint < %.1f%%.\n', ...
          'Holdout SKR MAE %.1f bit/s, R2 %.4f; QBER MAE %.3f pp, R2 %.4f.\n', ...
          'Direct: modeled SKR %.1f bit/s, QBER %.3f%%, raw %.1f clicks/s.\n', ...
          'ML route: modeled SKR %.1f bit/s, QBER %.3f%%, raw %.1f clicks/s (%s).\n', ...
          'SKR difference %+0.2f%%; timings direct %.4fs, ML total %.4fs.\n', ...
          'Generic entropy SKR proxy only; no DPS finite-key security proof.'], ...
          m.n_train,m.n_test,m.n_verify,m.n_direct,m.n_ml_candidates, ...
          m.feasible_ml_count,100*m.qber_limit,m.mae_skr,m.r2_skr, ...
          100*m.mae_qber,m.r2_qber,m.direct_best_skr, ...
          100*m.direct_best_qber,m.direct_best_raw,m.ml_best_skr, ...
          100*m.ml_best_qber,m.ml_best_raw,m.ml_best_stage, ...
          m.percent_gain,m.t_direct_s,m.t_ml_total_s);
      else
        msg=sprintf(['Static eta %.8f; raw %.1f clicks/s, QBER %.3f%%.\n', ...
          'Static modeled SKR %.1f bit/s; 48-node pooled modeled SKR %.1f bit/s.\n', ...
          'Fading pooled QBER %.3f%%; mean instantaneous SKR %.1f bit/s.\n', ...
          'AR(1) outage sample %.2f%% below %.0f modeled bit/s.\n', ...
          'Generic asymptotic entropy proxy, not a security proof.'], ...
          r.eta,p.clock*r.physical.gain,100*r.physical.qber, ...
          p.clock*r.proxy.rate_per_gate,r.fading.pooled_rate, ...
          100*r.fading.qber,r.fading.mean_node_rate, ...
          100*r.outage_fraction,p.outage_threshold);
      endif
    case 2
      link=r.link;
      if page==1
        plot(a,r.t_s/60,link.elevation_deg); hold(a,'on');
        plot(a,[min(r.t_s),max(r.t_s)]/60,p.cutoff_deg*[1,1],'r--'); hold(a,'off');
        xlabel(a,'Minutes from zenith'); ylabel(a,'Elevation (deg)'); title(a,'LEO pass'); grid(a,'on');
        plot(b,r.t_s/60,link.eta); xlabel(b,'Minutes from zenith');
        ylabel(b,'Effective transmittance'); title(b,'Open-window optical eta'); grid(b,'on');
      else
        plot(a,r.t_s/60,link.raw_per_s); hold(a,'on');
        plot(a,r.t_s/60,link.rate_per_s); hold(a,'off');
        dps_plot_key(a,{'Raw clicks/s','Modeled SKR (bit/s)'}, ...
            [.00 .447 .741; .85 .325 .098]);
        xlabel(a,'Minutes'); title(a,'Pass rates'); grid(a,'on');
        plot(b,r.t_s(link.open)/60,100*link.proxy.qber(link.open));
        xlabel(b,'Minutes'); ylabel(b,'Modeled QBER (%)'); title(b,'Open-window QBER');grid(b,'on');
      endif
      msg=sprintf(['Contact %.2f min above %.1f deg; zenith eta %.7f.\n', ...
        'Zenith physical clicks %.0f/s; zenith modeled rate %.0f bit/s.\n', ...
        'Integrated raw click equivalent %.0f; integrated modeled pass proxy %.0f bits.'], ...
        r.contact_minutes,p.cutoff_deg,r.zenith_eta, ...
        r.zenith_raw_per_s,r.zenith_proxy_per_s,link.raw_budget,link.proxy_budget);
    case 3
      if page==1
        plot(a,r.t_s/60,r.A.elevation_deg);hold(a,'on');
        plot(a,r.t_s/60,r.B.elevation_deg);hold(a,'off');
        dps_plot_key(a,{'Station A','Station B'}, ...
            [.00 .447 .741; .85 .325 .098]); xlabel(a,'Minutes');
        ylabel(a,'Elevation (deg)');title(a,'Ground station geometry');grid(a,'on');
        plot(b,r.t_s/60,r.A.rate_per_s);hold(b,'on');
        plot(b,r.t_s/60,r.B.rate_per_s);hold(b,'off');
        dps_plot_key(b,{'A hop','B hop'}, ...
            [.00 .447 .741; .85 .325 .098]); xlabel(b,'Minutes');
        ylabel(b,'Modeled SKR proxy (bit/s)');title(b,'Independent hop windows');grid(b,'on');
      else
        plot(a,r.t_s/60,double(r.A.open));hold(a,'on');
        plot(a,r.t_s/60,double(r.B.open));hold(a,'off');
        dps_plot_key(a,{'A contact','B contact'}, ...
            [.00 .447 .741; .85 .325 .098]); xlabel(a,'Minutes');
        ylabel(a,'Contact indicator');title(a,'Overlap is not required for stored keys');
        bar(b,[r.A.proxy_budget,r.B.proxy_budget,r.trusted_relay_proxy_bits]);
        set(b,'XTick',1:3,'XTickLabel',{'A hop','B hop','Bottleneck'});
        ylabel(b,'Modeled bit proxy');title(b,'Trusted relay capacity');
      endif
      msg=sprintf(['A budget %.0f bits, B budget %.0f bits; trusted relay bottleneck %.0f bits.\n', ...
        'Simultaneous station visibility %.0f s; stored-hop XOR relay assumes satellite trust.\n', ...
        'No scheduling, buffer limit or finite-key security accounted for.'], ...
        r.A.proxy_budget,r.B.proxy_budget,r.trusted_relay_proxy_bits,r.overlap_seconds);
    case 4
      if page==1
        plot(a,r.t_s/60,r.A{1}.rate_per_s);hold(a,'on');
        plot(a,r.t_s/60,r.A{2}.rate_per_s);plot(a,r.t_s/60,r.A{3}.rate_per_s);hold(a,'off');
        dps_plot_key(a,{'A-S0','A-S1','A-S2'}, ...
            [.00 .447 .741; .85 .325 .098; .929 .694 .125]); xlabel(a,'Minutes');
        ylabel(a,'Modeled SKR proxy (bit/s)');title(a,'Station A to satellite links');grid(a,'on');
        plot(b,r.t_s/60,r.IS{1,2}.rate_per_s);hold(b,'on');
        plot(b,r.t_s/60,r.IS{1,3}.rate_per_s);
        plot(b,r.t_s/60,r.IS{2,3}.rate_per_s);hold(b,'off');
        dps_plot_key(b,{'S0-S1','S0-S2','S1-S2'}, ...
            [.00 .447 .741; .85 .325 .098; .929 .694 .125]); xlabel(b,'Minutes');
        ylabel(b,'Modeled SKR proxy (bit/s)');title(b,'Adjacent inter-satellite links');grid(b,'on');
      else
        edges=[r.A{1}.proxy_budget,r.B{1}.proxy_budget, ...
               r.IS{1,2}.proxy_budget,r.IS{1,3}.proxy_budget, ...
               r.IS{2,3}.proxy_budget,r.B{3}.proxy_budget];
        bar(a,edges);set(a,'XTick',1:6,'XTickLabel', ...
            {'A-S0','S0-B','S0-S1','S0-S2','S1-S2','S2-B'});
        ylabel(a,'Modeled bit proxy');title(a,'Integrated edge budgets');
        bar(b,r.route_proxy_bits);set(b,'XTick',1:3,'XTickLabel',r.route_names);
        ylabel(b,'Modeled bit proxy');title(b,'Route bottlenecks');
      endif
      msg=sprintf(['Routes: A-S0-B %.0f; A-S0-S2-B %.0f (Earth blocks S0-S2);\n', ...
        'A-S0-S1-S2-B %.0f modeled bit proxy.\n', ...
        'Each route assumes trusted nodes and independent time-integrated edge budgets.'], ...
        r.route_proxy_bits(1),r.route_proxy_bits(2),r.route_proxy_bits(3));
  endswitch
  set(S.summary,'String',msg);
  drawnow();
endfunction

function export_result(S,f)
  stamp=datestr(now,'yyyymmdd_HHMMSS');
  folder=fullfile(S.root,'results',sprintf('scenario%d_%s',S.stage,stamp));
  mkdir(folder);
  p=S.p; result=S.result; ml=S.ml;
  save('-mat',fullfile(folder,'simulation.mat'),'p','result','ml');
  fh=fopen(fullfile(folder,'summary.txt'),'w');
  fprintf(fh,'%s\n\n%s\n\n',result.name,get(S.summary,'String'));
  keys=fieldnames(p);
  for k=1:numel(keys)
    v=p.(keys{k});
    if isnumeric(v) && numel(v)<=3
      fprintf(fh,'%s: %s\n',keys{k},mat2str(v));
    endif
  endfor
  fclose(fh);
  switch S.stage
    case 1
      write_csv(fullfile(folder,'distance_sweep.csv'), ...
        'distance_km,modeled_rate_bit_s,compact_qber', ...
        [result.distance_km(:),result.sweep_rate(:),result.sweep.qber(:)]);
      write_csv(fullfile(folder,'correlated_fade.csv'), ...
        'time_s,fade_factor,modeled_rate_bit_s', ...
        [result.fade_t_s,result.fade_factor,result.fade_rate]);
      if !isempty(ml)
        write_csv(fullfile(folder,'ml_holdout.csv'), ...
          'true_raw_clicks_s,predicted_raw_clicks_s,true_skr_bps,predicted_skr_bps,true_qber,predicted_qber', ...
          [ml.test_true_raw,ml.test_pred_raw,ml.test_true_skr,ml.test_pred_skr,ml.test_true_qber,ml.test_pred_qber]);
        write_csv(fullfile(folder,'ml_verified_shortlist.csv'), ...
          'mu,radius_m,pointing_db,sigma_log,visibility,log10_dark,pred_skr_bps,physics_raw_s,physics_qber,physics_skr_bps', ...
          [ml.ml_shortlist_designs, ml.ml_predicted_shortlist_skr, ...
           ml.verify_truth_raw,ml.verify_truth_qber,ml.verify_truth_skr]);
        write_csv(fullfile(folder,'ml_direct_vs_ml_winners.csv'), ...
          'method,mu,radius_m,pointing_db,sigma_log,visibility,log10_dark,raw_clicks_s,qber,skr_bps', ...
          [(1),ml.direct_best_design,ml.direct_best_raw,ml.direct_best_qber,ml.direct_best_skr; ...
           (2),ml.ml_best_design,ml.ml_best_raw,ml.ml_best_qber,ml.ml_best_skr]);
      endif
    case 2
      write_csv(fullfile(folder,'satellite_pass.csv'), ...
        'time_s,elevation_deg,distance_km,eta,physical_raw_per_s,modeled_rate_bit_s,compact_qber', ...
        [result.t_s(:),result.link.elevation_deg(:),result.link.distance_km(:), ...
         result.link.eta(:),result.link.raw_per_s(:), ...
         result.link.rate_per_s(:),result.link.proxy.qber(:)]);
    case 3
      write_csv(fullfile(folder,'relay_pass.csv'), ...
        'time_s,A_elevation_deg,B_elevation_deg,A_rate_bit_s,B_rate_bit_s', ...
        [result.t_s(:),result.A.elevation_deg(:),result.B.elevation_deg(:), ...
         result.A.rate_per_s(:),result.B.rate_per_s(:)]);
    case 4
      write_csv(fullfile(folder,'route_budgets.csv'), ...
        'route_index,modeled_bit_proxy',[1:3;result.route_proxy_bits]');
  endswitch
  print(f,fullfile(folder,'dashboard.png'),'-dpng');
  set(S.summary,'String',[get(S.summary,'String'),sprintf('\nExported to %s',folder)]);
  fprintf('Exported %s\n',folder);
endfunction

function write_csv(path,header,data)
  fh=fopen(path,'w'); fprintf(fh,'%s\n',header);fclose(fh);
  dlmwrite(path,data,'-append','delimiter',',','precision','%.12g');
endfunction


% -----------------------------------------------------------------------
% Graphics lifecycle helpers (Octave-safe navigation)
% -----------------------------------------------------------------------
function dps_clear_plot_axis(ax)
  if !ishandle(ax), return; endif
  % A colorbar is a companion axes and needs to be closed explicitly to
  % prevent it from surviving into the next page or shrinking its plot.
  try
    colorbar(ax,'off');
  catch
    % Some older Octave graphics toolkits have no colorbar for this axes.
  end_try_catch
  cla(ax);
  hold(ax,'off');
endfunction

function dps_plot_key(ax, labels, colors, corner)
  % Simple, STATIC keyed labels.  Unlike legend(), these text objects do not
  % register autoupdate/dellistener callbacks, so cla() can safely remove them.
  if nargin < 4, corner='northeast'; endif
  if isempty(labels), return; endif
  was_held=ishold(ax);
  hold(ax,'on');
  right= !isempty(strfind(corner,'east'));
  bottom= !isempty(strfind(corner,'south'));
  if right
    x=.97; ha='right';
  else
    x=.03; ha='left';
  endif
  count=numel(labels);
  for k=1:count
    if bottom
      y=.06+(count-k)*.085;
    else
      y=.97-(k-1)*.085;
    endif
    text(ax,x,y,['-- ',labels{k}], 'Units','normalized', ...
       'Interpreter','none','FontSize',8, 'FontWeight','bold', ...
       'HorizontalAlignment',ha, 'VerticalAlignment','top', ...
       'Color',colors(k,:), 'BackgroundColor',[1 1 1], ...
       'Clipping','on');
  endfor
  if !was_held, hold(ax,'off'); endif
endfunction
