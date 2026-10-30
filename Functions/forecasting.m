function [results] = forecasting(p_forecasts_fixed_h_imputed, ETM, PREDICTORS, real, rollwind, direct, model, start_date, end_date, Lastin, predictors_transfomations, raw_transformations, Target_scheme, Hsize, regressors, IC, Pn, P_AR, P_custom_ARDL, P_custom_ARDI, P_custom_VAR, target_series, regressors_real_activity, regressors_ex_rates, regressors_et, regressors_cu, regressors_inventories, regressors_etm, regressors_w_act, regressors_var_metals, benchmark, futures, treatment, folder_fig, real_time, real_price_vintage)

if nargin < 36 || isempty(real_time)
    real_time = 1;
end

if ~ismember(real_time, [0 1])
    error('real_time must be 0 (non real-time) or 1 (real-time)');
end

if nargin < 37 || isempty(real_price_vintage)
    real_price_vintage = 'real_time';
end

real_price_vintage = lower(strtrim(char(real_price_vintage)));
switch real_price_vintage
    case {'real_time', 'real-time', 'rt'}
        use_last_cpi_vintage_for_real_prices = false;
    case {'last_vintage', 'last-vintage', 'last', 'final'}
        use_last_cpi_vintage_for_real_prices = true;
    otherwise
        error('real_price_vintage must be ''real_time'' or ''last_vintage''');
end

tree_model_names = {'Random_Forest', 'Gradient_Boosting', 'BMA_MC3', 'DMA', 'LASSO'};

%% Reshape ETM and Regressors datasets

% Attach ETMs data to regressor dataset

% Find Target series
ETM_id = cellstr(ETM.id);
ETM_id = ETM_id(:)';
[target_present, pos_targets] = ismember(target_series, ETM_id);
if any(~target_present)
    error('Missing target series in ETM data: %s', strjoin(target_series(~target_present), ', '));
end

% Creates separate volumes objects
ETM_volumes.data = ETM.data; ETM_volumes.data(:,pos_targets) = [];
ETM_volumes.id = ETM_id; ETM_volumes.id(pos_targets) = [];
ETM_volumes.obs = ETM.obs;

% Creates separate prices objects
ETM_prices.data = ETM.data(:,pos_targets);
ETM_prices.id = ETM_id(pos_targets);
ETM_prices.obs = ETM.obs;

%% Generate ETM tensor

if real == 1 % Real ETMs prices

    if model == 1

        pos_cpi = find(strcmp(PREDICTORS.SA.id,'CPIAUCSL'));
        
        first_vin = PREDICTORS.SA.data(:,1,1);
        first_vin_size = find(isnan(first_vin), 1, 'first')-1; 
    
        ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.SA.data,2),size(ETM_prices.data,2));
        ETM_volumes_data = nan(length(ETM_prices.obs),size(PREDICTORS.SA.data,2),size(ETM_volumes.data,2));
    
            for vin = 1:size(PREDICTORS.SA.data,2)
                cpi_vin = vin;
                if use_last_cpi_vintage_for_real_prices
                    cpi_vin = size(PREDICTORS.SA.data,2);
                end
                ETM_temp = ETM_prices.data./squeeze(PREDICTORS.SA.data(:,cpi_vin,pos_cpi));
                n_fill = min(first_vin_size + vin - 1, size(ETM_temp, 1));
                if n_fill >= 1
                    ETM_data(1:n_fill, vin, :) = ETM_temp(1:n_fill, :);
                    ETM_volumes_data(1:n_fill, vin, :) = ETM_volumes.data(1:n_fill, :);
                end
            end

        observed_ETM.data = ETM_prices.data./squeeze(PREDICTORS.SA.data(:,end,pos_cpi));
        observed_ETM.obs = ETM_prices.obs;

    elseif model == 2

        pos_cpi = find(strcmp(PREDICTORS.BAR.id,'CPIAUCSL'));

        first_vin = PREDICTORS.BAR.data(:,1,1);
        first_vin_size = find(isnan(first_vin), 1, 'first')-1; 
    
        ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.BAR.data,2),size(ETM_prices.data,2));
        ETM_volumes_data = nan(length(ETM_prices.obs),size(PREDICTORS.BAR.data,2),size(ETM_volumes.data,2));
    
            for vin = 1:size(PREDICTORS.BAR.data,2)
                cpi_vin = vin;
                if use_last_cpi_vintage_for_real_prices
                    cpi_vin = size(PREDICTORS.BAR.data,2);
                end
                ETM_temp = ETM_prices.data./squeeze(PREDICTORS.BAR.data(:,cpi_vin,pos_cpi));
                n_fill = min(first_vin_size + vin - 1, size(ETM_temp, 1));
                if n_fill >= 1
                    ETM_data(1:n_fill, vin, :) = ETM_temp(1:n_fill, :);
                    ETM_volumes_data(1:n_fill, vin, :) = ETM_volumes.data(1:n_fill, :);
                end
            end

        observed_ETM.data = ETM_prices.data./squeeze(PREDICTORS.BAR.data(:,end,pos_cpi));
        observed_ETM.obs = ETM_prices.obs;

    elseif model == 3

        pos_cpi = find(strcmp(PREDICTORS.BAR_SV.id,'CPIAUCSL'));

        first_vin = PREDICTORS.BAR_SV.data(:,1,1);
        first_vin_size = find(isnan(first_vin), 1, 'first')-1; 
    
        ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.BAR_SV.data,2),size(ETM_prices.data,2));
        ETM_volumes_data = nan(length(ETM_prices.obs),size(PREDICTORS.BAR_SV.data,2),size(ETM_volumes.data,2));
    
            for vin = 1:size(PREDICTORS.BAR_SV.data,2)
                cpi_vin = vin;
                if use_last_cpi_vintage_for_real_prices
                    cpi_vin = size(PREDICTORS.BAR_SV.data,2);
                end
                ETM_temp = ETM_prices.data./squeeze(PREDICTORS.BAR_SV.data(:,cpi_vin,pos_cpi));
                n_fill = min(first_vin_size + vin - 1, size(ETM_temp, 1));
                if n_fill >= 1
                    ETM_data(1:n_fill, vin, :) = ETM_temp(1:n_fill, :);
                    ETM_volumes_data(1:n_fill, vin, :) = ETM_volumes.data(1:n_fill, :);
                end
            end

        observed_ETM.data = ETM_prices.data./squeeze(PREDICTORS.BAR_SV.data(:,end,pos_cpi));
        observed_ETM.obs = ETM_prices.obs;

    elseif model == 4

        pos_cpi = find(strcmp(PREDICTORS.BAR_SVo.id,'CPIAUCSL'));

        first_vin = PREDICTORS.BAR_SVo.data(:,1,1);
        first_vin_size = find(isnan(first_vin), 1, 'first')-1; 
    
        ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.BAR_SVo.data,2),size(ETM_prices.data,2));
        ETM_volumes_data = nan(length(ETM_prices.obs),size(PREDICTORS.BAR_SVo.data,2),size(ETM_volumes.data,2));
    
            for vin = 1:size(PREDICTORS.BAR_SVo.data,2)
                cpi_vin = vin;
                if use_last_cpi_vintage_for_real_prices
                    cpi_vin = size(PREDICTORS.BAR_SVo.data,2);
                end
                ETM_temp = ETM_prices.data./squeeze(PREDICTORS.BAR_SVo.data(:,cpi_vin,pos_cpi));
                n_fill = min(first_vin_size + vin - 1, size(ETM_temp, 1));
                if n_fill >= 1
                    ETM_data(1:n_fill, vin, :) = ETM_temp(1:n_fill, :);
                    ETM_volumes_data(1:n_fill, vin, :) = ETM_volumes.data(1:n_fill, :);
                end
            end

        observed_ETM.data = ETM_prices.data./squeeze(PREDICTORS.BAR_SVo.data(:,end,pos_cpi));
        observed_ETM.obs = ETM_prices.obs;

    elseif model == 5

    pos_cpi = find(strcmp(PREDICTORS.LAST_R.id,'CPIAUCSL'));

    first_vin = PREDICTORS.LAST_R.data(:,1,1);
    first_vin_size = find(isnan(first_vin), 1, 'first')-1; 

        ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.LAST_R.data,2),size(ETM_prices.data,2));
        ETM_volumes_data = nan(length(ETM_prices.obs),size(PREDICTORS.LAST_R.data,2),size(ETM_volumes.data,2));

        for vin = 1:size(PREDICTORS.LAST_R.data,2)
            cpi_vin = vin;
            if use_last_cpi_vintage_for_real_prices
                cpi_vin = size(PREDICTORS.LAST_R.data,2);
            end
            ETM_temp = ETM_prices.data./squeeze(PREDICTORS.LAST_R.data(:,cpi_vin,pos_cpi));
            n_fill = min(first_vin_size + vin - 1, size(ETM_temp, 1));
            if n_fill >= 1
                ETM_data(1:n_fill, vin, :) = ETM_temp(1:n_fill, :);
                ETM_volumes_data(1:n_fill, vin, :) = ETM_volumes.data(1:n_fill, :);
            end
        end 

    observed_ETM.data = ETM_prices.data./squeeze(PREDICTORS.LAST_R.data(:,end,pos_cpi));
    observed_ETM.obs = ETM_prices.obs;

    elseif model == 6

    pos_cpi = find(strcmp(PREDICTORS.RW.id,'CPIAUCSL'));

    first_vin = PREDICTORS.RW.data(:,1,1);
    first_vin_size = find(isnan(first_vin), 1, 'first')-1; 

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

    ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.RW.data,2),size(ETM_prices.data,2));
    ETM_volumes_data = nan(length(ETM_prices.obs),size(PREDICTORS.RW.data,2),size(ETM_volumes.data,2));

        for vin = 1:size(PREDICTORS.RW.data,2)
            cpi_vin = vin;
            if use_last_cpi_vintage_for_real_prices
                cpi_vin = size(selected_data,2);
            end
            ETM_temp = ETM_prices.data./squeeze(selected_data(:,cpi_vin,pos_cpi));
            n_fill = min(first_vin_size + vin - 1, size(ETM_temp, 1));
            if n_fill >= 1
                ETM_data(1:n_fill, vin, :) = ETM_temp(1:n_fill, :);
                ETM_volumes_data(1:n_fill, vin, :) = ETM_volumes.data(1:n_fill, :);
            end
        end
    end 

    observed_ETM.data = ETM_prices.data./squeeze(PREDICTORS.RW.data(:,end,pos_cpi));
    observed_ETM.obs = ETM_prices.obs;

elseif real == 0 % Nominal ETMs prices

    if model == 1

        first_vin = PREDICTORS.SA.data(:,1,1);
        first_vin_size = find(isnan(first_vin), 1, 'first')-1;

        ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.SA.data,2),size(ETM_prices.data,2));
        ETM_volumes_data = nan(length(ETM_prices.obs),size(PREDICTORS.SA.data,2),size(ETM_volumes.data,2));
    
            for vin = 1:size(PREDICTORS.SA.data,2)
                ETM_temp = ETM_prices.data;
                n_fill = min(first_vin_size + vin - 1, size(ETM_temp, 1));
                if n_fill >= 1
                    ETM_data(1:n_fill, vin, :) = ETM_temp(1:n_fill, :);
                    ETM_volumes_data(1:n_fill, vin, :) = ETM_volumes.data(1:n_fill, :);
                end
            end

        observed_ETM.data = ETM_prices.data;
        observed_ETM.obs = ETM_prices.obs;

    elseif model == 2

        first_vin = PREDICTORS.BAR.data(:,1,1);
        first_vin_size = find(isnan(first_vin), 1, 'first')-1;

        ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.BAR.data,2),size(ETM_prices.data,2));
        ETM_volumes_data = nan(length(ETM_prices.obs),size(PREDICTORS.BAR.data,2),size(ETM_volumes.data,2));

        vintage_number = size(PREDICTORS.BAR.data,2);

    elseif model == 3

        first_vin = PREDICTORS.BAR_SV.data(:,1,1);
        first_vin_size = find(isnan(first_vin), 1, 'first')-1;

        ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.BAR_SV.data,2),size(ETM_prices.data,2));
        ETM_volumes_data = nan(length(ETM_prices.obs),size(PREDICTORS.BAR_SV.data,2),size(ETM_volumes.data,2));

        vintage_number = size(PREDICTORS.BAR_SV.data,2);

    elseif model == 4

        first_vin = PREDICTORS.BAR_SVo.data(:,1,1);
        first_vin_size = find(isnan(first_vin), 1, 'first')-1;

        ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.BAR_SVo.data,2),size(ETM_prices.data,2));
        ETM_volumes_data = nan(length(ETM_prices.obs),size(PREDICTORS.BAR_SVo.data,2),size(ETM_volumes.data,2));

        vintage_number = size(PREDICTORS.BAR_SVo.data,2);


    elseif model == 5

        first_vin = PREDICTORS.LAST_R.data(:,1,1);
        first_vin_size = find(isnan(first_vin), 1, 'first')-1;

        ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.LAST_R.data,2),size(ETM_prices.data,2));
        ETM_volumes_data = nan(length(ETM_prices.obs),size(PREDICTORS.LAST_R.data,2),size(ETM_volumes.data,2));

        vintage_number = size(PREDICTORS.LAST_R.data,2);

    elseif model == 6

    first_vin = PREDICTORS.RW.data(:,1,1);
    first_vin_size = find(isnan(first_vin), 1, 'first')-1; 

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

    ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.RW.data,2),size(ETM_prices.data,2));
    ETM_volumes_data = nan(length(ETM_prices.obs),size(PREDICTORS.RW.data,2),size(ETM_volumes.data,2));

        for vin = 1:size(PREDICTORS.RW.data,2)
            ETM_temp = ETM_prices.data;
            n_fill = min(first_vin_size + vin - 1, size(ETM_temp, 1));
            if n_fill >= 1
                ETM_data(1:n_fill, vin, :) = ETM_temp(1:n_fill, :);
                ETM_volumes_data(1:n_fill, vin, :) = ETM_volumes.data(1:n_fill, :);
            end
        end
    end

    observed_ETM.data = ETM_prices.data;
    observed_ETM.obs = ETM_prices.obs;

end

if real_time == 0
    if length(observed_ETM.obs) < 3
        error('non real-time forecasting requires at least three observations');
    end

    last_non_nowcasted_obs = observed_ETM.obs(end-2);
    if end_date > last_non_nowcasted_obs
        end_date = last_non_nowcasted_obs;
    end
end

%% Align external forecasts to the OOS evaluation window

IS_start = Lastin; idx_start = find(futures.Copper.obs == IS_start);
IS_end = end_date - calmonths(1); idx_end = find(futures.Copper.obs == IS_end);

if isempty(idx_start) || isempty(idx_end)
    error('Check Futures first and last available dates');
end

ETM_names_futures = fieldnames(futures);
for i = 1:length(ETM_names_futures)
    futures.(ETM_names_futures{i}).data(:,1:idx_start - 1) = [];
    futures.(ETM_names_futures{i}).obs(:,1:idx_start - 1) = [];

    futures.(ETM_names_futures{i}).data(:,idx_end + 1:end) = [];
    futures.(ETM_names_futures{i}).obs(:,idx_end + 1:end) = [];
    futures.(ETM_names_futures{i}).horizons = futures_horizons_from_id(futures.(ETM_names_futures{i}));
end

IS_start = Lastin; idx_start = find(p_forecasts_fixed_h_imputed.Copper.survey_dates == IS_start);
IS_end = end_date - calmonths(1); idx_end = find(p_forecasts_fixed_h_imputed.Copper.survey_dates == IS_end);

if isempty(idx_start) || isempty(idx_end)
    error('Check P. Forecasters first and last available dates');
end

ETM_names_p_fore = fieldnames(p_forecasts_fixed_h_imputed);
for i = 1:length(ETM_names_p_fore)
    p_forecasts_fixed_h_imputed.(ETM_names_p_fore{i}).data(:,1:idx_start - 1) = [];
    p_forecasts_fixed_h_imputed.(ETM_names_p_fore{i}).survey_dates(:,1:idx_start - 1) = [];

    p_forecasts_fixed_h_imputed.(ETM_names_p_fore{i}).data(:,idx_end + 1:end) = [];
    p_forecasts_fixed_h_imputed.(ETM_names_p_fore{i}).survey_dates(:,idx_end + 1:end) = [];
end

%% Select Predictors Nowcast Model

    if model == 0

        error('missing code')

    elseif model == 1

        MACRO.data = PREDICTORS.SA.data;
        MACRO.obs = PREDICTORS.obs;
        MACRO.id = PREDICTORS.SA.id;
        MACRO.vintages = PREDICTORS.vintages_nowcasted;

    elseif model == 2

        MACRO.data = PREDICTORS.BAR.data;
        MACRO.obs = PREDICTORS.obs;
        MACRO.id = PREDICTORS.BAR.id;
        MACRO.vintages = PREDICTORS.vintages_nowcasted;

    elseif model == 3

        MACRO.data = PREDICTORS.BAR_SV.data;
        MACRO.obs = PREDICTORS.obs;
        MACRO.id = PREDICTORS.BAR_SV.id;
        MACRO.vintages = PREDICTORS.vintages_nowcasted;

    elseif model == 4

        MACRO.data = PREDICTORS.BAR_SVo.data;
        MACRO.obs = PREDICTORS.obs;
        MACRO.id = PREDICTORS.BAR_SVo.id;
        MACRO.vintages = PREDICTORS.vintages_nowcasted;

    elseif model == 5

        MACRO.data = PREDICTORS.LAST_R.data;
        MACRO.obs = PREDICTORS.obs;
        MACRO.id = PREDICTORS.LAST_R.id;
        MACRO.vintages = PREDICTORS.vintages_last_release;

    elseif model == 6

    selected_data = NaN(size(PREDICTORS.RW.data));

    for r = 1:size(selected_data,3)
        if PREDICTORS.best_model(r) == 0
           selected_data(:,:,r) = PREDICTORS.RW.data(:,:,r);
        elseif PREDICTORS.best_model(r) == 1
           selected_data(:,:,r) = squeeze(PREDICTORS.SA.data(:,:,r));
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
        MACRO.data = selected_data;
        MACRO.obs = PREDICTORS.obs;
        MACRO.id = PREDICTORS.RW.id;
        MACRO.vintages = PREDICTORS.vintages_nowcasted;

    end

