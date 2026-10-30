% ===========================================================================================
% Replication code for Figure 2 and Table 2 in:
%
% Bastianin, A., Rossini, L., and Tonni, L.
% "A Real-Time Framework for Forecasting Metal Prices"
% International Journal of Forecasting
% -------------------------------------------------------------------------------------------
% Code author:  Lorenzo Tonni (lorenzo.tonni@unimi.it)
% Last updated: 2026-10-27
% Tested with:  MATLAB R2025b
% ===========================================================================================

% Settings and data import
clear all; clear session; close all; clc
rng(12345, 'twister');

% ===============|| Set Output Folder ||============= %
if isfolder(join([pwd,'\outputs'],'')); Folder_output = join([pwd,'\outputs'],''); % windows
else; Folder_output = join([pwd,'/outputs'],''); % mac
end

% ====================|| Set path ||================= %
if isfolder(join([pwd,'\Data'],'')); addpath(join([pwd,'\Data'],'')); % windows
else; addpath(join([pwd,'/Data'],''));
end
if isfolder(join([pwd,'\Data'],'')); Folder_data = join([pwd,'\Data'],''); % windows
else; Folder_data = join([pwd,'/Data'],''); % mac
end
if isfolder(join([pwd,'\Data\Other Predictors'],'')); Folder_new_predictors = join([pwd,'\Data\Other Predictors'],''); % windows
else; Folder_new_predictors = join([pwd,'/Data/Other Predictors'],''); % mac
end
if isfolder(join([pwd,'\Functions'],'')); addpath(join([pwd,'\Functions'],'')); % windows
else; addpath(join([pwd,'/Functions'],''));
end

% ===============|| Set Figures Folder ||============= %
if isfolder(join([pwd,'\Figures'],'')); folder_fig = join([pwd,'\Figures'],''); % windows
else; folder_fig = join([pwd,'/Figures'],''); % mac
end

%% Predictor selection

ALL_PREDICTOR_IDS = { ...
    'INDPRO'; ...
    'A31SNO'; ...
    'CPIAUCSL'; ...
    'AWHMAN'; ...
    'A35DVS'; ...
    'PCU331331'; ...
    'PCU335911335911'; ...
    'RBCLBIS'; ...
    'RBAUBIS'; ...
    'RBCNBIS'; ...
    'RBIDBIS'; ...
    'RBPEBIS'; ...
    'RBPHBIS'; ...
    'RBRUBIS'; ...
    'CAPUTLG331S'; ...
    'CAPUTLB562A3CS'; ...
    'ANMNO'; ...
    'WIP'; ...
    'CLI_G7'; ...
    'CLI_China'; ...
    'SP500'; ...
    'Gold'; ...
    'BDI'; ...
    'T10Y3M'; ...
    'VIX'; ...
    'WTI'; ...
    'Iron_Ore_Price'; ...
    'Copper_convenience_yield'; ...
    'Aluminum_convenience_yield'; ...
    'Nickel_convenience_yield'; ...
    'Zinc_convenience_yield'; ...
    'Copper_equity_index_EW'; ...
    'Aluminum_equity_index_EW'; ...
    'Nickel_equity_index_EW'; ...
    'Zinc_equity_index_EW'};

NOWCAST_PREDICTOR_IDS = { ...
    'INDPRO'; ...
    'A31SNO'; ...
    'CPIAUCSL'; ...
    'AWHMAN'; ...
    'A35DVS'; ...
    'PCU331331'; ...
    'PCU335911335911'; ...
    'RBCLBIS'; ...
    'RBAUBIS'; ...
    'RBCNBIS'; ...
    'RBIDBIS'; ...
    'RBPEBIS'; ...
    'RBPHBIS'; ...
    'RBRUBIS'; ...
    'CAPUTLG331S'; ...
    'CAPUTLB562A3CS'; ...
    'ANMNO'; ...
    'WIP'; ...
    'CLI_G7'; ...
    'CLI_China'};

