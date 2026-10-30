function [PREDICTORS_balanced, PREDICTORS_nan, pred_id] = import_predictors_fr

%% Import raw data
INDPRO        = readtable('data_FR.xlsx','Sheet','INDPRO','VariableNamingRule','preserve');
A31SNO        = readtable('data_FR.xlsx','Sheet','A31SNO','VariableNamingRule','preserve');
CPIAUCSL      = readtable('data_FR.xlsx','Sheet','CPIAUCSL','VariableNamingRule','preserve');
AWHMAN        = readtable('data_FR.xlsx','Sheet','AWHMAN','VariableNamingRule','preserve');
A35DVS        = readtable('data_FR.xlsx','Sheet','A35DVS','VariableNamingRule','preserve');
PCU331331    = readtable('data_FR.xlsx','Sheet','PCU331331','VariableNamingRule','preserve');
PCU335911335911 = readtable('data_FR.xlsx','Sheet','PCU335911335911','VariableNamingRule','preserve');
RBCLBIS     = readtable('data_FR.xlsx','Sheet','RBCLBIS','VariableNamingRule','preserve');
RBAUBIS         = readtable('data_FR.xlsx','Sheet','RBAUBIS','VariableNamingRule','preserve');
RBCNBIS         = readtable('data_FR.xlsx','Sheet','RBCNBIS','VariableNamingRule','preserve');
RBIDBIS     = readtable('data_FR.xlsx','Sheet','RBIDBIS','VariableNamingRule','preserve');
RBPEBIS          = readtable('data_FR.xlsx','Sheet','RBPEBIS','VariableNamingRule','preserve');
RBPHBIS   = readtable('data_FR.xlsx','Sheet','RBPHBIS','VariableNamingRule','preserve');
RBRUBIS        = readtable('data_FR.xlsx','Sheet','RBRUBIS','VariableNamingRule','preserve');
CAPUTLG331S        = readtable('data_FR.xlsx','Sheet','CAPUTLG331S','VariableNamingRule','preserve');
CAPUTLB562A3CS        = readtable('data_FR.xlsx','Sheet','CAPUTLB562A3CS','VariableNamingRule','preserve');
ANMNO        = readtable('data_FR.xlsx','Sheet','ANMNO','VariableNamingRule','preserve');

% Import data
DATA.INDPRO        = table2array(INDPRO(:,2:end));
DATA.A31SNO        = table2array(A31SNO(:,2:end));
DATA.CPIAUCSL      = table2array(CPIAUCSL(:,2:end));
DATA.AWHMAN        = table2array(AWHMAN(:,2:end));
DATA.A35DVS        = table2array(A35DVS(:,2:end));
DATA.PCU331331    = table2array(PCU331331(:,2:end));
DATA.PCU335911335911 = table2array(PCU335911335911(:,2:end));
DATA.RBCLBIS     = table2array(RBCLBIS(:,2:end));
DATA.RBAUBIS         = table2array(RBAUBIS(:,2:end));
DATA.RBCNBIS         = table2array(RBCNBIS(:,2:end));
DATA.RBIDBIS     = table2array(RBIDBIS(:,2:end));
DATA.RBPEBIS          = table2array(RBPEBIS(:,2:end));
DATA.RBPHBIS   = table2array(RBPHBIS(:,2:end));
DATA.RBRUBIS       = table2array(RBRUBIS(:,2:end));

DATA.CAPUTLG331S      = table2array(CAPUTLG331S(:,2:end));
DATA.CAPUTLB562A3CS       = table2array(CAPUTLB562A3CS(:,2:end));
DATA.ANMNO       = table2array(ANMNO(:,2:end));
DATA.CAPUTLG331S(DATA.CAPUTLG331S == 0) = NaN;
DATA.CAPUTLB562A3CS(DATA.CAPUTLB562A3CS == 0) = NaN;
DATA.ANMNO(DATA.ANMNO == 0) = NaN;

