function [results] = forecasting_bm_dfm_ragged_nominal(ETM, PREDICTORS, real, rollwind, model, start_date, end_date, Lastin, predictors_transfomations, raw_transformations, Target_scheme, Hsize, target_series, benchmark, treatment, real_time, real_price_vintage, dfm_opts, results_ref)
% =================================================================================
% Real metal-price forecasts from a Banbura-Modugno (2014) dynamic factor model (DFM)
% estimated by EM on the unbalanced (ragged-edge) real-time panel of predictors
% ---------------------------------------------------------------------------------
% SYNTAX: forecasting_bm_dfm_ragged_nominal(ETM,PREDICTORS,...,Hsize,target_series,...,
%                                           dfm_opts,results_ref)
% where:
%      - ETM: balanced structure of metal prices
%      - PREDICTORS: real-time vintages of the predictors WITHOUT nowcasted edge
%      - Hsize: maximum forecast horizon (h = 1,...,Hsize)
%      - target_series: metals to forecast
%      - dfm_opts: structure containing
%            - p       = number of lags of the factor VAR (default is 1)
%            - maxiter = maximum number of EM iterations
%            - thresh  = EM convergence threshold (default is 1e-3)
%      - results_ref: output of forecasting.m; supplies the RW-D benchmark and the
%                     realized real prices, so that all errors share the same targets
%      - remaining arguments: as in forecasting.m (only real = 1 and real_time = 1
%        are supported)
% ---------------------------------------------------------------------------------
% OUTPUT: results = structure with, for each metal, the fields RW and BM_DFM_1F,
%         BM_DFM_2F, BM_DFM_3F (y_hat, y_obs, eps, dates and RMSPE_level, in USD per
%         metric ton)
% ---------------------------------------------------------------------------------
% REFERENCES:
%
% 1. Banbura, M. and Modugno, M. (2014). Maximum likelihood estimation of factor
%    models on datasets with arbitrary pattern of missing data.
%    Journal of Applied Econometrics                                        [BM14]
% ---------------------------------------------------------------------------------

if nargin < 16 || isempty(real_time)
    real_time = 1;
end

if nargin < 17 || isempty(real_price_vintage) 
    real_price_vintage = 'real_time'; 
end

if nargin < 18 || isempty(dfm_opts)
    dfm_opts = struct();
end

if nargin < 19 || isempty(results_ref)
    error('results_ref (output of forecasting.m, Table 3) is required to report the RW-D benchmark');
end

if real ~= 1 || real_time ~= 1
    error('forecasting_bm_dfm_ragged_nominal supports real == 1 and real_time == 1 only');
end

dfm_factor_counts = [1 2 3];
dfm_opts.n_factors = dfm_factor_counts;
if ~isfield(dfm_opts,'p'); dfm_opts.p = 1; end
if ~isfield(dfm_opts,'maxiter'); dfm_opts.maxiter = 20; end
if ~isfield(dfm_opts,'thresh'); dfm_opts.thresh = 1e-3; end

root_folder = fileparts(fileparts(mfilename('fullpath')));
mf_folder = fullfile(root_folder, 'MF');
if exist(mf_folder, 'dir') == 7
    addpath(mf_folder, '-end');
end

model_name = 'BM_DFM_NOMINAL';
dfm_model_names = arrayfun(@(k) sprintf('BM_DFM_%dF', k), dfm_factor_counts, 'UniformOutput', false);

%% Reshape ETM and Regressors datasets

ETM_id = cellstr(ETM.id);
ETM_id = ETM_id(:)';
[target_present, pos_targets] = ismember(target_series, ETM_id);
if any(~target_present)
    error('Missing target series in ETM data: %s', strjoin(target_series(~target_present), ', '));
end

ETM_volumes.data = ETM.data;
ETM_volumes.data(:,pos_targets) = [];
ETM_volumes.id = ETM_id;
ETM_volumes.id(pos_targets) = [];
ETM_volumes.obs = ETM.obs;

ETM_prices.data = ETM.data(:,pos_targets);
ETM_prices.id = ETM_id(pos_targets);
ETM_prices.obs = ETM.obs;

%% Select Predictors Nowcast Model (only used for the vintage structure and the CPI)

if model == 1
    pred_data = PREDICTORS.SA.data;
    pred_id = PREDICTORS.SA.id;
elseif model == 2
    pred_data = PREDICTORS.BAR.data;
    pred_id = PREDICTORS.BAR.id;
elseif model == 3
    pred_data = PREDICTORS.BAR_SV.data;
    pred_id = PREDICTORS.BAR_SV.id;
elseif model == 4
    pred_data = PREDICTORS.BAR_SVo.data;
    pred_id = PREDICTORS.BAR_SVo.id;
elseif model == 5
    pred_data = PREDICTORS.LAST_R.data;
    pred_id = PREDICTORS.LAST_R.id;
