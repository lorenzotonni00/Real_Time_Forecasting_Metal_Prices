function [forecast_comb] = forecast_comb_fn(ETM, PREDICTORS, real, model, results, target_series, rolling, Hsize, start_date, Lastin, raw_transformations, treatment, real_time)

if nargin < 13 || isempty(real_time)
    real_time = 1;
end

if ~ismember(real_time, [0 1])
    error('real_time must be 0 (non real-time) or 1 (real-time)');
end

%% MCS Training (months)
window = 12;

% Number of ETM prices
n_ETM = size(target_series,2);

% Model Names
model_names = fieldnames(results.Copper);

% Max OOS size
Out_s = find(~isnan(squeeze(results.Copper.RW.eps(1,:))), 1, 'last');

count = 0;

hx = waitbar(0,'Estimating Forecast Combinations...');
for ETM_index = 1:n_ETM
    model_names_temp = model_names;
    drop_1 = ['ARDL_p_' target_series{ETM_index}];
    drop_2 = ['ARDL_IC_' target_series{ETM_index}];
    drop_3 = 'p_forecasts';
    drop_4 = 'futures';
    pos_1 = find(strcmp(model_names_temp, drop_1));
    pos_2 = find(strcmp(model_names_temp, drop_2));
    pos_3 = find(strcmp(model_names_temp, drop_3));
    pos_4 = find(strcmp(model_names_temp, drop_4));
    model_names_temp([pos_1 pos_2 pos_3 pos_4]) = [];
    metal = target_series{ETM_index};
    n_models = size(model_names_temp,1);

    % Pre-Store some objects
    forecast_comb.(target_series{ETM_index}).threshold.y_hat = nan(Hsize, Out_s);
    forecast_comb.(target_series{ETM_index}).threshold.y_obs= nan(Hsize, Out_s);
    forecast_comb.(target_series{ETM_index}).threshold.dates = NaT(Hsize, Out_s);
    forecast_comb.(target_series{ETM_index}).threshold.eps= nan(Hsize, Out_s);
    forecast_comb.(target_series{ETM_index}).threshold.MSPE = nan(1, Hsize);
    forecast_comb.(target_series{ETM_index}).threshold.RMSPE = nan(1, Hsize);
    forecast_comb.(target_series{ETM_index}).threshold.RMSPE_cum = nan(Hsize, Out_s);

    forecast_comb.(target_series{ETM_index}).top_2.y_hat = nan(Hsize, Out_s);
    forecast_comb.(target_series{ETM_index}).top_2.y_obs= nan(Hsize, Out_s);
    forecast_comb.(target_series{ETM_index}).top_2.dates = NaT(Hsize, Out_s);
    forecast_comb.(target_series{ETM_index}).top_2.eps= nan(Hsize, Out_s);
    forecast_comb.(target_series{ETM_index}).top_2.MSPE = nan(1, Hsize);
    forecast_comb.(target_series{ETM_index}).top_2.RMSPE = nan(1, Hsize);
    forecast_comb.(target_series{ETM_index}).top_2.RMSPE_cum = nan(Hsize, Out_s);

    forecast_comb.(target_series{ETM_index}).all_models_name = model_names_temp;

   for Horizon_index = 1:Hsize
        indeces = 1:Hsize;
        OOS_size = find(~isnan(squeeze(results.(target_series{ETM_index}).RW.eps(Horizon_index,:))), 1, 'last');
        data_temp = NaN(n_models, OOS_size);
        eps_temp = NaN(n_models, OOS_size);
        for mod = 1:n_models
            data_temp(mod,:) = results.(target_series{ETM_index}).(model_names_temp{mod}).y_hat(Horizon_index,1:OOS_size);
            eps_temp(mod,:) = results.(target_series{ETM_index}).(model_names_temp{mod}).eps(Horizon_index,1:OOS_size).^2;
        end

        all_models_comb = mean(data_temp,1);
        real_Y.value = results.(target_series{ETM_index}).RW.y_obs(Horizon_index, 1:OOS_size);
        real_Y.dates = results.(target_series{ETM_index}).RW.dates(Horizon_index, 1:OOS_size);
        for t = 1:OOS_size
            count = count + 1;
            if t < window + 1
                Yhat = all_models_comb(1,t);
                forecast_comb.(target_series{ETM_index}).threshold.y_hat(Horizon_index, t) = Yhat;
                forecast_comb.(target_series{ETM_index}).threshold.y_obs(Horizon_index,t) = real_Y.value(1,t);
                forecast_comb.(target_series{ETM_index}).threshold.dates(Horizon_index,t) = real_Y.dates(1,t);
                forecast_comb.(target_series{ETM_index}).threshold.eps(Horizon_index, t) = Yhat - real_Y.value(1,t);

                forecast_comb.(target_series{ETM_index}).top_2.y_hat(Horizon_index, t) = Yhat;
                forecast_comb.(target_series{ETM_index}).top_2.y_obs(Horizon_index,t) = real_Y.value(1,t);
                forecast_comb.(target_series{ETM_index}).top_2.dates(Horizon_index,t) = real_Y.dates(1,t);
                forecast_comb.(target_series{ETM_index}).top_2.eps(Horizon_index, t) = Yhat - real_Y.value(1,t);
            else
                if rolling == 1
                    eps_temp_RT = eps_temp(:,t-window:t - 1);
                elseif rolling == 0
                    eps_temp_RT = eps_temp(:,1: t - 1);
                end
                
                MCS_temp = MCS_RT_b(eps_temp_RT);
            
                selected_models_index = find(MCS_temp(:,2) > 0.25);
                selected_models_threshold = MCS_temp(selected_models_index,1);

                % SSM-25 average
                Yhat = mean(data_temp(selected_models_threshold,t),1);
                forecast_comb.(target_series{ETM_index}).threshold.y_hat(Horizon_index, t) = Yhat;
                forecast_comb.(target_series{ETM_index}).threshold.y_obs(Horizon_index,t) = real_Y.value(1,t);
                forecast_comb.(target_series{ETM_index}).threshold.dates(Horizon_index,t) = real_Y.dates(1,t);
                forecast_comb.(target_series{ETM_index}).threshold.eps(Horizon_index, t) = Yhat - real_Y.value(1,t);

                % Top-2 models
                [p_values, ~] = maxk(MCS_temp(:,2), 2);

                models_indexes = find(ismember(MCS_temp(:,2), p_values));
                models_indexes_2 = MCS_temp(models_indexes,1);

                best_model = models_indexes_2(end);

                second_best_candidates = models_indexes_2(1:end-1);

                if length(second_best_candidates) == 1
                    second_best_model = second_best_candidates;
                    selected_models_top_2 = [best_model, second_best_model];
                else
                    rmspe_cum_temp = NaN(n_models,1);
                    for i_tmp = 1:n_models
                        rmspe_cum_temp(i_tmp) = results.TABLES_RMSPE_level_cum.(target_series{ETM_index}).(model_names_temp{i_tmp})(Horizon_index, t);
                    end
                    candidates_values = rmspe_cum_temp(second_best_candidates);
                    [~, idx] = min(candidates_values);
                    second_best_model = second_best_candidates(idx);
                    selected_models_top_2 = [best_model, second_best_model];
                end

                horizon = sprintf('Horizon_%d', indeces(Horizon_index));
                forecast_comb.(target_series{ETM_index}).(horizon).top_2_models_name{1,t} = model_names_temp(selected_models_top_2,1);
                forecast_comb.(target_series{ETM_index}).(horizon).top_2_models_number(:,t) = selected_models_top_2;
                Yhat = mean(data_temp(selected_models_top_2,t),1);
                forecast_comb.(target_series{ETM_index}).top_2.y_hat(Horizon_index, t) = Yhat;
                forecast_comb.(target_series{ETM_index}).top_2.y_obs(Horizon_index,t) = real_Y.value(1,t);
                forecast_comb.(target_series{ETM_index}).top_2.dates(Horizon_index,t) = real_Y.dates(1,t);
                forecast_comb.(target_series{ETM_index}).top_2.eps(Horizon_index, t) = Yhat - real_Y.value(1,t);
            end
            waitbar(count/(n_ETM*Hsize*Out_s),hx,sprintf('Estimating Forecast Combinations: %2.2f',(count/(n_ETM*Hsize*Out_s))*100));
        end
   end