% Import vintages (Columns)
Vintages.INDPRO        = INDPRO.Properties.VariableNames;        Vintages.INDPRO(:,1) = [];          Vintages.INDPRO = datetime(Vintages.INDPRO, 'InputFormat', 'MM/dd/yyyy');
Vintages.A31SNO        = A31SNO.Properties.VariableNames;        Vintages.A31SNO(:,1) = [];          Vintages.A31SNO = datetime(Vintages.A31SNO, 'InputFormat', 'MM/dd/yyyy');
Vintages.CPIAUCSL      = CPIAUCSL.Properties.VariableNames;      Vintages.CPIAUCSL(:,1) = [];        Vintages.CPIAUCSL = datetime(Vintages.CPIAUCSL, 'InputFormat', 'MM/dd/yyyy');
Vintages.AWHMAN        = AWHMAN.Properties.VariableNames;        Vintages.AWHMAN(:,1) = [];          Vintages.AWHMAN = datetime(Vintages.AWHMAN, 'InputFormat', 'MM/dd/yyyy');
Vintages.A35DVS        = A35DVS.Properties.VariableNames;        Vintages.A35DVS(:,1) = [];          Vintages.A35DVS = datetime(Vintages.A35DVS, 'InputFormat', 'MM/dd/yyyy');
Vintages.PCU331331    = PCU331331.Properties.VariableNames;    Vintages.PCU331331(:,1) = [];      Vintages.PCU331331 = datetime(Vintages.PCU331331, 'InputFormat', 'MM/dd/yyyy');
Vintages.PCU335911335911 = PCU335911335911.Properties.VariableNames; Vintages.PCU335911335911(:,1) = [];   Vintages.PCU335911335911 = datetime(Vintages.PCU335911335911, 'InputFormat', 'MM/dd/yyyy');
Vintages.RBCLBIS     = RBCLBIS.Properties.VariableNames;     Vintages.RBCLBIS(:,1) = [];       Vintages.RBCLBIS = datetime(Vintages.RBCLBIS, 'InputFormat', 'MM/dd/yyyy');
Vintages.RBAUBIS         = RBAUBIS.Properties.VariableNames;         Vintages.RBAUBIS(:,1) = [];           Vintages.RBAUBIS = datetime(Vintages.RBAUBIS, 'InputFormat', 'MM/dd/yyyy');
Vintages.RBCNBIS         = RBCNBIS.Properties.VariableNames;         Vintages.RBCNBIS(:,1) = [];           Vintages.RBCNBIS = datetime(Vintages.RBCNBIS, 'InputFormat', 'MM/dd/yyyy');
Vintages.RBIDBIS     = RBIDBIS.Properties.VariableNames;     Vintages.RBIDBIS(:,1) = [];       Vintages.RBIDBIS = datetime(Vintages.RBIDBIS, 'InputFormat', 'MM/dd/yyyy');
Vintages.RBPEBIS          = RBPEBIS.Properties.VariableNames;          Vintages.RBPEBIS(:,1) = [];            Vintages.RBPEBIS = datetime(Vintages.RBPEBIS, 'InputFormat', 'MM/dd/yyyy');
Vintages.RBPHBIS   = RBPHBIS.Properties.VariableNames;   Vintages.RBPHBIS(:,1) = [];     Vintages.RBPHBIS = datetime(Vintages.RBPHBIS, 'InputFormat', 'MM/dd/yyyy');
Vintages.RBRUBIS        = RBRUBIS.Properties.VariableNames;        Vintages.RBRUBIS(:,1) = [];          Vintages.RBRUBIS = datetime(Vintages.RBRUBIS, 'InputFormat', 'MM/dd/yyyy');