elseif model == 6
    pred_data = select_best_nowcast_data(PREDICTORS);
    pred_id = PREDICTORS.RW.id;
else
    error('Unknown nowcasting model');
end

if model == 5
    MACRO.vintages = PREDICTORS.vintages_last_release;
else
    MACRO.vintages = PREDICTORS.vintages_nowcasted;
end
MACRO.data = pred_data;
MACRO.id = pred_id;
MACRO.obs = PREDICTORS.obs;

pos_cpi = find(strcmp(pred_id,'CPIAUCSL'));
if isempty(pos_cpi)
    error('CPIAUCSL is required in the predictor panel');
end

%% Generate ETM tensor (NOMINAL prices up to the vintage month)

first_vin = pred_data(:,1,1);
first_vin_size = find(isnan(first_vin), 1, 'first') - 1;

n_vint = size(pred_data,2);
ETM_data = nan(length(ETM_prices.obs),n_vint,size(ETM_prices.data,2));
ETM_volumes_data = nan(length(ETM_prices.obs),n_vint,size(ETM_volumes.data,2));

for vin = 1:n_vint
    % Nominal prices are observed in real time up to the vintage month
    n_nom = find(ETM_prices.obs == MACRO.vintages(vin), 1);
    if isempty(n_nom)
        error('vintage month %s is not available in the ETM price series', string(MACRO.vintages(vin)));
    end
    ETM_data(1:n_nom,vin,:) = ETM_prices.data(1:n_nom,:);

    % Inventories
    ETM_volumes_data(1:first_vin_size + vin - 1,vin,:) = ETM_volumes.data(1:first_vin_size + vin - 1,:);
end

obs_dates = ETM_prices.obs;

if ~isfield(PREDICTORS, 'contains_nowcasted_values') || PREDICTORS.contains_nowcasted_values
    MACRO.data = remove_nowcasted_edge(MACRO.data, MACRO.id);
end

%% Select Sample Size

if ETM_prices.obs(1) <= start_date
    pos_1st_insample = find(ETM_prices.obs == start_date);
else
    pos_1st_insample = 1;
end

ETM_data(1:pos_1st_insample-1,:,:) = [];
ETM_volumes_data(1:pos_1st_insample-1,:,:) = [];
obs_dates(1:pos_1st_insample-1,:) = [];

MACRO.data(1:pos_1st_insample-1,:,:) = [];
MACRO.obs(1:pos_1st_insample-1,:) = [];

if MACRO.vintages(1) <= Lastin
    pos_last_insample = find(MACRO.vintages == Lastin);
else
    pos_last_insample = 1;
end

ETM_data(:,1:pos_last_insample-1,:) = [];
ETM_volumes_data(:,1:pos_last_insample-1,:) = [];
MACRO.data(:,1:pos_last_insample-1,:) = [];
MACRO.vintages(:,1:pos_last_insample-1) = [];

%% Attach ETM data (nominal prices) to Predictors dataset

