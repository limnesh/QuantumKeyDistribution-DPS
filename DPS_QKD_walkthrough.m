%% DPS-QKD school project: run sections in order in the Octave editor.
% The companion dps_qkd_simulator.m contains the explained function bodies.
% THEORY.md derives every equation; parameters.json documents all units.
% No packages need installing. The full result r retains intermediate arrays.

%% 1. Editable parameters (change these during runtime, then rerun sections)
addpath(fileparts(mfilename('fullpath')));
p=dps_qkd_simulator('defaults');
% Examples: uncomment a setting to use it.
% p.clock_hz=1e6;             % With block_slots=1000, blocks last 1 ms.
% p.n_slots=1000000;          % More detector trials.
% p.eve_mode='phase-resend';  % Alternatives: 'none', 'beam-split'.
% p.eve_fraction=0.5;
% p.fading_model='gamma-gamma';
% p.elevation_deg=30;
disp(p);

%% 2. Byte-to-phase-to-key calculation
% For A5, pulse phase bits are 1 0 1 0 0 1 0 1.
% Adjacent XOR key is 1 1 1 0 1 1 1. Columns explained below.
frame=dps_qkd_simulator('encode',p.sample_hex);
fprintf('slot | previous phase bit | current phase bit | Alice key | delta rad | ideal detector\n');
disp(frame);

%% 3. Fiber: inspect loss and dispersion before photon counting
fiber=p; fiber.channel='Fiber';
c_fiber=dps_qkd_simulator('channel',fiber);
disp(c_fiber.ledger);
r_fiber=dps_qkd_simulator(fiber,true);

%% 4. FSO: geometry, extinction, turbulence, pointing, clouds
fso=p; fso.channel='FSO-Terrestrial';
c_fso=dps_qkd_simulator('channel',fso);
disp(c_fso.ledger);
r_fso=dps_qkd_simulator(fso,true);
fprintf('First independent blocks: intensity I, pointing factor, transmission\n');
nb=min(10,numel(r_fso.fading.fade));
disp([r_fso.fading.fade(1:nb)' r_fso.fading.pointing(1:nb)' r_fso.fading.eta_blocks(1:nb)']);

%% 5. Satellite downlink: altitude is not slant range
sat=p; sat.channel='Satellite-Ground';
c_sat=dps_qkd_simulator('channel',sat);
disp(c_sat.ledger);
fprintf('Altitude (m), HV Cn2 (m^-2/3), every 100th integration point\n');
disp([c_sat.profile_h(1:100:end)' c_sat.profile_cn2(1:100:end)']);
r_sat=dps_qkd_simulator(sat,true);
dps_qkd_simulator('atmosphere',p);

%% 6. Detection and sifting: inspect actual retained trials
% Select the result to inspect. Column 15 is accepted single-click status.
r=r_fiber;
disp(r.trace_names);
disp(r.trace(1:20,:));
idx=find(r.trace(:,15)); disp(r.trace(idx(1:min(20,end)),:));
fprintf('First 80 Alice/Bob sifted bits (before public test reveal):\n');
disp(r.alice_sifted(1:min(80,end))); disp(r.bob_sifted(1:min(80,end)));
fprintf('Public test slots are 1-based in Octave:\n'); disp(r.test_indices(1:min(20,end)));
disp(r.summary.classroom_status);

%% 7. Eve experiment: change pulse phases or tap optical power
eve=p; eve.eve_mode='phase-resend'; eve.eve_fraction=.7;
r_eve=dps_qkd_simulator(eve,true);
eve.eve_mode='beam-split'; eve.eve_tap=.7;
r_tap=dps_qkd_simulator(eve,true);

%% 8. Sweep fiber/FSO distances, satellite elevation, and both Eve attacks
% Five groups; each has QBER and rate charts with explicit x-axis units.
sweep_table=dps_qkd_simulator('sweeps',p);

%% 9. Export a reproducible report and charts
dps_qkd_simulator('export',fiber,'outputs/runtime/octave/fiber');
dps_qkd_simulator('export',fso,'outputs/runtime/octave/terrestrial');
dps_qkd_simulator('export',sat,'outputs/runtime/octave/satellite');
dps_qkd_simulator('export-sweeps',p,'outputs/runtime/octave');
% Load any Python or Octave exported configuration later:
% p=jsondecode(fileread('outputs/runtime/octave/fiber/configuration.json'));

%% 10. Verify physical limits, then open the runtime editor if desired
dps_qkd_simulator('selftest');
% dps_qkd_simulator();           % Graphical all-parameter editor.
% dps_qkd_simulator('console');  % Text-only alternative.