Vintages.CAPUTLG331S        = CAPUTLG331S.Properties.VariableNames;        Vintages.CAPUTLG331S(:,1) = [];          Vintages.CAPUTLG331S = datetime(Vintages.CAPUTLG331S, 'InputFormat', 'MM/dd/yyyy');
Vintages.CAPUTLB562A3CS        = CAPUTLB562A3CS.Properties.VariableNames;        Vintages.CAPUTLB562A3CS(:,1) = [];          Vintages.CAPUTLB562A3CS = datetime(Vintages.CAPUTLB562A3CS, 'InputFormat', 'MM/dd/yyyy');
Vintages.ANMNO        = ANMNO.Properties.VariableNames;        Vintages.ANMNO(:,1) = [];          Vintages.ANMNO = datetime(Vintages.ANMNO, 'InputFormat', 'MM/dd/yyyy');

% Import dates obs (Rows)
DATES.INDPRO        = table2array(INDPRO(:,1));        DATES.INDPRO = datetime(DATES.INDPRO, 'InputFormat', 'dd/MM/yyyy');
DATES.A31SNO        = table2array(A31SNO(:,1));        DATES.A31SNO = datetime(DATES.A31SNO, 'InputFormat', 'dd/MM/yyyy');
DATES.CPIAUCSL      = table2array(CPIAUCSL(:,1));      DATES.CPIAUCSL = datetime(DATES.CPIAUCSL, 'InputFormat', 'dd/MM/yyyy');
DATES.AWHMAN        = table2array(AWHMAN(:,1));        DATES.AWHMAN = datetime(DATES.AWHMAN, 'InputFormat', 'dd/MM/yyyy');
DATES.A35DVS        = table2array(A35DVS(:,1));        DATES.A35DVS = datetime(DATES.A35DVS, 'InputFormat', 'dd/MM/yyyy');
DATES.PCU331331    = table2array(PCU331331(:,1));    DATES.PCU331331 = datetime(DATES.PCU331331, 'InputFormat', 'dd/MM/yyyy');
DATES.PCU335911335911 = table2array(PCU335911335911(:,1)); DATES.PCU335911335911 = datetime(DATES.PCU335911335911, 'InputFormat', 'dd/MM/yyyy');
DATES.RBCLBIS     = table2array(RBCLBIS(:,1));     DATES.RBCLBIS = datetime(DATES.RBCLBIS, 'InputFormat', 'dd/MM/yyyy');
DATES.RBAUBIS         = table2array(RBAUBIS(:,1));         DATES.RBAUBIS = datetime(DATES.RBAUBIS, 'InputFormat', 'dd/MM/yyyy');
DATES.RBCNBIS         = table2array(RBCNBIS(:,1));         DATES.RBCNBIS = datetime(DATES.RBCNBIS, 'InputFormat', 'dd/MM/yyyy');
DATES.RBIDBIS     = table2array(RBIDBIS(:,1));     DATES.RBIDBIS = datetime(DATES.RBIDBIS, 'InputFormat', 'dd/MM/yyyy');
DATES.RBPEBIS          = table2array(RBPEBIS(:,1));          DATES.RBPEBIS = datetime(DATES.RBPEBIS, 'InputFormat', 'dd/MM/yyyy');
DATES.RBPHBIS   = table2array(RBPHBIS(:,1));   DATES.RBPHBIS = datetime(DATES.RBPHBIS, 'InputFormat', 'dd/MM/yyyy');
DATES.RBRUBIS        = table2array(RBRUBIS(:,1));        DATES.RBRUBIS = datetime(DATES.RBRUBIS, 'InputFormat', 'dd/MM/yyyy');

DATES.CAPUTLG331S        = table2array(CAPUTLG331S(:,1));        DATES.CAPUTLG331S = datetime(DATES.CAPUTLG331S, 'InputFormat', 'dd/MM/yyyy');
DATES.CAPUTLB562A3CS        = table2array(CAPUTLB562A3CS(:,1));        DATES.CAPUTLB562A3CS = datetime(DATES.CAPUTLB562A3CS, 'InputFormat', 'dd/MM/yyyy');
DATES.ANMNO        = table2array(ANMNO(:,1));        DATES.ANMNO = datetime(DATES.ANMNO, 'InputFormat', 'dd/MM/yyyy');

% Longest available obs series
DATES.date_max = DATES.INDPRO;
first_obs = DATES.date_max(1);
last_obs = DATES.date_max(end);

