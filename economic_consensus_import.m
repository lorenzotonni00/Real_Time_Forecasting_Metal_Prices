% ===========================================================================================
% Code to import Economic Consensus data from raw xlsx files.
% -------------------------------------------------------------------------------------------
% Code author:  Lorenzo Tonni (lorenzo.tonni@unimi.it)
% Last updated: 2026-10-27
% Tested with:  MATLAB R2025b
% ===========================================================================================

% Settings and data import
clear all; clear session; close all; clc
warning off all

% ===============|| Set Output Folder ||============= %
if isfolder(join([pwd,'\outputs'],'')); Folder_output = join([pwd,'\outputs'],''); % windows
else; Folder_output = join([pwd,'/outputs'],''); % mac
end

% ===============|| Set Professional Survey Folder ||============= %
if isfolder(join([pwd,'\Economic_Consensus'],'')); Folder_survey = join([pwd,'\Economic_Consensus'],''); % windows
else; Folder_survey = join([pwd,'/Economic_Consensus'],''); % mac
end


%% Generate file IDs

% Insert dates first and last xlsx file
startDate = datetime(1995, 8, 1);
endDate = datetime(2025, 11, 1);

numMonths = calmonths(between(startDate, endDate, 'months')) + 1;

% Pre-Store
monthList = cell(1, numMonths);

idx = 1;
for d = startDate:calmonths(1):endDate
    monthStr = datestr(d, 'mmmyyyy'); 
    monthStr(1) = upper(monthStr(1));
    monthList{idx} = ['EM' monthStr '.xlsx'];
    idx = idx + 1;
end

% Choose Commodities (Names in the Excel sheets)
commodities = {'Copper',...
               'Aluminium',...
               'Nickel',...
               'Zinc'
                };

commodities_matlab = cellfun(@(x) strrep(x, ' ', '_'), commodities, 'UniformOutput', false);
commodities_matlab = cellfun(@(x) strrep(x, '-', '_'), commodities_matlab, 'UniformOutput', false);
 
%%
for index = 1:length(commodities)
    p_forecasts.(commodities_matlab{index}).data         = NaN(24,idx-1);
    p_forecasts.(commodities_matlab{index}).spot         = NaN(1,idx-1);
    p_forecasts.(commodities_matlab{index}).st_dev       = NaN(24,idx-1);
    p_forecasts.(commodities_matlab{index}).survey_dates = NaT(1,idx-1);
    p_forecasts.(commodities_matlab{index}).horizon_dates = NaT(24,idx-1);
    p_forecasts.survey_dates = datetime(startDate:calmonths(1):endDate);
end

%%
hx = waitbar(0,'Importing Professional Forecasts');
for month_index = 1:idx-1
    filePath = fullfile(Folder_survey, monthList{month_index});
    if ~isfile(filePath)
        warning(['File not found: ', filePath, ' - Skip to next month.']);
        continue;
    end
    for metal_index = 1:length(commodities)
        sheet_name = commodities{metal_index};

        survey_date = readtable(filePath, 'Sheet', sheet_name, ...
               'VariableNamingRule', 'preserve', 'Range', 'A4:A4');
        spot = readtable(filePath, 'Sheet', sheet_name, ...
               'VariableNamingRule', 'preserve', 'Range', 'B7:B7');

        forecasts.survey_date = datetime(table2array(survey_date), 'InputFormat', 'dd/mm/yyyy');
        next_month = dateshift(forecasts.survey_date, 'start', 'month', 'next');
        forecasts.dates = next_month + calmonths(0:23);

        target_dates = read_consensus_target_dates(filePath, sheet_name);
        forecasts.data = place_consensus_values(forecasts.dates, target_dates, ...
            read_consensus_values(filePath, sheet_name, 7));
        forecasts.high = place_consensus_values(forecasts.dates, target_dates, ...
            read_consensus_values(filePath, sheet_name, 9));
        forecasts.low = place_consensus_values(forecasts.dates, target_dates, ...
            read_consensus_values(filePath, sheet_name, 10));
        forecasts.st_dev = place_consensus_values(forecasts.dates, target_dates, ...
            read_consensus_values(filePath, sheet_name, 11));

        p_forecasts.(commodities_matlab{metal_index}).data(:,month_index) = forecasts.data;
        p_forecasts.(commodities_matlab{metal_index}).spot(1,month_index) = table_value_or_nan(spot);
        p_forecasts.(commodities_matlab{metal_index}).st_dev(:,month_index) = forecasts.st_dev;
        p_forecasts.(commodities_matlab{metal_index}).highest(:,month_index) = forecasts.high;
        p_forecasts.(commodities_matlab{metal_index}).lowest(:,month_index) = forecasts.low;
        p_forecasts.(commodities_matlab{metal_index}).survey_dates(1,month_index) = forecasts.survey_date;
        p_forecasts.(commodities_matlab{metal_index}).horizon_dates(:,month_index) = forecasts.dates(:);

    end
    waitbar(month_index/(idx-1),hx,sprintf('Import Professional Forecasts: %2.2f',(month_index/(idx-1))*100));