MACRO.data = cat(3, MACRO.data, ETM_data, ETM_volumes_data);
MACRO.id = [MACRO.id', ETM_prices.id, ETM_volumes.id];
predictors_transfomations = transformations_for_ids(predictors_transfomations, MACRO.id, 'predictors_transfomations');
raw_transformations = transformations_for_ids(raw_transformations, ETM_prices.id, 'raw_transformations');

pos_cpi_macro = find(strcmp(MACRO.id, 'CPIAUCSL'), 1);
if predictors_transfomations(pos_cpi_macro) ~= 5
    error('CPIAUCSL is expected to enter the panel as second difference of the log (transformation 5)');
end

%% Transform predictor panel

X.data = nan(size(MACRO.data));

for pp = 1:size(MACRO.data,3)
    tcode_x = predictors_transfomations(pp);
    predictor_temp = squeeze(MACRO.data(:,:,pp));
    YYd = Building_regressors(predictor_temp,tcode_x);

    if tcode_x == 2 || tcode_x == 3
        YYd = [NaN(1,size(YYd,2)); YYd];
    elseif tcode_x == 4 || tcode_x == 5
        YYd = [NaN(2,size(YYd,2)); YYd];
    end
    X.data(:,:,pp) = YYd;
end

% Rows removed from the top of the transformed panel
if max(predictors_transfomations) == 2 || max(predictors_transfomations) == 3
    X.data(1,:,:) = [];
    X.obs = MACRO.obs(2:end);
    offset_X = 1;
elseif max(predictors_transfomations) == 4 || max(predictors_transfomations) == 5
    X.data(1:2,:,:) = [];
    X.obs = MACRO.obs(3:end);
    offset_X = 2;
else
    X.obs = MACRO.obs;
    offset_X = 0;
end

%% Forecasting setup

% Out-of-sample vintages
Out_s = min(sum(MACRO.vintages(:) + calmonths(1) <= end_date), size(ETM_data,2));
if Out_s < 1
    error('out-of-sample size is smaller than one observation');
end

nb_var = size(ETM_data,3);

target_positions_in_panel = zeros(1,numel(ETM_prices.id));
for yy = 1:numel(ETM_prices.id)
    target_positions_in_panel(yy) = find(strcmp(MACRO.id, ETM_prices.id{yy}), 1);
end
% DFM targets: the nominal metal prices and, last, the CPI
targets_all = [target_positions_in_panel, pos_cpi_macro];

% Table 3 reference (RW-D and realized levels)
if ~isfield(results_ref, 'level') || ~isfield(results_ref.level, 'RW') || ~isfield(results_ref.level.RW, 'data_real')
    error('results_ref.level.RW.data_real is required (output of forecasting.m)');
end
ref_data = results_ref.level.RW.data;
ref_real = results_ref.level.RW.data_real;
if size(ref_real,1) < Hsize || size(ref_real,2) < Out_s || size(ref_real,3) < nb_var
    error('results_ref.level.RW is smaller than the requested horizons/out-of-sample size/metals');
end

results = struct();
results.metadata.model = model_name;
results.metadata.description = 'Dynamic factor model estimated by EM/Kalman on a ragged-edge panel with NOMINAL metal prices (observed up to the vintage month) and CPI; real price forecast = nominal forecast / CPI forecast; RW-D and realized levels from forecasting.m';
results.metadata.dfm_opts = dfm_opts;
results.metadata.dfm_factor_counts = dfm_factor_counts;
results.metadata.models = dfm_model_names;
results.metadata.ragged_edge_missing_lags = ragged_edge_missing_lags(MACRO.id);
results.metadata.panel_ids = MACRO.id;
results.metadata.factor_vintages = MACRO.vintages(1:min(Out_s, numel(MACRO.vintages)));
results.metadata.level_description = 'y_hat, y_obs and eps are levels of the real price (USD per metric ton, as in Table 3); nominal_level_hat and cpi_level_hat are the two components of the DFM forecast';
results.metadata.factor_r2_description = 'For each vintage and DFM specification, R2 from univariate regressions factor_k = a + b * variable_j + error on the transformed panel used by the DFM.';

for y = 1:nb_var
    id_y = ETM_prices.id{y};

    results.(id_y).RW.y_hat = nan(Hsize, Out_s);
    results.(id_y).RW.y_obs = nan(Hsize, Out_s);
    results.(id_y).RW.dates = NaT(Hsize, Out_s);
    results.(id_y).RW.eps = nan(Hsize, Out_s);
    results.(id_y).RW.eps_2 = nan(Hsize, Out_s);
    results.(id_y).RW.MSPE_level = nan(1,Hsize);
    results.(id_y).RW.RMSPE_level = nan(1,Hsize);

    for mm = 1:numel(dfm_model_names)
        dfm_model_name = dfm_model_names{mm};
        results.(id_y).(dfm_model_name).y_hat = nan(Hsize, Out_s);
        results.(id_y).(dfm_model_name).y_obs = nan(Hsize, Out_s);
        results.(id_y).(dfm_model_name).dates = NaT(Hsize, Out_s);
        results.(id_y).(dfm_model_name).eps = nan(Hsize, Out_s);
        results.(id_y).(dfm_model_name).eps_2 = nan(Hsize, Out_s);
        results.(id_y).(dfm_model_name).MSPE_level = nan(1,Hsize);
        results.(id_y).(dfm_model_name).RMSPE_level = nan(1,Hsize);
        results.(id_y).(dfm_model_name).nominal_level_hat = nan(Hsize, Out_s);
        results.(id_y).(dfm_model_name).cpi_level_hat = nan(Hsize, Out_s);
    end
end

model_info = struct();
bm_factors = struct();
bm_factor_r2 = struct();
for mm = 1:numel(dfm_model_names)
    model_info.(dfm_model_names{mm}) = cell(1, Out_s);
    bm_factors.(dfm_model_names{mm}) = cell(1, Out_s);
    bm_factor_r2.(dfm_model_names{mm}) = cell(1, Out_s);
end

cpi_col = pos_cpi_macro;

for tt = 1:Out_s
    if rollwind == 1
        panel_tt = squeeze(X.data(tt:end,tt,:));
        row_shift = offset_X + tt - 1;
    else
        panel_tt = squeeze(X.data(:,tt,:));
        row_shift = offset_X;
    end

    vintage_date = MACRO.vintages(tt);
    idx_T = find(obs_dates == vintage_date, 1);
    if isempty(idx_T)
        error('vintage month %s not found in the price dates', string(vintage_date));
    end

    cpi_lev = squeeze(MACRO.data(:,tt,pos_cpi_macro));

    for mm = 1:numel(dfm_model_names)
        dfm_model_name = dfm_model_names{mm};

        % Model
        [monthly_forecasts, model_info.(dfm_model_name){tt}, fitted] = bm_dfm_forecast_panel_fit(panel_tt, targets_all, Hsize, dfm_factor_counts(mm), dfm_opts.p, dfm_opts.maxiter, dfm_opts.thresh);
        info_tt = model_info.(dfm_model_name){tt};
        bm_factors.(dfm_model_name){tt} = info_tt.factors;
        bm_factor_r2.(dfm_model_name){tt} = factor_variable_r2(panel_tt, info_tt.factors, MACRO.id, info_tt, vintage_date);

        % --- CPI level path from the last published CPI --------------------
        cpi_hat = nan(Hsize,1);
        T_row_macro = NaN;
        if strcmp(info_tt.fallback,'none') && ~isnan(info_tt.last_valid_row)
            last_valid = info_tt.last_valid_row;
            T_row_macro = last_valid + row_shift;

            % The last row of the DFM sample must be the vintage month
            if obs_row_date(MACRO.obs, T_row_macro) ~= vintage_date
                error('last DFM sample month (%s) differs from the vintage month (%s) for window %d', string(obs_row_date(MACRO.obs, T_row_macro)), string(vintage_date), tt);
            end

            t0 = find(~isnan(panel_tt(:,cpi_col)), 1, 'last');   % last published CPI (transformed) row
            t0_macro = t0 + row_shift;
            n_now = last_valid - t0;                              % nowcasted months (T-1, T)

            if ~isempty(t0) && n_now >= 0 && t0_macro > 1 && ~isnan(cpi_lev(t0_macro)) && ~isnan(cpi_lev(t0_macro-1))
                x_path = [fitted(t0+1:last_valid, end); monthly_forecasts(1:Hsize, end)];  % d2 log CPI: nowcast, then forecast
                l_cur = log(cpi_lev(t0_macro));
                d_cur = l_cur - log(cpi_lev(t0_macro-1));
                l_path = nan(numel(x_path),1);
                for kk = 1:numel(x_path)
                    d_cur = d_cur + x_path(kk);
                    l_cur = l_cur + d_cur;
                    l_path(kk) = l_cur;
                end
                cpi_hat = exp(l_path(n_now+1:n_now+Hsize));
            end
        end

        for y = 1:nb_var
            id_y = ETM_prices.id{y};

            % --- nominal price level path from the price at the vintage month
            nom_hat = nan(Hsize,1);
            if ~isnan(T_row_macro)
                P_T = MACRO.data(T_row_macro, tt, target_positions_in_panel(y));
                nom_hat = P_T*exp(cumsum(monthly_forecasts(1:Hsize, y)));
            end
            real_hat = nom_hat ./ cpi_hat;

            for hor = 1:Hsize
                if tt > Out_s - hor + 1
                    continue
                end

                real_idx = idx_T + hor;
                if real_idx > numel(obs_dates)
                    continue
                end

                real_level = ref_real(hor,tt,y);
                if isnan(real_level)
                    continue
                end

                y_hat_level = real_hat(hor);
                if isnan(y_hat_level)
                    % Missing DFM forecast: fall back on the RW-D of forecasting.m
                    y_hat_level = ref_data(hor,tt,y);
                    model_info.(dfm_model_name){tt}.fallback = 'rw_for_missing_target_forecast';
                end

                results.(id_y).(dfm_model_name).y_hat(hor,tt) = y_hat_level;
                results.(id_y).(dfm_model_name).y_obs(hor,tt) = real_level;
                results.(id_y).(dfm_model_name).dates(hor,tt) = obs_dates(real_idx);
                results.(id_y).(dfm_model_name).eps(hor,tt) = y_hat_level - real_level;
                results.(id_y).(dfm_model_name).nominal_level_hat(hor,tt) = nom_hat(hor);
                results.(id_y).(dfm_model_name).cpi_level_hat(hor,tt) = cpi_hat(hor);
            end
        end
    end
end

bm_em_convergence_details = bm_em_convergence_summary(model_info, dfm_model_names, dfm_factor_counts, MACRO.vintages, Out_s);
bm_em_convergence = bm_em_convergence_status(bm_em_convergence_details);
results.metadata.bm_em_convergence = bm_em_convergence;
results.metadata.bm_em_convergence_details = bm_em_convergence_details;
results.metadata.bm_em_convergence_description = '3x1 cell array over 1, 2, and 3 BM-DFM factors. Entry is ''do not converge'' if at least one OOS window did not converge; otherwise ''converge''.';
for y = 1:nb_var
    results.(ETM_prices.id{y}).BM_DFM_EM_convergence = bm_em_convergence;
end

results.metadata.model_info = model_info;
results.metadata.bm_factors = bm_factors;
results.metadata.bm_factor_r2 = bm_factor_r2;
evaluation_model_names = dfm_model_names;

%% RW-D benchmark: taken directly from forecasting.m (Table 3)

for y = 1:nb_var
    id_y = ETM_prices.id{y};
    if ~isfield(results_ref, id_y) || ~isfield(results_ref.(id_y), 'RW')
        error('results_ref does not contain the RW-D of %s', id_y);
    end
    ref_RW = results_ref.(id_y).RW;
    if size(ref_RW.eps_2,1) < Hsize || size(ref_RW.eps_2,2) < Out_s
        error('results_ref.%s.RW is smaller than the requested horizons/out-of-sample size', id_y);
    end

    results.(id_y).RW.y_hat = ref_data(1:Hsize,1:Out_s,y);
    results.(id_y).RW.y_obs = ref_real(1:Hsize,1:Out_s,y);
    results.(id_y).RW.dates = ref_RW.dates(1:Hsize,1:Out_s);
    results.(id_y).RW.eps   = results.(id_y).RW.y_hat - results.(id_y).RW.y_obs;

    % Check: target dates of the DFM models must coincide with those of Table 3
    dfm_dates = results.(id_y).(dfm_model_names{1}).dates;
    both_valid = ~isnat(dfm_dates) & ~isnat(results.(id_y).RW.dates);
    n_date_mismatch = nnz(dfm_dates(both_valid) ~= results.(id_y).RW.dates(both_valid));
    if n_date_mismatch > 0
        warning('forecasting_bm_dfm_ragged_nominal: %d target dates of %s differ from those of results_ref', n_date_mismatch, id_y);
    end
end

%% Evaluation

for y = 1:nb_var
    for hor = 1:Hsize
        eval_idx = 1:Out_s-hor+1;

        ref_RW = results_ref.(ETM_prices.id{y}).RW;
        results.(ETM_prices.id{y}).RW.eps_2(hor,eval_idx) = ref_RW.eps_2(hor,eval_idx);
        results.(ETM_prices.id{y}).RW.MSPE_level(1,hor) = mean(ref_RW.eps_2(hor,eval_idx),'omitnan');
        results.(ETM_prices.id{y}).RW.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).RW.MSPE_level(1,hor));

        if isfield(ref_RW,'RMSPE_level') && abs(results.(ETM_prices.id{y}).RW.RMSPE_level(1,hor) - ref_RW.RMSPE_level(1,hor)) > 1e-6*abs(ref_RW.RMSPE_level(1,hor))
            warning('forecasting_bm_dfm_ragged_nominal: RW-D RMSFE of %s at horizon %d differs from results_ref', ETM_prices.id{y}, hor);
        end

        nested_flag = 0;
        results.(ETM_prices.id{y}).RW.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor,eval_idx)',results.(ETM_prices.id{y}).RW.eps_2(hor,eval_idx)',hor-1,nested_flag,treatment);

        for mm = 1:numel(evaluation_model_names)
            eval_model_name = evaluation_model_names{mm};
            results.(ETM_prices.id{y}).(eval_model_name).eps_2(hor,eval_idx) = results.(ETM_prices.id{y}).(eval_model_name).eps(hor,eval_idx).^2;
            results.(ETM_prices.id{y}).(eval_model_name).MSPE_level(1,hor) = mean(results.(ETM_prices.id{y}).(eval_model_name).eps_2(hor,eval_idx),'omitnan');
            results.(ETM_prices.id{y}).(eval_model_name).RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).(eval_model_name).MSPE_level(1,hor));
            results.(ETM_prices.id{y}).(eval_model_name).DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor,eval_idx)',results.(ETM_prices.id{y}).(eval_model_name).eps_2(hor,eval_idx)',hor-1,nested_flag,treatment);
        end
    end