if real_time == 1

%% Models SELECTED - 12

horizon_t = 'Horizon_12';

clean_names = model_names_temp;

selection_matrix_star = nan(length(clean_names),size(results.Copper.RW.eps,2));

for tt = 1:size(forecast_comb.(target_series{ETM_index}).(horizon_t).top_2_models_number,2)
    for i = 1:2 % first and second-best models
        for b = 1:length(clean_names)
            if forecast_comb.(target_series{ETM_index}).(horizon_t).top_2_models_number(i,tt) == b
                selection_matrix_star(b, tt) = b;
            end
        end
    end
end

figure;
hold on;
for i = 1:size(selection_matrix_star, 1)
    for j = 1:size(selection_matrix_star, 2)
        y = selection_matrix_star(i, j);
        
        if ~isnan(y)
            plot([results.Copper.AR_p.dates(1,j) - 0.5, results.Copper.AR_p.dates(1,j) + 0.5], [y, y], '-', 'LineWidth', 5);
            plot(results.Copper.AR_p.dates(1,j), y, 'ko', 'MarkerSize', 8); 
        end
    end
end
hold off;

ylim([0.5, length(clean_names) + 0.5]);
yticks(1:length(clean_names));
yticklabels(clean_names);

ax = gca;
ax.FontSize = 10;

