
function [PREDICTORS_lev_now, results] = nowcast_direct(PREDICTORS_balanced, direct, rollwind, P_AR, Pn, pred_id, IC, predictors_transfomations, ngibbs, nburn, first_date, last_date)

predictors_transfomations = transformations_for_ids(predictors_transfomations, pred_id, 'predictors_transfomations');
[PREDICTORS_balanced, missing_vintage_report] = fill_missing_vintage_columns(PREDICTORS_balanced);

PREDICTORS_balanced = trim_predictors_balanced(PREDICTORS_balanced, first_date, last_date);

%%
if direct == 0
    Target_scheme = 'SinglePeriod';
elseif direct == 1
    Target_scheme = 'SW';
end

%% Data Transformed

nb_var = size(PREDICTORS_balanced.data,3);
Hsize_by_var = zeros(1, nb_var);
base_Hsize_by_var = zeros(1, nb_var);
extra_nowcast_horizon = zeros(size(PREDICTORS_balanced.data, 2), nb_var);
if isfield(PREDICTORS_balanced, 'extra_nowcast_horizon')
    imported_extra_horizon = PREDICTORS_balanced.extra_nowcast_horizon;
    n_extra_vintages = min(size(imported_extra_horizon, 1), size(extra_nowcast_horizon, 1));
    n_extra_vars = min(size(imported_extra_horizon, 2), size(extra_nowcast_horizon, 2));
    extra_nowcast_horizon(1:n_extra_vintages, 1:n_extra_vars) = imported_extra_horizon(1:n_extra_vintages, 1:n_extra_vars);
end
required_nowcast_horizon = nan(size(PREDICTORS_balanced.data, 2), nb_var);
if isfield(PREDICTORS_balanced, 'required_nowcast_horizon')
    imported_required_horizon = PREDICTORS_balanced.required_nowcast_horizon;
    n_required_vintages = min(size(imported_required_horizon, 1), size(required_nowcast_horizon, 1));
    n_required_vars = min(size(imported_required_horizon, 2), size(required_nowcast_horizon, 2));
    required_nowcast_horizon(1:n_required_vintages, 1:n_required_vars) = imported_required_horizon(1:n_required_vintages, 1:n_required_vars);
end

% Pre-Store data
PREDICTORS_lev_now = struct();
PREDICTORS_lev_now.AR_p.data = PREDICTORS_balanced.data;
PREDICTORS_lev_now.AR_IC.data = PREDICTORS_balanced.data;
PREDICTORS_lev_now.SA.data = PREDICTORS_balanced.data;
PREDICTORS_lev_now.RW.data = PREDICTORS_balanced.data;

% Pre-Store obs
PREDICTORS_lev_now.AR_p.obs = PREDICTORS_balanced.obs;
PREDICTORS_lev_now.AR_IC.obs = PREDICTORS_balanced.obs;
PREDICTORS_lev_now.SA.obs = PREDICTORS_balanced.obs;
PREDICTORS_lev_now.RW.obs = PREDICTORS_balanced.obs;

% Pre-Store vintages
PREDICTORS_lev_now.AR_p.vintages = PREDICTORS_balanced.vintages;
PREDICTORS_lev_now.AR_IC.vintages = PREDICTORS_balanced.vintages;
PREDICTORS_lev_now.SA.vintages = PREDICTORS_balanced.vintages;
PREDICTORS_lev_now.RW.vintages = PREDICTORS_balanced.vintages;

level_model_fields = {'AR_p', 'AR_IC', 'RW', 'SA', 'BAR', 'BAR_SV', 'BAR_SVo'};
for mm = 1:numel(level_model_fields)
    model_name = level_model_fields{mm};
    if ~isfield(PREDICTORS_lev_now, model_name) || ~isfield(PREDICTORS_lev_now.(model_name), 'data')
        PREDICTORS_lev_now.(model_name).data = PREDICTORS_balanced.data;
    end
    PREDICTORS_lev_now.(model_name).obs = PREDICTORS_balanced.obs;
    PREDICTORS_lev_now.(model_name).vintages = PREDICTORS_balanced.vintages;
end

% Observed Predictors
observed_predictors.data = squeeze(PREDICTORS_balanced.data(:,end,:));
observed_predictors.obs = PREDICTORS_balanced.obs;

%%
pos_T10YFF = find(strcmp(pred_id,'T10YFF'));
if ~isempty(pos_T10YFF) && pos_T10YFF ~= nb_var
    error('non-nowcasted variables must be ordered last in the xlsx file')
end

%% Nowcasting