end

results.TABLES_RMSPE_level.RW = nan(Hsize,nb_var);
results.TABLES_level.RW = nan(Hsize,nb_var);
for mm = 1:numel(evaluation_model_names)
    results.TABLES_RMSPE_level.(evaluation_model_names{mm}) = nan(Hsize,nb_var);
    results.TABLES_level.(evaluation_model_names{mm}) = nan(Hsize,nb_var);
end

for y = 1:nb_var
    for hor = 1:Hsize
        results.TABLES_RMSPE_level.RW(hor,y) = results.(ETM_prices.id{y}).RW.RMSPE_level(1,hor);

        if strcmp("AR",benchmark)==1
            error('AR benchmark is not available in forecasting_bm_dfm_ragged_nominal');
        elseif strcmp("RW",benchmark)==1
            bench = results.(ETM_prices.id{y}).RW.RMSPE_level(1,hor);
        end

        results.TABLES_level.RW(hor,y) = results.(ETM_prices.id{y}).RW.RMSPE_level(1,hor)/bench;
        for mm = 1:numel(evaluation_model_names)
            eval_model_name = evaluation_model_names{mm};
            results.TABLES_RMSPE_level.(eval_model_name)(hor,y) = results.(ETM_prices.id{y}).(eval_model_name).RMSPE_level(1,hor);
            results.TABLES_level.(eval_model_name)(hor,y) = results.(ETM_prices.id{y}).(eval_model_name).RMSPE_level(1,hor)/bench;
        end
    end