title(['Horizon ', num2str(horizon_t)]);
grid on;

%% Models SELECTED - 24

horizon_t = 'Horizon_24';

clean_names = model_names_temp;

selection_matrix_star = nan(length(clean_names),size(results.Copper.RW.eps,2));

for tt = 1:size(forecast_comb.(target_series{ETM_index}).(horizon_t).top_2_models_number,2)
    for i = 1:2
        for b = 1:length(clean_names)
            if forecast_comb.(target_series{ETM_index}).(horizon_t).top_2_models_number(i,tt) == b
                selection_matrix_star(b, tt) = b;
            end
        end
    end
end

figure;
hold on;
for i = 1:size(selection_matrix_star, 1) 
    for j = 1:size(selection_matrix_star, 2) 
        y = selection_matrix_star(i, j);
        
        if ~isnan(y)
            plot([results.Copper.AR_p.dates(1,j) - 0.5, results.Copper.AR_p.dates(1,j) + 0.5], [y, y], '-', 'LineWidth', 5);
            plot(results.Copper.AR_p.dates(1,j), y, 'ko', 'MarkerSize', 8); 
        end
    end
end
hold off;

ylim([0.5, length(clean_names) + 0.5]);
yticks(1:length(clean_names));
yticklabels(clean_names);

ax = gca;
ax.FontSize = 10;

title(['Horizon ', num2str(horizon_t)]);
grid on;

end

end
close(hx);

%% Import ETM data

%% Reshape ETM and Regressors datasets

% Find Target series
[~, pos_targets] = ismember(target_series, ETM.id);

% Creates separate prices objects
ETM_prices.data = ETM.data(:,pos_targets);
ETM_prices.id = ETM.id(1,pos_targets);
ETM_prices.obs = ETM.obs;
raw_transformations = transformations_for_ids(raw_transformations, ETM_prices.id, 'raw_transformations');

%% Generate ETM tensor