hx = waitbar(0,'Nowcasting Predictors...');
for y = 1:nb_var % For each predictor

    if strcmp("A35DVS",pred_id{y})==1 || strcmp("A35DTI",pred_id{y})==1 || strcmp("A31ANO",pred_id{y})==1 || strcmp("ANMNO",pred_id{y})==1
        base_Hsize = 3;
    elseif strcmp("T10YFF",pred_id{y})==1
        base_Hsize = 0;
    else 
        base_Hsize = 2;
    end

    Y_temp = squeeze(PREDICTORS_balanced.data(:,:,y));
    pos_1st_obs = find(~all(isnan(Y_temp), 2), 1);
    pos_1st_vin = find(~all(isnan(Y_temp), 1), 1);
    base_Hsize_by_var(y) = base_Hsize;
    if isempty(pos_1st_vin)
        extra_horizon_y = 0;
        required_horizon_y = [];
    else
        extra_horizon_y = extra_nowcast_horizon(pos_1st_vin:end, y);
        required_horizon_y = required_nowcast_horizon(pos_1st_vin:end, y);
    end
    Hsize = infer_nowcast_horizon(Y_temp, pos_1st_obs, pos_1st_vin, base_Hsize, extra_horizon_y, required_horizon_y);
    Hsize_by_var(y) = Hsize;
    Y = Y_temp(pos_1st_obs:end,pos_1st_vin:end);

    Y_observed = observed_predictors.data(pos_1st_obs:end,y);
    Y_dates = observed_predictors.obs(pos_1st_obs:end);

    % Number of out-of-sample periods
    Out_s = size(Y,2);

    % Store some objects
    results.(pred_id{y}) = struct();
    results.(pred_id{y}).SA.y_hat = nan(Hsize, Out_s);
    results.(pred_id{y}).SA.y_obs= nan(Hsize, Out_s);
    results.(pred_id{y}).SA.dates = NaT(Hsize, Out_s);
    results.(pred_id{y}).SA.eps= nan(Hsize, Out_s);
    results.(pred_id{y}).SA.eps_2= nan(Hsize, Out_s);
    results.(pred_id{y}).SA.MSPE = nan(1, Hsize);
    results.(pred_id{y}).SA.RMSPE = nan(1, Hsize);
    results.(pred_id{y}).SA.RMSPE_cum = nan(Hsize, Out_s);

    results.(pred_id{y}).RW.y_hat = nan(Hsize, Out_s);
    results.(pred_id{y}).RW.y_obs= nan(Hsize, Out_s);
    results.(pred_id{y}).RW.dates = NaT(Hsize, Out_s);
    results.(pred_id{y}).RW.eps= nan(Hsize, Out_s);
    results.(pred_id{y}).RW.eps_2= nan(Hsize, Out_s);
    results.(pred_id{y}).RW.MSPE = nan(1, Hsize);
    results.(pred_id{y}).RW.RMSPE = nan(1, Hsize);
    results.(pred_id{y}).RW.RMSPE_cum = nan(Hsize, Out_s);

    results.(pred_id{y}).AR_p.parameters = nan(Hsize, Out_s);
    results.(pred_id{y}).AR_p.y_hat = nan(Hsize, Out_s);
    results.(pred_id{y}).AR_p.y_obs= nan(Hsize, Out_s);
    results.(pred_id{y}).AR_p.dates = NaT(Hsize, Out_s);
    results.(pred_id{y}).AR_p.eps= nan(Hsize, Out_s);
    results.(pred_id{y}).AR_p.eps_2= nan(Hsize, Out_s);
    results.(pred_id{y}).AR_p.MSPE = nan(1, Hsize);
    results.(pred_id{y}).AR_p.RMSPE = nan(1, Hsize);
    results.(pred_id{y}).AR_p.RMSPE_cum = nan(Hsize, Out_s);

    results.(pred_id{y}).AR_IC.parameters = nan(Hsize, Out_s);
    results.(pred_id{y}).AR_IC.y_hat = nan(Hsize, Out_s);
    results.(pred_id{y}).AR_IC.y_obs= nan(Hsize, Out_s);
    results.(pred_id{y}).AR_IC.dates = NaT(Hsize, Out_s);
    results.(pred_id{y}).AR_IC.eps= nan(Hsize, Out_s);
    results.(pred_id{y}).AR_IC.eps_2= nan(Hsize, Out_s);
    results.(pred_id{y}).AR_IC.MSPE = nan(1, Hsize);
    results.(pred_id{y}).AR_IC.RMSPE = nan(1, Hsize);
    results.(pred_id{y}).AR_IC.RMSPE_cum = nan(Hsize, Out_s);

    results.(pred_id{y}).BAR.parameters = nan(Hsize, Out_s);
    results.(pred_id{y}).BAR.y_hat = nan(Hsize, Out_s);
    results.(pred_id{y}).BAR.y_obs= nan(Hsize, Out_s);
    results.(pred_id{y}).BAR.dates = NaT(Hsize, Out_s);
    results.(pred_id{y}).BAR.eps= nan(Hsize, Out_s);
    results.(pred_id{y}).BAR.eps_2= nan(Hsize, Out_s);
    results.(pred_id{y}).BAR.MSPE = nan(1, Hsize);
    results.(pred_id{y}).BAR.RMSPE = nan(1, Hsize);
    results.(pred_id{y}).BAR.RMSPE_cum = nan(Hsize, Out_s);

    results.(pred_id{y}).BAR_SV.parameters = nan(Hsize, Out_s);
    results.(pred_id{y}).BAR_SV.y_hat = nan(Hsize, Out_s);
    results.(pred_id{y}).BAR_SV.y_obs= nan(Hsize, Out_s);
    results.(pred_id{y}).BAR_SV.dates = NaT(Hsize, Out_s);
    results.(pred_id{y}).BAR_SV.eps= nan(Hsize, Out_s);
    results.(pred_id{y}).BAR_SV.eps_2= nan(Hsize, Out_s);
    results.(pred_id{y}).BAR_SV.MSPE = nan(1, Hsize);
    results.(pred_id{y}).BAR_SV.RMSPE = nan(1, Hsize);
    results.(pred_id{y}).BAR_SV.RMSPE_cum = nan(Hsize, Out_s);

    results.(pred_id{y}).BAR_SVo.parameters = nan(Hsize, Out_s);
    results.(pred_id{y}).BAR_SVo.y_hat = nan(Hsize, Out_s);
    results.(pred_id{y}).BAR_SVo.y_obs= nan(Hsize, Out_s);
    results.(pred_id{y}).BAR_SVo.dates = NaT(Hsize, Out_s);
    results.(pred_id{y}).BAR_SVo.eps= nan(Hsize, Out_s);
    results.(pred_id{y}).BAR_SVo.eps_2= nan(Hsize, Out_s);
    results.(pred_id{y}).BAR_SVo.MSPE = nan(1, Hsize);
    results.(pred_id{y}).BAR_SVo.RMSPE = nan(1, Hsize);
    results.(pred_id{y}).BAR_SVo.RMSPE_cum = nan(Hsize, Out_s);

    hxx = waitbar(0,'pred_id{y}');

    for hor = 1:Hsize % For each horizon

        tcode_y = predictors_transfomations(y);

        % Transform Predictors data
        % Dependent variable
        Yg = Building_target(Y,tcode_y,Target_scheme,hor);
        Yg_tr_3 = Building_target(Y,3,Target_scheme,hor);
        % Lagged regressors
        Yd = Building_regressors(Y,tcode_y);
        % Observed evaluation values are computed directly from Y_observed
        % at the actual vintage edge.

        % Cut predictors
        if max(predictors_transfomations) == 0 || max(predictors_transfomations) == 1
            cut_pred = 0;
        elseif max(predictors_transfomations) == 2 || max(predictors_transfomations) == 3
            cut_pred = 1;
        elseif max(predictors_transfomations) == 4 || max(predictors_transfomations) == 5
            cut_pred = 2;
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
        elseif cut_y > cut_pred
            Yd(1:cut_hor_y,:) = [];
        elseif cut_y < cut_pred
            difference = cut_pred - cut_y;
            cut_Yd = max (difference, cut_hor_y);
            Yd(1:cut_Yd,:) = [];
            if cut_hor_y < difference
                cut_Yg = difference - cut_hor_y;
                Yg(1:cut_Yg,:) = [];
            end
        end

        last_observed_by_vintage = nan(1, Out_s);
        for vv = 1:Out_s
            last_observed_vv = find(~isnan(Y(:, vv)), 1, 'last');
            if ~isempty(last_observed_vv)
                last_observed_by_vintage(vv) = last_observed_vv;
            end
        end
        first_last_observed_pos = find(~isnan(last_observed_by_vintage), 1, 'first');
        if isempty(first_last_observed_pos)
            rolling_start_by_vintage = ones(1, Out_s);
        else
            first_last_observed = last_observed_by_vintage(first_last_observed_pos);
            rolling_start_by_vintage = max(1, last_observed_by_vintage - first_last_observed + 1);
            rolling_start_by_vintage(isnan(rolling_start_by_vintage)) = 1;
        end
        
         for tt = 1:Out_s - hor + 1% For each OOS period
            
            % disp(tt)

            % Store observed value for forecast evaluation
            [real_Y.value, real_Y.value_tr_3, real_Y_idx] = nowcast_observed_target(Y_observed, last_observed_by_vintage(tt), hor, tcode_y, Target_scheme);
            if isnan(real_Y_idx) || real_Y_idx < 1 || real_Y_idx > numel(Y_dates)
                real_Y.date = NaT;
            else
                real_Y.date = Y_dates(real_Y_idx);
            end

            if rollwind == 0 % Expanding Window
                Ygg = squeeze(Yg(:,tt));
                Ygg_tr_3 = squeeze(Yg_tr_3(:,tt));
                Ydd = squeeze(Yd(:,tt));

                [Y_g, Y_d] = align_target_regressor(Ygg, Ydd);
                Y_g_tr_3 = Ygg_tr_3(isfinite(Ygg_tr_3));

                % Model: RW (level)
                Yhat = 0;
                results.(pred_id{y}).RW.y_hat(hor, tt) = Yhat;
                results.(pred_id{y}).RW.y_obs(hor,tt) = real_Y.value_tr_3;
                results.(pred_id{y}).RW.dates(hor,tt) = real_Y.date;
                results.(pred_id{y}).RW.eps(hor, tt) = Yhat - real_Y.value;

                % Model: SA (RW + Drift)
                Yhat = mean(Y_g_tr_3);
                results.(pred_id{y}).SA.y_hat(hor, tt) = Yhat;
                results.(pred_id{y}).SA.y_obs(hor,tt) = real_Y.value_tr_3;
                results.(pred_id{y}).SA.dates(hor,tt) = real_Y.date;
                results.(pred_id{y}).SA.eps(hor, tt) = Yhat - real_Y.value;

                % Model: AR(p)
                lags = 'manual';
                [Yhat, P_ic] = AR_new(lags, direct, IC, hor, Pn, P_AR, Y_g, Y_d);
                results.(pred_id{y}).AR_p.parameters(hor, tt) = P_ic;
                results.(pred_id{y}).AR_p.y_hat(hor, tt) = Yhat;
                results.(pred_id{y}).AR_p.y_obs(hor,tt) = real_Y.value;
                results.(pred_id{y}).AR_p.dates(hor,tt) = real_Y.date;
                results.(pred_id{y}).AR_p.eps(hor, tt) = Yhat - real_Y.value;

                % Model: AR(AIC)
                lags = 'i_criteria';
                [Yhat, P_ic] = AR_new(lags, direct, IC, hor, Pn, P_AR, Y_g, Y_d);
                results.(pred_id{y}).AR_IC.parameters(hor, tt) = P_ic;
                results.(pred_id{y}).AR_IC.y_hat(hor, tt) = Yhat;
                results.(pred_id{y}).AR_IC.y_obs(hor,tt) = real_Y.value;
                results.(pred_id{y}).AR_IC.dates(hor,tt) = real_Y.date;
                results.(pred_id{y}).AR_IC.eps(hor, tt) = Yhat - real_Y.value;

                % Model: BAR(1)
                [Yhat, P] = safe_bayesian_nowcast('BAR', direct, hor, Y_g, Y_d, Hsize, ngibbs, nburn, tcode_y);
                results.(pred_id{y}).BAR.parameters(hor, tt) = P;
                results.(pred_id{y}).BAR.y_hat(hor, tt) = Yhat;
                results.(pred_id{y}).BAR.y_obs(hor,tt) = real_Y.value;
                results.(pred_id{y}).BAR.dates(hor,tt) = real_Y.date;
                results.(pred_id{y}).BAR.eps(hor, tt) = Yhat - real_Y.value;

                % Model: BAR-SV(1)
                [Yhat, P] = safe_bayesian_nowcast('BAR_SV', direct, hor, Y_g, Y_d, Hsize, ngibbs, nburn, tcode_y);
                results.(pred_id{y}).BAR_SV.parameters(hor, tt) = P;
                results.(pred_id{y}).BAR_SV.y_hat(hor, tt) = Yhat;
                results.(pred_id{y}).BAR_SV.y_obs(hor,tt) = real_Y.value;
                results.(pred_id{y}).BAR_SV.dates(hor,tt) = real_Y.date;
                results.(pred_id{y}).BAR_SV.eps(hor, tt) = Yhat - real_Y.value;

                % Model: BAR-SVo(1)
                [Yhat, P] = safe_bayesian_nowcast('BAR_SVo', direct, hor, Y_g, Y_d, Hsize, ngibbs, nburn, tcode_y);
                results.(pred_id{y}).BAR_SVo.parameters(hor, tt) = P;
                results.(pred_id{y}).BAR_SVo.y_hat(hor, tt) = Yhat;
                results.(pred_id{y}).BAR_SVo.y_obs(hor,tt) = real_Y.value;
                results.(pred_id{y}).BAR_SVo.dates(hor,tt) = real_Y.date;
                results.(pred_id{y}).BAR_SVo.eps(hor, tt) = Yhat - real_Y.value;

            elseif rollwind == 1 % Rolling Window
                
                count = rolling_start_by_vintage(tt);
                Ygg = squeeze(Yg(count:end,tt));
                Ygg_tr_3 = squeeze(Yg_tr_3(count:end,tt));
                Ydd = squeeze(Yd(count:end,tt));

                [Y_g, Y_d] = align_target_regressor(Ygg, Ydd);
                Y_g_tr_3 = Ygg_tr_3(isfinite(Ygg_tr_3));

                % Model: RW + Drift(level) - Sample Average
                Yhat = mean(Y_g_tr_3);
                results.(pred_id{y}).SA.y_hat(hor, tt) = Yhat;
                results.(pred_id{y}).SA.y_obs(hor,tt) = real_Y.value_tr_3;
                results.(pred_id{y}).SA.dates(hor,tt) = real_Y.date;
                results.(pred_id{y}).SA.eps(hor, tt) = Yhat - real_Y.value;

                % Model: RW
                Yhat = 0;
                results.(pred_id{y}).RW.y_hat(hor, tt) = Yhat;
                results.(pred_id{y}).RW.y_obs(hor,tt) = real_Y.value_tr_3;
                results.(pred_id{y}).RW.dates(hor,tt) = real_Y.date;
                results.(pred_id{y}).RW.eps(hor, tt) = Yhat - real_Y.value;

                % Model: AR(p)
                lags = 'manual';
                [Yhat, P_ic] = AR_new(lags, direct, IC, hor, Pn, P_AR, Y_g, Y_d);
                results.(pred_id{y}).AR_p.parameters(hor, tt) = P_ic;
                results.(pred_id{y}).AR_p.y_hat(hor, tt) = Yhat;
                results.(pred_id{y}).AR_p.y_obs(hor,tt) = real_Y.value;
                results.(pred_id{y}).AR_p.dates(hor,tt) = real_Y.date;
                results.(pred_id{y}).AR_p.eps(hor, tt) = Yhat - real_Y.value;

                % Model: AR(AIC)
                lags = 'i_criteria';
                [Yhat, P_ic] = AR_new(lags, direct, IC, hor, Pn, P_AR, Y_g, Y_d);
                results.(pred_id{y}).AR_IC.parameters(hor, tt) = P_ic;
                results.(pred_id{y}).AR_IC.y_hat(hor, tt) = Yhat;
                results.(pred_id{y}).AR_IC.y_obs(hor,tt) = real_Y.value;
                results.(pred_id{y}).AR_IC.dates(hor,tt) = real_Y.date;
                results.(pred_id{y}).AR_IC.eps(hor, tt) = Yhat - real_Y.value;

                % Model: BAR(1)
                [Yhat, P] = safe_bayesian_nowcast('BAR', direct, hor, Y_g, Y_d, Hsize, ngibbs, nburn, tcode_y);
                results.(pred_id{y}).BAR.parameters(hor, tt) = P;
                results.(pred_id{y}).BAR.y_hat(hor, tt) = Yhat;
                results.(pred_id{y}).BAR.y_obs(hor,tt) = real_Y.value;
                results.(pred_id{y}).BAR.dates(hor,tt) = real_Y.date;
                results.(pred_id{y}).BAR.eps(hor, tt) = Yhat - real_Y.value;

                % Model: BAR-SV(1)
                [Yhat, P] = safe_bayesian_nowcast('BAR_SV', direct, hor, Y_g, Y_d, Hsize, ngibbs, nburn, tcode_y);
                results.(pred_id{y}).BAR_SV.parameters(hor, tt) = P;
                results.(pred_id{y}).BAR_SV.y_hat(hor, tt) = Yhat;
                results.(pred_id{y}).BAR_SV.y_obs(hor,tt) = real_Y.value;
                results.(pred_id{y}).BAR_SV.dates(hor,tt) = real_Y.date;
                results.(pred_id{y}).BAR_SV.eps(hor, tt) = Yhat - real_Y.value;

                % Model: BAR-SVo(1)
                [Yhat, P] = safe_bayesian_nowcast('BAR_SVo', direct, hor, Y_g, Y_d, Hsize, ngibbs, nburn, tcode_y);
                results.(pred_id{y}).BAR_SVo.parameters(hor, tt) = P;
                results.(pred_id{y}).BAR_SVo.y_hat(hor, tt) = Yhat;
                results.(pred_id{y}).BAR_SVo.y_obs(hor,tt) = real_Y.value;
                results.(pred_id{y}).BAR_SVo.dates(hor,tt) = real_Y.date;
                results.(pred_id{y}).BAR_SVo.eps(hor, tt) = Yhat - real_Y.value;

            end
         end

        waitbar(hor/Hsize, hxx, sprintf('Nowcasting: %s %2.2f%%', pred_id{y}, (hor/Hsize)*100));
    end  
    close(hxx)
