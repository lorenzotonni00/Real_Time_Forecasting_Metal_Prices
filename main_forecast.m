% ===========================================================================================
% Replication code for Bastianin, A., Rossini, L., and Tonni, L. "A Real-Time Framework
% for Forecasting Metal Prices", International Journal of Forecasting
%
% Produces the real-time forecasting results for the real prices of copper, aluminum,
% nickel and zinc (Tables 3-5, Figures 3-6 and the Supplement
% tables/figures).
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

% ===============|| Set Professional Survey Folder ||============= %
if isfolder(join([pwd,'\Economic_Consensus'],'')); Folder_survey = join([pwd,'\Economic_Consensus'],''); % windows
else; Folder_survey = join([pwd,'/Economic_Consensus'],''); % mac
end

% ====================|| Set path ||================= %
if isfolder(join([pwd,'\Data'],'')); Folder_data = join([pwd,'\Data'],''); addpath(Folder_data); % windows
else; Folder_data = join([pwd,'/Data'],''); addpath(Folder_data);
end
if isfolder(join([pwd,'\Data\Other Predictors'],'')); Folder_new_predictors = join([pwd,'\Data\Other Predictors'],''); % windows
else; Folder_new_predictors = join([pwd,'/Data/Other Predictors'],''); % mac
end
if isfolder(join([pwd,'\Functions'],'')); addpath(join([pwd,'\Functions'],'')); % windows
else; addpath(join([pwd,'/Functions'],''));
end
if isfolder(join([pwd,'\Economic_Consensus'],'')); addpath(join([pwd,'\Economic_Consensus'],'')); % windows
else; addpath(join([pwd,'/Economic_Consensus'],''));
end

% ===============|| Set Figures Folder ||============= %
if isfolder(join([pwd,'\Figures'],'')); folder_fig = join([pwd,'\Figures'],''); % windows
else; folder_fig = join([pwd,'/Figures'],''); % mac
end

%% Check all non-public data are correctly stored

data_check = check_nonpublic_data(Folder_data, Folder_new_predictors);
if ~data_check.all_available
    return
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

NON_NOWCAST_PREDICTOR_IDS = setdiff(ALL_PREDICTOR_IDS, NOWCAST_PREDICTOR_IDS, 'stable');

%% Import Data

% Nowcasted Data (level) - US Predictors
load('PREDICTORS_lev_US_nowcasted.mat', 'PREDICTORS_lev_US_nowcasted');

% Nowcasted Data (level) - US + World Predictors
US_WORLD_nowcast_file = fullfile(Folder_data, 'PREDICTORS_lev_US_WORLD_nowcasted.mat');
if exist(US_WORLD_nowcast_file, 'file') == 2
    S_extended = load(US_WORLD_nowcast_file, 'PREDICTORS_lev_US_WORLD_nowcasted', 'other_predictors_import_report');
    PREDICTORS_lev_US_WORLD_nowcasted = S_extended.PREDICTORS_lev_US_WORLD_nowcasted;
    WORLD_predictors_import_report = struct();
else
    warning('US-WORLD nowcasted predictor file not found: %s. Extended exercises will use the US predictor set.', US_WORLD_nowcast_file);
    PREDICTORS_lev_US_WORLD_nowcasted = PREDICTORS_lev_US_WORLD_nowcasted;
    WORLD_predictors_import_report = struct();
end

% Available real-time data without nowcasted edge - US Predictors' Set
observed_nowcast_file = fullfile(Folder_data, 'PREDICTORS_lev_US_observed.mat');
if exist(observed_nowcast_file, 'file') == 2
    S_available = load(observed_nowcast_file, 'PREDICTORS_lev_US_observed');
    PREDICTORS_lev_US_observed = S_available.PREDICTORS_lev_US_observed;
else
    warning('Available predictor file not found: %s. Banbura-Modugno DFM will use the nowcasted panel and remove its edge.', observed_nowcast_file);
    PREDICTORS_lev_US_observed = PREDICTORS_lev_US_WORLD_nowcasted;
end

% Available real-time data without nowcasted edge - US + World Predictors' Set
available_extended_file = fullfile(Folder_data, 'PREDICTORS_lev_US_WORLD_observed.mat');
if exist(available_extended_file, 'file') == 2
    S_available_extended = load(available_extended_file, 'PREDICTORS_lev_US_WORLD_observed');
    PREDICTORS_lev_US_WORLD_observed= S_available_extended.PREDICTORS_lev_US_WORLD_observed;