WORLD_NOWCAST_PREDICTOR_IDS = {'WIP'; 'CLI_G7'; 'CLI_China'};
NON_NOWCAST_PREDICTOR_IDS = setdiff(ALL_PREDICTOR_IDS, NOWCAST_PREDICTOR_IDS, 'stable');

%% Macroeconomic predictors data

% Predictors transformations: (0) level, (1) log-level, (2) diff 1, 
%                             (3) log-diff 1, (4) diff 2, (5) log-diff 2 
t_INDPRO        = 3;
t_A31SNO        = 1;
t_CPI           = 5;
t_AWHMAN        = 1;
t_A35DVS        = 1;
t_PPI_metals    = 3;
t_PPI_batteries = 3;
t_Australia     = 3;
t_Chile         = 3;
t_China         = 3;
t_Indonesia     = 3;
t_Peru          = 3;
t_Philippines   = 3;
t_Russia        = 3;
t_CAPUTLG331S  = 1;     
t_CAPUTLB562A3CS = 1;
t_ANMNO = 1;
t_WIP = 3;
t_CLI_G7 = 0;
t_CLI_China = 0;
t_SP500 = 3;
t_Gold = 3;
t_BDI = 1;
t_T10Y3M = 0;
t_VIX = 1;
t_WTI = 1;
t_Iron_Ore_Price = 1;
t_Copper_convenience_yield = 0;
t_Aluminum_convenience_yield = 0;
t_Nickel_convenience_yield = 0;
t_Zinc_convenience_yield = 0;
t_Copper_equity_index_EW = 3;
t_Aluminum_equity_index_EW = 3;
t_Nickel_equity_index_EW = 3;
t_Zinc_equity_index_EW = 3;

predictors_transfomations = struct( ...
    'INDPRO', t_INDPRO, ...
    'A31SNO', t_A31SNO, ...
    'CPIAUCSL', t_CPI, ...
    'AWHMAN', t_AWHMAN, ...
    'A35DVS', t_A35DVS, ...
    'PCU331331', t_PPI_metals, ...
    'PCU335911335911', t_PPI_batteries, ...
    'RBCLBIS', t_Australia, ...
    'RBAUBIS', t_Chile, ...
    'RBCNBIS', t_China, ...
    'RBIDBIS', t_Indonesia, ...
    'RBPEBIS', t_Peru, ...
    'RBPHBIS', t_Philippines, ...
    'RBRUBIS', t_Russia, ...
    'CAPUTLG331S', t_CAPUTLG331S, ...
    'CAPUTLB562A3CS', t_CAPUTLB562A3CS, ...
    'ANMNO', t_ANMNO, ...
    'WIP', t_WIP, ...
    'CLI_G7', t_CLI_G7, ...
    'CLI_China', t_CLI_China, ...
    'SP500', t_SP500, ...
    'Gold', t_Gold, ...
    'BDI', t_BDI, ...
    'T10Y3M', t_T10Y3M, ...
    'VIX', t_VIX, ...
    'WTI', t_WTI, ...
    'Iron_Ore_Price', t_Iron_Ore_Price, ...
    'Copper_convenience_yield', t_Copper_convenience_yield, ...
    'Aluminum_convenience_yield', t_Aluminum_convenience_yield, ...
    'Nickel_convenience_yield', t_Nickel_convenience_yield, ...
    'Zinc_convenience_yield', t_Zinc_convenience_yield, ...
    'Copper_equity_index_EW', t_Copper_equity_index_EW, ...
    'Aluminum_equity_index_EW', t_Aluminum_equity_index_EW, ...
    'Nickel_equity_index_EW', t_Nickel_equity_index_EW, ...
    'Zinc_equity_index_EW', t_Zinc_equity_index_EW);

%% Import predictors from ALFRED

% First Release Import
[PREDICTORS_balanced_US, ~, pred_id_US] = import_predictors_fr;

%% Import predictors from other sources (OECD; Baumeister and Hamilton, 2019)