waitbar(y/nb_var,hx,sprintf('Nowcasting Predictors: %2.2f',(y/nb_var*100)));
end
close(hx)
results.Hsize_by_var = array2table(Hsize_by_var(:), 'VariableNames', {'Hsize'}, 'RowNames', cellstr(pred_id(:)));
results.base_Hsize_by_var = array2table(base_Hsize_by_var(:), 'VariableNames', {'base_Hsize'}, 'RowNames', cellstr(pred_id(:)));
results.extra_nowcast_horizon = extra_nowcast_horizon;
results.required_nowcast_horizon = required_nowcast_horizon;
results.missing_vintage_report = missing_vintage_report;

%% Tables RMSPE

Hsize_table = max(Hsize_by_var);

% RW Benchmark
results.TABLES.table_RMSPE_SA = nan(Hsize_table,nb_var);
results.TABLES.table_RMSPE_AR_p = nan(Hsize_table,nb_var);
results.TABLES.table_RMSPE_AR_ic = nan(Hsize_table,nb_var);
results.TABLES.table_RMSPE_BAR = nan(Hsize_table,nb_var);
results.TABLES.table_RMSPE_BAR_SV = nan(Hsize_table,nb_var);
results.TABLES.table_RMSPE_BAR_SVo = nan(Hsize_table,nb_var);