end
close(hx)

%% ========= || Imputation of missing values || ========= %%

% Metals
metals_imp = {'Copper', 'Aluminium', 'Nickel', 'Zinc'};

%% Step 1 — fill per-commodity survey_dates (NaT → chain from previous)
for m_i = 1:length(metals_imp)
    c_i = metals_imp{m_i};
    if isnat(p_forecasts.(c_i).survey_dates(1,1))
        p_forecasts.(c_i).survey_dates(1,1) = p_forecasts.Copper.survey_dates(1,1);
    end

    for s_i = 2:length(p_forecasts.(c_i).survey_dates)
        if isnat(p_forecasts.(c_i).survey_dates(1,s_i))
            p_forecasts.(c_i).survey_dates(1,s_i) = ...
                p_forecasts.(c_i).survey_dates(1,s_i-1) + calmonths(1);
        end
    end
end

%% Step 2 — vertical (within-survey) horizon interpolation (Dovern et al.)
data_fh = struct();
for m_i = 1:length(metals_imp)
    c_i = metals_imp{m_i};
    data_fh.(c_i).data          = p_forecasts.(c_i).data;
    data_fh.(c_i).st_dev        = p_forecasts.(c_i).st_dev;
    data_fh.(c_i).spot          = p_forecasts.(c_i).spot;
    data_fh.(c_i).survey_dates  = p_forecasts.(c_i).survey_dates;
    data_fh.(c_i).horizon_dates = p_forecasts.(c_i).horizon_dates;

    N_cols = size(data_fh.(c_i).data, 2);
    for col_i = 1:N_cols
        col_data = p_forecasts.(c_i).data(:, col_i);
        if all(isnan(col_data)); continue; end
        non_nan_r = find(~isnan(col_data));
        first_r   = non_nan_r(1);
        last_r    = non_nan_r(end);
        nan_r     = find(isnan(col_data));
        for k_i = 1:length(nan_r)
            nv = nan_r(k_i);
            if nv > first_r && nv < last_r
                prec = max(non_nan_r(non_nan_r < nv));
                succ = min(non_nan_r(non_nan_r > nv));
                dist = succ - prec;
                w_p  = (dist - (nv - prec)) / dist;
                w_s  = (dist - (succ - nv))  / dist;
                data_fh.(c_i).data(nv,   col_i) = w_p * p_forecasts.(c_i).data(prec,   col_i) + w_s * p_forecasts.(c_i).data(succ,   col_i);
                data_fh.(c_i).st_dev(nv, col_i) = w_p * p_forecasts.(c_i).st_dev(prec, col_i) + w_s * p_forecasts.(c_i).st_dev(succ, col_i);
            end
        end
    end
end

%% Step 3 — horizontal (cross-survey) imputation for missing columns

data_imp = data_fh;
for m_i = 1:length(metals_imp)
    c_i = metals_imp{m_i};
    empty_cols = find(all(isnan(data_imp.(c_i).data), 1));
    full_cols  = find(any(~isnan(data_imp.(c_i).data), 1));

    for k_i = 1:length(empty_cols)
        col_idx = empty_cols(k_i);

        smaller = full_cols(full_cols <= col_idx);
        larger  = full_cols(full_cols >= col_idx);
        
        if isempty(smaller) || isempty(larger); continue; end

        col_l = max(smaller);
        col_r = min(larger);
        if col_l == col_r; continue; end

        nn_l  = find(~isnan(data_imp.(c_i).data(:, col_l)));
        nn_r  = find(~isnan(data_imp.(c_i).data(:, col_r)));
        ult_l = nn_l(end);
        pri_r = nn_r(1);

        d_l   = col_idx - col_l;
        d_r   = col_r   - col_idx;
        d_tot = d_l + d_r;
        w_l   = (d_tot - d_l) / d_tot;
        w_r   = (d_tot - d_r) / d_tot;

        h_lo = pri_r + d_r;
        h_hi = ult_l - d_l;

        for h = h_lo:h_hi
            data_imp.(c_i).data(h,   col_idx) = w_l * data_imp.(c_i).data(h + d_l, col_l) + w_r * data_imp.(c_i).data(h - d_r, col_r);
            data_imp.(c_i).st_dev(h, col_idx) = w_l * data_imp.(c_i).st_dev(h + d_l, col_l) + w_r * data_imp.(c_i).st_dev(h - d_r, col_r);
        end
    end
end

%% Step 4 — cut to targetDate = 01-Mar-2004 (start of monthly survey period)
targetDate   = datetime('01-Mar-2004');
top_sd       = p_forecasts.survey_dates;  
cut_idx      = find(top_sd == targetDate);