[WORLD_NOWCAST_PANELS, ~, other_predictors_import_report] = import_other_predictors_nowcast(Folder_new_predictors, [], WORLD_NOWCAST_PREDICTOR_IDS, {});
PREDICTORS_balanced_ALL_nowcast = append_vintage_predictors(PREDICTORS_balanced_US, WORLD_NOWCAST_PANELS);
n_US_predictors = numel(pred_id_US);
idx_WORLD_predictors = n_US_predictors+1:numel(PREDICTORS_balanced_ALL_nowcast.id);
PREDICTORS_balanced_WORLD = PREDICTORS_balanced_ALL_nowcast;
PREDICTORS_balanced_WORLD.data = PREDICTORS_balanced_WORLD.data(:, :, idx_WORLD_predictors);
PREDICTORS_balanced_WORLD.id = PREDICTORS_balanced_WORLD.id(idx_WORLD_predictors);
PREDICTORS_balanced_WORLD.extra_nowcast_horizon = PREDICTORS_balanced_WORLD.extra_nowcast_horizon(:, idx_WORLD_predictors);
PREDICTORS_balanced_WORLD.required_nowcast_horizon = PREDICTORS_balanced_WORLD.required_nowcast_horizon(:, idx_WORLD_predictors);
pred_id_OTHER_nowcast = PREDICTORS_balanced_WORLD.id;

predictors_transfomations_OTHER_nowcast = predictors_transfomations;

%% Example Data Revisions - Figure (2)

font_size = 20;
plot_size = 2;
axis_size = 15;

% Print Figure (2)
print_revisions(1, font_size, plot_size, axis_size, folder_fig);

%% Nowcast macroeconomic predictors

% ========= || Settings || ========= %
IC = 'AIC'; % 'BIC'/'AIC' |  Information Criteria for lags selection
Pn = 3;
P_AR = 1;
ngibbs = 6000;
nburn = 1000;

% =================================== %
print_RMSPE = 1; % Print cumulative RMSPE figures
% =================================== %

%% Nowcasting estimates

% First Measured Date
first_date = datetime('2000-1-01', 'InputFormat', 'yyyy-MM-dd');

% Last Vintage Date
last_date = datetime('2024-01-01', 'InputFormat', 'yyyy-MM-dd');

% Nowcast US Variables
[PREDICTORS_lev_now_US, results_US] = nowcast_direct(PREDICTORS_balanced_US, 1, 1, P_AR, Pn, pred_id_US, IC, predictors_transfomations, ngibbs, nburn, first_date, last_date);

% Nowcast World Variables
[PREDICTORS_lev_now_WORLD, results_WORLD] = nowcast_direct(PREDICTORS_balanced_WORLD, 1, 1, P_AR, Pn, pred_id_OTHER_nowcast, IC, predictors_transfomations_OTHER_nowcast, ngibbs, nburn, first_date, last_date);

% Print Table (2)
print_nowcast_table(results_US, results_WORLD);

%% Save balanced dataset
fileName = 'Results_nowcasting_US.mat';
filePath = fullfile(Folder_data, fileName);
save(filePath, 'results_US');

fileName = 'Results_nowcasting_WORLD.mat';
filePath = fullfile(Folder_data, fileName);
save(filePath, 'results_WORLD', 'other_predictors_import_report');

%% Balance predictors nowcasted dataset

[PREDICTORS_now_balanced_US] = balance_pred_2(PREDICTORS_lev_now_US);
[PREDICTORS_now_balanced_WORLD] = balance_pred_2(PREDICTORS_lev_now_WORLD);

[PREDICTORS_lev_available_US, available_missing_vintage_report] = make_available_predictors(PREDICTORS_balanced_US);
[PREDICTORS_lev_available_WORLD, available_missing_vintage_report_new] = make_available_predictors(PREDICTORS_balanced_WORLD);
[PREDICTORS_available_balanced_US] = balance_pred_2(PREDICTORS_lev_available_US);
[PREDICTORS_available_balanced_WORLD] = balance_pred_2(PREDICTORS_lev_available_WORLD);

%% Store Results