%% Select Sample Size

% Cut Rows
if ETM_prices.obs(1) <= start_date
    pos_1st_insample = find(ETM_prices.obs == start_date);
else
    pos_1st_insample = 1;
end

ETM_data(1:pos_1st_insample-1,:,:) = [];
observed_ETM.data(1:pos_1st_insample-1,:) = [];
observed_ETM.obs(1:pos_1st_insample-1,:) = [];
ETM_volumes_data(1:pos_1st_insample-1,:,:) = [];

MACRO.data(1:pos_1st_insample-1,:,:) = [];
MACRO.obs(1:pos_1st_insample-1,:) = [];

% Cut Columns
if MACRO.vintages(1) <= Lastin
   pos_last_insample = find(MACRO.vintages == Lastin);
else
   pos_last_insample = 1;
end

ETM_data(:,1:pos_last_insample-1,:) = [];
ETM_volumes_data(:,1:pos_last_insample-1,:) = [];

MACRO.data(:,1:pos_last_insample-1,:) = [];
MACRO.vintages(:,1:pos_last_insample-1) = [];

if real_time == 0
    pos_non_rt_end_macro = find(MACRO.obs == end_date, 1);
    pos_non_rt_end_etm = find(observed_ETM.obs == end_date, 1);

    if isempty(pos_non_rt_end_macro) || isempty(pos_non_rt_end_etm)
        error('non real-time end_date is not available in the balanced sample');
    end

    MACRO.data(pos_non_rt_end_macro+1:end,:,:) = [];
    MACRO.obs(pos_non_rt_end_macro+1:end,:) = [];

    ETM_data(pos_non_rt_end_etm+1:end,:,:) = [];
    ETM_volumes_data(pos_non_rt_end_etm+1:end,:,:) = [];
    observed_ETM.data(pos_non_rt_end_etm+1:end,:) = [];
    observed_ETM.obs(pos_non_rt_end_etm+1:end,:) = [];

    MACRO.data = use_final_vintage_with_rt_mask(MACRO.data);
    ETM_data = use_final_vintage_with_rt_mask(ETM_data);
    ETM_volumes_data = use_final_vintage_with_rt_mask(ETM_volumes_data);
end

%% Attach ETM data to Predictors dataset 

CPI_forecast_data = [];
CPI_forecast_pos = find(strcmp(MACRO.id, 'CPIAUCSL'), 1);
if ~isempty(CPI_forecast_pos)
    CPI_forecast_data = MACRO.data(:, :, CPI_forecast_pos);
end

excluded_max_tcode = -Inf;
if isfield(PREDICTORS, 'model_input_exclude_ids') && ~isempty(PREDICTORS.model_input_exclude_ids)
    model_input_exclude_ids = cellstr(PREDICTORS.model_input_exclude_ids);
    [drop_present, drop_idx] = ismember(model_input_exclude_ids, cellstr(MACRO.id));
    drop_idx = drop_idx(drop_present);

    if isstruct(predictors_transfomations) && any(drop_present)
        excluded_max_tcode = max(transformations_for_ids(predictors_transfomations, model_input_exclude_ids(drop_present), 'predictors_transfomations'));
    end

    if ~isempty(drop_idx)
        keep_idx = true(1, size(MACRO.data, 3));
        keep_idx(drop_idx) = false;
        MACRO.data = MACRO.data(:, :, keep_idx);
        MACRO.id = MACRO.id(keep_idx);
    end
end