for dd = 1:nb_var

    Hsize_var = Hsize_by_var(dd);

    for h=1:Hsize_var
        results.TABLES.table_RMSPE_SA(h,dd) = results.(pred_id{dd}).SA.RMSPE(1,h);
        results.TABLES.table_RMSPE_AR_p(h,dd) = results.(pred_id{dd}).AR_p.RMSPE(1,h);
        results.TABLES.table_RMSPE_AR_ic(h,dd) = results.(pred_id{dd}).AR_IC.RMSPE(1,h);
        results.TABLES.table_RMSPE_BAR(h,dd) = results.(pred_id{dd}).BAR.RMSPE(1,h);
        results.TABLES.table_RMSPE_BAR_SV(h,dd) = results.(pred_id{dd}).BAR_SV.RMSPE(1,h);
        results.TABLES.table_RMSPE_BAR_SVo(h,dd) = results.(pred_id{dd}).BAR_SVo.RMSPE(1,h);
    end

end

%% Tables Ratio 

Hsize_table = max(Hsize_by_var);

% RW Benchmark
results.TABLES.table_AR_p_SA = nan(Hsize_table,nb_var);
results.TABLES.table_AR_ic_SA = nan(Hsize_table,nb_var);
results.TABLES.table_BAR_SA = nan(Hsize_table,nb_var);
results.TABLES.table_BAR_SV_SA = nan(Hsize_table,nb_var);
results.TABLES.table_BAR_SA_SVo = nan(Hsize_table,nb_var);