PREDICTORS_lev_US_nowcasted = PREDICTORS_now_balanced_US;
PREDICTORS_lev_US_nowcasted.results = results_US;
PREDICTORS_lev_US_nowcasted.contains_nowcasted_values = true;
PREDICTORS_lev_US_nowcasted.allowed_predictor_ids = ALL_PREDICTOR_IDS;
PREDICTORS_lev_US_nowcasted.nowcast_predictor_ids = cellstr(PREDICTORS_lev_US_nowcasted.RW.id(:));

PREDICTORS_lev_US_observed = PREDICTORS_available_balanced_US;
PREDICTORS_lev_US_observed.contains_nowcasted_values = false;
PREDICTORS_lev_US_observed.missing_vintage_report = available_missing_vintage_report;
PREDICTORS_lev_US_observed.allowed_predictor_ids = ALL_PREDICTOR_IDS;
PREDICTORS_lev_US_observed.nowcast_predictor_ids = cellstr(PREDICTORS_lev_US_observed.RW.id(:));

PREDICTORS_lev_US_WORLD_nowcasted = append_nowcasted_predictors(PREDICTORS_lev_US_nowcasted, PREDICTORS_now_balanced_WORLD);
PREDICTORS_lev_US_WORLD_nowcasted.results_new_predictors = results_WORLD;
PREDICTORS_lev_US_WORLD_nowcasted.new_predictors_import_report = other_predictors_import_report;
PREDICTORS_lev_US_WORLD_nowcasted.new_nowcast_predictors = WORLD_NOWCAST_PANELS;
PREDICTORS_lev_US_WORLD_nowcasted.contains_nowcasted_values = true;
PREDICTORS_lev_US_WORLD_nowcasted.allowed_predictor_ids = ALL_PREDICTOR_IDS;
PREDICTORS_lev_US_WORLD_nowcasted.nowcast_predictor_ids = cellstr(PREDICTORS_lev_US_WORLD_nowcasted.RW.id(:));
PREDICTORS_lev_US_WORLD_nowcasted.non_nowcast_predictor_ids = NON_NOWCAST_PREDICTOR_IDS;

PREDICTORS_lev_US_WORLD_observed = append_nowcasted_predictors(PREDICTORS_lev_US_observed, PREDICTORS_available_balanced_WORLD);
PREDICTORS_lev_US_WORLD_observed.contains_nowcasted_values = false;
PREDICTORS_lev_US_WORLD_observed.new_predictors_import_report = other_predictors_import_report;
PREDICTORS_lev_US_WORLD_observed.new_nowcast_predictors = WORLD_NOWCAST_PANELS;
PREDICTORS_lev_US_WORLD_observed.missing_vintage_report_old = available_missing_vintage_report;
PREDICTORS_lev_US_WORLD_observed.missing_vintage_report_new_predictors = available_missing_vintage_report_new;
PREDICTORS_lev_US_WORLD_observed.allowed_predictor_ids = ALL_PREDICTOR_IDS;
PREDICTORS_lev_US_WORLD_observed.nowcast_predictor_ids = cellstr(PREDICTORS_lev_US_WORLD_observed.RW.id(:));
PREDICTORS_lev_US_WORLD_observed.non_nowcast_predictor_ids = NON_NOWCAST_PREDICTOR_IDS;

%% Export Objects

% Save balanced dataset
fileName = 'PREDICTORS_lev_US_nowcasted.mat';
filePath = fullfile(Folder_data, fileName);
save(filePath, 'PREDICTORS_lev_US_nowcasted');

fileName = 'PREDICTORS_lev_US_WORLD_nowcasted.mat';
filePath = fullfile(Folder_data, fileName);
save(filePath, 'PREDICTORS_lev_US_WORLD_nowcasted', 'other_predictors_import_report', '-v7.3');

fileName = 'PREDICTORS_lev_US_observed.mat';
filePath = fullfile(Folder_data, fileName);
save(filePath, 'PREDICTORS_lev_US_observed', 'available_missing_vintage_report');

fileName = 'PREDICTORS_lev_US_WORLD_observed.mat';
filePath = fullfile(Folder_data, fileName);
save(filePath, 'PREDICTORS_lev_US_WORLD_observed', 'available_missing_vintage_report', 'available_missing_vintage_report_new', 'other_predictors_import_report', '-v7.3');