% Longest available vintage series
Vintages.vintage_max = Vintages.INDPRO;
first_vin = Vintages.vintage_max(1);
last_vin = Vintages.vintage_max(end);

% Import variables' IDs
id = fieldnames(DATA);

%% Create an order-3 tensor with data and NaN
DATA_nan = nan(length(DATES.date_max), length(Vintages.vintage_max), length(id));
missing_vin_1 = zeros(length(id), 1);
missing_vin_2 = zeros(length(id), 1);
missing_obs = zeros(length(id), 1);
extra_nowcast_horizon = zeros(length(Vintages.vintage_max), length(id));
required_nowcast_horizon = nan(length(Vintages.vintage_max), length(id));
for i = 1:length(id)
    
    current_var = id{i};
    current_matrix = DATA.(current_var);
    current_dates = DATES.(current_var); current_first_obs = current_dates(1);
    current_vintages = Vintages.(current_var); current_first_vin = current_vintages(1);

    current_extra_horizon = compute_extra_nowcast_horizon(current_matrix);
    current_required_horizon = compute_required_nowcast_horizon(current_matrix, current_dates, current_vintages);

    if current_first_obs == first_obs
        if current_first_vin == first_vin
            DATA_nan(:,:,i) = current_matrix;
            extra_nowcast_horizon(:,i) = current_extra_horizon;
            required_nowcast_horizon(:,i) = current_required_horizon;
        elseif current_first_vin > first_vin
            missing_vin_1(i,1) = calmonths(between(first_vin, current_first_vin, 'months'));
            missing_data = nan(length(DATES.date_max), missing_vin_1(i,1));
            current_matrix_nan = [missing_data, current_matrix];
            DATA_nan(:,:,i) = current_matrix_nan;

            vin_offset = missing_vin_1(i,1);
            extra_nowcast_horizon(vin_offset+1:end,i) = current_extra_horizon;
            required_nowcast_horizon(vin_offset+1:end,i) = current_required_horizon;
        end
    elseif current_first_obs >  first_obs
        missing_obs(i,1) = calmonths(between(first_obs, current_first_obs, 'months'));
        missing_data_obs = nan(missing_obs(i,1),length(Vintages.(current_var)));
        current_matrix_nan_obs = [missing_data_obs; current_matrix];

        missing_vin_2(i,1) = calmonths(between(first_vin, current_first_vin, 'months'));
        missing_data_vin = nan(length(DATES.date_max), missing_vin_2(i,1));
        current_matrix_nan = [missing_data_vin, current_matrix_nan_obs];

        DATA_nan(:,:,i) = current_matrix_nan;

        vin_offset = missing_vin_2(i,1);
        extra_nowcast_horizon(vin_offset+1:end,i) = current_extra_horizon;
        required_nowcast_horizon(vin_offset+1:end,i) = current_required_horizon;
    end
end

dates_nan = DATES.date_max;
vintages_nan = Vintages.vintage_max;

%% -----------------------------------------
PREDICTORS_nan.data = DATA_nan;
PREDICTORS_nan.obs = dates_nan;
PREDICTORS_nan.vintages = vintages_nan;
PREDICTORS_nan.id = id;
PREDICTORS_nan.extra_nowcast_horizon = extra_nowcast_horizon;
PREDICTORS_nan.required_nowcast_horizon = required_nowcast_horizon;
%-----------------------------------------

%% Check

if any(extra_nowcast_horizon(:) ~= 0)
    warning('import_predictors_fr:UnexpectedExtraHorizon', ...
        'Non-zero extra_nowcast_horizon found in data_FR.xlsx; expected all zeros.');
end

