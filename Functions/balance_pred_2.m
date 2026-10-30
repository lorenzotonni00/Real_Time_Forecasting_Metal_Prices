function [PREDICTORS_now_balanced] = balance_pred_2(PREDICTORS_lev_now)

%% Balanced predictors dataset
nb_obs = size(PREDICTORS_lev_now.AR_p.data,1);
nb_vin = size(PREDICTORS_lev_now.AR_p.data,2);
nb_var = size(PREDICTORS_lev_now.AR_p.data,3);

%% Find NaN

% NaN rows (obs)
first_non_nan_rows = nan(nb_var,1);
for i = 1:nb_var 
    matrix = PREDICTORS_lev_now.AR_p.data(:,:,i);
    for r = 1:nb_obs 
        onlyNaN = all(isnan(matrix(r, :)));
        if onlyNaN == 0
            first_non_nan_rows(i,1) = r;
            break
        end
    end
end

% NaN columns (vintages)
first_non_nan_columns = nan(nb_var,1);
for i = 1:nb_var
    matrix = PREDICTORS_lev_now.AR_p.data(:,:,i);
    for r = 1:nb_vin
        onlyNaN = all(isnan(matrix(:, r)));
        if onlyNaN == 0
            first_non_nan_columns(i,1) = r;
            break
        end
    end
end

%% Balance

max_nan_rows = max(first_non_nan_rows);
max_nan_columns = max(first_non_nan_columns);

predictors_balanced_AR_p = PREDICTORS_lev_now.AR_p.data(max_nan_rows:end, max_nan_columns:end,:);
predictors_balanced_AR_IC = PREDICTORS_lev_now.AR_IC.data(max_nan_rows:end, max_nan_columns:end,:);
predictors_balanced_RW = PREDICTORS_lev_now.RW.data(max_nan_rows:end, max_nan_columns:end,:);
predictors_balanced_SA = PREDICTORS_lev_now.SA.data(max_nan_rows:end, max_nan_columns:end,:);
predictors_balanced_BAR = PREDICTORS_lev_now.BAR.data(max_nan_rows:end, max_nan_columns:end,:);
predictors_balanced_BAR_SV = PREDICTORS_lev_now.BAR_SV.data(max_nan_rows:end, max_nan_columns:end,:);
predictors_balanced_BAR_SVo = PREDICTORS_lev_now.BAR_SVo.data(max_nan_rows:end, max_nan_columns:end,:);

% observations
obs_balanced = PREDICTORS_lev_now.AR_p.obs(max_nan_rows:end); 

% vintages
vin_balanced = PREDICTORS_lev_now.AR_p.vintages(max_nan_columns:end); 

%-----------------------------------------

PREDICTORS_now_balanced.AR_p.data = predictors_balanced_AR_p;
PREDICTORS_now_balanced.AR_IC.data = predictors_balanced_AR_IC;
PREDICTORS_now_balanced.RW.data = predictors_balanced_RW;
PREDICTORS_now_balanced.SA.data = predictors_balanced_SA;
PREDICTORS_now_balanced.BAR.data = predictors_balanced_BAR;
PREDICTORS_now_balanced.BAR_SV.data = predictors_balanced_BAR_SV;
PREDICTORS_now_balanced.BAR_SVo.data = predictors_balanced_BAR_SVo;

PREDICTORS_now_balanced.AR_p.obs = obs_balanced;
PREDICTORS_now_balanced.AR_IC.obs = obs_balanced;
PREDICTORS_now_balanced.RW.obs = obs_balanced;
PREDICTORS_now_balanced.SA.obs = obs_balanced;
PREDICTORS_now_balanced.BAR.obs = obs_balanced;
PREDICTORS_now_balanced.BAR_SV.obs = obs_balanced;
PREDICTORS_now_balanced.BAR_SVo.obs = obs_balanced;

PREDICTORS_now_balanced.AR_p.vintages = vin_balanced;
PREDICTORS_now_balanced.AR_IC.vintages = vin_balanced;
PREDICTORS_now_balanced.RW.vintages = vin_balanced;
PREDICTORS_now_balanced.SA.vintages = vin_balanced;
PREDICTORS_now_balanced.BAR.vintages = vin_balanced;
PREDICTORS_now_balanced.BAR_SV.vintages = vin_balanced;
PREDICTORS_now_balanced.BAR_SVo.vintages = vin_balanced;

PREDICTORS_now_balanced.AR_p.id = PREDICTORS_lev_now.AR_p.id;
PREDICTORS_now_balanced.AR_IC.id = PREDICTORS_lev_now.AR_IC.id;
PREDICTORS_now_balanced.RW.id = PREDICTORS_lev_now.RW.id;
PREDICTORS_now_balanced.SA.id = PREDICTORS_lev_now.SA.id;
PREDICTORS_now_balanced.BAR.id = PREDICTORS_lev_now.BAR.id;
PREDICTORS_now_balanced.BAR_SV.id = PREDICTORS_lev_now.BAR_SV.id;
PREDICTORS_now_balanced.BAR_SVo.id = PREDICTORS_lev_now.BAR_SVo.id;

if isfield(PREDICTORS_lev_now, 'contains_nowcasted_values')
    PREDICTORS_now_balanced.contains_nowcasted_values = PREDICTORS_lev_now.contains_nowcasted_values;
end
if isfield(PREDICTORS_lev_now, 'missing_vintage_report')
    PREDICTORS_now_balanced.missing_vintage_report = PREDICTORS_lev_now.missing_vintage_report;
end

end