end

for y = 1:nb_var
    results.tables_ratio_long.(ETM_prices.id{y}) = NaN(length(fieldnames(results.TABLES_level)), Hsize);
    results.tables_ratio_long_p_value.(ETM_prices.id{y}) = cell(length(fieldnames(results.TABLES_level)), Hsize);
    modelli = fieldnames(results.TABLES_level);

    for model_idx = 1:length(modelli)
        for horizon = 1:Hsize
            ratio = results.TABLES_level.(modelli{model_idx})(horizon,y);
            results.tables_ratio_long.(ETM_prices.id{y})(model_idx, horizon) = ratio;
            results.tables_ratio_long_p_value.(ETM_prices.id{y}){model_idx, horizon} = add_stars(ratio, results.(ETM_prices.id{y}).(modelli{model_idx}).DM_p_value(1,horizon));
        end
    end
end

end

function d = obs_row_date(obs, row)
% Date of a row of the observation axis (NaT if out of range)
if row >= 1 && row <= numel(obs)
    d = obs(row);
else
    d = NaT;
end
end


function summary = bm_em_convergence_summary(model_info, model_names, factor_counts, vintages, Out_s)

empty_entry = struct( ...
    'n_factors', NaN, ...
    'model_name', '', ...
    'any_nonconverged', false, ...
    'nonconverged_windows', [], ...
    'nonconverged_vintages', [], ...
    'em_ran_by_window', false(1,Out_s), ...
    'em_converged_by_window', nan(1,Out_s), ...
    'em_iterations_by_window', nan(1,Out_s), ...
    'em_relative_loglik_change_by_window', nan(1,Out_s), ...
    'em_loglik_by_window', nan(1,Out_s), ...
    'fallback_by_window', {cell(1,Out_s)}, ...
    'error_by_window', {cell(1,Out_s)});