MACRO.data = cat(3, MACRO.data, ETM_data, ETM_volumes_data);
MACRO.id = [MACRO.id', ETM_prices.id, ETM_volumes.id];
predictors_transfomations = transformations_for_ids(predictors_transfomations, MACRO.id, 'predictors_transfomations');
raw_transformations = transformations_for_ids(raw_transformations, ETM_prices.id, 'raw_transformations');

%% Transform Predictors data

X.data = nan(size(MACRO.data));

for pp = 1:size(MACRO.data,3)
    tcode_x = predictors_transfomations(pp);
    preditor_temp = squeeze(MACRO.data(:,:,pp));
    YYd = Building_regressors(preditor_temp,tcode_x);

    if tcode_x == 2 || tcode_x == 3
        YYd = [NaN(1,size(YYd,2)); YYd];
    elseif tcode_x == 4 || tcode_x == 5
        YYd = [NaN(2,size(YYd,2)); YYd];
    end
    X.data(:,:,pp) = YYd;
end

if max(predictors_transfomations) == 2 || max(predictors_transfomations) == 3
    X.data(1,:,:) = [];
    X.obs = MACRO.obs(2:end);
elseif max(predictors_transfomations) == 4 || max(predictors_transfomations) == 5
    X.data(1:2,:,:) = [];
    X.obs = MACRO.obs(3:end);
end

%% Forecasting

% Number of out-of-sample periods
pos_oos_end = find(ETM_prices.obs == end_date, 1);
if isempty(pos_oos_end)
    error('end_date is not available in ETM_prices.obs');
end

end_gap = length(ETM_prices.obs) - pos_oos_end;
if end_gap >= 0
    Out_s = size(ETM_data,2) - end_gap - 1;
else
    Out_s = size(ETM_data,2);
end

if Out_s < 1
    error('out-of-sample size is smaller than one observation');
end

n_ETM_forecast = size(ETM_data,3);
total_forecast_horizon_tasks = n_ETM_forecast * Hsize;
completed_forecast_horizon_tasks = 0;

hx = waitbar(0,'Forecasting ETMs prices...');
for y = 1:size(ETM_data,3) % For each ETM

    Y = squeeze(ETM_data(:,:,y));
    Y_observed = squeeze(observed_ETM.data(:,y));
    Y_dates = observed_ETM.obs;

    if real_time == 1
        figure;
        plot(Y_dates, Y_observed);
        plot(Y_dates, Y(:,end));
    end

    % Pre-store some objects

    results.(ETM_prices.id{y}) = struct();
    results.(ETM_prices.id{y}).futures.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).futures.y_obs = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).futures.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).futures.eps = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).futures.eps_2 = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).futures.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).futures.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).futures.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).p_forecasts.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).p_forecasts.y_obs = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).p_forecasts.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).p_forecasts.eps = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).p_forecasts.eps_2 = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).p_forecasts.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).p_forecasts.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).p_forecasts.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).RW.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).RW.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).RW.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).RW.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).RW.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).RW.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).RW.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).RW.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).AR_p.parameters = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).AR_p.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).AR_p.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).AR_p.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).AR_p.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).AR_p.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).AR_p.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).AR_p.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).AR_p.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).AR_IC.parameters = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).AR_IC.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).AR_IC.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).AR_IC.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).AR_IC.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).AR_IC.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).AR_IC.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).AR_IC.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).AR_IC.RMSPE_cum = nan(Hsize, Out_s);

    for tree_model = 1:numel(tree_model_names)
        model_name = tree_model_names{tree_model};
        results.(ETM_prices.id{y}).(model_name).parameters = cell(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).y_hat = nan(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).y_obs = nan(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).dates = NaT(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).eps = nan(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).eps_2 = nan(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).MSPE = nan(1, Hsize);
        results.(ETM_prices.id{y}).(model_name).RMSPE = nan(1, Hsize);
        results.(ETM_prices.id{y}).(model_name).RMSPE_cum = nan(Hsize, Out_s);
    end

    results.(ETM_prices.id{y}).ARDI_p_1F.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_p_1F.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_p_1F.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_p_1F.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_p_1F.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_p_1F.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDI_p_1F.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDI_p_1F.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).ARDI_IC_1F.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_IC_1F.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_IC_1F.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_IC_1F.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_IC_1F.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_IC_1F.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDI_IC_1F.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDI_IC_1F.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).ARDI_p_2F.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_p_2F.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_p_2F.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_p_2F.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_p_2F.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_p_2F.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDI_p_2F.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDI_p_2F.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).ARDI_IC_2F.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_IC_2F.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_IC_2F.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_IC_2F.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_IC_2F.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDI_IC_2F.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDI_IC_2F.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDI_IC_2F.RMSPE_cum = nan(Hsize, Out_s);

    for exogenous_predictor = 1:size(regressors,2)
        model_name = ['ARDL_p_' regressors{exogenous_predictor}];
        results.(ETM_prices.id{y}).(model_name).y_hat = nan(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).y_obs= nan(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).dates = NaT(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).eps= nan(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).eps_2= nan(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).MSPE = nan(1, Hsize);
        results.(ETM_prices.id{y}).(model_name).RMSPE = nan(1, Hsize);
        results.(ETM_prices.id{y}).(model_name).RMSPE_cum = nan(Hsize, Out_s);
    end

    for exogenous_predictor = 1:size(regressors,2)
        model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
        results.(ETM_prices.id{y}).(model_name).y_hat = nan(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).y_obs= nan(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).dates = NaT(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).eps= nan(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).eps_2= nan(Hsize, Out_s);
        results.(ETM_prices.id{y}).(model_name).MSPE = nan(1, Hsize);
        results.(ETM_prices.id{y}).(model_name).RMSPE = nan(1, Hsize);
        results.(ETM_prices.id{y}).(model_name).RMSPE_cum = nan(Hsize, Out_s);
    end

    results.(ETM_prices.id{y}).ARDL_p_real_activity.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_real_activity.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_real_activity.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_real_activity.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_real_activity.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_real_activity.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDL_p_real_activity.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDL_p_real_activity.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).ARDL_p_cu.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_cu.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_cu.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_cu.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_cu.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_cu.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDL_p_cu.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDL_p_cu.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).ARDL_p_et.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_et.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_et.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_et.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_et.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_et.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDL_p_et.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDL_p_et.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).ARDL_p_ex_rates.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_ex_rates.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_ex_rates.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_ex_rates.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_ex_rates.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_ex_rates.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDL_p_ex_rates.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDL_p_ex_rates.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).ARDL_p_inventories.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_inventories.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_inventories.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_inventories.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_inventories.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_inventories.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDL_p_inventories.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDL_p_inventories.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).ARDL_p_etm.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_etm.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_etm.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_etm.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_etm.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_etm.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDL_p_etm.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDL_p_etm.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).ARDL_p_w_act.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_w_act.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_w_act.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_w_act.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_w_act.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).ARDL_p_w_act.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDL_p_w_act.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).ARDL_p_w_act.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).VAR_p_specific.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).VAR_p_specific.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).VAR_p_specific.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).VAR_p_specific.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).VAR_p_specific.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).VAR_p_specific.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).VAR_p_specific.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).VAR_p_specific.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).FAVAR_specific_p_1F.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).FAVAR_specific_p_1F.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).FAVAR_specific_p_1F.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).FAVAR_specific_p_1F.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).FAVAR_specific_p_1F.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).FAVAR_specific_p_1F.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).FAVAR_specific_p_1F.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).FAVAR_specific_p_1F.RMSPE_cum = nan(Hsize, Out_s);

    results.(ETM_prices.id{y}).FAVAR_specific_p_2F.y_hat = nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).FAVAR_specific_p_2F.y_obs= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).FAVAR_specific_p_2F.dates = NaT(Hsize, Out_s);
    results.(ETM_prices.id{y}).FAVAR_specific_p_2F.eps= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).FAVAR_specific_p_2F.eps_2= nan(Hsize, Out_s);
    results.(ETM_prices.id{y}).FAVAR_specific_p_2F.MSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).FAVAR_specific_p_2F.RMSPE = nan(1, Hsize);
    results.(ETM_prices.id{y}).FAVAR_specific_p_2F.RMSPE_cum = nan(Hsize, Out_s);

    hxx = waitbar(0,'ETM.id{y}');
    for hor = 1:Hsize % For each horizon

        % Transform CPI
        if isempty(CPI_forecast_data)
            error('CPIAUCSL is required to construct real-price forecasts.');
        end
        CPI_temp = squeeze(CPI_forecast_data);

        CPIg = Building_target(CPI_temp,3,'SW',hor);

        tcode_y = raw_transformations(y);

        % Transform ETMs data
        % Dependent variable
        Yg = Building_target(Y,tcode_y,Target_scheme,hor);
        % Lagged regressors
        Yd = Building_regressors(Y,tcode_y);
        % Observed values
        Y_obs = Building_target(Y_observed,tcode_y,Target_scheme,hor);
        
        Y_date = Y_dates;
        target_date_offset = numel(Y_dates) - size(Y_obs, 1);
        Y_obs_dates = Y_dates(target_date_offset + 1:end);

        % Transform ETMs data for VAR estimates
        X_var.data = nan(size(MACRO.data));

        for pp = 1:size(MACRO.data,3)
            tcode_x = predictors_transfomations(pp);
            preditor_temp = squeeze(MACRO.data(:,:,pp));
            YYg_var = Building_target(preditor_temp,tcode_x,Target_scheme,hor);
        
            if tcode_x == 2 || tcode_x == 3
                YYg_var = [NaN(1 + hor - 1,size(YYg_var,2)); YYg_var];
            elseif tcode_x == 4 || tcode_x == 5
                YYg_var = [NaN(2 + hor - 1,size(YYg_var,2)); YYg_var];
            end
            X_var.data(:,:,pp) = YYg_var;
        end
        
        if max(predictors_transfomations) == 2 || max(predictors_transfomations) == 3
            X_var.data(1:1 + hor - 1,:,:) = [];
            X_var.obs = MACRO.obs(2 + hor - 1:end);
        elseif max(predictors_transfomations) == 4 || max(predictors_transfomations) == 5
            X_var.data(1:2 + hor - 1,:,:) = [];
            X_var.obs = MACRO.obs(3 + hor - 1:end);
        end

        % Cut predictors
        if max(predictors_transfomations) == 0 || max(predictors_transfomations) == 1
            cut_pred = 0;
        elseif max(predictors_transfomations) == 2 || max(predictors_transfomations) == 3
            cut_pred = 1;
        elseif max(predictors_transfomations) == 4 || max(predictors_transfomations) == 5
            cut_pred = 2;
        end

        % Cut predictors needed when the excluded series are taken into account
        cut_pred_full = cut_pred;
        if excluded_max_tcode == 4 || excluded_max_tcode == 5
            cut_pred_full = max(cut_pred_full, 2);
        elseif excluded_max_tcode == 2 || excluded_max_tcode == 3
            cut_pred_full = max(cut_pred_full, 1);
        end

        % Cut dependent variables
        if tcode_y == 0 || tcode_y == 1
            cut_y = 0;
        elseif tcode_y == 2 || tcode_y == 3
            cut_y = 1;
        elseif tcode_y == 4 || tcode_y == 5
            cut_y = 2;
        end

        % In case of horizon growth rates
        cut_hor_y = size(Yd,1) - size(Yg,1);

        if cut_pred == cut_y
            Yd(1:cut_hor_y,:) = [];
            Xd = X.data; Xd(1:cut_hor_y,:,:) = [];
            CPIg(1:cut_hor_y,:) = [];
        elseif cut_y > cut_pred
            difference = cut_y - cut_pred;
            Yd(1:cut_hor_y,:) = [];
            Xd = X.data; Xd(1:cut_hor_y + difference,:,:) = [];
            CPIg(1:cut_hor_y + difference,:,:) = [];
        elseif cut_y < cut_pred
            difference = cut_pred - cut_y;
            cut_Yd = max (difference, cut_hor_y);
            Yd(1:cut_Yd,:) = [];
            if cut_hor_y < difference
                cut_Yg = difference - cut_hor_y;
                Yg(1:cut_Yg,:) = [];
                X_var.data(1:cut_Yg,:,:) = [];
                X_var.obs(1:cut_Yg,:,:) = [];
                Y_obs(1:cut_Yg,:) = [];
                Y_date(1:cut_Yg,:) = [];
                Y_obs_dates(1:cut_Yg,:) = [];
                Xd = X.data; 
            else
                Xd = X.data; Xd(1:cut_hor_y - difference,:,:) = [];
                CPIg(1:cut_hor_y - difference,:,:) = [];
            end
        end

        if hor == 1 && cut_pred == cut_y && cut_pred_full > cut_y
            n_extra = cut_pred_full - cut_y - cut_hor_y;
            if n_extra > 0
                Yd(1:n_extra,:) = [];
                Yg(1:n_extra,:) = [];
                Xd(1:n_extra,:,:) = [];
                X_var.data(1:n_extra,:,:) = [];
                X_var.obs(1:n_extra,:,:) = [];
                Y_obs(1:n_extra,:) = [];
                Y_date(1:n_extra,:) = [];
                Y_obs_dates(1:n_extra,:) = [];
            end
        end

        count = 0;

        % In-sample size first window
        vin_1 = Yg(:,1); vin_1_c = vin_1(~any(isnan(vin_1), 2), :);
        InSize = size(vin_1_c,1);
        
         for tt = 1:Out_s - hor + 1 % For each OOS period

            % Store observed value for forecast evaluation
            idx_obs = InSize + tt - 1 + hor;
            if idx_obs <= length(Y_obs)
                real_Y.value = Y_obs(idx_obs);
            else
                real_Y.value = NaN;
            end
            if idx_obs <= length(Y_obs_dates)
                real_Y.date = Y_obs_dates(idx_obs);
            else
                real_Y.date = NaT;
            end

            if rollwind == 0 % Expanding Window
                Ygg = squeeze(Yg(:,tt));
                Ydd = squeeze(Yd(:,tt));
                Xdd = squeeze(Xd(:,tt,:));
                Ygg_var = squeeze(X_var.data(:,tt,:));
                CPIgg = CPIg(:,tt);

                Y_g = Ygg(~any(isnan(Ygg), 2), :);
                Y_d = Ydd(~any(isnan(Ydd), 2), :);
                X_d = Xdd(~any(isnan(Xdd), 2), :);
                Y_g_var = Ygg_var(~any(isnan(Ygg_var), 2), :);
                CPI_g = CPIgg(~any(isnan(CPIgg), 2), :);

                % Models: Professional Forecasters Survey
                % CPI forecast
                CPI_TEMP = CPI_temp(:,tt);
                CPI_TEMP = CPI_TEMP(~any(isnan(CPI_TEMP), 2), :);
                last_cpi = CPI_TEMP(end,1);
                CPIg_hat = mean(CPI_g);
                CPI_hat = last_cpi.*exp(CPIg_hat);
                % ETM price forecast
                p_forecast_name = ETM_prices.id{y};
                if ~isfield(p_forecasts_fixed_h_imputed, p_forecast_name)
                    p_forecast_name = ETM_names_p_fore{y};
                end
                Yhat = p_forecasts_fixed_h_imputed.(p_forecast_name).data(hor,tt)./CPI_hat;
                results.(ETM_prices.id{y}).p_forecasts.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).p_forecasts.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).p_forecasts.dates(hor,tt) = real_Y.date;

                % Model: RW + Drift(level)
                if tcode_y == 0 || tcode_y == 1
                    Yhat = Y_g(end);
                elseif tcode_y == 2 || tcode_y == 3
                    Yhat = mean(Y_g);
                elseif tcode_y == 4 || tcode_y == 5
                    Yhat = 0;
                end
                results.(ETM_prices.id{y}).RW.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).RW.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).RW.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).RW.eps(hor, tt) = Yhat - real_Y.value;

                % Model: AR(p)
                lags = 'manual';
                [Yhat, P_ic] = AR_new(lags, direct, IC, hor, Pn, P_AR, Y_g, Y_d);
                results.(ETM_prices.id{y}).AR_p.parameters(hor, tt) = P_ic;
                results.(ETM_prices.id{y}).AR_p.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).AR_p.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).AR_p.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).AR_p.eps(hor, tt) = Yhat - real_Y.value;

                % Model: AR(AIC)
                lags = 'i_criteria';
                [Yhat, P_ic] = AR_new(lags, direct, IC, hor, Pn, P_AR, Y_g, Y_d);
                results.(ETM_prices.id{y}).AR_IC.parameters(hor, tt) = P_ic;
                results.(ETM_prices.id{y}).AR_IC.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).AR_IC.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).AR_IC.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).AR_IC.eps(hor, tt) = Yhat - real_Y.value;

                for tree_model = 1:numel(tree_model_names)
                    model_name = tree_model_names{tree_model};
                    [Yhat, model_info] = tree_ml_forecast(MACRO, ETM_prices, model_name, direct, hor, Y_g, Y_d, X_d, y);
                    results.(ETM_prices.id{y}).(model_name).parameters{hor, tt} = model_info;
                    results.(ETM_prices.id{y}).(model_name).y_hat(hor, tt) = Yhat;
                    results.(ETM_prices.id{y}).(model_name).y_obs(hor,tt) = real_Y.value;
                    results.(ETM_prices.id{y}).(model_name).dates(hor,tt) = real_Y.date;
                    results.(ETM_prices.id{y}).(model_name).eps(hor, tt) = Yhat - real_Y.value;
                end

                % Model: ARDL(p,q)
                if strcmp(ETM_prices.id{y}, 'Copper')
                    excluded_variables = {'Iron_Ore_Price',...
                                        'Aluminum_convenience_yield',... 
                                        'Nickel_convenience_yield',...
                                        'Zinc_convenience_yield',...
                                        'Aluminum_equity_index_EW',... 
                                        'Nickel_equity_index_EW',...
                                        'Zinc_equity_index_EW'};
                elseif strcmp(ETM_prices.id{y}, 'Aluminum')
                    excluded_variables = {'Iron_Ore_Price',...
                                        'Copper_convenience_yield',... 
                                        'Nickel_convenience_yield',...
                                        'Zinc_convenience_yield',...
                                        'Copper_equity_index_EW',... 
                                        'Nickel_equity_index_EW',...
                                        'Zinc_equity_index_EW'};
                elseif strcmp(ETM_prices.id{y}, 'Nickel')
                    excluded_variables = {'Aluminum_convenience_yield',... 
                                        'Copper_convenience_yield',...
                                        'Zinc_convenience_yield',...
                                        'Aluminum_equity_index_EW',... 
                                        'Copper_equity_index_EW',...
                                        'Zinc_equity_index_EW'};
                elseif strcmp(ETM_prices.id{y}, 'Zinc')
                    excluded_variables = {'Iron_Ore_Price',...
                                        'Aluminum_convenience_yield',... 
                                        'Nickel_convenience_yield',...
                                        'Copper_convenience_yield',...
                                        'Aluminum_equity_index_EW',... 
                                        'Nickel_equity_index_EW',...
                                        'Copper_equity_index_EW'};
                end

                for exogenous_predictor = 1:size(regressors,2)
                    if strcmp(ETM_prices.id{y}, regressors{exogenous_predictor})
                        continue;
                    elseif ismember(regressors{exogenous_predictor}, excluded_variables)
                        continue;
                    end
                    [~, x_positions] = available_regressor_positions(MACRO.id, {regressors{exogenous_predictor}});
                    if isempty(x_positions); continue; end
                    X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                    lags = 'manual';
                    [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, Pn, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                    model_name = ['ARDL_p_' regressors{exogenous_predictor}];
                    results.(ETM_prices.id{y}).(model_name).parameters{hor, tt} = P_ic;
                    results.(ETM_prices.id{y}).(model_name).y_hat(hor, tt) = Yhat;
                    results.(ETM_prices.id{y}).(model_name).y_obs(hor,tt) = real_Y.value;
                    results.(ETM_prices.id{y}).(model_name).dates(hor,tt) = real_Y.date;
                    results.(ETM_prices.id{y}).(model_name).eps(hor, tt) = Yhat - real_Y.value;
                end

                % Model: ARDL(IC)
                for exogenous_predictor = 1:size(regressors,2)
                    if strcmp(ETM_prices.id{y}, regressors{exogenous_predictor})
                        continue;
                    elseif ismember(regressors{exogenous_predictor}, excluded_variables)
                        continue;
                    end
                    [~, x_positions] = available_regressor_positions(MACRO.id, {regressors{exogenous_predictor}});
                    if isempty(x_positions); continue; end
                    X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                    lags = 'i_criteria';
                    [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, Pn, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                    model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
                    results.(ETM_prices.id{y}).(model_name).parameters{hor, tt} = P_ic;
                    results.(ETM_prices.id{y}).(model_name).y_hat(hor, tt) = Yhat;
                    results.(ETM_prices.id{y}).(model_name).y_obs(hor,tt) = real_Y.value;
                    results.(ETM_prices.id{y}).(model_name).dates(hor,tt) = real_Y.date;
                    results.(ETM_prices.id{y}).(model_name).eps(hor, tt) = Yhat - real_Y.value;
                end

                % Model: ARDL(p,q) - Real Activity
                [~, x_positions] = available_regressor_positions(MACRO.id, regressors_real_activity);
                X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                lags = 'manual';
                [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, 1, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                results.(ETM_prices.id{y}).ARDL_p_real_activity.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDL_p_real_activity.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDL_p_real_activity.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDL_p_real_activity.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDL_p_real_activity.eps(hor, tt) = Yhat - real_Y.value;

                % Model: ARDL(p,q) - CU
                [~, x_positions] = available_regressor_positions(MACRO.id, regressors_cu);
                X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                lags = 'manual';
                [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, 1, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                results.(ETM_prices.id{y}).ARDL_p_cu.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDL_p_cu.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDL_p_cu.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDL_p_cu.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDL_p_cu.eps(hor, tt) = Yhat - real_Y.value;

                % Model: ARDL(p,q) - ET
                [~, x_positions] = available_regressor_positions(MACRO.id, regressors_et);
                X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                lags = 'manual';
                [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, 1, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                results.(ETM_prices.id{y}).ARDL_p_et.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDL_p_et.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDL_p_et.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDL_p_et.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDL_p_et.eps(hor, tt) = Yhat - real_Y.value;

                % Model: ARDL(p,q) - Exchange Rates
                [~, x_positions] = available_regressor_positions(MACRO.id, regressors_ex_rates);
                X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                lags = 'manual';
                [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, 1, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                results.(ETM_prices.id{y}).ARDL_p_ex_rates.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDL_p_ex_rates.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDL_p_ex_rates.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDL_p_ex_rates.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDL_p_ex_rates.eps(hor, tt) = Yhat - real_Y.value;

                % Model: ARDL(p,q) - Inventories
                [~, x_positions] = available_regressor_positions(MACRO.id, regressors_inventories);
                X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                lags = 'manual';
                [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, 1, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                results.(ETM_prices.id{y}).ARDL_p_inventories.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDL_p_inventories.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDL_p_inventories.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDL_p_inventories.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDL_p_inventories.eps(hor, tt) = Yhat - real_Y.value;

                % Model: ARDL(p,q) - ETMs
                regressors_etm_temp = regressors_etm;
                regressors_etm_temp(strcmp(regressors_etm_temp, ETM_prices.id{y})) = [];
                [regressors_etm_temp, x_positions] = available_regressor_positions(MACRO.id, regressors_etm_temp);
                X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                lags = 'manual';
                [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, 1, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                results.(ETM_prices.id{y}).ARDL_p_etm.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDL_p_etm.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDL_p_etm.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDL_p_etm.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDL_p_etm.eps(hor, tt) = Yhat - real_Y.value;

                % Model: ARDL(p,q) - Inventories
                [~, x_positions] = available_regressor_positions(MACRO.id, regressors_w_act);
                X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                lags = 'manual';
                [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, 1, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                results.(ETM_prices.id{y}).ARDL_p_w_act.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDL_p_w_act.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDL_p_w_act.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDL_p_w_act.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDL_p_w_act.eps(hor, tt) = Yhat - real_Y.value;

                % Model: AR-DI(p,q) - 1 Factor
                K_f = 1;
                lags = 'manual';
                [Yhat, P_ic, factors] = ARDI_new(MACRO, ETM_prices, lags, direct, IC, hor, Pn, K_f, P_custom_ARDI, Y_g, Y_d, X_d, y);
                results.(ETM_prices.id{y}).ARDI_p_1F.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDI_p_1F.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDI_p_1F.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDI_p_1F.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDI_p_1F.eps(hor, tt) = Yhat - real_Y.value;
                if tt == Out_s - hor + 1 && hor == 1
                    results.(ETM_prices.id{y}).ARDI_p_1F.factors = factors;
                end

                % Model: AR-DI(AIC) - 1 Factor
                K_f = 1;
                lags = 'i_criteria';
                [Yhat, P_ic, factors] = ARDI_new(MACRO, ETM_prices, lags, direct, IC, hor, Pn, K_f, P_custom_ARDI, Y_g, Y_d, X_d, y);
                results.(ETM_prices.id{y}).ARDI_IC_1F.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDI_IC_1F.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDI_IC_1F.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDI_IC_1F.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDI_IC_1F.eps(hor, tt) = Yhat - real_Y.value;
                if tt == Out_s - hor + 1 && hor == 1
                    results.(ETM_prices.id{y}).ARDI_IC_1F.factors = factors;
                end

                % Model: AR-DI(p,q) - 2 Factors
                K_f = 2;
                lags = 'manual';
                [Yhat, P_ic, factors] = ARDI_new(MACRO, ETM_prices, lags, direct, IC, hor, Pn, K_f, P_custom_ARDI, Y_g, Y_d, X_d, y);
                results.(ETM_prices.id{y}).ARDI_p_2F.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDI_p_2F.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDI_p_2F.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDI_p_2F.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDI_p_2F.eps(hor, tt) = Yhat - real_Y.value;
                if tt == Out_s - hor + 1 && hor == 1
                    results.(ETM_prices.id{y}).ARDI_p_2F.factors = factors;
                end
              
                % Model: AR-DI(AIC) - 2 Factors
                K_f = 2;
                lags = 'i_criteria';
                [Yhat, P_ic, factors] = ARDI_new(MACRO, ETM_prices, lags, direct, IC, hor, Pn, K_f, P_custom_ARDI, Y_g, Y_d, X_d, y);
                results.(ETM_prices.id{y}).ARDI_IC_2F.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDI_IC_2F.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDI_IC_2F.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDI_IC_2F.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDI_IC_2F.eps(hor, tt) = Yhat - real_Y.value;
                if tt == Out_s - hor + 1 && hor == 1
                    results.(ETM_prices.id{y}).ARDI_IC_2F.factors = factors;
                end

                % Model: VAR(p) - ETMs
                regressors_var_etm_temp = regressors_var_metals;
                [regressors_var_etm_temp, x_positions] = available_regressor_positions(MACRO.id, regressors_var_etm_temp);
                Y_g_sel = Y_g_var(:,x_positions); % Selected 
                X_d_sel = X_d(:,x_positions); % Selected 
                lags = 'manual';
                [Yhat_var, P_ic] = VAR_new(lags, direct, IC, hor, 1, P_custom_VAR, Y_g_sel, X_d_sel);
                pos_yhat_target = find(strcmp(regressors_var_etm_temp, ETM_prices.id{y}));
                Yhat = Yhat_var(pos_yhat_target);
                results.(ETM_prices.id{y}).VAR_p_etm.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).VAR_p_etm.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).VAR_p_etm.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).VAR_p_etm.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).VAR_p_etm.eps(hor, tt) = Yhat - real_Y.value;

                % Model: VAR(p) - ETMs
                regressors_var_etm_temp = regressors_var_metals;
                [regressors_var_etm_temp, x_positions] = available_regressor_positions(MACRO.id, regressors_var_etm_temp);
                Y_g_sel = Y_g_var(:,x_positions); % Selected 
                X_d_sel = X_d(:,x_positions); % Selected 
                lags = 'i_criteria';
                [Yhat_var, P_ic] = VAR_new(lags, direct, IC, hor, 1, P_custom_VAR, Y_g_sel, X_d_sel);
                pos_yhat_target = find(strcmp(regressors_var_etm_temp, ETM_prices.id{y}));
                Yhat = Yhat_var(pos_yhat_target);
                results.(ETM_prices.id{y}).VAR_IC_etm.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).VAR_IC_etm.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).VAR_IC_etm.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).VAR_IC_etm.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).VAR_IC_etm.eps(hor, tt) = Yhat - real_Y.value;

            elseif rollwind == 1 % Rolling WindoW
                
                count = count + 1;
                Ygg = squeeze(Yg(count:end,tt));
                Ydd = squeeze(Yd(count:end,tt));
                Xdd = squeeze(Xd(count:end,tt,:));
                Ygg_var = squeeze(X_var.data(count:end,tt,:));
                CPIgg = CPIg(count:end,tt);

                Y_g = Ygg(~any(isnan(Ygg), 2), :);
                Y_d = Ydd(~any(isnan(Ydd), 2), :);
                X_d = Xdd(~any(isnan(Xdd), 2), :);
                Y_g_var = Ygg_var(~any(isnan(Ygg_var), 2), :);
                CPI_g = CPIgg(~any(isnan(CPIgg), 2), :);

                % Models: Futures
                % CPI forecast
                CPI_TEMP = CPI_temp(:,tt);
                CPI_TEMP = CPI_TEMP(~any(isnan(CPI_TEMP), 2), :);
                last_cpi = CPI_TEMP(end,1);
                CPIg_hat = mean(CPI_g);
                CPI_hat = last_cpi.*exp(CPIg_hat);
                % ETM price forecast
                futures_name = ETM_prices.id{y};
                if ~isfield(futures, futures_name)
                    futures_name = ETM_names_futures{y};
                end
                futures_hor_pos = find(futures.(futures_name).horizons == hor, 1);
                if isempty(futures_hor_pos) || tt > size(futures.(futures_name).data, 2)
                    Yhat = NaN;
                elseif real == 1
                    Yhat = futures.(futures_name).data(futures_hor_pos,tt)./CPI_hat;
                elseif real == 0
                    Yhat = futures.(futures_name).data(futures_hor_pos,tt);
                end
                results.(ETM_prices.id{y}).futures.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).futures.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).futures.dates(hor,tt) = real_Y.date;

                % Models: Professional Forecasters Survey
                % CPI forecast
                CPI_TEMP = CPI_temp(:,tt);
                CPI_TEMP = CPI_TEMP(~any(isnan(CPI_TEMP), 2), :);
                last_cpi = CPI_TEMP(end,1);
                CPIg_hat = mean(CPI_g);
                CPI_hat = last_cpi.*exp(CPIg_hat);
                % ETM price forecast
                p_forecast_name = ETM_prices.id{y};
                if ~isfield(p_forecasts_fixed_h_imputed, p_forecast_name)
                    p_forecast_name = ETM_names_p_fore{y};
                end
                if real == 1
                    Yhat = p_forecasts_fixed_h_imputed.(p_forecast_name).data(hor,tt)./CPI_hat;
                elseif real == 0
                    Yhat = p_forecasts_fixed_h_imputed.(p_forecast_name).data(hor,tt);
                end
                results.(ETM_prices.id{y}).p_forecasts.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).p_forecasts.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).p_forecasts.dates(hor,tt) = real_Y.date;

                % Model: RW + Drift(level)
                if tcode_y == 0 || tcode_y == 1
                    Yhat = Y_g(end);
                elseif tcode_y == 2 || tcode_y == 3
                    Yhat = mean(Y_g);
                elseif tcode_y == 4 || tcode_y == 5
                    Yhat = 0;
                end
                results.(ETM_prices.id{y}).RW.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).RW.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).RW.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).RW.eps(hor, tt) = Yhat - real_Y.value;

                % Model: AR(p)
                lags = 'manual';
                [Yhat, P_ic] = AR_new(lags, direct, IC, hor, Pn, P_AR, Y_g, Y_d);
                results.(ETM_prices.id{y}).AR_p.parameters(hor, tt) = P_ic;
                results.(ETM_prices.id{y}).AR_p.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).AR_p.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).AR_p.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).AR_p.eps(hor, tt) = Yhat - real_Y.value;

                % Model: AR(AIC)
                lags = 'i_criteria';
                [Yhat, P_ic] = AR_new(lags, direct, IC, hor, Pn, P_AR, Y_g, Y_d);
                results.(ETM_prices.id{y}).AR_IC.parameters(hor, tt) = P_ic;
                results.(ETM_prices.id{y}).AR_IC.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).AR_IC.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).AR_IC.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).AR_IC.eps(hor, tt) = Yhat - real_Y.value;

                for tree_model = 1:numel(tree_model_names)
                    model_name = tree_model_names{tree_model};
                    [Yhat, model_info] = tree_ml_forecast(MACRO, ETM_prices, model_name, direct, hor, Y_g, Y_d, X_d, y);
                    results.(ETM_prices.id{y}).(model_name).parameters{hor, tt} = model_info;
                    results.(ETM_prices.id{y}).(model_name).y_hat(hor, tt) = Yhat;
                    results.(ETM_prices.id{y}).(model_name).y_obs(hor,tt) = real_Y.value;
                    results.(ETM_prices.id{y}).(model_name).dates(hor,tt) = real_Y.date;
                    results.(ETM_prices.id{y}).(model_name).eps(hor, tt) = Yhat - real_Y.value;
                end

                % Model: ARDL(p,q)
                if strcmp(ETM_prices.id{y}, 'Copper')
                    excluded_variables = {'Iron_Ore_Price',...
                                        'Aluminum_convenience_yield',... 
                                        'Nickel_convenience_yield',...
                                        'Zinc_convenience_yield',...
                                        'Aluminum_equity_index_EW',... 
                                        'Nickel_equity_index_EW',...
                                        'Zinc_equity_index_EW'};
                elseif strcmp(ETM_prices.id{y}, 'Aluminum')
                    excluded_variables = {'Iron_Ore_Price',...
                                        'Copper_convenience_yield',... 
                                        'Nickel_convenience_yield',...
                                        'Zinc_convenience_yield',...
                                        'Copper_equity_index_EW',... 
                                        'Nickel_equity_index_EW',...
                                        'Zinc_equity_index_EW'};
                elseif strcmp(ETM_prices.id{y}, 'Nickel')
                    excluded_variables = {'Aluminum_convenience_yield',... 
                                        'Copper_convenience_yield',...
                                        'Zinc_convenience_yield',...
                                        'Aluminum_equity_index_EW',... 
                                        'Copper_equity_index_EW',...
                                        'Zinc_equity_index_EW'};
                elseif strcmp(ETM_prices.id{y}, 'Zinc')
                    excluded_variables = {'Iron_Ore_Price',...
                                        'Aluminum_convenience_yield',... 
                                        'Nickel_convenience_yield',...
                                        'Copper_convenience_yield',...
                                        'Aluminum_equity_index_EW',... 
                                        'Nickel_equity_index_EW',...
                                        'Copper_equity_index_EW'};
                end

                for exogenous_predictor = 1:size(regressors,2)
                    if strcmp(ETM_prices.id{y}, regressors{exogenous_predictor})
                        continue;
                    elseif ismember(regressors{exogenous_predictor}, excluded_variables)
                        continue;
                    end
                    [~, x_positions] = available_regressor_positions(MACRO.id, {regressors{exogenous_predictor}});
                    if isempty(x_positions); continue; end
                    X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                    lags = 'manual';
                    [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, Pn, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                    model_name = ['ARDL_p_' regressors{exogenous_predictor}];
                    results.(ETM_prices.id{y}).(model_name).parameters{hor, tt} = P_ic;
                    results.(ETM_prices.id{y}).(model_name).y_hat(hor, tt) = Yhat;
                    results.(ETM_prices.id{y}).(model_name).y_obs(hor,tt) = real_Y.value;
                    results.(ETM_prices.id{y}).(model_name).dates(hor,tt) = real_Y.date;
                    results.(ETM_prices.id{y}).(model_name).eps(hor, tt) = Yhat - real_Y.value;
                end

                % Model: ARDL(IC)
                for exogenous_predictor = 1:size(regressors,2)
                    if strcmp(ETM_prices.id{y}, regressors{exogenous_predictor})
                        continue;
                    elseif ismember(regressors{exogenous_predictor}, excluded_variables)
                        continue;
                    end
                    [~, x_positions] = available_regressor_positions(MACRO.id, {regressors{exogenous_predictor}});
                    if isempty(x_positions); continue; end
                    X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                    lags = 'i_criteria';
                    [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, Pn, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                    model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
                    results.(ETM_prices.id{y}).(model_name).parameters{hor, tt} = P_ic;
                    results.(ETM_prices.id{y}).(model_name).y_hat(hor, tt) = Yhat;
                    results.(ETM_prices.id{y}).(model_name).y_obs(hor,tt) = real_Y.value;
                    results.(ETM_prices.id{y}).(model_name).dates(hor,tt) = real_Y.date;
                    results.(ETM_prices.id{y}).(model_name).eps(hor, tt) = Yhat - real_Y.value;
                end

                % Model: ARDL(p,q) - Real Activity
                [~, x_positions] = available_regressor_positions(MACRO.id, regressors_real_activity);
                X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                lags = 'manual';
                [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, 1, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                results.(ETM_prices.id{y}).ARDL_p_real_activity.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDL_p_real_activity.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDL_p_real_activity.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDL_p_real_activity.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDL_p_real_activity.eps(hor, tt) = Yhat - real_Y.value;

                % Model: ARDL(p,q) - ETMs
                regressors_etm_temp = regressors_etm;
                regressors_etm_temp(strcmp(regressors_etm_temp, ETM_prices.id{y})) = [];
                [regressors_etm_temp, x_positions] = available_regressor_positions(MACRO.id, regressors_etm_temp);
                X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                lags = 'manual';
                [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, 1, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                results.(ETM_prices.id{y}).ARDL_p_etm.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDL_p_etm.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDL_p_etm.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDL_p_etm.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDL_p_etm.eps(hor, tt) = Yhat - real_Y.value;

                % Model: ARDL(p,q) - CU
                [~, x_positions] = available_regressor_positions(MACRO.id, regressors_cu);
                X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                lags = 'manual';
                [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, 1, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                results.(ETM_prices.id{y}).ARDL_p_cu.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDL_p_cu.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDL_p_cu.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDL_p_cu.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDL_p_cu.eps(hor, tt) = Yhat - real_Y.value;

                % Model: ARDL(p,q) - ET
                [~, x_positions] = available_regressor_positions(MACRO.id, regressors_et);
                X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                lags = 'manual';
                [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, 1, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                results.(ETM_prices.id{y}).ARDL_p_et.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDL_p_et.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDL_p_et.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDL_p_et.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDL_p_et.eps(hor, tt) = Yhat - real_Y.value;

                % Model: ARDL(p,q) - Exchange Rates
                [~, x_positions] = available_regressor_positions(MACRO.id, regressors_ex_rates);
                X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                lags = 'manual';
                [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, 1, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                results.(ETM_prices.id{y}).ARDL_p_ex_rates.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDL_p_ex_rates.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDL_p_ex_rates.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDL_p_ex_rates.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDL_p_ex_rates.eps(hor, tt) = Yhat - real_Y.value;

                % Model: ARDL(p,q) - Inventories
                [~, x_positions] = available_regressor_positions(MACRO.id, regressors_inventories);
                X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                lags = 'manual';
                [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, 1, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                results.(ETM_prices.id{y}).ARDL_p_inventories.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDL_p_inventories.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDL_p_inventories.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDL_p_inventories.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDL_p_inventories.eps(hor, tt) = Yhat - real_Y.value;

                % Model: ARDL(p,q) - Inventories
                [~, x_positions] = available_regressor_positions(MACRO.id, regressors_w_act);
                X_d_sel = X_d(:,x_positions); % Selected exogenous regressors
                lags = 'manual';
                [Yhat, P_ic] = ARDL_new(lags, direct, IC, hor, 1, P_custom_ARDL, Y_g, Y_d, X_d_sel);
                results.(ETM_prices.id{y}).ARDL_p_w_act.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDL_p_w_act.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDL_p_w_act.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDL_p_w_act.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDL_p_w_act.eps(hor, tt) = Yhat - real_Y.value;

                % Model: AR-DI(p,q) - 1 Factor
                K_f = 1;
                lags = 'manual';
                [Yhat, P_ic, factors_stat] = ARDI_new(MACRO, ETM_prices, lags, direct, IC, hor, Pn, K_f, P_custom_ARDI, Y_g, Y_d, X_d, y);
                results.(ETM_prices.id{y}).ARDI_p_1F.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDI_p_1F.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDI_p_1F.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDI_p_1F.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDI_p_1F.eps(hor, tt) = Yhat - real_Y.value;
                if hor == 12
                    results.(ETM_prices.id{y}).ARDI_p_1F = store_factor_stat_slice(results.(ETM_prices.id{y}).ARDI_p_1F, factors_stat, tt);
                elseif tt == Out_s - hor + 1 && hor == 1
                    results.(ETM_prices.id{y}).ARDI_p_1F.factors_last_tt = factors_stat;
                end

                % Model: AR-DI(AIC) - 1 Factor
                K_f = 1;
                lags = 'i_criteria';
                [Yhat, P_ic, factors_stat] = ARDI_new(MACRO, ETM_prices, lags, direct, IC, hor, Pn, K_f, P_custom_ARDI, Y_g, Y_d, X_d, y);
                results.(ETM_prices.id{y}).ARDI_IC_1F.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDI_IC_1F.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDI_IC_1F.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDI_IC_1F.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDI_IC_1F.eps(hor, tt) = Yhat - real_Y.value;
                if hor == 12
                    results.(ETM_prices.id{y}).ARDI_IC_1F = store_factor_stat_slice(results.(ETM_prices.id{y}).ARDI_IC_1F, factors_stat, tt);
                elseif tt == Out_s - hor + 1 && hor == 1
                    results.(ETM_prices.id{y}).ARDI_IC_1F.factors_last_tt = factors_stat;
                end

                % Model: AR-DI(p,q) - 2 Factors
                K_f = 2;
                lags = 'manual';
                [Yhat, P_ic, factors_stat] = ARDI_new(MACRO, ETM_prices, lags, direct, IC, hor, Pn, K_f, P_custom_ARDI, Y_g, Y_d, X_d, y);
                results.(ETM_prices.id{y}).ARDI_p_2F.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDI_p_2F.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDI_p_2F.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDI_p_2F.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDI_p_2F.eps(hor, tt) = Yhat - real_Y.value;
                if tt == Out_s - hor + 1 && hor == 1
                    results.(ETM_prices.id{y}).ARDI_p_2F.factors = factors_stat;

                    n_fac_ardi = size(factors_stat.factors, 1);
                    n_xd_ardi  = size(X_d, 1);
                    n_cm_ardi  = min(n_fac_ardi, n_xd_ardi);
                    for ff=1:2
                        for regr = 1:size(X_d,2)
                            mdl = fitlm(X_d(end-n_cm_ardi+1:end,regr), factors_stat.factors(end-n_cm_ardi+1:end,ff));
                            R2 = mdl.Rsquared.Ordinary;
                            results.factors_ARDI.models = MACRO.id;
                            results.factors_ARDI.R2(ff,regr) = R2;
                        end
                    end
                end

                % Model: AR-DI(AIC) - 2 Factors
                K_f = 2;
                lags = 'i_criteria';
                [Yhat, P_ic, factors] = ARDI_new(MACRO, ETM_prices, lags, direct, IC, hor, Pn, K_f, P_custom_ARDI, Y_g, Y_d, X_d, y);
                results.(ETM_prices.id{y}).ARDI_IC_2F.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).ARDI_IC_2F.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).ARDI_IC_2F.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).ARDI_IC_2F.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).ARDI_IC_2F.eps(hor, tt) = Yhat - real_Y.value;
                if tt == Out_s - hor + 1 && hor == 1
                    results.(ETM_prices.id{y}).ARDI_IC_2F.factors = factors;
                end

                % Model: VAR(p) - Metal Specific
                if strcmp(ETM_prices.id{y}, 'Copper')
                    relevant_variables = {'A31SNO'};
                elseif strcmp(ETM_prices.id{y}, 'Aluminum')
                    relevant_variables = {'A31SNO'};
                elseif strcmp(ETM_prices.id{y}, 'Nickel')
                    relevant_variables = {'A31SNO'};
                elseif strcmp(ETM_prices.id{y}, 'Zinc')
                    relevant_variables = {'A31SNO'};
                end
                ETM_volume = [ETM_prices.id{y} '_Stock'];
                regressors_var_temp = [ETM_prices.id{y}, ETM_volume, relevant_variables];
                [regressors_var_temp, x_positions] = available_regressor_positions(MACRO.id, regressors_var_temp);
                Y_g_sel = Y_g_var(:,x_positions); % Selected 
                X_d_sel = X_d(:,x_positions); % Selected 
                lags = 'manual';
                [Yhat_var, P_ic] = VAR_new(lags, direct, IC, hor, 1, P_custom_VAR, Y_g_sel, X_d_sel);
                pos_yhat_target = find(strcmp(regressors_var_temp, ETM_prices.id{y}));
                Yhat = Yhat_var(pos_yhat_target);
                results.(ETM_prices.id{y}).VAR_p_specific.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).VAR_p_specific.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).VAR_p_specific.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).VAR_p_specific.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).VAR_p_specific.eps(hor, tt) = Yhat - real_Y.value;

                % Model: FAVAR(p) - 1 Factor (Specific)
                K_f = 1;
                if strcmp(ETM_prices.id{y}, 'Copper')
                    relevant_variables = {'A31SNO'};
                elseif strcmp(ETM_prices.id{y}, 'Aluminum')
                    relevant_variables = {'A31SNO'};
                elseif strcmp(ETM_prices.id{y}, 'Nickel')
                    relevant_variables = {'A31SNO'};
                elseif strcmp(ETM_prices.id{y}, 'Zinc')
                    relevant_variables = {'A31SNO'};
                end
                ETM_volume = [ETM_prices.id{y} '_Stock'];
                regressors_var_temp = [ETM_prices.id{y}, ETM_volume, relevant_variables];
                [regressors_var_temp, x_positions] = available_regressor_positions(MACRO.id, regressors_var_temp);
                Y_g_sel = Y_g_var(:,x_positions); % Selected 
                X_d_sel = X_d(:,x_positions); % Selected 
                lags = 'manual';
                [Yhat_var, P_ic, factors, factors_stat] = FAVAR_new(MACRO, lags, direct, IC, hor, Pn, K_f, P_custom_VAR,  Y_g_sel, Y_g_var, X_d_sel, X_d, y, regressors_var_temp);
                pos_yhat_target = find(strcmp(regressors_var_temp, ETM_prices.id{y}));
                Yhat = Yhat_var(pos_yhat_target);
                results.(ETM_prices.id{y}).FAVAR_specific_p_1F.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).FAVAR_specific_p_1F.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).FAVAR_specific_p_1F.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).FAVAR_specific_p_1F.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).FAVAR_specific_p_1F.eps(hor, tt) = Yhat - real_Y.value;

                if hor == 12
                    results.(ETM_prices.id{y}).FAVAR_specific_p_1F = store_factor_stat_slice(results.(ETM_prices.id{y}).FAVAR_specific_p_1F, factors_stat, tt);
                elseif tt == Out_s - hor + 1 && hor == 1
                    results.(ETM_prices.id{y}).FAVAR_specific_p_1F.factors_last_tt = factors_stat;
                end

                % Model: FAVAR(p) - 2 Factors (Specific)
                K_f = 2;
                if strcmp(ETM_prices.id{y}, 'Copper')
                    relevant_variables = {'A31SNO'};
                elseif strcmp(ETM_prices.id{y}, 'Aluminum')
                    relevant_variables = {'A31SNO'};
                elseif strcmp(ETM_prices.id{y}, 'Nickel')
                    relevant_variables = {'A31SNO'};
                elseif strcmp(ETM_prices.id{y}, 'Zinc')
                    relevant_variables = {'A31SNO'};
                end
                ETM_volume = [ETM_prices.id{y} '_Stock'];
                regressors_var_temp = [ETM_prices.id{y}, ETM_volume, relevant_variables];
                [regressors_var_temp, x_positions] = available_regressor_positions(MACRO.id, regressors_var_temp);
                Y_g_sel = Y_g_var(:,x_positions); % Selected 
                X_d_sel = X_d(:,x_positions); % Selected 
                lags = 'manual';
                [Yhat_var, P_ic, factors, factors_stat] = FAVAR_new(MACRO, lags, direct, IC, hor, 4, K_f, P_custom_VAR,  Y_g_sel, Y_g_var, X_d_sel, X_d, y, regressors_var_temp);
                pos_yhat_target = find(strcmp(regressors_var_temp, ETM_prices.id{y}));
                Yhat = Yhat_var(pos_yhat_target);
                results.(ETM_prices.id{y}).FAVAR_specific_p_2F.parameters{hor, tt} = P_ic;
                results.(ETM_prices.id{y}).FAVAR_specific_p_2F.y_hat(hor, tt) = Yhat;
                results.(ETM_prices.id{y}).FAVAR_specific_p_2F.y_obs(hor,tt) = real_Y.value;
                results.(ETM_prices.id{y}).FAVAR_specific_p_2F.dates(hor,tt) = real_Y.date;
                results.(ETM_prices.id{y}).FAVAR_specific_p_2F.eps(hor, tt) = Yhat - real_Y.value;
                if tt == Out_s - hor + 1 && hor == 1
                    results.(ETM_prices.id{y}).FAVAR_specific_p_2F.factors = factors;

                    n_fac_favar = size(factors, 1);
                    n_xd_favar  = size(X_d, 1);
                    n_cm_favar  = min(n_fac_favar, n_xd_favar);
                    for ff=1:2
                        for regr = 1:size(X_d,2)
                            mdl = fitlm(X_d(end-n_cm_favar+1:end,regr), factors(end-n_cm_favar+1:end,ff));
                            R2 = mdl.Rsquared.Ordinary;
                            results.factors_FAVAR.models = MACRO.id;
                            results.factors_FAVAR.R2(ff,regr) = R2;
                        end
                    end
                end 
            end
        end

        waitbar(hor/Hsize, hxx, sprintf('Forecasting: %s %2.2f%%', ETM_prices.id{y}, (hor/Hsize)*100));
        completed_forecast_horizon_tasks = completed_forecast_horizon_tasks + 1;
        forecast_horizon_percentage = 100 * completed_forecast_horizon_tasks / total_forecast_horizon_tasks;
        fprintf('Forecast horizons completed: %.1f%% (%d out of %d)\n', forecast_horizon_percentage, completed_forecast_horizon_tasks, total_forecast_horizon_tasks);
    end  

    close(hxx)