for dd = 1:nb_var
    Hsize_var = Hsize_by_var(dd);

    for h=1:Hsize_var
        results.TABLES.table_AR_p_SA(h,dd) = results.(pred_id{dd}).AR_p.RMSPE(1,h)/results.(pred_id{dd}).SA.RMSPE(1,h);
        results.TABLES.table_AR_ic_SA(h,dd) = results.(pred_id{dd}).AR_IC.RMSPE(1,h)/results.(pred_id{dd}).SA.RMSPE(1,h);
        results.TABLES.table_BAR_SA(h,dd) = results.(pred_id{dd}).BAR.RMSPE(1,h)/results.(pred_id{dd}).SA.RMSPE(1,h);
        results.TABLES.table_BAR_SV_SA(h,dd) = results.(pred_id{dd}).BAR_SV.RMSPE(1,h)/results.(pred_id{dd}).SA.RMSPE(1,h);
        results.TABLES.table_BAR_SVo_SA(h,dd) = results.(pred_id{dd}).BAR_SVo.RMSPE(1,h)/results.(pred_id{dd}).SA.RMSPE(1,h);
    end

end

%% 

PREDICTORS_lev_now = fill_nowcast_level_edges(PREDICTORS_lev_now, PREDICTORS_balanced, results, pred_id, predictors_transfomations, Hsize_by_var, base_Hsize_by_var, extra_nowcast_horizon, required_nowcast_horizon);