if real == 1 % Real ETMs prices

    if model == 1

        pos_cpi = find(strcmp(PREDICTORS.SA.id,'CPIAUCSL'));

        first_vin = PREDICTORS.SA.data(:,1,1);
        first_vin_size = find(isnan(first_vin), 1, 'first')-1; 
    
        ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.SA.data,2),size(ETM_prices.data,2));
    
            for vin = 1:size(PREDICTORS.SA.data,2)
                ETM_temp = ETM_prices.data./squeeze(PREDICTORS.SA.data(:,vin,pos_cpi));
                n_rows = min(first_vin_size + vin - 1, size(ETM_temp, 1));
                ETM_data(1:n_rows,vin,:) = ETM_temp(1:n_rows,:);
            end

        observed_ETM.data = ETM_prices.data./squeeze(PREDICTORS.SA.data(:,end,pos_cpi));
        observed_ETM.obs = ETM_prices.obs;

    elseif model == 2

        pos_cpi = find(strcmp(PREDICTORS.BAR.id,'CPIAUCSL'));

        first_vin = PREDICTORS.BAR.data(:,1,1);
        first_vin_size = find(isnan(first_vin), 1, 'first')-1; 
    
        ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.BAR.data,2),size(ETM_prices.data,2));
    
            for vin = 1:size(PREDICTORS.BAR.data,2)
                ETM_temp = ETM_prices.data./squeeze(PREDICTORS.BAR.data(:,vin,pos_cpi));
                n_rows = min(first_vin_size + vin - 1, size(ETM_temp, 1));
                ETM_data(1:n_rows,vin,:) = ETM_temp(1:n_rows,:);
            end

        observed_ETM.data = ETM_prices.data./squeeze(PREDICTORS.BAR.data(:,end,pos_cpi));
        observed_ETM.obs = ETM_prices.obs;

    elseif model == 3

        pos_cpi = find(strcmp(PREDICTORS.BAR_SV.id,'CPIAUCSL'));

        first_vin = PREDICTORS.BAR_SV.data(:,1,1);
        first_vin_size = find(isnan(first_vin), 1, 'first')-1; 
    
        ETM_data = nan(length(ETM_prices.obs),size(PREDICTORS.BAR_SV.data,2),size(ETM_prices.data,2));
    
            for vin = 1:size(PREDICTORS.BAR_SV.data,2)
                ETM_temp = ETM_prices.data./squeeze(PREDICTORS.BAR_SV.data(:,vin,pos_cpi));
                n_rows = min(first_vin_size + vin - 1, size(ETM_temp, 1));
                ETM_data(1:n_rows,vin,:) = ETM_temp(1:n_rows,:);
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
                ETM_temp = ETM_prices.data./squeeze(PREDICTORS.BAR_SVo.data(:,vin,pos_cpi));
                n_rows = min(first_vin_size + vin - 1, size(ETM_temp, 1));
                ETM_data(1:n_rows,vin,:) = ETM_temp(1:n_rows,:);
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
            ETM_temp = ETM_prices.data./squeeze(PREDICTORS.LAST_R.data(:,vin,pos_cpi));
            ETM_data(1:first_vin_size + vin - 1,vin,:) = ETM_temp(1:first_vin_size + vin - 1,:);
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
            ETM_temp = ETM_prices.data./squeeze(selected_data(:,vin,pos_cpi));
            ETM_data(1:first_vin_size + vin - 1,vin,:) = ETM_temp(1:first_vin_size + vin - 1,:);
            ETM_volumes_data(1:first_vin_size + vin - 1,vin,:) = ETM_volumes.data(1:first_vin_size + vin - 1,:);
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

        vintage_number = size(PREDICTORS.SA.data,2);

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
            ETM_data(1:first_vin_size + vin - 1,vin,:) = ETM_temp(1:first_vin_size + vin - 1,:);
            ETM_volumes_data(1:first_vin_size + vin - 1,vin,:) = ETM_volumes.data(1:first_vin_size + vin - 1,:);
        end
    end 

    observed_ETM.data = ETM_prices.data;
    observed_ETM.obs = ETM_prices.obs;

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

% Cut Columns
if MACRO.vintages(1) <= Lastin
   pos_last_insample = find(MACRO.vintages == Lastin);
else
   pos_last_insample = 1;
end

ETM_data(:,1:pos_last_insample-1,:) = [];

if real_time == 0
    non_rt_end_date = results.(target_series{1}).RW.dates(1, Out_s);
    pos_non_rt_end = find(observed_ETM.obs == non_rt_end_date, 1);

    if isempty(pos_non_rt_end)
        error('non real-time end date is not available in the ETM sample');
    end

    ETM_data(pos_non_rt_end+1:end,:,:) = [];
    observed_ETM.data(pos_non_rt_end+1:end,:) = [];
    observed_ETM.obs(pos_non_rt_end+1:end,:) = [];

    ETM_data = use_final_vintage_with_rt_mask(ETM_data);