else
    warning('Extended available predictor file not found: %s. Extended Banbura-Modugno DFM will use the available old predictor set.', available_extended_file);
    PREDICTORS_lev_US_WORLD_observed = PREDICTORS_lev_US_observed;
end

% ETMs Price (level)
[ETM_monthly_raw] = import_ETM;

% Select Macroeconomic Predictors
PREDICTORS_lev_US_WORLD_nowcasted = select_predictors_by_id(PREDICTORS_lev_US_WORLD_nowcasted, NOWCAST_PREDICTOR_IDS);
PREDICTORS_lev_US_WORLD_observed = select_predictors_by_id(PREDICTORS_lev_US_WORLD_observed, NOWCAST_PREDICTOR_IDS);

% Import Financial Predictors
[~, NEW_FINANCIAL_PREDICTORS, financial_predictors_import_report] = import_financial_predictors(Folder_new_predictors, ETM_monthly_raw, {}, NON_NOWCAST_PREDICTOR_IDS);
nowcast_predictors_import_report = WORLD_predictors_import_report;
WORLD_predictors_import_report = financial_predictors_import_report;
WORLD_predictors_import_report.nowcast = nowcast_predictors_import_report;

PREDICTORS_lev_US_WORLD_nowcasted = append_financial_predictors_realtime(PREDICTORS_lev_US_WORLD_nowcasted, NEW_FINANCIAL_PREDICTORS);
PREDICTORS_lev_US_WORLD_observed = append_financial_predictors_realtime(PREDICTORS_lev_US_WORLD_observed, NEW_FINANCIAL_PREDICTORS);
PREDICTORS_lev_US_WORLD_nowcasted.non_nowcast_predictors = NEW_FINANCIAL_PREDICTORS;
PREDICTORS_lev_US_WORLD_observed.non_nowcast_predictors = NEW_FINANCIAL_PREDICTORS;

% Load Consensus Economics Survey of Professional Forecasters Data
load('p_forecasts_fixed_h_imputed.mat');

% Load Daily Futures Prices
[futures_raw] = import_futures_daily;

% Balance Data (level)
[PREDICTORS_US, ETM, ~] = balance_forecast(PREDICTORS_lev_US_nowcasted, ETM_monthly_raw, futures_raw);
[PREDICTORS_US_WORLD, ETM_extended, futures_extended] = balance_forecast(PREDICTORS_lev_US_WORLD_nowcasted, ETM_monthly_raw, futures_raw);
[PREDICTORS_bm, ETM_bm, ~] = balance_forecast(PREDICTORS_lev_US_observed, ETM_monthly_raw, futures_raw);

WORLD_predictors_id = setdiff(cellstr(PREDICTORS_US_WORLD.SA.id), cellstr(PREDICTORS_US.SA.id), 'stable');
unexpected_predictor_ids = setdiff(cellstr(PREDICTORS_US_WORLD.SA.id), ALL_PREDICTOR_IDS, 'stable');
if ~isempty(unexpected_predictor_ids)
    error('Unexpected predictors imported in main_forecast.m: %s', strjoin(unexpected_predictor_ids, ', '));
end

%% ============|| Forecasting ETMs Prices ||==============%

% First (pseudo) in-sample date (referred to variables in level, before transformations)
start_date = datetime('2000-1-01', 'InputFormat', 'yyyy-MM-dd');

% Last Out-of-sample date
 end_date = datetime('2023-11-01', 'InputFormat', 'yyyy-MM-dd');  % (max 1 jan 2024 if nominal)   
                                                                  % (max 1 nov 2023 if real)
% Last vintage in-sample date (minimum 01 Apr 2015: first available vintage)                                   
Lastin = datetime('2015-04-01', 'InputFormat', 'yyyy-MM-dd'); 

%============|| Choose Imput Data Nowcasting model ||===========%

% (1) RW-D; (2) BAR; (3) BAR-SV; (4) BAR-SVO;
% (5) Last release data (not real time);

model = 1;