for y = 1:nb_var
    Hsize_var = Hsize_by_var(y);
    for hor = 1:Hsize_var
        level_eval_end = size(results.(pred_id{y}).AR_p.eps, 2) - hor;
        if level_eval_end < 1
            continue
        end
        level_eval_idx = 1:level_eval_end;

        % Squared eps - level
        results.(pred_id{y}).AR_p.eps_2(hor, level_eval_idx) = PREDICTORS_lev_now.AR_p.eps(hor,level_eval_idx,y).^2;
        results.(pred_id{y}).AR_IC.eps_2(hor, level_eval_idx) = PREDICTORS_lev_now.AR_IC.eps(hor,level_eval_idx,y).^2;
        results.(pred_id{y}).RW.eps_2(hor, level_eval_idx) = PREDICTORS_lev_now.RW.eps(hor,level_eval_idx,y).^2;
        results.(pred_id{y}).SA.eps_2(hor, level_eval_idx) = PREDICTORS_lev_now.SA.eps(hor,level_eval_idx,y).^2;
        results.(pred_id{y}).BAR.eps_2(hor, level_eval_idx) = PREDICTORS_lev_now.BAR.eps(hor,level_eval_idx,y).^2;
        results.(pred_id{y}).BAR_SV.eps_2(hor, level_eval_idx) = PREDICTORS_lev_now.BAR_SV.eps(hor,level_eval_idx,y).^2;
        results.(pred_id{y}).BAR_SVo.eps_2(hor, level_eval_idx) = PREDICTORS_lev_now.BAR_SVo.eps(hor,level_eval_idx,y).^2;

        % DM Test
        nested_flag = 0;
        results.(pred_id{y}).AR_p.DM_p_value(1,hor) = dm_p_value_clean(results.(pred_id{y}).SA.eps_2(hor, level_eval_idx)',results.(pred_id{y}).AR_p.eps_2(hor, level_eval_idx)',hor,nested_flag);
        results.(pred_id{y}).AR_IC.DM_p_value(1,hor) = dm_p_value_clean(results.(pred_id{y}).SA.eps_2(hor, level_eval_idx)',results.(pred_id{y}).AR_IC.eps_2(hor, level_eval_idx)',hor,nested_flag);
        results.(pred_id{y}).RW.DM_p_value(1,hor) = dm_p_value_clean(results.(pred_id{y}).SA.eps_2(hor, level_eval_idx)',results.(pred_id{y}).RW.eps_2(hor, level_eval_idx)',hor,nested_flag);
        results.(pred_id{y}).SA.DM_p_value(1,hor) = dm_p_value_clean(results.(pred_id{y}).SA.eps_2(hor, level_eval_idx)',results.(pred_id{y}).SA.eps_2(hor, level_eval_idx)',hor,nested_flag);
        results.(pred_id{y}).BAR.DM_p_value(1,hor) = dm_p_value_clean(results.(pred_id{y}).SA.eps_2(hor, level_eval_idx)',results.(pred_id{y}).BAR.eps_2(hor, level_eval_idx)',hor,nested_flag);
        results.(pred_id{y}).BAR_SV.DM_p_value(1,hor) = dm_p_value_clean(results.(pred_id{y}).SA.eps_2(hor, level_eval_idx)',results.(pred_id{y}).BAR_SV.eps_2(hor, level_eval_idx)',hor,nested_flag);
        results.(pred_id{y}).BAR_SVo.DM_p_value(1,hor) = dm_p_value_clean(results.(pred_id{y}).SA.eps_2(hor, level_eval_idx)',results.(pred_id{y}).BAR_SVo.eps_2(hor, level_eval_idx)',hor,nested_flag);

        % MSPE level
        results.(pred_id{y}).AR_p.MSPE_level(1,hor) = mean(PREDICTORS_lev_now.AR_p.eps(hor,level_eval_idx,y).^2,2,'omitnan');
        results.(pred_id{y}).AR_IC.MSPE_level(1,hor) = mean(PREDICTORS_lev_now.AR_IC.eps(hor,level_eval_idx,y).^2,2,'omitnan');
        results.(pred_id{y}).RW.MSPE_level(1,hor) = mean(PREDICTORS_lev_now.RW.eps(hor,level_eval_idx,y).^2,2,'omitnan');
        results.(pred_id{y}).SA.MSPE_level(1,hor) = mean(PREDICTORS_lev_now.SA.eps(hor,level_eval_idx,y).^2,2,'omitnan');
        results.(pred_id{y}).BAR.MSPE_level(1,hor) = mean(PREDICTORS_lev_now.BAR.eps(hor,level_eval_idx,y).^2,2,'omitnan');
        results.(pred_id{y}).BAR_SV.MSPE_level(1,hor) = mean(PREDICTORS_lev_now.BAR_SV.eps(hor,level_eval_idx,y).^2,2,'omitnan');
        results.(pred_id{y}).BAR_SVo.MSPE_level(1,hor) = mean(PREDICTORS_lev_now.BAR_SVo.eps(hor,level_eval_idx,y).^2,2,'omitnan');
        
        % RMSPE level
        results.(pred_id{y}).AR_p.RMSPE_level(1,hor) = sqrt(results.(pred_id{y}).AR_p.MSPE_level(1,hor));
        results.(pred_id{y}).AR_IC.RMSPE_level(1,hor) = sqrt(results.(pred_id{y}).AR_IC.MSPE_level(1,hor));
        results.(pred_id{y}).RW.RMSPE_level(1,hor) = sqrt(results.(pred_id{y}).RW.MSPE_level(1,hor));
        results.(pred_id{y}).SA.RMSPE_level(1,hor) = sqrt(results.(pred_id{y}).SA.MSPE_level(1,hor));
        results.(pred_id{y}).BAR.RMSPE_level(1,hor) = sqrt(results.(pred_id{y}).BAR.MSPE_level(1,hor));
        results.(pred_id{y}).BAR_SV.RMSPE_level(1,hor) = sqrt(results.(pred_id{y}).BAR_SV.MSPE_level(1,hor));
        results.(pred_id{y}).BAR_SVo.RMSPE_level(1,hor) = sqrt(results.(pred_id{y}).BAR_SVo.MSPE_level(1,hor));
       
    end