end

%% Data Level 

for yyy = 1:n_ETM

    Y_temp = squeeze(ETM_data(:,:,yyy));

    pos_1st_obs = find(~all(isnan(Y_temp), 2), 1);
    pos_1st_vin = find(~all(isnan(Y_temp), 1), 1);

    vin_1 = Y_temp(:,pos_1st_vin); vin_1_c = vin_1(~any(isnan(vin_1), 2), :);
    InSize = size(vin_1_c,1);

    for ttt = 1:Out_s

        lastx =   Y_temp(pos_1st_obs - 1 + InSize + ttt - 1, pos_1st_vin + ttt - 1);
        lastx_1 = Y_temp(pos_1st_obs - 1 + InSize + ttt - 2, pos_1st_vin + ttt - 1);

           if raw_transformations(yyy) == 1

               error('missing code')

           elseif raw_transformations(yyy) == 3

                    for hhh = 1:Hsize
                        % Forecast - Long
                        ETM_lev_fore.RW.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).RW.y_hat(hhh,ttt));
                        ETM_lev_fore.threshold.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) = lastx.*exp(forecast_comb.(ETM_prices.id{yyy}).threshold.y_hat(hhh,ttt));          
                        ETM_lev_fore.top_2.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) = lastx.*exp(forecast_comb.(ETM_prices.id{yyy}).top_2.y_hat(hhh,ttt));                  

                        % Observed - Long
                        ETM_lev_fore.RW.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).RW.y_obs(hhh,ttt));
                        ETM_lev_fore.threshold.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) = lastx.*exp(forecast_comb.(ETM_prices.id{yyy}).threshold.y_obs(hhh,ttt));
                        ETM_lev_fore.top_2.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) = lastx.*exp(forecast_comb.(ETM_prices.id{yyy}).top_2.y_obs(hhh,ttt));
 
                        % Errors - Long
                        ETM_lev_fore.RW.eps(hhh, ttt, yyy) = ETM_lev_fore.RW.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.RW.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        ETM_lev_fore.threshold.eps(hhh, ttt, yyy) = ETM_lev_fore.threshold.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.threshold.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        ETM_lev_fore.top_2.eps(hhh, ttt, yyy) = ETM_lev_fore.top_2.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.top_2.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);

                        % Forecast - Compact
                        results.level.RW.data_compact(hhh, ttt, yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).RW.y_hat(hhh,ttt));
                        results.level.threshold.data_compact(hhh, ttt, yyy) = lastx.*exp(forecast_comb.(ETM_prices.id{yyy}).threshold.y_hat(hhh,ttt));          
                        results.level.top_2.data_compact(hhh, ttt, yyy) = lastx.*exp(forecast_comb.(ETM_prices.id{yyy}).top_2.y_hat(hhh,ttt));                  

                        % Observed - Compact
                        results.level.RW.data_real_compact(hhh, ttt, yyy) = lastx.*exp(results.(ETM_prices.id{yyy}).RW.y_obs(hhh,ttt));
                        results.level.threshold.data_real_compact(hhh, ttt, yyy) = lastx.*exp(forecast_comb.(ETM_prices.id{yyy}).threshold.y_obs(hhh,ttt));
                        results.level.top_2.data_real_compact(hhh, ttt, yyy) = lastx.*exp(forecast_comb.(ETM_prices.id{yyy}).top_2.y_obs(hhh,ttt));
 
                        % Errors - Compact
                        results.level.RW.eps_compact(hhh, ttt, yyy) = ETM_lev_fore.RW.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.RW.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        results.level.threshold.eps_compact(hhh, ttt, yyy) = ETM_lev_fore.threshold.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.threshold.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                        results.level.top_2.eps_compact(hhh, ttt, yyy) = ETM_lev_fore.top_2.data_real(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy) - ETM_lev_fore.top_2.data(pos_1st_obs - 1 + InSize + ttt - 1 + hhh, pos_1st_vin + ttt - 1, yyy);
                    end
                
            elseif raw_transformations(yyy) == 5
                error('missing code')
            end
    end