summary = repmat(empty_entry, numel(model_names), 1);
vintages = vintages(:)';

for mm = 1:numel(model_names)
    model_name = model_names{mm};
    summary(mm).n_factors = factor_counts(mm);
    summary(mm).model_name = model_name;

    for tt = 1:Out_s
        if ~isfield(model_info, model_name) || numel(model_info.(model_name)) < tt || isempty(model_info.(model_name){tt})
            continue
        end

        info_tt = model_info.(model_name){tt};

        if isfield(info_tt, 'em_ran') && ~isempty(info_tt.em_ran)
            summary(mm).em_ran_by_window(tt) = logical(info_tt.em_ran);
        elseif isfield(info_tt, 'em_converged') && ~isempty(info_tt.em_converged)
            summary(mm).em_ran_by_window(tt) = true;
        end

        if isfield(info_tt, 'em_converged') && ~isempty(info_tt.em_converged) && ~isnan(double(info_tt.em_converged))
            summary(mm).em_converged_by_window(tt) = double(logical(info_tt.em_converged));
        end

        if isfield(info_tt, 'em_iterations') && ~isempty(info_tt.em_iterations)
            summary(mm).em_iterations_by_window(tt) = info_tt.em_iterations;
        end

        if isfield(info_tt, 'em_relative_loglik_change') && ~isempty(info_tt.em_relative_loglik_change)
            summary(mm).em_relative_loglik_change_by_window(tt) = info_tt.em_relative_loglik_change;
        end

        if isfield(info_tt, 'em_loglik') && ~isempty(info_tt.em_loglik)
            summary(mm).em_loglik_by_window(tt) = info_tt.em_loglik;
        elseif isfield(info_tt, 'loglik') && ~isempty(info_tt.loglik)
            summary(mm).em_loglik_by_window(tt) = info_tt.loglik;
        end

        if isfield(info_tt, 'fallback') && ~isempty(info_tt.fallback)
            summary(mm).fallback_by_window{tt} = info_tt.fallback;
        end

        if isfield(info_tt, 'error') && ~isempty(info_tt.error)
            summary(mm).error_by_window{tt} = info_tt.error;
        end
    end

    nonconverged = summary(mm).em_ran_by_window & (summary(mm).em_converged_by_window == 0);
    summary(mm).any_nonconverged = any(nonconverged);
    summary(mm).nonconverged_windows = find(nonconverged);

    if ~isempty(vintages) && ~isempty(summary(mm).nonconverged_windows)
        valid_windows = summary(mm).nonconverged_windows(summary(mm).nonconverged_windows <= numel(vintages));
        summary(mm).nonconverged_vintages = vintages(valid_windows);
    end