end

%% Tables RMSPE - level

Hsize_table = max(Hsize_by_var);

% RW Benchmark
results.TABLES_RMSPE_level.table_SA = nan(Hsize_table,nb_var);
results.TABLES_RMSPE_level.table_AR_p = nan(Hsize_table,nb_var);
results.TABLES_RMSPE_level.table_AR_ic = nan(Hsize_table,nb_var);
results.TABLES_RMSPE_level.table_BAR = nan(Hsize_table,nb_var);
results.TABLES_RMSPE_level.table_BAR_SV = nan(Hsize_table,nb_var);
results.TABLES_RMSPE_level.table_BAR_SVo = nan(Hsize_table,nb_var);

for dd = 1:nb_var
    Hsize_var = Hsize_by_var(dd);

    for h=1:Hsize_var
        results.TABLES_RMSPE_level.table_SA(h,dd) = results.(pred_id{dd}).SA.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.table_AR_p(h,dd) = results.(pred_id{dd}).AR_p.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.table_AR_ic(h,dd) = results.(pred_id{dd}).AR_IC.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.table_BAR(h,dd) = results.(pred_id{dd}).BAR.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.table_BAR_SV(h,dd) = results.(pred_id{dd}).BAR_SV.RMSPE_level(1,h);
        results.TABLES_RMSPE_level.table_BAR_SVo(h,dd) = results.(pred_id{dd}).BAR_SVo.RMSPE_level(1,h);
    end
end

%% Tables Ratio - level

% RW Benchmark
results.TABLES_level.AR_p = nan(Hsize_table,nb_var);
results.TABLES_level.AR_IC = nan(Hsize_table,nb_var);
results.TABLES_level.BAR = nan(Hsize_table,nb_var);
results.TABLES_level.BAR_SV = nan(Hsize_table,nb_var);
results.TABLES_level.BAR_SVo = nan(Hsize_table,nb_var);
results.TABLES_level.SA = nan(Hsize_table,nb_var);
results.TABLES_level.RW = nan(Hsize_table,nb_var);