waitbar(y/size(ETM_data,3),hx,sprintf('Forecasting ETMs prices: %2.2f',(y/size(ETM_data,3))*100));
end
close(hx)

results = mask_results_after_end_date(results, ETM_prices.id, end_date);

if real_time == 1 && Hsize >= 12 && Out_s >= 12

%% Factors Contribution over time - ARDI

plot_ardi_group_contributions(results, ETM_prices.id, folder_fig);

%% Single Regressor contribution to Factor - ARDI

ETM_prices_id = ETM_prices.id;

for ETM_index = 1:4

regressors_name = results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.id;
position_etm = find(strcmp(regressors_name,ETM_prices.id{ETM_index}));
regressors_name(:,position_etm) = [];
K = size(regressors_name,2);

for F = 1:2
st_data = results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.st_data; 
loadings = results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.loadings; loadings = squeeze(loadings(:,F,:));

gloadings = NaN(size(st_data,2),Out_s - 12 + 1);
for jj = 1:Out_s - 12 + 1
    for i = 1:size(st_data,2)
        gloadings(i,jj) = st_data(end,i,jj)*loadings(i,jj);
    end
end

mavg = 3;
y1 = movmean(gloadings',mavg,1);
F_smoothed = movmean(squeeze(results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.factors(end,F,:)),mavg,1);

time = results.(ETM_prices_id{ETM_index}).ARDI_p_1F.dates(12, 1:Out_s-12+1);
time_last_obs = time - calmonths(12);

fig_print = figure;
tiledlayout(1,1,"TileSpacing","tight","Padding","compact");
ax = nexttile;
names = regressors_name(:);

colororder(ax, lines(K));

bb = bar(ax, time_last_obs, y1, 'stacked', 'EdgeColor', 'none');
hold on;

plot(ax, time_last_obs, F_smoothed(:,1), 'LineWidth', 2, 'Color', 'k');

lg = legend(ax, bb, names, ...
    'Orientation', 'horizontal', ...
    'Location', 'southoutside', ...
    'NumColumns', ceil(K/3));
lg.FontSize = 8;
lg.Box = 'off';

grid(ax, 'on');
box(ax, 'off');
grid on

% Print Options
figdir = fullfile(pwd, 'Figures');
if ~exist(figdir, 'dir')
    mkdir(figdir);
end

variable = ETM.id{ETM_index};
factor_number = num2str(F);
filenameBase = ['single_ARDI_' variable factor_number];

pdfPath = fullfile(figdir, [filenameBase '.pdf']);
pngPath = fullfile(figdir, [filenameBase '.png']);

exportgraphics(fig_print, pdfPath, 'ContentType', 'vector');
exportgraphics(fig_print, pngPath, 'Resolution', 600);

end
end

%% Factors Contribution over time - FAVAR

plot_favar_group_contributions(results, ETM_prices.id, folder_fig);

%% Single Regressor contribution to Factor - FAVAR

ETM_prices_id = ETM_prices.id;

for ETM_index = 1:4

regressors_name = results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.id;
position_etm = find(strcmp(regressors_name,ETM_prices.id{ETM_index}));
regressors_name(:,position_etm) = [];
K = size(regressors_name,2);

for F = 1:2
st_data = results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.st_data; 
loadings = results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.loadings; loadings = squeeze(loadings(:,F,:));

gloadings = NaN(size(st_data,2),Out_s - 12 + 1);
for jj = 1:Out_s - 12 + 1
    for i = 1:size(st_data,2)
        gloadings(i,jj) = st_data(end,i,jj)*loadings(i,jj);
    end
end

mavg = 3;
y1 = movmean(gloadings',mavg,1);
F_smoothed = movmean(squeeze(results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.factors(end,F,:)),mavg,1);

time = results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.dates(12, 1:Out_s-12+1);
time_last_obs = time - calmonths(12);

fig_print = figure;
tiledlayout(1,1,"TileSpacing","tight","Padding","compact");
ax = nexttile;
names = regressors_name(:);

colororder(ax, lines(K));

bb = bar(ax, time_last_obs, y1, 'stacked', 'EdgeColor', 'none');
hold on;

plot(ax, time_last_obs, F_smoothed(:,1), 'LineWidth', 2, 'Color', 'k');

lg = legend(ax, bb, names, ...
    'Orientation', 'horizontal', ...
    'Location', 'southoutside', ...
    'NumColumns', ceil(K/3));
lg.FontSize = 8;
lg.Box = 'off';

grid(ax, 'on');
box(ax, 'off');
grid on

% Print Options
figdir = fullfile(pwd, 'Figures');
if ~exist(figdir, 'dir')
    mkdir(figdir);
end

variable = ETM.id{ETM_index}; 
factor_number = num2str(F);
filenameBase = ['single_FAVAR_' variable factor_number];

pdfPath = fullfile(figdir, [filenameBase '.pdf']);
pngPath = fullfile(figdir, [filenameBase '.png']);

exportgraphics(fig_print, pdfPath, 'ContentType', 'vector');
exportgraphics(fig_print, pngPath, 'Resolution', 600); 

end
end

end

%% Data Level 

for yyy = 1:size(ETM_data,3)

    Y_temp = squeeze(ETM_data(:,:,yyy));

    pos_1st_obs = find(~all(isnan(Y_temp), 2), 1);
    pos_1st_vin = find(~all(isnan(Y_temp), 1), 1);

    vin_1 = Y_temp(:,pos_1st_vin); vin_1_c = vin_1(~any(isnan(vin_1), 2), :);
    InSize = size(vin_1_c,1);

    max_level_periods = min(Out_s, size(Y_temp, 2) - pos_1st_vin + 1);
    for ttt = 1:max(max_level_periods, 0)

        level_col = pos_1st_vin + ttt - 1;
        lastx_idx = pos_1st_obs - 1 + InSize + ttt - 1;

        if level_col > size(Y_temp, 2) || lastx_idx > size(Y_temp, 1) || lastx_idx <= 1
            continue
        end

        max_h_level = min([Hsize, Out_s - ttt + 1, size(Y_temp, 1) - lastx_idx]);
        if max_h_level < 1
            continue
        end

        lastx =   Y_temp(lastx_idx, level_col);
        lastx_1 = Y_temp(lastx_idx - 1, level_col);

        % [DIAG] Print lastx for first metal, first OOS period
        if yyy == 1 && ttt == 1
            fprintf('[DIAG-lastx] yyy=1 ttt=1: lastx=%.4f | lastx_idx=%d | level_col=%d | real_time=%d\n', lastx, lastx_idx, level_col, real_time);
        end
        % [/DIAG]

        if raw_transformations(yyy) == 1

            error('missing code')

        elseif raw_transformations(yyy) == 3

            for hhh = 1:max_h_level
                        ETM_lev_fore.futures.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = results.(ETM_prices.id{yyy}).futures.y_hat(hhh,ttt);
                        ETM_lev_fore.p_forecasts.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = results.(ETM_prices.id{yyy}).p_forecasts.y_hat(hhh,ttt);
                        ETM_lev_fore.AR_p.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).AR_p.y_hat(hhh,ttt));
                        ETM_lev_fore.AR_IC.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).AR_IC.y_hat(hhh,ttt));
                        ETM_lev_fore.RW.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).RW.y_hat(hhh,ttt));
                        for tree_model = 1:numel(tree_model_names)
                            model_name = tree_model_names{tree_model};
                            ETM_lev_fore.(model_name).data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).(model_name).y_hat(hhh,ttt));
                        end
                        ETM_lev_fore.ARDI_p_1F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_p_1F.y_hat(hhh,ttt));
                        ETM_lev_fore.ARDI_IC_1F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_IC_1F.y_hat(hhh,ttt));
                        ETM_lev_fore.ARDI_p_2F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_p_2F.y_hat(hhh,ttt));
                        ETM_lev_fore.ARDI_IC_2F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_IC_2F.y_hat(hhh,ttt));
                        for exogenous_predictor = 1:size(regressors,2)
                            model_name = ['ARDL_p_' regressors{exogenous_predictor}];
                            ETM_lev_fore.(model_name).data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).(model_name).y_hat(hhh,ttt));
                            model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
                            ETM_lev_fore.(model_name).data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).(model_name).y_hat(hhh,ttt));
                        end
                        ETM_lev_fore.ARDL_p_real_activity.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_real_activity.y_hat(hhh,ttt));
                        ETM_lev_fore.ARDL_p_cu.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_cu.y_hat(hhh,ttt));
                        ETM_lev_fore.ARDL_p_et.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_et.y_hat(hhh,ttt));
                        ETM_lev_fore.ARDL_p_ex_rates.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_ex_rates.y_hat(hhh,ttt));
                        ETM_lev_fore.ARDL_p_etm.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_etm.y_hat(hhh,ttt));
                        ETM_lev_fore.ARDL_p_inventories.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_inventories.y_hat(hhh,ttt));
                        ETM_lev_fore.ARDL_p_w_act.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_w_act.y_hat(hhh,ttt));

                        ETM_lev_fore.VAR_p_specific.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).VAR_p_specific.y_hat(hhh,ttt));
                        ETM_lev_fore.FAVAR_specific_p_1F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).FAVAR_specific_p_1F.y_hat(hhh,ttt));
                        ETM_lev_fore.FAVAR_specific_p_2F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).FAVAR_specific_p_2F.y_hat(hhh,ttt));
               
                        ETM_lev_fore.futures.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).futures.y_obs(hhh,ttt));                        
                        ETM_lev_fore.p_forecasts.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).p_forecasts.y_obs(hhh,ttt));
                        ETM_lev_fore.AR_p.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).AR_p.y_obs(hhh,ttt));
                        ETM_lev_fore.AR_IC.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).AR_IC.y_obs(hhh,ttt));
                        ETM_lev_fore.RW.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).RW.y_obs(hhh,ttt));
                        for tree_model = 1:numel(tree_model_names)
                            model_name = tree_model_names{tree_model};
                            ETM_lev_fore.(model_name).data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).(model_name).y_obs(hhh,ttt));
                        end
                        ETM_lev_fore.ARDI_p_1F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_p_1F.y_obs(hhh,ttt));
                        ETM_lev_fore.ARDI_IC_1F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_IC_1F.y_obs(hhh,ttt));
                        ETM_lev_fore.ARDI_p_2F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_p_2F.y_obs(hhh,ttt));
                        ETM_lev_fore.ARDI_IC_2F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_IC_2F.y_obs(hhh,ttt));
                        for exogenous_predictor = 1:size(regressors,2)
                            model_name = ['ARDL_p_' regressors{exogenous_predictor}];
                            ETM_lev_fore.(model_name).data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).(model_name).y_obs(hhh,ttt));
                            model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
                            ETM_lev_fore.(model_name).data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).(model_name).y_obs(hhh,ttt));
                        end
                        ETM_lev_fore.ARDL_p_real_activity.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_real_activity.y_obs(hhh,ttt));
                        ETM_lev_fore.ARDL_p_cu.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_cu.y_obs(hhh,ttt));
                        ETM_lev_fore.ARDL_p_inventories.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_inventories.y_obs(hhh,ttt));
                        ETM_lev_fore.ARDL_p_w_act.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_w_act.y_obs(hhh,ttt));

                        ETM_lev_fore.ARDL_p_ex_rates.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_ex_rates.y_obs(hhh,ttt));
                        ETM_lev_fore.ARDL_p_etm.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_etm.y_obs(hhh,ttt));
                        ETM_lev_fore.ARDL_p_et.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_et.y_obs(hhh,ttt));

                        ETM_lev_fore.VAR_p_specific.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).VAR_p_specific.y_obs(hhh,ttt));
                        ETM_lev_fore.FAVAR_specific_p_1F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).FAVAR_specific_p_1F.y_obs(hhh,ttt));
                        ETM_lev_fore.FAVAR_specific_p_2F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).FAVAR_specific_p_2F.y_obs(hhh,ttt));

                        ETM_lev_fore.futures.eps(hhh, ttt, yyy) = ETM_lev_fore.futures.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.futures.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        ETM_lev_fore.p_forecasts.eps(hhh, ttt, yyy) = ETM_lev_fore.p_forecasts.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.p_forecasts.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        ETM_lev_fore.AR_p.eps(hhh, ttt, yyy) = ETM_lev_fore.AR_p.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.AR_p.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        ETM_lev_fore.AR_IC.eps(hhh, ttt, yyy) = ETM_lev_fore.AR_IC.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.AR_IC.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        ETM_lev_fore.RW.eps(hhh, ttt, yyy) = ETM_lev_fore.RW.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.RW.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        for tree_model = 1:numel(tree_model_names)
                            model_name = tree_model_names{tree_model};
                            ETM_lev_fore.(model_name).eps(hhh, ttt, yyy) = ETM_lev_fore.(model_name).data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.(model_name).data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        end
                        ETM_lev_fore.ARDI_p_1F.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDI_p_1F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDI_p_1F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        ETM_lev_fore.ARDI_IC_1F.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDI_IC_1F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDI_IC_1F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        ETM_lev_fore.ARDI_p_2F.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDI_p_2F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDI_p_2F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        ETM_lev_fore.ARDI_IC_2F.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDI_IC_2F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDI_IC_2F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        for exogenous_predictor = 1:size(regressors,2)
                            model_name = ['ARDL_p_' regressors{exogenous_predictor}];
                            ETM_lev_fore.(model_name).eps(hhh, ttt, yyy) = ETM_lev_fore.(model_name).data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.(model_name).data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                            model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
                            ETM_lev_fore.(model_name).eps(hhh, ttt, yyy) = ETM_lev_fore.(model_name).data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.(model_name).data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        end
                        ETM_lev_fore.ARDL_p_real_activity.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDL_p_real_activity.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDL_p_real_activity.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        ETM_lev_fore.ARDL_p_ex_rates.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDL_p_ex_rates.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDL_p_ex_rates.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        ETM_lev_fore.ARDL_p_etm.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDL_p_etm.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDL_p_etm.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        ETM_lev_fore.ARDL_p_cu.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDL_p_cu.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDL_p_cu.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        ETM_lev_fore.ARDL_p_et.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDL_p_et.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDL_p_et.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        ETM_lev_fore.ARDL_p_inventories.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDL_p_inventories.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDL_p_inventories.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        ETM_lev_fore.ARDL_p_w_act.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDL_p_w_act.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDL_p_w_act.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);

                        ETM_lev_fore.VAR_p_specific.eps(hhh, ttt, yyy) = ETM_lev_fore.VAR_p_specific.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.VAR_p_specific.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        ETM_lev_fore.FAVAR_specific_p_1F.eps(hhh, ttt, yyy) = ETM_lev_fore.FAVAR_specific_p_1F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.FAVAR_specific_p_1F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        ETM_lev_fore.FAVAR_specific_p_2F.eps(hhh, ttt, yyy) = ETM_lev_fore.FAVAR_specific_p_2F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.FAVAR_specific_p_2F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);

                        % Forecast Level - Compact
                        results.level.futures.data(hhh, ttt,yyy) = results.(ETM_prices.id{yyy}).futures.y_hat(hhh,ttt);
                        results.level.p_forecasts.data(hhh, ttt,yyy) = results.(ETM_prices.id{yyy}).p_forecasts.y_hat(hhh,ttt);
                        results.level.AR_p.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).AR_p.y_hat(hhh,ttt));
                        results.level.AR_IC.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).AR_IC.y_hat(hhh,ttt));
                        results.level.RW.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).RW.y_hat(hhh,ttt));
                        for tree_model = 1:numel(tree_model_names)
                            model_name = tree_model_names{tree_model};
                            results.level.(model_name).data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).(model_name).y_hat(hhh,ttt));
                        end
                        results.level.ARDI_p_1F.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_p_1F.y_hat(hhh,ttt));
                        results.level.ARDI_IC_1F.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_IC_1F.y_hat(hhh,ttt));
                        results.level.ARDI_p_2F.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_p_2F.y_hat(hhh,ttt));
                        results.level.ARDI_IC_2F.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_IC_2F.y_hat(hhh,ttt));
                        for exogenous_predictor = 1:size(regressors,2)
                            model_name = ['ARDL_p_' regressors{exogenous_predictor}];
                            results.level.(model_name).data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).(model_name).y_hat(hhh,ttt));
                            model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
                            results.level.(model_name).data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).(model_name).y_hat(hhh,ttt));
                        end
                        results.level.ARDL_p_real_activity.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_real_activity.y_hat(hhh,ttt));
                        results.level.ARDL_p_ex_rates.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_ex_rates.y_hat(hhh,ttt));
                        results.level.ARDL_p_etm.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_etm.y_hat(hhh,ttt));
                        results.level.ARDL_p_et.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_et.y_hat(hhh,ttt));
                        results.level.ARDL_p_cu.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_cu.y_hat(hhh,ttt));
                        results.level.ARDL_p_inventories.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_inventories.y_hat(hhh,ttt));
                        results.level.ARDL_p_w_act.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_w_act.y_hat(hhh,ttt));

                        results.level.VAR_p_specific.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).VAR_p_specific.y_hat(hhh,ttt));
                        results.level.FAVAR_specific_p_1F.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).FAVAR_specific_p_1F.y_hat(hhh,ttt));
                        results.level.FAVAR_specific_p_2F.data(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).FAVAR_specific_p_2F.y_hat(hhh,ttt));

                        % Observed Level - Compact
                        results.level.futures.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).futures.y_obs(hhh,ttt));
                        results.level.p_forecasts.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).p_forecasts.y_obs(hhh,ttt));
                        results.level.AR_p.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).AR_p.y_obs(hhh,ttt));
                        results.level.AR_IC.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).AR_IC.y_obs(hhh,ttt));
                        results.level.RW.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).RW.y_obs(hhh,ttt));
                        for tree_model = 1:numel(tree_model_names)
                            model_name = tree_model_names{tree_model};
                            results.level.(model_name).data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).(model_name).y_obs(hhh,ttt));
                        end
                        results.level.ARDI_p_1F.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_p_1F.y_obs(hhh,ttt));
                        results.level.ARDI_IC_1F.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_IC_1F.y_obs(hhh,ttt));
                        results.level.ARDI_p_2F.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_p_2F.y_obs(hhh,ttt));
                        results.level.ARDI_IC_2F.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDI_IC_2F.y_obs(hhh,ttt));
                        for exogenous_predictor = 1:size(regressors,2)
                            model_name = ['ARDL_p_' regressors{exogenous_predictor}];
                            results.level.(model_name).data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).(model_name).y_obs(hhh,ttt));
                            model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
                            results.level.(model_name).data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).(model_name).y_obs(hhh,ttt));
                        end
                        results.level.ARDL_p_real_activity.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_real_activity.y_obs(hhh,ttt));
                        results.level.ARDL_p_ex_rates.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_ex_rates.y_obs(hhh,ttt));
                        results.level.ARDL_p_etm.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_etm.y_obs(hhh,ttt));
                        results.level.ARDL_p_et.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_et.y_obs(hhh,ttt));
                        results.level.ARDL_p_inventories.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_inventories.y_obs(hhh,ttt));
                        results.level.ARDL_p_cu.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_cu.y_obs(hhh,ttt));
                        results.level.ARDL_p_w_act.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).ARDL_p_w_act.y_obs(hhh,ttt));

                        results.level.VAR_p_specific.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).VAR_p_specific.y_obs(hhh,ttt));
                        results.level.FAVAR_specific_p_1F.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).FAVAR_specific_p_1F.y_obs(hhh,ttt));
                        results.level.FAVAR_specific_p_2F.data_real(hhh, ttt,yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).FAVAR_specific_p_2F.y_obs(hhh,ttt));

                        % Error Level - Compact
                        results.level.futures.eps(hhh, ttt, yyy) = ETM_lev_fore.futures.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.futures.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        results.level.p_forecasts.eps(hhh, ttt, yyy) = ETM_lev_fore.p_forecasts.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.p_forecasts.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        results.level.AR_p.eps(hhh, ttt, yyy) = ETM_lev_fore.AR_p.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.AR_p.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        results.level.AR_IC.eps(hhh, ttt, yyy) = ETM_lev_fore.AR_IC.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.AR_IC.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        results.level.RW.eps(hhh, ttt, yyy) = ETM_lev_fore.RW.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.RW.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        for tree_model = 1:numel(tree_model_names)
                            model_name = tree_model_names{tree_model};
                            results.level.(model_name).eps(hhh, ttt, yyy) = ETM_lev_fore.(model_name).data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.(model_name).data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        end
                        results.level.ARDI_p_1F.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDI_p_1F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDI_p_1F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        results.level.ARDI_IC_1F.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDI_IC_1F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDI_IC_1F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        results.level.ARDI_p_2F.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDI_p_2F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDI_p_2F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        results.level.ARDI_IC_2F.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDI_IC_2F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDI_IC_2F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        for exogenous_predictor = 1:size(regressors,2)
                            model_name = ['ARDL_p_' regressors{exogenous_predictor}];
                            results.level.(model_name).eps(hhh, ttt, yyy) = ETM_lev_fore.(model_name).data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.(model_name).data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                            model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
                            results.level.(model_name).eps(hhh, ttt, yyy) = ETM_lev_fore.(model_name).data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.(model_name).data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        end
                        results.level.ARDL_p_real_activity.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDL_p_real_activity.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDL_p_real_activity.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        results.level.ARDL_p_ex_rates.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDL_p_ex_rates.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDL_p_ex_rates.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        results.level.ARDL_p_etm.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDL_p_etm.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDL_p_etm.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        results.level.ARDL_p_et.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDL_p_et.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDL_p_et.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        results.level.ARDL_p_inventories.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDL_p_inventories.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDL_p_inventories.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        results.level.ARDL_p_cu.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDL_p_cu.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDL_p_cu.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        results.level.ARDL_p_w_act.eps(hhh, ttt, yyy) = ETM_lev_fore.ARDL_p_w_act.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.ARDL_p_w_act.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);

                        results.level.VAR_p_specific.eps(hhh, ttt, yyy) = ETM_lev_fore.VAR_p_specific.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.VAR_p_specific.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        results.level.FAVAR_specific_p_1F.eps(hhh, ttt, yyy) = ETM_lev_fore.FAVAR_specific_p_1F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.FAVAR_specific_p_1F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
                        results.level.FAVAR_specific_p_2F.eps(hhh, ttt, yyy) = ETM_lev_fore.FAVAR_specific_p_2F.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy) - ETM_lev_fore.FAVAR_specific_p_2F.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1,yyy);
            end

        elseif raw_transformations(yyy) == 5
            error('missing code')
        end
    end