end

end

function status = bm_em_convergence_status(summary)

status = cell(numel(summary), 1);
for mm = 1:numel(summary)
    if summary(mm).any_nonconverged
        status{mm} = 'do not converge';
    else
        status{mm} = 'converge';
    end
end

end

function r2_output = factor_variable_r2(panel, factors, variable_ids, info, vintage_value)

if nargin < 5
    vintage_value = [];
end

variable_ids = variable_ids(:);
r2_output = struct();
r2_output.vintage = vintage_value;
r2_output.variable_ids = variable_ids;
r2_output.factor_ids = {};
r2_output.first_valid_row = NaN;
r2_output.last_valid_row = NaN;
r2_output.r2 = [];
r2_output.n_obs = [];
r2_output.table = table();
r2_output.n_obs_table = table();

if isempty(panel) || isempty(factors) || ~isfield(info, 'first_valid_row') || ~isfield(info, 'last_valid_row') || ...
        isnan(info.first_valid_row) || isnan(info.last_valid_row)
    return
end

first_row = info.first_valid_row;
last_row = info.last_valid_row;
if first_row < 1 || last_row > size(panel,1) || first_row > last_row
    return
end

panel = panel(first_row:last_row,:);
n_obs_common = min(size(panel,1), size(factors,1));
if n_obs_common < 3
    return
end

panel = panel(1:n_obs_common,:);
factors = factors(1:n_obs_common,:);

nb_variables = size(panel,2);
nb_factors = size(factors,2);
r2 = nan(nb_variables, nb_factors);
n_obs = zeros(nb_variables, nb_factors);

for kk = 1:nb_factors
    factor_k = factors(:,kk);
    for jj = 1:nb_variables
        variable_j = panel(:,jj);
        complete_idx = isfinite(factor_k) & isfinite(variable_j);
        n_obs(jj,kk) = sum(complete_idx);

        if n_obs(jj,kk) < 3
            continue
        end

        y = factor_k(complete_idx);
        x = variable_j(complete_idx);
        X = [ones(size(x)), x];
        sst = sum((y - mean(y)).^2);

        if sst <= eps || rank(X) < 2
            continue
        end

        beta = X\y;
        residual = y - X*beta;
        r2(jj,kk) = min(1, max(0, 1 - sum(residual.^2)/sst));
    end
end

factor_ids = arrayfun(@(kk) sprintf('Factor_%d', kk), 1:nb_factors, 'UniformOutput', false);
r2_table = array2table(r2, 'VariableNames', factor_ids);
r2_table.Variable = variable_ids(1:nb_variables);
r2_table = movevars(r2_table, 'Variable', 'Before', 1);

n_obs_table = array2table(n_obs, 'VariableNames', factor_ids);
n_obs_table.Variable = variable_ids(1:nb_variables);
n_obs_table = movevars(n_obs_table, 'Variable', 'Before', 1);

r2_output.factor_ids = factor_ids;
r2_output.first_valid_row = first_row;
r2_output.last_valid_row = last_row;
r2_output.r2 = r2;
r2_output.n_obs = n_obs;
r2_output.table = r2_table;
r2_output.n_obs_table = n_obs_table;

end

function selected_data = select_best_nowcast_data(PREDICTORS)

selected_data = NaN(size(PREDICTORS.RW.data));

for r = 1:size(selected_data,3)
    if PREDICTORS.best_model(r) == 0
        selected_data(:,:,r) = PREDICTORS.RW.data(:,:,r);
    elseif PREDICTORS.best_model(r) == 1
        selected_data(:,:,r) = PREDICTORS.SA.data(:,:,r);
    elseif PREDICTORS.best_model(r) == 2
        selected_data(:,:,r) = PREDICTORS.AR_p.data(:,:,r);
    elseif PREDICTORS.best_model(r) == 3
        selected_data(:,:,r) = PREDICTORS.AR_IC.data(:,:,r);
    elseif PREDICTORS.best_model(r) == 4
        selected_data(:,:,r) = PREDICTORS.BAR.data(:,:,r);
    elseif PREDICTORS.best_model(r) == 5
        selected_data(:,:,r) = PREDICTORS.BAR_SV.data(:,:,r);
    elseif PREDICTORS.best_model(r) == 6
        selected_data(:,:,r) = PREDICTORS.BAR_SVo.data(:,:,r);
    end
end

end

function txt = add_stars(ratio, p_value)

if isnan(ratio)
    txt = '';
elseif p_value < 0.01 || p_value > 0.99
    txt = [num2str(ratio,'%.3f') '***'];
elseif p_value < 0.05 || p_value > 0.95
    txt = [num2str(ratio,'%.3f') '**'];
