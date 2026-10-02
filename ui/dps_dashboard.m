function dps_dashboard(stage,p)
  if nargin<2, p=dps_defaults(); endif
  names = {'Ground FSO + turbulence + ML','LEO satellite downlink', ...
           'Trusted satellite relay','Three satellite network'};
  pages = {{'Baseline','Distance and mu','Fading and outage','ML surrogate'}, ...
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
  common = {'Optics and detector', ...
    {'mu','visibility','dark','phase_sigma','fec','clock','pointing_db'}, ...
    {'Mean photons / pulse','Visibility','Dark / detector / gate','Phase sigma (rad)', ...
     'Error correction fEC','Clock (slots/s)','Pointing loss (dB)'}};
  switch stage
    case 1
      ground = {'Ground optical link', ...
        {'distance_km','w0','divergence','aperture','alpha_db_km','optics','detector'}, ...
        {'Distance (km)','Waist w0 (m)','Divergence (rad)','Radius (m)', ...
         'Attenuation (dB/km)','Optics efficiency','Detector efficiency'}};
      turbulence = {'Turbulence and outage', ...
        {'sigma_log','rho','fade_count','fade_dt','outage_threshold'}, ...
        {'Log-normal sigma','Temporal AR(1) rho','Number of samples', ...
         'Sample step (s)','Outage threshold (bit/s)'}};
      groups = [ground;common;turbulence];
    case 2
      orbit = {'Orbit and aperture', ...
        {'altitude_km','cutoff_deg','sat_divergence','sat_aperture','shell_km','zenith_loss_db'}, ...
        {'Altitude (km)','Elevation cutoff (deg)','Divergence (rad)', ...
         'Receiver radius (m)','Atmosphere shell (km)','Zenith loss (dB)'}};
      groups = [orbit;common];
    case 3
      relay = {'Two-station geometry', ...
        {'altitude_km','station_offset_deg','cutoff_deg','sat_divergence','sat_aperture','zenith_loss_db'}, ...
        {'Altitude (km)','Station angle +/- (deg)','Elevation cutoff (deg)', ...
         'Divergence (rad)','Receiver radius (m)','Zenith loss (dB)'}};
      groups = [relay;common];
    case 4
      network = {'Network geometry', ...
        {'altitude_km','station_offset_deg','cutoff_deg','inter_divergence','inter_aperture'}, ...
        {'Altitude (km)','Station angle +/- (deg)','Elevation cutoff (deg)', ...
         'Inter-satellite divergence (rad)','Inter-satellite radius (m)'}};
      downlink = {'Downlink optical link', ...
        {'sat_divergence','sat_aperture','zenith_loss_db','shell_km','optics','detector'}, ...
        {'Downlink divergence (rad)','Receiver radius (m)','Zenith loss (dB)', ...
         'Atmosphere shell (km)','Optics efficiency','Detector efficiency'}};
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
    if S.stage==1 && get(S.page_popup,'Value')==4 && isempty(S.ml)
      set(S.summary,'String','Training surrogate and checking 14,000 designs. Please wait...'); drawnow();
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
  cla(a); cla(b); page=get(S.page_popup,'Value');
  switch S.stage
    case 1
      switch page
        case 1
          bar(a,[p.clock*r.physical.gain,p.clock*r.proxy.rate_per_gate, ...
                 r.fading.pooled_rate]);
          set(a,'XTick',1:3,'XTickLabel',{'Raw clicks','Static proxy','Faded proxy'});
          ylabel(a,'Count or modeled bit/s'); title(a,'20 km ground baseline');
          bar(b,100*[r.physical.qber,r.proxy.qber,r.fading.qber]);
          set(b,'XTick',1:3,'XTickLabel',{'Physical','Compact','Faded compact'});
          ylabel(b,'QBER (%)'); title(b,'Different model definitions');
        case 2
          plot(a,r.distance_km,r.sweep_rate,'LineWidth',1.6); grid(a,'on');
          xlabel(a,'Distance (km)'); ylabel(a,'Modeled bit/s'); title(a,'Ground range sweep');
          plot(b,r.mu_grid,r.mu_rate,'LineWidth',1.6); grid(b,'on');
          xlabel(b,'Mean photons / pulse'); ylabel(b,'Faded modeled bit/s'); title(b,'Photon sweep');
        case 3
          plot(a,r.fade_t_s/3600,r.fade_rate,'LineWidth',.7); hold(a,'on');
          plot(a,[0,max(r.fade_t_s)/3600],p.outage_threshold*[1,1],'r--');hold(a,'off');
          xlabel(a,'Elapsed hours'); ylabel(a,'Modeled bit/s'); title(a,'Correlated fading samples');
          hist(b,r.fade_rate,35);
          xlabel(b,'Modeled bit/s'); ylabel(b,'Number of samples'); title(b,'Rate distribution');
        case 4
          scatter(a,S.ml.test_true_rate,S.ml.test_pred_rate,12,'filled');
          xlabel(a,'Physics modeled bit/s'); ylabel(a,'ML modeled bit/s');
          title(a,'Independent 180 point test'); grid(a,'on');
          imagesc(b,linspace(.03,.38,140),linspace(.06,.18,100), ...
                   S.ml.predicted_rate_grid);
          set(b,'YDir','normal');
          xlabel(b,'Mean photons / pulse'); ylabel(b,'Receiver radius (m)');
          title(b,'14,000-point surrogate search'); colorbar(b);
      endswitch
      if page==4
        m=S.ml;
        msg=sprintf(['Training 520, independent test 180; five features.\n', ...
          'MAE %.1f modeled bit/s; rate R2 %.4f; QBER MAE %.3f percentage points; QBER R2 %.4f.\n', ...
          'ML choice mu %.4f, radius %.4f m; prediction %.1f bit/s, QBER %.3f%%.\n', ...
          'Physics recheck %.1f bit/s, QBER %.3f%%; direct grid %.1f bit/s, QBER %.3f%%.'], ...
          m.mae_rate,m.r2_rate,100*m.mae_qber,m.r2_qber, ...
          m.ml_choice(1),m.ml_choice(2),m.ml_rate,100*m.ml_qber, ...
          m.recheck_rate,100*m.recheck_qber,m.truth_rate,100*m.truth_qber);
      else
        msg=sprintf(['Static eta %.8f; physical raw clicks %.1f/s; physical QBER %.3f%%.\n', ...
          'Compact modeled QBER %.3f%%, phase error %.3f%%, rate %.1f modeled bit/s.\n', ...
          '48-node faded pooled rate %.1f modeled bit/s, mean per-state rate %.1f bit/s.\n', ...
          'AR(1) sample outage %.2f%% below %.0f bit/s (seeded Octave stream).'], ...
          r.eta,p.clock*r.physical.gain,100*r.physical.qber, ...
          100*r.proxy.qber,100*r.proxy.phase,p.clock*r.proxy.rate_per_gate, ...
          r.fading.pooled_rate,r.fading.mean_node_rate, ...
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
        legend(a,{'Raw clicks/s','Modeled bit/s'}); xlabel(a,'Minutes'); title(a,'Pass rates'); grid(a,'on');
        plot(b,r.t_s(link.open)/60,100*link.proxy.qber(link.open));
        xlabel(b,'Minutes'); ylabel(b,'Compact QBER (%)'); title(b,'Open-window QBER');grid(b,'on');
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
        legend(a,{'Station A','Station B'}); xlabel(a,'Minutes');
        ylabel(a,'Elevation (deg)');title(a,'Ground station geometry');grid(a,'on');
        plot(b,r.t_s/60,r.A.rate_per_s);hold(b,'on');
        plot(b,r.t_s/60,r.B.rate_per_s);hold(b,'off');
        legend(b,{'A hop','B hop'});xlabel(b,'Minutes');
        ylabel(b,'Modeled bit/s');title(b,'Independent hop windows');grid(b,'on');
      else
        plot(a,r.t_s/60,double(r.A.open));hold(a,'on');
        plot(a,r.t_s/60,double(r.B.open));hold(a,'off');
        legend(a,{'A contact','B contact'});xlabel(a,'Minutes');
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
        legend(a,{'A-S0','A-S1','A-S2'});xlabel(a,'Minutes');
        ylabel(a,'Modeled bit/s');title(a,'Station A to satellite links');grid(a,'on');
        plot(b,r.t_s/60,r.IS{1,2}.rate_per_s);hold(b,'on');
        plot(b,r.t_s/60,r.IS{1,3}.rate_per_s);
        plot(b,r.t_s/60,r.IS{2,3}.rate_per_s);hold(b,'off');
        legend(b,{'S0-S1','S0-S2','S1-S2'});xlabel(b,'Minutes');
        ylabel(b,'Modeled bit/s');title(b,'Adjacent inter-satellite links');grid(b,'on');
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
          'true_rate_bit_s,predicted_rate_bit_s,true_qber,predicted_qber', ...
          [ml.test_true_rate,ml.test_pred_rate,ml.test_true_qber,ml.test_pred_qber]);
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