end

%% 

nb_var = size(ETM_data,3);

for y = 1:nb_var
    
    for hor = 1:Hsize

        eval_len = Out_s - hor + 1;
        fixed_model_names = [{'futures', 'p_forecasts', 'AR_p', 'AR_IC', 'RW'}, tree_model_names, ...
            {'ARDI_p_1F', 'ARDI_IC_1F', 'ARDI_p_2F', 'ARDI_IC_2F'}];
        for model_idx = 1:numel(fixed_model_names)
            model_name = fixed_model_names{model_idx};
            results.(ETM_prices.id{y}).(model_name).eps_2(hor, 1:eval_len) = squared_forecast_error_row(ETM_lev_fore.(model_name).eps, hor, y, eval_len);
        end

        for exogenous_predictor = 1:size(regressors,2)
            model_name = ['ARDL_p_' regressors{exogenous_predictor}];
            results.(ETM_prices.id{y}).(model_name).eps_2(hor, 1:eval_len) = squared_forecast_error_row(ETM_lev_fore.(model_name).eps, hor, y, eval_len);
            model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
            results.(ETM_prices.id{y}).(model_name).eps_2(hor, 1:eval_len) = squared_forecast_error_row(ETM_lev_fore.(model_name).eps, hor, y, eval_len);
        end

        grouped_model_names = {'ARDL_p_real_activity', 'ARDL_p_ex_rates', 'ARDL_p_etm', 'ARDL_p_et', ...
            'ARDL_p_inventories', 'ARDL_p_cu', 'ARDL_p_w_act', 'VAR_p_specific', 'FAVAR_specific_p_1F', 'FAVAR_specific_p_2F'};
        for model_idx = 1:numel(grouped_model_names)
            model_name = grouped_model_names{model_idx};
            results.(ETM_prices.id{y}).(model_name).eps_2(hor, 1:eval_len) = squared_forecast_error_row(ETM_lev_fore.(model_name).eps, hor, y, eval_len);
        end

        % DM Test
        nested_flag = 0;
        results.(ETM_prices.id{y}).p_forecasts.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).p_forecasts.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).futures.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).futures.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).AR_p.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).AR_p.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).AR_IC.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).AR_IC.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).RW.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        for tree_model = 1:numel(tree_model_names)
            model_name = tree_model_names{tree_model};
            results.(ETM_prices.id{y}).(model_name).DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).(model_name).eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        end
        results.(ETM_prices.id{y}).ARDI_p_1F.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).ARDI_p_1F.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).ARDI_IC_1F.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).ARDI_IC_1F.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).ARDI_p_2F.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).ARDI_p_2F.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).ARDI_IC_2F.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).ARDI_IC_2F.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        for exogenous_predictor = 1:size(regressors,2)
            model_name = ['ARDL_p_' regressors{exogenous_predictor}];
            results.(ETM_prices.id{y}).(model_name).DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).(model_name).eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
            model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
            results.(ETM_prices.id{y}).(model_name).DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).(model_name).eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        end
        results.(ETM_prices.id{y}).ARDL_p_real_activity.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).ARDL_p_real_activity.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).ARDL_p_ex_rates.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).ARDL_p_ex_rates.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).ARDL_p_etm.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).ARDL_p_etm.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).ARDL_p_et.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).ARDL_p_et.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).ARDL_p_cu.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).ARDL_p_cu.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).ARDL_p_inventories.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).ARDL_p_inventories.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).ARDL_p_w_act.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).ARDL_p_w_act.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);

        results.(ETM_prices.id{y}).VAR_p_specific.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).VAR_p_specific.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).FAVAR_specific_p_1F.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).FAVAR_specific_p_1F.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);
        results.(ETM_prices.id{y}).FAVAR_specific_p_2F.DM_p_value(1,hor) = test_DM(results.(ETM_prices.id{y}).RW.eps_2(hor, 1:end-hor+1)',results.(ETM_prices.id{y}).FAVAR_specific_p_2F.eps_2(hor, 1:end-hor+1)',hor-1,nested_flag, treatment);

        % MSPE level
        vec = ETM_lev_fore.futures.eps(hor,1:end-hor+1,y);
        results.(ETM_prices.id{y}).futures.MSPE_level(1,hor) = mean(vec.^2,2,'omitnan');
        vec = ETM_lev_fore.p_forecasts.eps(hor,1:end-hor+1,y);
        results.(ETM_prices.id{y}).p_forecasts.MSPE_level(1,hor) = mean(vec.^2,2,'omitnan');
        results.(ETM_prices.id{y}).AR_p.MSPE_level(1,hor) = mean(ETM_lev_fore.AR_p.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        results.(ETM_prices.id{y}).AR_IC.MSPE_level(1,hor) = mean(ETM_lev_fore.AR_IC.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        results.(ETM_prices.id{y}).RW.MSPE_level(1,hor) = mean(ETM_lev_fore.RW.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        for tree_model = 1:numel(tree_model_names)
            model_name = tree_model_names{tree_model};
            results.(ETM_prices.id{y}).(model_name).MSPE_level(1,hor) = mean(ETM_lev_fore.(model_name).eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        end
        results.(ETM_prices.id{y}).ARDI_p_1F.MSPE_level(1,hor) = mean(ETM_lev_fore.ARDI_p_1F.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        results.(ETM_prices.id{y}).ARDI_IC_1F.MSPE_level(1,hor) = mean(ETM_lev_fore.ARDI_IC_1F.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        results.(ETM_prices.id{y}).ARDI_p_2F.MSPE_level(1,hor) = mean(ETM_lev_fore.ARDI_p_2F.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        results.(ETM_prices.id{y}).ARDI_IC_2F.MSPE_level(1,hor) = mean(ETM_lev_fore.ARDI_IC_2F.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        for exogenous_predictor = 1:size(regressors,2)
            model_name = ['ARDL_p_' regressors{exogenous_predictor}];
            results.(ETM_prices.id{y}).(model_name).MSPE_level(1,hor) = mean(ETM_lev_fore.(model_name).eps(hor,1:end-hor+1,y).^2,2,'omitnan');
            model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
            results.(ETM_prices.id{y}).(model_name).MSPE_level(1,hor) = mean(ETM_lev_fore.(model_name).eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        end
        results.(ETM_prices.id{y}).ARDL_p_real_activity.MSPE_level(1,hor) = mean(ETM_lev_fore.ARDL_p_real_activity.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        results.(ETM_prices.id{y}).ARDL_p_ex_rates.MSPE_level(1,hor) = mean(ETM_lev_fore.ARDL_p_ex_rates.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        results.(ETM_prices.id{y}).ARDL_p_etm.MSPE_level(1,hor) = mean(ETM_lev_fore.ARDL_p_etm.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        results.(ETM_prices.id{y}).ARDL_p_et.MSPE_level(1,hor) = mean(ETM_lev_fore.ARDL_p_et.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        results.(ETM_prices.id{y}).ARDL_p_cu.MSPE_level(1,hor) = mean(ETM_lev_fore.ARDL_p_cu.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        results.(ETM_prices.id{y}).ARDL_p_inventories.MSPE_level(1,hor) = mean(ETM_lev_fore.ARDL_p_inventories.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        results.(ETM_prices.id{y}).ARDL_p_w_act.MSPE_level(1,hor) = mean(ETM_lev_fore.ARDL_p_w_act.eps(hor,1:end-hor+1,y).^2,2,'omitnan');

        results.(ETM_prices.id{y}).VAR_p_specific.MSPE_level(1,hor) = mean(ETM_lev_fore.VAR_p_specific.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        results.(ETM_prices.id{y}).FAVAR_specific_p_1F.MSPE_level(1,hor) = mean(ETM_lev_fore.FAVAR_specific_p_1F.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        results.(ETM_prices.id{y}).FAVAR_specific_p_2F.MSPE_level(1,hor) = mean(ETM_lev_fore.FAVAR_specific_p_2F.eps(hor,1:end-hor+1,y).^2,2,'omitnan');
        
        % RMSPE level
        results.(ETM_prices.id{y}).futures.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).futures.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).p_forecasts.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).p_forecasts.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).AR_p.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).AR_p.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).AR_IC.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).AR_IC.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).RW.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).RW.MSPE_level(1,hor));
        for tree_model = 1:numel(tree_model_names)
            model_name = tree_model_names{tree_model};
            results.(ETM_prices.id{y}).(model_name).RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).(model_name).MSPE_level(1,hor));
        end
        results.(ETM_prices.id{y}).ARDI_p_1F.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).ARDI_p_1F.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).ARDI_IC_1F.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).ARDI_IC_1F.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).ARDI_p_2F.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).ARDI_p_2F.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).ARDI_IC_2F.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).ARDI_IC_2F.MSPE_level(1,hor));
        for exogenous_predictor = 1:size(regressors,2)
            model_name = ['ARDL_p_' regressors{exogenous_predictor}];
            results.(ETM_prices.id{y}).(model_name).RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).(model_name).MSPE_level(1,hor));
            model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
            results.(ETM_prices.id{y}).(model_name).RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).(model_name).MSPE_level(1,hor));
        end
        results.(ETM_prices.id{y}).ARDL_p_real_activity.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).ARDL_p_real_activity.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).ARDL_p_ex_rates.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).ARDL_p_ex_rates.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).ARDL_p_etm.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).ARDL_p_etm.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).ARDL_p_et.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).ARDL_p_et.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).ARDL_p_cu.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).ARDL_p_cu.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).ARDL_p_inventories.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).ARDL_p_inventories.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).ARDL_p_w_act.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).ARDL_p_w_act.MSPE_level(1,hor));

        results.(ETM_prices.id{y}).VAR_p_specific.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).VAR_p_specific.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).FAVAR_specific_p_1F.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).FAVAR_specific_p_1F.MSPE_level(1,hor));
        results.(ETM_prices.id{y}).FAVAR_specific_p_2F.RMSPE_level(1,hor) = sqrt(results.(ETM_prices.id{y}).FAVAR_specific_p_2F.MSPE_level(1,hor));
    end