% =============|| General Settings ||=============%
Target_scheme = 'SW'; % 'SinglePeriod': monthly growth rate | 'SW': horizon growth rate
rollwind = 1;   % 1: rolling window | 0: expanding window
IC = 'AIC'; % 'BIC'/'AIC' |  Information Criteria for lags selection
Pn = 3; % Maximum Number of Lags Considered for IC
benchmark = 'RW'; % 'RW': Random Walk | 'AR': AR(1)
Hsize = 24; % Maximum forecast horizon (h = 1,...,Hsize)
real = 1; % Real price forecasts (1: real | 0: nominal)
real_time_forecast = 1; % (1): pseudo real-time vintages | (0): last vintage values
real_price_vintage = 'real_time'; % 'real_time': vintage CPI | 'last_vintage': final CPI for all vintages
run_non_real_time_forecast = 1; % Run forecasting exercise with revised (non real-time) data
run_bm_dfm_ragged_forecast = 1; % Run Banbura-Modugno DFM
run_mcs = 1; % Run Model Confidence Set (MCS)
run_forecast_combination = 1; % Run forecast combinations
bm_dfm_opts.p = 1;
bm_dfm_opts.maxiter = 150; % Max attempts for EM convergence in Banbura-Modugno DFM
bm_dfm_opts.thresh = 1e-3; % Convergence threshold in Banbura-Modugno DFM

% Variables to forecast
target_series = {
    'Copper', ...
    'Aluminum', ...
    'Nickel',...
    'Zinc'
};

% =============|| AR settings ||==================%
P_AR = 1; % User selected nb of lags for AR model

% =============|| AR-DI settings ||===============%
P_custom_ARDI = 1; % User selected nb of lags for ARDI model (same for all variables)

% =============|| AR-DL settings ||===============%
P_custom_ARDL = 1; % User selected nb of lags for ARDL model (same for all variables)

% (1) Single exogenous regressors in the ARDL model
regressors = {
     'INDPRO'...
     'A31SNO', ...
     'AWHMAN', ...
     'A35DVS', ...
     'PCU331331', ...
     'PCU335911335911', ...
     'RBCLBIS', ...
     'RBAUBIS', ...
     'RBCNBIS', ...
     'RBIDBIS', ...
     'RBPEBIS', ... 
     'RBPHBIS', ...
     'RBRUBIS' ...
     'Aluminum',...
     'Copper', ...
     'Nickel',...
     'Zinc', ...
     'Zinc_Stock', ...
     'Aluminum_Stock',...
     'Copper_Stock',...
     'Nickel_Stock',...
     'CAPUTLG331S',...
     'CAPUTLB562A3CS',...
     'ANMNO'
     };

%% Group ARDL Models

% (1) Economic Activity
regressors_real_activity = {
     'INDPRO'...
     'AWHMAN', ...
     'A31SNO', ...
     'ANMNO'
};

% (2) Energy Transition
regressors_et = {
    'PCU335911335911'
    'A35DVS'};

% (3) Capacity Utilization
regressors_cu = {
    'CAPUTLG331S',...
    'CAPUTLB562A3CS'};

% (4) Exchange Rates
regressors_ex_rates = {
     'RBCLBIS', ...
     'RBAUBIS', ...
     'RBCNBIS', ...
     'RBIDBIS', ...
     'RBPEBIS', ... 
     'RBPHBIS', ...
     'RBRUBIS'
};

% (5) ETM Prices
regressors_etm = {
     'Aluminum',...
     'Copper', ...
     'Nickel',...
     'Zinc'
};

% (6) Metal Inventories
regressors_inventories = {
     'Aluminum_Stock',...
     'Copper_Stock', ...
     'Nickel_Stock',...
     'Zinc_Stock'
};

% (7) World Economic Activity
regressors_w_act = {
    'WIP',...
    'CLI_G7',...
    'CLI_China'
};

%% =============|| VAR settings ||===============%
P_custom_VAR = 1; % User selected nb of lags for VAR model

target_var_metals = {
     'Aluminum',...
     'Copper', ...
     'Nickel',...
     'Zinc'
};
                                         
                                                                   
% (A) Metals Price transformations (horizon level): (0) level, (1) log-level, (2) diff 1, 
%                                                   (3) log-diff 1, (4) diff 2, (5) log-diff 2 

t_COPP = 3;
t_ALUM = 3;
t_NICK = 3;
t_ZINC = 3;

raw_transformations = struct( ...
    'Copper', t_COPP, ...
    'Aluminum', t_ALUM, ...
    'Nickel', t_NICK, ...
    'Zinc', t_ZINC);

