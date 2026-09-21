addpath(pwd);
cases=jsondecode(fileread('outputs/validation/cases.json'));
rows=cell(1,numel(cases));
for i=1:numel(cases)
  r=dps_qkd_simulator('quiet',cases(i));
  rows{i}=struct('summary',r.summary,'ledger',{r.calculations});
end
p=dps_qkd_simulator('defaults'); p.channel='FSO-Terrestrial'; p.n_slots=10000;
p.block_slots=50; p.fso_pointing_urad=30;
r=dps_qkd_simulator('quiet',p);
point=struct('radius',r.channel.aperture_radius,'width',r.channel.w, ...
  'offset',r.fading.offset,'capture',r.fading.pointing*r.channel.geom);
fid=fopen('outputs/validation/octave_deterministic.json','w');
fprintf(fid,'%s',jsonencode(struct('cases',{rows},'pointing',point))); fclose(fid);