end

%% Tables RMSPE - level

% RW Benchmark
results.TABLES_RMSPE_level.futures = nan(Hsize,nb_var);
results.TABLES_RMSPE_level.p_forecasts = nan(Hsize,nb_var);
results.TABLES_RMSPE_level.AR_p = nan(Hsize,nb_var);
results.TABLES_RMSPE_level.AR_IC = nan(Hsize,nb_var);
results.TABLES_RMSPE_level.RW = nan(Hsize,nb_var);
for tree_model = 1:numel(tree_model_names)
    model_name = tree_model_names{tree_model};
    results.TABLES_RMSPE_level.(model_name) = nan(Hsize,nb_var);
end
results.TABLES_RMSPE_level.ARDI_p_1F = nan(Hsize,nb_var);
results.TABLES_RMSPE_level.ARDI_IC_2F = nan(Hsize,nb_var);
results.TABLES_RMSPE_level.ARDI_p_2F = nan(Hsize,nb_var);
results.TABLES_RMSPE_level.ARDI_IC_1F = nan(Hsize,nb_var);
for exogenous_predictor = 1:size(regressors,2)
    model_name = ['ARDL_p_' regressors{exogenous_predictor}];
    results.TABLES_RMSPE_level.(model_name) = nan(Hsize,nb_var);
    model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
    results.TABLES_RMSPE_level.(model_name) = nan(Hsize,nb_var);
end
results.TABLES_RMSPE_level.ARDL_p_real_activity = nan(Hsize,nb_var);
results.TABLES_RMSPE_level.ARDL_p_ex_rates = nan(Hsize,nb_var);
results.TABLES_RMSPE_level.ARDL_p_etm = nan(Hsize,nb_var);
results.TABLES_RMSPE_level.ARDL_p_et = nan(Hsize,nb_var);
results.TABLES_RMSPE_level.ARDL_p_cu = nan(Hsize,nb_var);
results.TABLES_RMSPE_level.ARDL_p_inventories = nan(Hsize,nb_var);
results.TABLES_RMSPE_level.ARDL_p_w_act = nan(Hsize,nb_var);

results.TABLES_RMSPE_level.VAR_p_specific = nan(Hsize,nb_var);

results.TABLES_RMSPE_level.FAVAR_specific_p_1F = nan(Hsize,nb_var);
results.TABLES_RMSPE_level.FAVAR_specific_p_2F = nan(Hsize,nb_var);

for dd = 1:nb_var
    for h=1:Hsize
        results.TABLES_RMSPE_level.futures(h,dd) = results.(ETM_prices.id{dd}).futures.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.p_forecasts(h,dd) = results.(ETM_prices.id{dd}).p_forecasts.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.AR_p(h,dd) = results.(ETM_prices.id{dd}).AR_p.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.AR_IC(h,dd) = results.(ETM_prices.id{dd}).AR_IC.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.RW(h,dd) = results.(ETM_prices.id{dd}).RW.RMSPE_level(1,h);
        for tree_model = 1:numel(tree_model_names)
            model_name = tree_model_names{tree_model};
            results.TABLES_RMSPE_level.(model_name)(h,dd) = results.(ETM_prices.id{dd}).(model_name).RMSPE_level(1,h);
        end
        results.TABLES_RMSPE_level.ARDI_p_1F(h,dd) = results.(ETM_prices.id{dd}).ARDI_p_1F.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.ARDI_IC_1F(h,dd) = results.(ETM_prices.id{dd}).ARDI_IC_1F.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.ARDI_p_2F(h,dd) = results.(ETM_prices.id{dd}).ARDI_p_2F.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.ARDI_IC_2F(h,dd) = results.(ETM_prices.id{dd}).ARDI_IC_2F.RMSPE_level(1,h);
        for exogenous_predictor = 1:size(regressors,2)
            table_name = ['ARDL_p_' regressors{exogenous_predictor}];
            model_name = ['ARDL_p_' regressors{exogenous_predictor}];
            results.TABLES_RMSPE_level.(table_name)(h,dd) = results.(ETM_prices.id{dd}).(model_name).RMSPE_level(1,h);
            table_name = ['ARDL_IC_' regressors{exogenous_predictor}];
            model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
            results.TABLES_RMSPE_level.(table_name)(h,dd) = results.(ETM_prices.id{dd}).(model_name).RMSPE_level(1,h);
        end
        results.TABLES_RMSPE_level.ARDL_p_real_activity(h,dd) = results.(ETM_prices.id{dd}).ARDL_p_real_activity.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.ARDL_p_ex_rates(h,dd) = results.(ETM_prices.id{dd}).ARDL_p_ex_rates.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.ARDL_p_etm(h,dd) = results.(ETM_prices.id{dd}).ARDL_p_etm.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.ARDL_p_et(h,dd) = results.(ETM_prices.id{dd}).ARDL_p_et.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.ARDL_p_cu(h,dd) = results.(ETM_prices.id{dd}).ARDL_p_cu.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.ARDL_p_inventories(h,dd) = results.(ETM_prices.id{dd}).ARDL_p_inventories.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.ARDL_p_w_act(h,dd) = results.(ETM_prices.id{dd}).ARDL_p_w_act.RMSPE_level(1,h);

        results.TABLES_RMSPE_level.VAR_p_specific(h,dd) = results.(ETM_prices.id{dd}).VAR_p_specific.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.FAVAR_specific_p_1F(h,dd) = results.(ETM_prices.id{dd}).FAVAR_specific_p_1F.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.FAVAR_specific_p_2F(h,dd) = results.(ETM_prices.id{dd}).FAVAR_specific_p_2F.RMSPE_level(1,h);
    end