for dd = 1:nb_var
    Hsize_var = Hsize_by_var(dd);

    for h=1:Hsize_var
        results.TABLES_level.AR_p(h,dd) = results.(pred_id{dd}).AR_p.RMSPE_level(1,h)/results.(pred_id{dd}).SA.RMSPE_level(1,h);
        results.TABLES_level.AR_IC(h,dd) = results.(pred_id{dd}).AR_IC.RMSPE_level(1,h)/results.(pred_id{dd}).SA.RMSPE_level(1,h);
        results.TABLES_level.SA(h,dd) = results.(pred_id{dd}).SA.RMSPE_level(1,h)/results.(pred_id{dd}).SA.RMSPE_level(1,h);
        results.TABLES_level.RW(h,dd) = results.(pred_id{dd}).RW.RMSPE_level(1,h)/results.(pred_id{dd}).SA.RMSPE_level(1,h);
        results.TABLES_level.BAR(h,dd) = results.(pred_id{dd}).BAR.RMSPE_level(1,h)/results.(pred_id{dd}).SA.RMSPE_level(1,h);
        results.TABLES_level.BAR_SV(h,dd) = results.(pred_id{dd}).BAR_SV.RMSPE_level(1,h)/results.(pred_id{dd}).SA.RMSPE_level(1,h);
        results.TABLES_level.BAR_SVo(h,dd) = results.(pred_id{dd}).BAR_SVo.RMSPE_level(1,h)/results.(pred_id{dd}).SA.RMSPE_level(1,h);
    end
end

%% Tables Ratio - Reshaped

modelli = fieldnames(results.(pred_id{1}));

for y = 1:length(modelli)
results.tables_ratio_long.(modelli{y}) = NaN(Hsize_table, nb_var);
results.tables_ratio_long_p_value.(modelli{y}) = cell(Hsize_table, nb_var);
end


for model = 1:length(modelli)
    for y = 1:nb_var
        for horizon = 1:Hsize_table
            results.tables_ratio_long.(modelli{model})(horizon, y) = results.TABLES_level.(modelli{model})(horizon,y);
        end
    end
end

for model = 1:length(modelli)
     for y = 1:nb_var
        Hsize_var = Hsize_by_var(y);
        for horizon = 1:Hsize_table
            ratio = results.TABLES_level.(modelli{model})(horizon,y);
            results.tables_ratio_long.(modelli{model})(horizon, y) = results.TABLES_level.(modelli{model})(horizon,y);

            if horizon <= Hsize_var
                p_value = results.(pred_id{y}).(modelli{model}).DM_p_value(1,horizon);
            else
                p_value = NaN;
            end

            if (p_value >= 0.05 && p_value < 0.1) || (p_value > 0.9 && p_value <= 0.95)
                results.tables_ratio_long_p_value.(modelli{model}){horizon, y} = strcat(num2str(ratio), '*');
            elseif (p_value >= 0.01 && p_value < 0.05) || (p_value > 0.95 && p_value <= 0.99)
                results.tables_ratio_long_p_value.(modelli{model}){horizon, y} = strcat(num2str(ratio), '**');
            elseif p_value < 0.01 || p_value > 0.99
                results.tables_ratio_long_p_value.(modelli{model}){horizon, y} = strcat(num2str(ratio), '***');
            else
                results.tables_ratio_long_p_value.(modelli{model}){horizon, y} = num2str(ratio);
            end
        end
    end
end
%% Store IDs

PREDICTORS_lev_now.RW.id = pred_id;
PREDICTORS_lev_now.SA.id = pred_id;
PREDICTORS_lev_now.AR_p.id = pred_id;
PREDICTORS_lev_now.AR_IC.id = pred_id;
PREDICTORS_lev_now.BAR.id = pred_id;
PREDICTORS_lev_now.BAR_SV.id = pred_id;
PREDICTORS_lev_now.BAR_SVo.id = pred_id;

end

function p_value = dm_p_value_clean(benchmark_eps_2, model_eps_2, hor, nested_flag)

valid_idx = isfinite(benchmark_eps_2) & isfinite(model_eps_2);
benchmark_eps_2 = benchmark_eps_2(valid_idx);
model_eps_2 = model_eps_2(valid_idx);

if numel(benchmark_eps_2) <= hor + 1
    p_value = NaN;
    return
end

p_value = test_DM(benchmark_eps_2, model_eps_2, hor, nested_flag);

end

function [Y_g, Y_d] = align_target_regressor(Ygg, Ydd)

Ygg = Ygg(:);
Ydd = Ydd(:);
last_regressor = find(isfinite(Ydd), 1, 'last');

if isempty(last_regressor)
    Y_g = [];
    Y_d = [];
    return
end

Y_d = Ydd(1:last_regressor);
Y_g = NaN(last_regressor, 1);
n_target = min(numel(Ygg), last_regressor);
Y_g(1:n_target) = Ygg(1:n_target);

end

function [Yhat, P] = safe_bayesian_nowcast(model_name, direct, hor, Y_g, Y_d, Hsize, ngibbs, nburn, tcode_y)

Yhat = NaN;
P = NaN;

try
    if strcmp(model_name, 'BAR')
        [Yhat, P] = BAR_new(direct, hor, Y_g, Y_d, Hsize, ngibbs, nburn, tcode_y);
    elseif strcmp(model_name, 'BAR_SV')
        [Yhat, P] = BAR_SV_new(direct, hor, Y_g, Y_d, Hsize, ngibbs, nburn, tcode_y);
    elseif strcmp(model_name, 'BAR_SVo')
        [Yhat, P] = BAR_SVo_new(direct, hor, Y_g, Y_d, Hsize, ngibbs, nburn, tcode_y);
    else
        error('Unknown Bayesian nowcast model: %s', model_name);
    end
catch
    Yhat = NaN;
    P = NaN;
end

end