end

%% 

for y = 1:n_ETM
    for hor = 1:Hsize

        % DM Test
        nested_flag = 0;
        forecast_comb.(ETM_prices.id{y}).threshold.DM_p_value(1,hor) = test_DM(ETM_lev_fore.RW.eps(hor,1:end-hor+1,y).^2',ETM_lev_fore.threshold.eps(hor,1:end-hor+1,y).^2',hor-1,nested_flag, treatment);
        forecast_comb.(ETM_prices.id{y}).top_2.DM_p_value(1,hor) = test_DM(ETM_lev_fore.RW.eps(hor,1:end-hor+1,y).^2',ETM_lev_fore.top_2.eps(hor,1:end-hor+1,y).^2',hor-1,nested_flag, treatment);

        % MSPE level
        forecast_comb.(ETM_prices.id{y}).RW.MSPE_level(1,hor) = mean(ETM_lev_fore.RW.eps(hor,1:end-hor+1,y).^2,2);
        forecast_comb.(ETM_prices.id{y}).threshold.MSPE_level(1,hor) = mean(ETM_lev_fore.threshold.eps(hor,1:end-hor+1,y).^2,2);
        forecast_comb.(ETM_prices.id{y}).top_2.MSPE_level(1,hor) = mean(ETM_lev_fore.top_2.eps(hor,1:end-hor+1,y).^2,2);
 
        % RMSPE level
        forecast_comb.(ETM_prices.id{y}).RW.RMSPE_level(1,hor) = sqrt(forecast_comb.(ETM_prices.id{y}).RW.MSPE_level(1,hor));
        forecast_comb.(ETM_prices.id{y}).threshold.RMSPE_level(1,hor) = sqrt(forecast_comb.(ETM_prices.id{y}).threshold.MSPE_level(1,hor));
        forecast_comb.(ETM_prices.id{y}).top_2.RMSPE_level(1,hor) = sqrt(forecast_comb.(ETM_prices.id{y}).top_2.MSPE_level(1,hor));
    end
end

%% Tables RMSPE - level

% RW Benchmark
forecast_comb.TABLES_RMSPE_level.RW = nan(Hsize,n_ETM);
forecast_comb.TABLES_RMSPE_level.threshold = nan(Hsize,n_ETM);
forecast_comb.TABLES_RMSPE_level.top_2 = nan(Hsize,n_ETM);

for dd = 1:n_ETM
    for h=1:Hsize
        forecast_comb.TABLES_RMSPE_level.RW(h,dd) = forecast_comb.(ETM_prices.id{dd}).RW.RMSPE_level(1,h);
        forecast_comb.TABLES_RMSPE_level.threshold(h,dd) = forecast_comb.(ETM_prices.id{dd}).threshold.RMSPE_level(1,h);
        forecast_comb.TABLES_RMSPE_level.top_2(h,dd) = forecast_comb.(ETM_prices.id{dd}).top_2.RMSPE_level(1,h);
    end
end

%% Tables Ratio - level

% RW Benchmark
forecast_comb.TABLES_level.threshold = nan(Hsize,n_ETM);
forecast_comb.TABLES_level.top_2 = nan(Hsize,n_ETM);

for dd = 1:n_ETM
    for h=1:Hsize
        benchmark = forecast_comb.(ETM_prices.id{dd}).RW.RMSPE_level(1,h);
        forecast_comb.TABLES_level.threshold(h,dd) = forecast_comb.(ETM_prices.id{dd}).threshold.RMSPE_level(1,h)/benchmark;
        forecast_comb.TABLES_level.top_2(h,dd) = forecast_comb.(ETM_prices.id{dd}).top_2.RMSPE_level(1,h)/benchmark;
    end
end

%% Tables Ratio - Reshaped

for y = 1:length(ETM_prices.id)
forecast_comb.tables_ratio_long_f_comb.(ETM_prices.id{y}) = NaN(length(fieldnames(forecast_comb.TABLES_level)), Hsize);
forecast_comb.tables_ratio_long_f_comb_p_value.(ETM_prices.id{y}) = cell(length(fieldnames(forecast_comb.TABLES_level)), Hsize);