elseif p_value < 0.1 || p_value > 0.9
    txt = [num2str(ratio,'%.3f') '*'];
else
    txt = num2str(ratio,'%.3f');
end

end


% Provide the DFM nowcast of the target observations missing at the end.
function [monthly_forecasts, model_info, fitted] = bm_dfm_forecast_panel_fit(panel, target_positions, Hsize, n_factors, p, maxiter, thresh)

model_info = struct();
model_info.method = 'Banbura_Modugno_DFM';
model_info.n_factors = n_factors;
model_info.p = p;
model_info.maxiter = maxiter;
model_info.thresh = thresh;
model_info.fallback = 'none';
model_info.first_valid_row = NaN;
model_info.last_valid_row = NaN;
model_info.factors = [];
model_info.em_ran = false;
model_info.em_converged = NaN;
model_info.em_iterations = NaN;
model_info.em_relative_loglik_change = NaN;
model_info.em_loglik = NaN;

monthly_forecasts = NaN(Hsize, numel(target_positions));
fitted = NaN(size(panel,1), numel(target_positions)); % smoothed (in-sample) values of the targets, rows of the input panel

valid_rows = any(~isnan(panel),2);
last_valid_row = find(valid_rows, 1, 'last');
first_valid_row = find(valid_rows, 1, 'first');

if isempty(first_valid_row) || isempty(last_valid_row)
    model_info.fallback = 'empty_panel';
    return
end

model_info.first_valid_row = first_valid_row;
model_info.last_valid_row = last_valid_row;
panel = panel(first_valid_row:last_valid_row,:);

valid_cols = ~all(isnan(panel),1);
kept_cols = find(valid_cols);
panel = panel(:,valid_cols);

[target_kept, target_positions_kept] = ismember(target_positions, kept_cols);
if ~any(target_kept)
    model_info.fallback = 'target_not_in_panel';
    return
end

target_positions_kept = target_positions_kept(target_kept);
target_positions_original = find(target_kept);

col_mean = mean(panel, 1, 'omitnan');
col_std = std(panel, 0, 1, 'omitnan');
valid_cols = ~isnan(col_mean) & ~isnan(col_std) & col_std > 0;

if sum(valid_cols) < n_factors + 1
    model_info.fallback = 'too_few_series';
    monthly_forecasts(:,target_positions_original) = repmat(col_mean(target_positions_kept), Hsize, 1);
    return
end

kept_cols_second = find(valid_cols);
panel = panel(:,valid_cols);
col_mean = col_mean(valid_cols);
col_std = col_std(valid_cols);

[target_kept_second, target_positions_second] = ismember(target_positions_kept, kept_cols_second);
if ~any(target_kept_second)
    model_info.fallback = 'target_removed_as_constant';
    return
end

target_positions_final = target_positions_second(target_kept_second);
target_positions_original = target_positions_original(target_kept_second);

X_s = (panel - col_mean)./col_std;

[T,N] = size(X_s);
q_use = min(n_factors, N - 1);

init = struct();
init.idF = true(N,1);
init.idI = false(N,1);
init.nQ = 0;
init.nM = N;
init.q = q_use;
init.p = p;

opts_init = struct();
opts_init.method = 3;
opts_init.k = 3;

blocks = true(N,1);
ss = ss_DFM_MF_blocks(X_s, init, opts_init, blocks);

opts_em = struct();
opts_em.method = 3;
opts_em.k = 3;
opts_em.s = 1;
opts_em.verbose = 0;
opts_em.maxiter = maxiter;
opts_em.thresh = thresh;

EM = EM_DFM_MF_blocks(X_s, ss, init, blocks, opts_em);
model_info.em_ran = true;
KF = kalman(X_s, EM);
model_info.factors = KF.ZtT(:,1:q_use);
fit_std = KF.ZtT * EM.C(target_positions_final,:)';
fitted(first_valid_row:last_valid_row, target_positions_original) = fit_std.*col_std(target_positions_final) + col_mean(target_positions_final);
if isfield(EM, 'converged'); model_info.em_converged = EM.converged; end
if isfield(EM, 'iterations'); model_info.em_iterations = EM.iterations; end
if isfield(EM, 'relative_loglik_change'); model_info.em_relative_loglik_change = EM.relative_loglik_change; end
if isfield(EM, 'loglik'); model_info.em_loglik = EM.loglik; end

z = KF.Ztt(:,T+1);
z_fore = z;

for hh = 1:Hsize
    z_fore = EM.A*z_fore;
    yhat_std = EM.C(target_positions_final,:)*z_fore;
    monthly_forecasts(hh,target_positions_original) = yhat_std'.*col_std(target_positions_final) + col_mean(target_positions_final);
end

model_info.n_obs = T;
model_info.n_series = N;
model_info.loglik = KF.loglik;

end