end

%% Tables Ratio - level

% RW Benchmark
results.TABLES_level.futures = nan(Hsize,nb_var);
results.TABLES_level.p_forecasts = nan(Hsize,nb_var);
results.TABLES_level.AR_p = nan(Hsize,nb_var);
results.TABLES_level.AR_IC = nan(Hsize,nb_var);
results.TABLES_level.RW = nan(Hsize,nb_var);
for tree_model = 1:numel(tree_model_names)
    model_name = tree_model_names{tree_model};
    results.TABLES_level.(model_name) = nan(Hsize,nb_var);
end
results.TABLES_level.ARDI_p_1F = nan(Hsize,nb_var);
results.TABLES_level.ARDI_IC_1F = nan(Hsize,nb_var);
results.TABLES_level.ARDI_p_2F = nan(Hsize,nb_var);
results.TABLES_level.ARDI_IC_2F = nan(Hsize,nb_var);
for exogenous_predictor = 1:size(regressors,2)
    model_name = ['ARDL_p_' regressors{exogenous_predictor}];
results.TABLES_level.(model_name) = nan(Hsize,nb_var);
    model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
results.TABLES_level.(model_name) = nan(Hsize,nb_var);
end
results.TABLES_level.ARDL_p_real_activity = nan(Hsize,nb_var);
results.TABLES_level.ARDL_p_ex_rates = nan(Hsize,nb_var);
results.TABLES_level.ARDL_p_etm = nan(Hsize,nb_var);
results.TABLES_level.ARDL_p_et = nan(Hsize,nb_var);
results.TABLES_level.ARDL_p_cu = nan(Hsize,nb_var);
results.TABLES_level.ARDL_p_inventories = nan(Hsize,nb_var);
results.TABLES_level.ARDL_p_w_act = nan(Hsize,nb_var);

results.TABLES_level.VAR_p_specific = nan(Hsize,nb_var);

results.TABLES_level.FAVAR_specific_p_1F = nan(Hsize,nb_var);
results.TABLES_level.FAVAR_specific_p_2F = nan(Hsize,nb_var);

for dd = 1:nb_var
    for h=1:Hsize
        if strcmp("AR",benchmark)==1
            bench = results.(ETM_prices.id{dd}).AR_p.RMSPE_level(1,h);
        elseif strcmp("RW",benchmark)==1
            bench = results.(ETM_prices.id{dd}).RW.RMSPE_level(1,h);
        end
        results.TABLES_level.futures(h,dd) = results.(ETM_prices.id{dd}).futures.RMSPE_level(1,h)/bench;
        results.TABLES_level.p_forecasts(h,dd) = results.(ETM_prices.id{dd}).p_forecasts.RMSPE_level(1,h)/bench;
        results.TABLES_level.AR_p(h,dd) = results.(ETM_prices.id{dd}).AR_p.RMSPE_level(1,h)/bench;
        results.TABLES_level.AR_IC(h,dd) = results.(ETM_prices.id{dd}).AR_IC.RMSPE_level(1,h)/bench;
        results.TABLES_level.RW(h,dd) = results.(ETM_prices.id{dd}).RW.RMSPE_level(1,h)/bench;
        for tree_model = 1:numel(tree_model_names)
            model_name = tree_model_names{tree_model};
            results.TABLES_level.(model_name)(h,dd) = results.(ETM_prices.id{dd}).(model_name).RMSPE_level(1,h)/bench;
        end
        results.TABLES_level.ARDI_p_1F(h,dd) = results.(ETM_prices.id{dd}).ARDI_p_1F.RMSPE_level(1,h)/bench;
        results.TABLES_level.ARDI_IC_1F(h,dd) = results.(ETM_prices.id{dd}).ARDI_IC_1F.RMSPE_level(1,h)/bench;
        results.TABLES_level.ARDI_p_2F(h,dd) = results.(ETM_prices.id{dd}).ARDI_p_2F.RMSPE_level(1,h)/bench;
        results.TABLES_level.ARDI_IC_2F(h,dd) = results.(ETM_prices.id{dd}).ARDI_IC_2F.RMSPE_level(1,h)/bench;
        for exogenous_predictor = 1:size(regressors,2)
            table_name = ['ARDL_p_' regressors{exogenous_predictor}];
            model_name = ['ARDL_p_' regressors{exogenous_predictor}];
            results.TABLES_level.(table_name)(h,dd) = results.(ETM_prices.id{dd}).(model_name).RMSPE_level(1,h)/bench;
            table_name = ['ARDL_IC_' regressors{exogenous_predictor}];
            model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
            results.TABLES_level.(table_name)(h,dd) = results.(ETM_prices.id{dd}).(model_name).RMSPE_level(1,h)/bench;
        end
        results.TABLES_level.ARDL_p_real_activity(h,dd) = results.(ETM_prices.id{dd}).ARDL_p_real_activity.RMSPE_level(1,h)/bench;
        results.TABLES_level.ARDL_p_ex_rates(h,dd) = results.(ETM_prices.id{dd}).ARDL_p_ex_rates.RMSPE_level(1,h)/bench;
        results.TABLES_level.ARDL_p_etm(h,dd) = results.(ETM_prices.id{dd}).ARDL_p_etm.RMSPE_level(1,h)/bench;
        results.TABLES_level.ARDL_p_et(h,dd) = results.(ETM_prices.id{dd}).ARDL_p_et.RMSPE_level(1,h)/bench;
        results.TABLES_level.ARDL_p_cu(h,dd) = results.(ETM_prices.id{dd}).ARDL_p_cu.RMSPE_level(1,h)/bench;
        results.TABLES_level.ARDL_p_inventories(h,dd) = results.(ETM_prices.id{dd}).ARDL_p_inventories.RMSPE_level(1,h)/bench;
        results.TABLES_level.ARDL_p_w_act(h,dd) = results.(ETM_prices.id{dd}).ARDL_p_w_act.RMSPE_level(1,h)/bench;

        results.TABLES_level.VAR_p_specific(h,dd) = results.(ETM_prices.id{dd}).VAR_p_specific.RMSPE_level(1,h)/bench;
 
        results.TABLES_level.FAVAR_specific_p_1F(h,dd) = results.(ETM_prices.id{dd}).FAVAR_specific_p_1F.RMSPE_level(1,h)/bench;
        results.TABLES_level.FAVAR_specific_p_2F(h,dd) = results.(ETM_prices.id{dd}).FAVAR_specific_p_2F.RMSPE_level(1,h)/bench;
    end
end

%% Tables Ratio - Reshaped

for y = 1:length(ETM_prices.id)
results.tables_ratio_long.(ETM_prices.id{y}) = NaN(length(fieldnames(results.TABLES_level)), Hsize);
results.tables_ratio_long_p_value.(ETM_prices.id{y}) = cell(length(fieldnames(results.TABLES_level)), Hsize);

end
modelli = fieldnames(results.TABLES_level);

for y = 1:length(ETM_prices.id)
    for model = 1:length(modelli)
        for horizon = 1:Hsize
            results.tables_ratio_long.(ETM_prices.id{y})(model, horizon) = results.TABLES_level.(modelli{model})(horizon,y);
        end
    end
end

for y = 1:length(ETM_prices.id)
    for model = 1:length(modelli)
        for horizon = 1:Hsize
            ratio = results.TABLES_level.(modelli{model})(horizon,y);
            p_value = results.(ETM_prices.id{y}).(modelli{model}).DM_p_value(1,horizon);
            results.tables_ratio_long.(ETM_prices.id{y})(model, horizon) = results.TABLES_level.(modelli{model})(horizon,y);
            if (p_value >= 0.05 && p_value < 0.1) || (p_value > 0.9 && p_value <= 0.95)
                results.tables_ratio_long_p_value.(ETM_prices.id{y}){model, horizon} = strcat(num2str(ratio), '*');
            elseif (p_value >= 0.01 && p_value < 0.05) || (p_value > 0.95 && p_value <= 0.99)
                results.tables_ratio_long_p_value.(ETM_prices.id{y}){model, horizon} = strcat(num2str(ratio), '**');
            elseif p_value < 0.01 || p_value > 0.99
                results.tables_ratio_long_p_value.(ETM_prices.id{y}){model, horizon} = strcat(num2str(ratio), '***');
            else
                results.tables_ratio_long_p_value.(ETM_prices.id{y}){model, horizon} = num2str(ratio);
            end
        end
    end
end

horizons = [1,3,6,9,12,15,18,21,24];
horizons = horizons(horizons <= Hsize);
for y = 1:length(ETM_prices.id)
   results.tables_ratio_long.(ETM_prices.id{y}) = results.tables_ratio_long.(ETM_prices.id{y})(:,horizons);
   results.tables_ratio_long_DM.(ETM_prices.id{y}) = results.tables_ratio_long_p_value.(ETM_prices.id{y})(:,horizons);
end

for y = 1:length(ETM_prices.id)
    results.tables_ratio_.(ETM_prices.id{y}) = array2table(results.tables_ratio_long.(ETM_prices.id{y}), 'RowNames', modelli, 'VariableNames', strcat('Hor-', string(horizons)));
end

%% RMSPE-level Cumulated

for y = 1:nb_var
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).futures = nan(Hsize,Out_s);
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).p_forecasts = nan(Hsize,Out_s);
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).AR_p = nan(Hsize,Out_s);
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).AR_IC = nan(Hsize,Out_s);
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).RW = nan(Hsize,Out_s);
    for tree_model = 1:numel(tree_model_names)
        model_name = tree_model_names{tree_model};
        results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).(model_name) = nan(Hsize,Out_s);
    end
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDI_p_1F = nan(Hsize,Out_s);
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDI_IC_2F = nan(Hsize,Out_s);
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDI_p_2F = nan(Hsize,Out_s);
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDI_IC_1F = nan(Hsize,Out_s);
    for exogenous_predictor = 1:size(regressors,2)
        model_name = ['ARDL_p_' regressors{exogenous_predictor}];
        results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).(model_name) = nan(Hsize,Out_s);
        model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
        results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).(model_name) = nan(Hsize,Out_s);
    end
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDL_p_real_activity = nan(Hsize,Out_s);
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDL_p_ex_rates = nan(Hsize,Out_s);
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDL_p_etm = nan(Hsize,Out_s);
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDL_p_et = nan(Hsize,Out_s);
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDL_p_cu = nan(Hsize,Out_s);
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDL_p_inventories = nan(Hsize,Out_s);
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDL_p_w_act = nan(Hsize,Out_s);

    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).VAR_p_specific = nan(Hsize,Out_s);

    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).FAVAR_specific_p_1F = nan(Hsize,Out_s);
    results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).FAVAR_specific_p_2F = nan(Hsize,Out_s);

    for hor=1:Hsize
        eval_len = Out_s - hor + 1;
        results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).futures(hor,1:eval_len) = cumulative_rmspe_row(ETM_lev_fore.futures.eps, hor, y, eval_len, false);
        p_forecasts_eps_row = forecast_error_row(ETM_lev_fore.p_forecasts.eps, hor, y, eval_len);
        if all(isnan(p_forecasts_eps_row))
            results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).p_forecasts(hor,1:eval_len) = nan;
        else
            results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).p_forecasts(hor,1:eval_len) = cumulative_rmspe_row(ETM_lev_fore.p_forecasts.eps, hor, y, eval_len, true);
        end
        fixed_model_names = [{'AR_p', 'AR_IC', 'RW'}, tree_model_names, ...
            {'ARDI_p_1F', 'ARDI_IC_1F', 'ARDI_p_2F', 'ARDI_IC_2F'}];
        for model_idx = 1:numel(fixed_model_names)
            model_name = fixed_model_names{model_idx};
            results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).(model_name)(hor,1:eval_len) = cumulative_rmspe_row(ETM_lev_fore.(model_name).eps, hor, y, eval_len, false);
        end
        for exogenous_predictor = 1:size(regressors,2)
            table_name = ['ARDL_p_' regressors{exogenous_predictor}];
            model_name = ['ARDL_p_' regressors{exogenous_predictor}];
            results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).(table_name)(hor,1:eval_len) = cumulative_rmspe_row(ETM_lev_fore.(model_name).eps, hor, y, eval_len, false);
            table_name = ['ARDL_IC_' regressors{exogenous_predictor}];
            model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
            results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).(table_name)(hor,1:eval_len) = cumulative_rmspe_row(ETM_lev_fore.(model_name).eps, hor, y, eval_len, false);
        end

        grouped_model_names = {'ARDL_p_real_activity', 'ARDL_p_ex_rates', 'ARDL_p_etm', 'ARDL_p_et', ...
            'ARDL_p_cu', 'ARDL_p_inventories', 'ARDL_p_w_act', 'VAR_p_specific', 'FAVAR_specific_p_1F', 'FAVAR_specific_p_2F'};
        for model_idx = 1:numel(grouped_model_names)
            model_name = grouped_model_names{model_idx};
            results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).(model_name)(hor,1:eval_len) = cumulative_rmspe_row(ETM_lev_fore.(model_name).eps, hor, y, eval_len, false);
        end
    end
end

%% Tables Ratio - level; Cumulated

