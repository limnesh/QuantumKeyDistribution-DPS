% Exercise all four runtime GUI callbacks without showing desktop windows.
% Run with octave-gui.exe --no-gui --quiet verify_octave_ui.m
addpath(fileparts(mfilename('fullpath')));
set(0,'defaultfigurevisible','off');
dps_qkd_simulator();
f=gcf(); tab=findobj(f,'type','uitable'); assert(numel(tab)==1);
data=get(tab,'Data'); assert(rows(data)==62);
for i=1:rows(data)
  if strcmp(data{i,2},'n_slots'), data{i,3}='1000'; end
  if strcmp(data{i,2},'sweep_slots'), data{i,3}='1000'; end
  if strcmp(data{i,2},'sweep_points'), data{i,3}='3'; end
end
set(tab,'Data',data);
output=findobj(f,'style','listbox');
labels={'Run selected','Compare all three','Parameter / Eve sweeps','Export current result'};
for i=1:4
  button=findobj(f,'style','pushbutton','string',labels{i}); assert(numel(button)==1);
  callback=get(button,'Callback'); callback(button,[]);
  lines=get(output,'String'); if ischar(lines), lines=cellstr(lines); end
  assert(~any(strncmp(lines,'Error:',6)),strjoin(lines,' | '));
  if i==1, assert(~isempty(strfind(lines{1},'DPS-QKD | Fiber'))); end
  if i==2, assert(sum(~cellfun(@isempty,strfind(lines,'DPS-QKD |')))==3); end
  if i==3, assert(~isempty(strfind(lines{1},'Columns: group'))); end
  if i==4, assert(exist('outputs/runtime/octave/diagnostics.png','file')==2); end
  fprintf('PASS: GUI action %s\n',labels{i});
end
close all;
fprintf('All 62 parameter rows and all four GUI callbacks passed.\n');