% (B) Predictors transformations: (0) level, (1) log-level, (2) diff 1, 
%                                 (3) log-diff 1, (4) diff 2, (5) log-diff 2 
t_INDPRO           = 3; 
t_A31SNO           = 1;
t_CPI              = 5;
t_AWHMAN           = 1;
t_A35DVS           = 1;
t_PPI_metals       = 3;
t_PPI_batteries    = 3;
t_Chile            = 3;
t_Australia        = 3;
t_China            = 3;
t_Indonesia        = 3;
t_Peru             = 3;
t_Philippines      = 3;
t_Russia           = 3;
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
t_Copper           = 3;
t_Aluminum         = 3;
t_Nickel           = 3;
t_Zinc             = 3;
t_Aluminum_Stock = 3;
t_Copper_Stock    = 3;
t_Nickel_Stock    = 3;
t_Zinc_Stock      = 3;

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
    'Zinc_equity_index_EW', t_Zinc_equity_index_EW, ...
    'Copper', t_Copper, ...
    'Aluminum', t_Aluminum, ...
    'Nickel', t_Nickel, ...
    'Zinc', t_Zinc, ...
    'Aluminum_Stock', t_Aluminum_Stock, ...
    'Copper_Stock', t_Copper_Stock, ...
    'Nickel_Stock', t_Nickel_Stock, ...
    'Zinc_Stock', t_Zinc_Stock);

%% Create US + World Dataset