for y = 1:nb_var
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).futures = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).p_forecasts = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).AR_p = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).AR_IC = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).RW = nan(Hsize,Out_s);
    for tree_model = 1:numel(tree_model_names)
        model_name = tree_model_names{tree_model};
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).(model_name) = nan(Hsize,Out_s);
    end
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDI_p_1F = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDI_IC_1F = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDI_p_2F = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDI_IC_2F = nan(Hsize,Out_s);
    for exogenous_predictor = 1:size(regressors,2)
        model_name = ['ARDL_p_' regressors{exogenous_predictor}];
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).(model_name) = nan(Hsize,Out_s);
        model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).(model_name) = nan(Hsize,Out_s);
    end
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDL_p_real_activity = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDL_p_ex_rates = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDL_p_etm = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDL_p_et = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDL_p_cu = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDL_p_inventories = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDL_p_w_act = nan(Hsize,Out_s);

    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).VAR_p_etm = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).VAR_IC_etm = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).VAR_p_specific = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).VAR_IC_specific = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).FAVAR_specific_p_1F = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).FAVAR_specific_IC_1F = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).FAVAR_specific_p_2F = nan(Hsize,Out_s);
    results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).FAVAR_specific_IC_2F = nan(Hsize,Out_s);

    for h=1:Hsize
        bench = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).RW(h,1:end-h+1);
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).futures(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).futures(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).p_forecasts(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).p_forecasts(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).AR_p(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).AR_p(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).AR_IC(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).AR_IC(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).RW(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).RW(h,1:end-h+1)./bench;
        for tree_model = 1:numel(tree_model_names)
            model_name = tree_model_names{tree_model};
            results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).(model_name)(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).(model_name)(h,1:end-h+1)./bench;
        end
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDI_p_1F(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDI_p_1F(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDI_IC_1F(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDI_IC_1F(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDI_p_2F(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDI_p_2F(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDI_IC_2F(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDI_IC_2F(h,1:end-h+1)./bench;
        for exogenous_predictor = 1:size(regressors,2)
            table_name = ['ARDL_p_' regressors{exogenous_predictor}];
            model_name = ['ARDL_p_' regressors{exogenous_predictor}];
            results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).(table_name)(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).(model_name)(h,1:end-h+1)./bench;
            table_name = ['ARDL_IC_' regressors{exogenous_predictor}];
            model_name = ['ARDL_IC_' regressors{exogenous_predictor}];
            results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).(table_name)(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).(model_name)(h,1:end-h+1)./bench;
        end
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDL_p_real_activity(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDL_p_real_activity(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDL_p_ex_rates(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDL_p_ex_rates(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDL_p_etm(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDL_p_etm(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDL_p_et(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDL_p_et(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDL_p_cu(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDL_p_cu(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDL_p_inventories(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDL_p_inventories(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).ARDL_p_w_act(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).ARDL_p_w_act(h,1:end-h+1)./bench;

        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).VAR_p_specific(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).VAR_p_specific(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).FAVAR_specific_p_1F(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).FAVAR_specific_p_1F(h,1:end-h+1)./bench;
        results.RMSPE_level_cum_ratio.(ETM_prices.id{y}).FAVAR_specific_p_2F(h,1:end-h+1) = results.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).FAVAR_specific_p_2F(h,1:end-h+1)./bench;
    end
end


%% Models' performances over time

 models = modelli';
 clean_names = cellfun(@(x) erase(x, 'table_'), models, 'UniformOutput', false);
 nomi_modelli = cellfun(@(x) strrep(x,'_', '-'), clean_names, 'UniformOutput', false);

%% Export Model Names

results.models = nomi_modelli;

close all

end

function [available_ids, positions] = available_regressor_positions(all_ids, requested_ids)
all_ids = cellstr(all_ids);
requested_ids = cellstr(requested_ids);
[is_present, positions] = ismember(requested_ids, all_ids);
available_ids = requested_ids(is_present);
positions = positions(is_present);
end

function horizons = futures_horizons_from_id(futures_series)
n_contracts = size(futures_series.data, 1);
horizons = 1:n_contracts;

if ~isfield(futures_series, 'id') || numel(futures_series.id) ~= n_contracts
    return
end

ids = cellstr(futures_series.id);
parsed = NaN(1, n_contracts);
for ii = 1:n_contracts
    token = regexp(strtrim(ids{ii}), '^(\d+)\s*m$', 'tokens', 'once');
    if ~isempty(token)
        parsed(ii) = str2double(token{1});
    end
end

if all(isfinite(parsed))
horizons = parsed;
end
end

function results = mask_results_after_end_date(results, metal_ids, end_date)
for yy = 1:numel(metal_ids)
    metal_name = metal_ids{yy};
    if ~isfield(results, metal_name)
        continue
    end

    model_names = fieldnames(results.(metal_name));
    for mm = 1:numel(model_names)
        model_name = model_names{mm};
        model_results = results.(metal_name).(model_name);

        if ~isstruct(model_results) || ~isfield(model_results, 'dates')
            continue
        end

        dates = model_results.dates;
        if isempty(dates) || ~isdatetime(dates)
            continue
        end

        invalid = ~isnat(dates) & dates > end_date;
        if ~any(invalid(:))
            continue
        end

        numeric_fields = {'y_hat', 'y_obs', 'eps', 'eps_2', 'RMSPE_cum'};
        for ff = 1:numel(numeric_fields)
            field_name = numeric_fields{ff};
            if isfield(model_results, field_name) && isnumeric(model_results.(field_name)) ...
                    && isequal(size(model_results.(field_name)), size(dates))
                temp = model_results.(field_name);
                temp(invalid) = NaN;
                model_results.(field_name) = temp;
            end
        end

        dates(invalid) = NaT;
        model_results.dates = dates;
        results.(metal_name).(model_name) = model_results;
    end
end
end

function model_results = store_factor_stat_slice(model_results, factors_stat, tt)
if ~isfield(model_results, 'factors_stat') || isempty(model_results.factors_stat)
    model_results.factors_stat = struct();
end

model_results.factors_stat.factors = assign_padded_slice(get_factor_field(model_results, 'factors'), factors_stat.factors, tt, true);
model_results.factors_stat.loadings = assign_padded_slice(get_factor_field(model_results, 'loadings'), factors_stat.loadings, tt, false);
model_results.factors_stat.st_data = assign_padded_slice(get_factor_field(model_results, 'st_data'), factors_stat.st_data, tt, true);
model_results.factors_stat.id = factors_stat.id;
end

function value = get_factor_field(model_results, field_name)
value = [];
if isfield(model_results, 'factors_stat') && isfield(model_results.factors_stat, field_name)
    value = model_results.factors_stat.(field_name);
end
end

function array = assign_padded_slice(existing, slice, tt, align_tail)
if isempty(slice)
    array = existing;
    return
end

slice_rows = size(slice, 1);
slice_cols = size(slice, 2);

if isempty(existing)
    array = NaN(slice_rows, slice_cols, tt);
else
    existing_rows = size(existing, 1);
    existing_cols = size(existing, 2);
    existing_slices = size(existing, 3);
    array_rows = max(existing_rows, slice_rows);
    array_cols = max(existing_cols, slice_cols);
    array_slices = max(existing_slices, tt);
    array = NaN(array_rows, array_cols, array_slices);

    if align_tail
        existing_row_idx = array_rows-existing_rows+1:array_rows;
    else
        existing_row_idx = 1:existing_rows;
    end
    array(existing_row_idx, 1:existing_cols, 1:existing_slices) = existing;
end

array_rows = size(array, 1);
if align_tail
    slice_row_idx = array_rows-slice_rows+1:array_rows;
else
    slice_row_idx = 1:slice_rows;
end
array(slice_row_idx, 1:slice_cols, tt) = slice;
end

function eps_row = forecast_error_row(eps_array, hor, variable_idx, target_len)
eps_row = nan(1, target_len);

if isempty(eps_array) || hor > size(eps_array, 1) || variable_idx > size(eps_array, 3)
    return
end

available_len = min(target_len, size(eps_array, 2) - hor + 1);
if available_len < 1
    return
end

eps_row(1:available_len) = eps_array(hor, 1:available_len, variable_idx);
end

function eps_2_row = squared_forecast_error_row(eps_array, hor, variable_idx, target_len)
eps_row = forecast_error_row(eps_array, hor, variable_idx, target_len);
eps_2_row = eps_row.^2;
end

function rmspe_row = cumulative_rmspe_row(eps_array, hor, variable_idx, target_len, skip_missing)
eps_row = forecast_error_row(eps_array, hor, variable_idx, target_len);
rmspe_row = nan(1, target_len);

if skip_missing
    valid_idx = find(~isnan(eps_row));
    if isempty(valid_idx)
        return
    end

    squared_errors = eps_row(valid_idx).^2;
    rmspe_row(valid_idx) = sqrt(cumsum(squared_errors) ./ (1:numel(squared_errors)));
    rmspe_row = fillmissing(rmspe_row, 'previous');
else
    rmspe_row = sqrt(cumsum(eps_row.^2) ./ (1:target_len));
end
end

function plot_ardi_group_contributions(results, metal_ids, folder_fig)
% Plot, for each metal in metal_ids and for each of the first two
% estimated ARDI factors, the grouped (8-category) contribution over time
% together with the smoothed factor overlaid as a black line.
%
% Data source: results.(metal).ARDI_IC_1F.factors_stat
%   .st_data   [1 x n_vars x T_plot]  standardised regressors
%   .loadings  [n_vars x n_factors x T_plot]
%   .factors   [T_in x n_factors x T_plot]
% Time axis: results.(metal).ARDI_p_1F.dates(12, 1:T_plot)
%
% Output: ARDI_<metal><F>.pdf / .png in folder_fig, for F = 1, 2.

ETM_prices_id = metal_ids;

group_metals = {'Aluminum','Copper','Nickel','Zinc'};
group_inventories = {'Zinc_Stock','Nickel_Stock','Aluminum_Stock','Copper_Stock'};
group_et = {'PCU335911335911','A35DVS'};
group_ex_rates = {'RBCLBIS','RBAUBIS','RBCNBIS','RBIDBIS','RBPEBIS','RBPHBIS','RBRUBIS'};
group_real_activity = {'INDPRO','ANMNO','A31SNO','AWHMAN'};
group_cu = {'CAPUTLG331S','CAPUTLB562A3CS'};
group_PPIs = {'PCU331331'};
group_w_act = {'WIP','CLI_G7','CLI_China'};

if ~exist(folder_fig, 'dir')
    mkdir(folder_fig);
end

for ETM_index = 1:numel(ETM_prices_id)

    group_metals_temp = group_metals;
    position_etm = find(strcmp(group_metals_temp, ETM_prices_id{ETM_index}));
    group_metals_temp(:,position_etm) = [];

    [~, idx_w_act] = ismember(group_w_act, results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.id);
    [~, idx_metals] = ismember(group_metals_temp, results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.id);
    [~, idx_real_activity] = ismember(group_real_activity, results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.id);
    [~, idx_PPIs] = ismember(group_PPIs, results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.id);
    [~, idx_ex_rates] = ismember(group_ex_rates, results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.id);
    [~, idx_et] = ismember(group_et, results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.id);
    [~, idx_cu] = ismember(group_cu, results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.id);
    [~, idx_inventories] = ismember(group_inventories, results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.id);

    idx = [idx_w_act, idx_metals, idx_real_activity, idx_PPIs, idx_ex_rates, idx_et, idx_cu, idx_inventories];
    grp = zeros(1, length(idx));

    grp(idx_w_act(idx_w_act > 0)) = 8;
    grp(idx_metals(idx_metals > 0)) = 7;
    grp(idx_real_activity(idx_real_activity > 0)) = 6;
    grp(idx_PPIs(idx_PPIs > 0)) = 5;
    grp(idx_ex_rates(idx_ex_rates > 0)) = 4;
    grp(idx_et(idx_et > 0)) = 3;
    grp(idx_cu(idx_cu > 0)) = 2;
    grp(idx_inventories(idx_inventories > 0)) = 1;

    for F = 1:2 % First and second factor
        st_data = results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.st_data;
        loadings = results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.loadings; loadings = squeeze(loadings(:,F,:));

        T_plot = size(st_data, 3);

        gloadings = NaN(8, T_plot);
        for jj = 1:T_plot
            gloadings(1,jj) = st_data(end,grp==1,jj)*loadings(grp==1,jj);
            gloadings(2,jj) = st_data(end,grp==2,jj)*loadings(grp==2,jj);
            gloadings(3,jj) = st_data(end,grp==3,jj)*loadings(grp==3,jj);
            gloadings(4,jj) = st_data(end,grp==4,jj)*loadings(grp==4,jj);
            gloadings(5,jj) = st_data(end,grp==5,jj)*loadings(grp==5,jj);
            gloadings(6,jj) = st_data(end,grp==6,jj)*loadings(grp==6,jj);
            gloadings(7,jj) = st_data(end,grp==7,jj)*loadings(grp==7,jj);
            gloadings(8,jj) = st_data(end,grp==8,jj)*loadings(grp==8,jj);
        end

        mavg = 3;
        y1 = movmean(gloadings',mavg,1);
        F_smoothed = movmean(squeeze(results.(ETM_prices_id{ETM_index}).ARDI_IC_1F.factors_stat.factors(end,F,:)),mavg,1);

        time = results.(ETM_prices_id{ETM_index}).ARDI_p_1F.dates(12, 1:T_plot);
        time_last_obs = time - calmonths(12);

        fig_print = figure;
        tiledlayout(1,1,"TileSpacing","tight","Padding","compact");
        ax = nexttile;
        bb=bar(time_last_obs,y1,'stacked','EdgeColor','n'); hold all;
        plot(time_last_obs,F_smoothed(:,1),'LineWidth',2,'Color', 'k')
        bb(1).FaceColor = '#1b9e77'; hold all
        bb(2).FaceColor = '#d95f02';
        bb(3).FaceColor = '#7570b3';
        bb(4).FaceColor = '#A6761D';
        bb(5).FaceColor = '#e7298a';
        bb(6).FaceColor = '#66a61e';
        bb(7).FaceColor = '#e6ab02';
        bb(8).FaceColor = '#666666';
        bb(1).DisplayName = 'Inventories';
        bb(2).DisplayName = 'CU';
        bb(3).DisplayName = 'ET';
        bb(4).DisplayName = 'Ex. Rates';
        bb(5).DisplayName = 'PPI';
        bb(6).DisplayName = 'Real Activity';
        bb(7).DisplayName = 'Metal Prices';
        bb(8).DisplayName = 'World Activity';
        lg = legend(ax, bb(:), 'Orientation', 'Horizontal', 'NumColumns', 4);
        lg.Layout.Tile = 'South';
        lg.Box='off';
        lg.FontSize = 18;
        ax.FontSize = 18;
        grid on

        % Print Options
        variable = ETM_prices_id{ETM_index};
        factor_number = num2str(F);
        filenameBase = ['ARDI_' variable factor_number];

        pdfPath = fullfile(folder_fig, [filenameBase '.pdf']);
        pngPath = fullfile(folder_fig, [filenameBase '.png']);

        exportgraphics(fig_print, pdfPath, 'ContentType', 'vector');  
        exportgraphics(fig_print, pngPath, 'Resolution', 600);    

    end
end
end

function plot_favar_group_contributions(results, metal_ids, folder_fig)
% Plot, for each metal in metal_ids and for each of the first two
% estimated FAVAR factors, the grouped (8-category) contribution over time
% together with the smoothed factor overlaid as a black line.
%
% Data source: results.(metal).FAVAR_specific_p_1F.factors_stat
%   .st_data   [1 x n_vars x T_plot]  standardised regressors
%   .loadings  [n_vars x n_factors x T_plot]
%   .factors   [T_in x n_factors x T_plot]
% Time axis: results.(metal).ARDI_p_1F.dates(12, 1:T_plot)
%
% Output: FAVAR_<metal><F>.pdf / .png in folder_fig, for F = 1, 2.

ETM_prices_id = metal_ids;

group_metals = {'Aluminum','Copper','Nickel','Zinc'};
group_inventories = {'Zinc_Stock','Nickel_Stock','Aluminum_Stock','Copper_Stock'};
group_et = {'PCU335911335911','A35DVS'};
group_ex_rates = {'RBCLBIS','RBAUBIS','RBCNBIS','RBIDBIS','RBPEBIS','RBPHBIS','RBRUBIS'};
group_real_activity = {'INDPRO','ANMNO','AWHMAN'};
group_cu = {'CAPUTLG331S','CAPUTLB562A3CS'};
group_PPIs = {'PCU331331'};
group_w_act = {'WIP','CLI_G7','CLI_China'};

if ~exist(folder_fig, 'dir')
    mkdir(folder_fig);
end

for ETM_index = 1:numel(ETM_prices_id)

    group_metals_temp = group_metals;
    position_etm = find(strcmp(group_metals_temp, ETM_prices_id{ETM_index}));
    group_metals_temp(:,position_etm) = [];

    group_inventories_temp = group_inventories;
    position_stock = find(strcmp(group_inventories, [ETM_prices_id{ETM_index}, '_Stock']));
    group_inventories_temp(:,position_stock) = [];

    [~, idx_metals] = ismember(group_metals_temp, results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.id);
    [~, idx_real_activity] = ismember(group_real_activity, results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.id);
    [~, idx_PPIs] = ismember(group_PPIs, results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.id);
    [~, idx_ex_rates] = ismember(group_ex_rates, results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.id);
    [~, idx_et] = ismember(group_et, results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.id);
    [~, idx_cu] = ismember(group_cu, results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.id);
    [~, idx_inventories] = ismember(group_inventories_temp, results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.id);
    [~, idx_w_act] = ismember(group_w_act, results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.id);

    idx = [idx_w_act, idx_metals, idx_real_activity, idx_PPIs, idx_ex_rates, idx_et, idx_cu, idx_inventories];
    grp = zeros(1, length(idx));

    grp(idx_w_act(idx_w_act > 0)) = 8;
    grp(idx_metals(idx_metals > 0)) = 7;
    grp(idx_real_activity(idx_real_activity > 0)) = 6;
    grp(idx_PPIs(idx_PPIs > 0)) = 5;
    grp(idx_ex_rates(idx_ex_rates > 0)) = 4;
    grp(idx_et(idx_et > 0)) = 3;
    grp(idx_cu(idx_cu > 0)) = 2;
    grp(idx_inventories(idx_inventories > 0)) = 1;

    for F = 1:2 % First and second factor
        st_data = results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.st_data;
        loadings = results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.loadings; loadings = squeeze(loadings(:,F,:));

        T_plot = size(st_data, 3);

        gloadings = NaN(8, T_plot);
        for jj = 1:T_plot
            gloadings(1,jj) = st_data(end,grp==1,jj)*loadings(grp==1,jj);
            gloadings(2,jj) = st_data(end,grp==2,jj)*loadings(grp==2,jj);
            gloadings(3,jj) = st_data(end,grp==3,jj)*loadings(grp==3,jj);
            gloadings(4,jj) = st_data(end,grp==4,jj)*loadings(grp==4,jj);
            gloadings(5,jj) = st_data(end,grp==5,jj)*loadings(grp==5,jj);
            gloadings(6,jj) = st_data(end,grp==6,jj)*loadings(grp==6,jj);
            gloadings(7,jj) = st_data(end,grp==7,jj)*loadings(grp==7,jj);
            gloadings(8,jj) = st_data(end,grp==8,jj)*loadings(grp==8,jj);
        end

        mavg = 3;
        y1 = movmean(gloadings',mavg,1);

        F_smoothed = movmean(squeeze(results.(ETM_prices_id{ETM_index}).FAVAR_specific_p_1F.factors_stat.factors(end,F,:)),mavg,1);

        time = results.(ETM_prices_id{ETM_index}).ARDI_p_1F.dates(12, 1:T_plot);
        time_last_obs = time - calmonths(12);

        fig_print = figure;
        tiledlayout(1,1,"TileSpacing","tight","Padding","compact");
        ax = nexttile;
        bb=bar(time_last_obs,y1,'stacked','EdgeColor','n'); hold all;
        plot(time_last_obs,F_smoothed(:,1),'LineWidth',2,'Color','k')
        bb(1).FaceColor = '#1b9e77'; hold all
        bb(2).FaceColor = '#d95f02';
        bb(3).FaceColor = '#7570b3';
        bb(4).FaceColor = '#A6761D';
        bb(5).FaceColor = '#e7298a';
        bb(6).FaceColor = '#66a61e';
        bb(7).FaceColor = '#e6ab02';
        bb(8).FaceColor = '#666666';
        bb(1).DisplayName = 'Inventories';
        bb(2).DisplayName = 'CU';
        bb(3).DisplayName = 'ET';
        bb(4).DisplayName = 'Ex. Rates';
        bb(5).DisplayName = 'PPI';
        bb(6).DisplayName = 'Real Activity';
        bb(7).DisplayName = 'Metal Prices';
        bb(8).DisplayName = 'World Activity';
        % Split the 8-entry legend over two rows (4 columns) so it no
        % longer overflows the figure width.
        lg  = legend(ax,bb(:),'Orientation','Horizontal','NumColumns',4);
        lg.Layout.Tile = 'South';
        lg.Box='off';
        lg.FontSize = 18;
        ax.FontSize = 18;
        grid on

        % Print Options
        variable = ETM_prices_id{ETM_index};
        factor_number = num2str(F);
        filenameBase = ['FAVAR_' variable factor_number];

        pdfPath = fullfile(folder_fig, [filenameBase '.pdf']);
        pngPath = fullfile(folder_fig, [filenameBase '.png']);

        exportgraphics(fig_print, pdfPath, 'ContentType', 'vector');  
        exportgraphics(fig_print, pngPath, 'Resolution', 600); 

    end
end
end