for m_i = 1:length(metals_imp)
    c_i = metals_imp{m_i};
    if ~isempty(cut_idx) && cut_idx > 1
        data_imp.(c_i).data(:,          1:cut_idx-1) = [];
        data_imp.(c_i).st_dev(:,        1:cut_idx-1) = [];
        data_imp.(c_i).spot(:,          1:cut_idx-1) = [];
        data_imp.(c_i).survey_dates(:,  1:cut_idx-1) = [];
        data_imp.(c_i).horizon_dates(:, 1:cut_idx-1) = [];
    end
end

%% Step 5 — fill survey_dates for imputed (missing) columns by chaining
for m_i = 1:length(metals_imp)
    c_i = metals_imp{m_i};
    sd_tmp = data_imp.(c_i).survey_dates;
    if isnat(sd_tmp(1,1)); sd_tmp(1,1) = targetDate; end
    for s_i = 2:length(sd_tmp)
        if isnat(sd_tmp(1,s_i))
            sd_tmp(1,s_i) = sd_tmp(1,s_i-1) + calmonths(1);
        end
    end
    data_imp.(c_i).survey_dates = sd_tmp;
end

%% Step 6 — fill horizon_dates for missing columns
for m_i = 1:length(metals_imp)
    c_i = metals_imp{m_i};
    N_s = size(data_imp.(c_i).horizon_dates, 2);
    for s_i = 1:N_s
        for h = 1:24
            if isnat(data_imp.(c_i).horizon_dates(h, s_i))
                if h == 1
                    data_imp.(c_i).horizon_dates(h, s_i) = data_imp.(c_i).survey_dates(1, s_i) + calmonths(1);
                else
                    data_imp.(c_i).horizon_dates(h, s_i) = data_imp.(c_i).horizon_dates(h-1, s_i) + calmonths(1);
                end
            end
        end
    end
end

%% Step 7 — build output struct (Aluminium → Aluminum for main_forecast.m compatibility)
metals_src = {'Copper', 'Aluminium', 'Nickel', 'Zinc'};
metals_dst = {'Copper', 'Aluminum',  'Nickel', 'Zinc'};

p_forecasts_fixed_h_imputed = struct();
for m_i = 1:length(metals_src)
    src = metals_src{m_i};
    dst = metals_dst{m_i};
    p_forecasts_fixed_h_imputed.(dst).data          = data_imp.(src).data;
    p_forecasts_fixed_h_imputed.(dst).spot          = data_imp.(src).spot;
    p_forecasts_fixed_h_imputed.(dst).survey_dates  = dateshift(data_imp.(src).survey_dates, 'start', 'month');
    p_forecasts_fixed_h_imputed.(dst).horizon_dates = dateshift(data_imp.(src).horizon_dates, 'start', 'month');
end

%% Save
if isfolder([pwd, '/Data']); data_folder_imp = [pwd, '/Data'];
else; data_folder_imp = [pwd, '\Data']; end
save(fullfile(data_folder_imp, 'p_forecasts_fixed_h_imputed.mat'), 'p_forecasts_fixed_h_imputed');

%%

function target_dates = read_consensus_target_dates(file_path, sheet_name)
    left_targets = readtable(file_path, 'Sheet', sheet_name, ...
        'VariableNamingRule', 'preserve', 'Range', 'C5:F5', 'ReadVariableNames', false);
    right_targets = readtable(file_path, 'Sheet', sheet_name, ...
        'VariableNamingRule', 'preserve', 'Range', 'H5:K5', 'ReadVariableNames', false);
    target_dates = [table2array(left_targets), table2array(right_targets)];
end

function values = read_consensus_values(file_path, sheet_name, row_number)
    left_range = sprintf('C%d:F%d', row_number, row_number);
    right_range = sprintf('H%d:K%d', row_number, row_number);
    left_values = readtable(file_path, 'Sheet', sheet_name, ...
        'VariableNamingRule', 'preserve', 'Range', left_range, 'ReadVariableNames', false);
    right_values = readtable(file_path, 'Sheet', sheet_name, ...
        'VariableNamingRule', 'preserve', 'Range', right_range, 'ReadVariableNames', false);
    values = [table2array(left_values), table2array(right_values)];
    values = double(values);
end

function forecast_values = place_consensus_values(horizon_dates, target_dates, values)
    forecast_values = NaN(1, numel(horizon_dates));
    target_months = dateshift(target_dates, 'start', 'month');
    horizon_months = dateshift(horizon_dates, 'start', 'month');
    valid_targets = ~isnat(target_months) & ~isnan(values);
    valid_values = values(valid_targets);
    [is_target_in_horizon, horizon_idx] = ismember(target_months(valid_targets), horizon_months);
    if any(is_target_in_horizon)
        forecast_values(horizon_idx(is_target_in_horizon)) = valid_values(is_target_in_horizon);
    end
end

function value = table_value_or_nan(input_table)
    value = table2array(input_table);
    if isempty(value) || isnan(value(1))
        value = NaN;
    else
        value = value(1);
    end
end