WORLD_regressors = setdiff(NOWCAST_PREDICTOR_IDS(:)', regressors, 'stable');
regressors_WORLD = [regressors, WORLD_regressors];
regressors_WORLD(strcmp(regressors_WORLD, 'CPIAUCSL')) = [];
predictors_US_WORLD = select_predictors_by_id(PREDICTORS_US_WORLD, NOWCAST_PREDICTOR_IDS);

%% (1a) Forecasting - Single Models Real-Time (US + World Data)

% D-M Test missings treatment
treatment = 0; % (0) drop the entire horizon-model if there are NaNs
               % (1) drop NaNs and run D-M test on a smaller sample

[results_US_WORLD] = forecasting(p_forecasts_fixed_h_imputed, ETM_extended, predictors_US_WORLD, real, rollwind, 1, model, start_date, end_date, Lastin, predictors_transfomations, raw_transformations, Target_scheme, Hsize, regressors_WORLD, IC, Pn, P_AR, P_custom_ARDL, P_custom_ARDI, P_custom_VAR, target_series, regressors_real_activity, regressors_ex_rates, regressors_et, regressors_cu, regressors_inventories, regressors_etm, regressors_w_act, target_var_metals, benchmark, futures_extended, treatment, folder_fig, real_time_forecast, real_price_vintage);

% Store Results
fileName = 'results_ratio_US_WORLD.mat';
filePath = fullfile(Folder_output, fileName);
save(filePath, 'results_US_WORLD', 'NOWCAST_PREDICTOR_IDS');

% Reproduce Tables (3) and (4)
print_forecast_tables(results_US_WORLD, target_series);

% Reproduce Figure (3)
plot_favar_factors(results_US_WORLD, 'Copper', folder_fig);

%% (1b) Model Confidence Set

if run_mcs == 1

    [MCS_stat, table_export] = MCS_b(target_series, results_US_WORLD, Hsize);

    % Store Results
    fileName = 'results_MCS.mat';
    filePath = fullfile(Folder_output, fileName);
    save(filePath, 'table_export');

end

%% (1c) Forecast Combination

if run_forecast_combination == 1

    rolling = 1;
    [forecast_comb] = forecast_comb_fn(ETM, predictors_US_WORLD, real, model, results_US_WORLD, target_series, rolling, Hsize, start_date, Lastin, raw_transformations, treatment, real_time_forecast);

    % Store Results
    fileName = 'results_comb.mat';
    filePath = fullfile(Folder_output, fileName);
    save(filePath, 'forecast_comb');

    print_forecast_comb_table(forecast_comb, target_series, results_US_WORLD);

end

%% (2) Forecasting - Single Models Non Real-Time (US + World Data Revised)

if run_non_real_time_forecast == 1

    real_time_forecast_non_rt = 0;

    [results_non_real_time] = forecasting(p_forecasts_fixed_h_imputed, ETM_extended, predictors_US_WORLD, real, rollwind, 1, model, start_date, end_date, Lastin, predictors_transfomations, raw_transformations, Target_scheme, Hsize, regressors_WORLD, IC, Pn, P_AR, P_custom_ARDL, P_custom_ARDI, P_custom_VAR, target_series, regressors_real_activity, regressors_ex_rates, regressors_et, regressors_cu, regressors_inventories, regressors_etm, regressors_w_act, target_var_metals, benchmark, futures_extended, treatment, folder_fig, real_time_forecast_non_rt, real_price_vintage);

    % Store Results
    fileName = 'results_ratio_non_real_time.mat';
    filePath = fullfile(Folder_output, fileName);
    save(filePath, 'results_non_real_time');

    % Reproduce Table S.7–S.8, S.9 and S.11–S.14
    print_non_rt_comparison_table(results_non_real_time, results_US_WORLD, target_series);

end

%% (3) Forecasting - Banbura-Modugno DFM (US dataset)

if run_bm_dfm_ragged_forecast == 1

    [results_bm_dfm_nominal] = forecasting_bm_dfm_ragged_nominal(ETM_bm, PREDICTORS_bm, real, rollwind, model, start_date, end_date, Lastin, predictors_transfomations, raw_transformations, Target_scheme, Hsize, target_series, benchmark, treatment, real_time_forecast, real_price_vintage, bm_dfm_opts, results_US_WORLD);

    % Store Results
    fileName = 'results_bm_dfm_nominal.mat';
    filePath = fullfile(Folder_output, fileName);
    save(filePath, 'results_bm_dfm_nominal');

    % Reproduce Table S.9
    print_dfm_table(results_bm_dfm_nominal, target_series);

end

%% (4) Forecasting - Single Models Real-Time (Financial Data Only)

vars_to_keep_daily = NON_NOWCAST_PREDICTOR_IDS;
if real == 1
    vars_to_keep_daily = [{'CPIAUCSL'}; vars_to_keep_daily];
end
PREDICTORS_DAILY = select_predictors_by_id(PREDICTORS_US_WORLD, vars_to_keep_daily);
PREDICTORS_DAILY.model_input_exclude_ids = {'CPIAUCSL'};

% Forecast
[results_DAILY] = forecasting(p_forecasts_fixed_h_imputed, ETM_extended, PREDICTORS_DAILY, real, rollwind, 1, model, start_date, end_date, Lastin, predictors_transfomations, raw_transformations, Target_scheme, Hsize, NON_NOWCAST_PREDICTOR_IDS', IC, Pn, P_AR, P_custom_ARDL, P_custom_ARDI, P_custom_VAR, target_series, {}, {}, {}, {}, {}, {}, {}, {}, benchmark, futures_extended, treatment, folder_fig, real_time_forecast, real_price_vintage);

% Store Results
fileName = 'results_ratio_DAILY.mat';
filePath = fullfile(Folder_output, fileName);
save(filePath, 'results_DAILY', 'vars_to_keep_daily', 'NON_NOWCAST_PREDICTOR_IDS', 'WORLD_predictors_id', 'WORLD_predictors_import_report', 'predictors_transfomations');

% Reproduce Table  S.11–S.14.
print_daily_table(results_DAILY, target_series);

%% Cumulative RMSPE Ratios

print = 1;
font_size = 20;
plot_size = 2;
axis_size = 15;

% % Individual Models
models_ind = {'p_forecasts',...
              'ARDL_p_A31SNO',...
              'ARDL_p_CAPUTLB562A3CS',...
              'Random_Forest',...
              'ARDI_p_2F',...
              'FAVAR_specific_p_2F'
              };

% Combined Forecasts
models_comb = {'threshold',...
              'top_2'
               };

% Print - Horizon 6
print_cum_ratios(print, results_US_WORLD, forecast_comb, models_ind, models_comb, 6, target_series, plot_size, font_size, axis_size, folder_fig);
% Print - Horizon 9
print_cum_ratios(print, results_US_WORLD, forecast_comb, models_ind, models_comb, 9, target_series, plot_size, font_size, axis_size, folder_fig);
% Print - Horizon 12
print_cum_ratios(print, results_US_WORLD, forecast_comb, models_ind, models_comb, 12, target_series, plot_size, font_size, axis_size, folder_fig);
% Print - Horizon 15
print_cum_ratios(print, results_US_WORLD, forecast_comb, models_ind, models_comb, 15, target_series, plot_size, font_size, axis_size, folder_fig);
% Print - Horizon 18
print_cum_ratios(print, results_US_WORLD, forecast_comb, models_ind, models_comb, 18, target_series, plot_size, font_size, axis_size, folder_fig);

% Visualize - Horizon 6
plot_cum_ratios_panel(results_US_WORLD, forecast_comb, models_ind, models_comb, 6, target_series, plot_size, font_size, axis_size);
% Visualize - Horizon 12
plot_cum_ratios_panel(results_US_WORLD, forecast_comb, models_ind, models_comb, 12, target_series, plot_size, font_size, axis_size);
% Visualize - Horizon 18
plot_cum_ratios_panel(results_US_WORLD, forecast_comb, models_ind, models_comb, 18, target_series, plot_size, font_size, axis_size);