end
modelli = fieldnames(forecast_comb.TABLES_level);

for y = 1:length(ETM_prices.id)
    for model = 1:length(modelli)
        for horizon = 1:Hsize
            forecast_comb.tables_ratio_long_f_comb.(ETM_prices.id{y})(model, horizon) = forecast_comb.TABLES_level.(modelli{model})(horizon,y);
        end
    end
end

for y = 1:length(ETM_prices.id)
    for model = 1:length(modelli)
        for horizon = 1:Hsize
            ratio = forecast_comb.TABLES_level.(modelli{model})(horizon,y);
            p_value = forecast_comb.(ETM_prices.id{y}).(modelli{model}).DM_p_value(1,horizon);
            forecast_comb.tables_ratio_long_f_comb.(ETM_prices.id{y})(model, horizon) = forecast_comb.TABLES_level.(modelli{model})(horizon,y);
            if (p_value >= 0.05 && p_value < 0.1) || (p_value > 0.9 && p_value <= 0.95)
                forecast_comb.tables_ratio_long_f_comb_p_value.(ETM_prices.id{y}){model, horizon} = strcat(num2str(ratio), '*');
            elseif (p_value >= 0.01 && p_value < 0.05) || (p_value > 0.95 && p_value <= 0.99)
                forecast_comb.tables_ratio_long_f_comb_p_value.(ETM_prices.id{y}){model, horizon} = strcat(num2str(ratio), '**');
            elseif p_value < 0.01 || p_value > 0.99
                forecast_comb.tables_ratio_long_f_comb_p_value.(ETM_prices.id{y}){model, horizon} = strcat(num2str(ratio), '***');
            else
                forecast_comb.tables_ratio_long_f_comb_p_value.(ETM_prices.id{y}){model, horizon} = num2str(ratio);
            end
        end
    end
end

horizons = [1,3,6,9,12,15,18,21,24];
for y = 1:n_ETM
   forecast_comb.tables_ratio_long_f_comb.(ETM_prices.id{y}) = forecast_comb.tables_ratio_long_f_comb_p_value.(ETM_prices.id{y})(:,horizons);
end

%% RMSPE-level Cumulated

for y = 1:n_ETM
    forecast_comb.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).threshold = nan(Hsize,Out_s);
    forecast_comb.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).top_2 = nan(Hsize,Out_s);
    forecast_comb.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).RW = nan(Hsize,Out_s);
    for hor=1:Hsize
        forecast_comb.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).RW(hor,1:Out_s - hor + 1) = sqrt(cumsum(ETM_lev_fore.RW.eps(hor, 1:end-hor+1, y).^2)./(1:Out_s - hor + 1));
        forecast_comb.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).threshold(hor,1:Out_s - hor + 1) = sqrt(cumsum(ETM_lev_fore.threshold.eps(hor, 1:end-hor+1, y).^2)./(1:Out_s - hor + 1));
        forecast_comb.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).top_2(hor,1:Out_s - hor + 1) = sqrt(cumsum(ETM_lev_fore.top_2.eps(hor, 1:end-hor+1, y).^2)./(1:Out_s - hor + 1));
    end
end

%% Tables Ratio - level; Cumulated

for y = 1:n_ETM
    forecast_comb.TABLES_RMSPE_level_cum_ratio.(ETM_prices.id{y}).threshold = nan(Hsize,Out_s);
    forecast_comb.TABLES_RMSPE_level_cum_ratio.(ETM_prices.id{y}).top_2 = nan(Hsize,Out_s);
    for h=1:Hsize
        bench = forecast_comb.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).RW(h,1:end-h+1);
        forecast_comb.TABLES_RMSPE_level_cum_ratio.(ETM_prices.id{y}).threshold(h,1:end-h+1) = forecast_comb.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).threshold(h,1:end-h+1)./bench;
        forecast_comb.TABLES_RMSPE_level_cum_ratio.(ETM_prices.id{y}).top_2(h,1:end-h+1) = forecast_comb.TABLES_RMSPE_level_cum.(ETM_prices.id{y}).top_2(h,1:end-h+1)./bench;
    end
end


end