n_three_period_vars = 0;
for kk = 1:length(id)
    col_vals = required_nowcast_horizon(~isnan(required_nowcast_horizon(:,kk)), kk);
    if isempty(col_vals)
        continue
    end
    if numel(unique(col_vals)) > 1
        warning('import_predictors_fr:NonConstantRequiredHorizon', ...
            'required_nowcast_horizon is not constant across vintages for %s.', id{kk});
        continue
    end
    if ~ismember(col_vals(1), [2, 3])
        warning('import_predictors_fr:UnexpectedRequiredHorizon', ...
            'required_nowcast_horizon for %s is %d, expected 2 or 3.', id{kk}, col_vals(1));
    elseif col_vals(1) == 3
        n_three_period_vars = n_three_period_vars + 1;
    end
end
if n_three_period_vars > 3
    warning('import_predictors_fr:TooManyThreePeriodVariables', ...
        '%d variables require a 3-period nowcast horizon; expected at most 3 (A35DVS plus at most two others).', n_three_period_vars);
end

%% Balanced predictors dataset

max_missing_obs = max(missing_obs);
max_missing_vin = max(max(missing_vin_1),max(missing_vin_2));

% data
predictors_balanced = PREDICTORS_nan.data;
predictors_balanced(1:max_missing_obs,:,:) = []; 
predictors_balanced(:,1:max_missing_vin,:) = []; 

% observations
obs_balanced = dates_nan; obs_balanced(1:max_missing_obs,:,:) = []; 

% vintages
vintages_balanced = vintages_nan; vintages_balanced(:,1:max_missing_vin,:) = [];

% nowcast horizon
extra_nowcast_horizon_balanced = extra_nowcast_horizon; extra_nowcast_horizon_balanced(1:max_missing_vin,:) = [];
required_nowcast_horizon_balanced = required_nowcast_horizon; required_nowcast_horizon_balanced(1:max_missing_vin,:) = [];

%-----------------------------------------
PREDICTORS_balanced.data = predictors_balanced;
PREDICTORS_balanced.obs = obs_balanced;
PREDICTORS_balanced.vintages = vintages_balanced;
PREDICTORS_balanced.id = id;
PREDICTORS_balanced.extra_nowcast_horizon = extra_nowcast_horizon_balanced;
PREDICTORS_balanced.required_nowcast_horizon = required_nowcast_horizon_balanced;
%-----------------------------------------
pred_id = PREDICTORS_nan.id;
%-----------------------------------------

end

function required_nowcast_horizon = compute_required_nowcast_horizon(data_matrix, obs_dates, vintage_months)

last_obs_idx = last_observed_index(data_matrix);
required_nowcast_horizon = nan(numel(last_obs_idx), 1);

for mm = 1:numel(last_obs_idx)
    if isnan(last_obs_idx(mm))
        continue
    end

    vintage_obs_idx = find(obs_dates == vintage_months(mm), 1, 'first');
    if isempty(vintage_obs_idx)
        last_obs_date = obs_dates(last_obs_idx(mm));
        required_nowcast_horizon(mm) = calmonths(between(last_obs_date, vintage_months(mm), 'months'));
    else
        required_nowcast_horizon(mm) = vintage_obs_idx - last_obs_idx(mm);
    end
    required_nowcast_horizon(mm) = max(0, required_nowcast_horizon(mm));
end

end

function extra_nowcast_horizon = compute_extra_nowcast_horizon(data_matrix)

last_obs_idx = last_observed_index(data_matrix);
extra_nowcast_horizon = zeros(numel(last_obs_idx), 1);
first_valid_pos = find(~isnan(last_obs_idx), 1, 'first');

if isempty(first_valid_pos)
    return
end

first_origin = last_obs_idx(first_valid_pos);
for mm = first_valid_pos:numel(last_obs_idx)
    if isnan(last_obs_idx(mm))
        continue
    end
    expected_origin = first_origin + (mm - first_valid_pos);
    extra_nowcast_horizon(mm) = max(0, expected_origin - last_obs_idx(mm));
end

end

function last_obs_idx = last_observed_index(data_matrix)

last_obs_idx = nan(1, size(data_matrix, 2));
for cc = 1:size(data_matrix, 2)
    current_last = find(~isnan(data_matrix(:, cc)), 1, 'last');
    if ~isempty(current_last)
        last_obs_idx(cc) = current_last;
    end
end

end
