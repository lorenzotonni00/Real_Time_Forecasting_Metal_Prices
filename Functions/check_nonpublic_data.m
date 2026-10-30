function data_check = check_nonpublic_data(Folder_data, Folder_new_predictors, show_popup)
% =================================================================================
% Check that the non-public data required by main_forecast.m are available
% ---------------------------------------------------------------------------------
% SYNTAX: data_check = check_nonpublic_data(Folder_data, Folder_new_predictors, show_popup)
% where:
%      - Folder_data: folder containing ETM_daily.xlsx, futures_daily.xlsx and
%                     p_forecasts_fixed_h_imputed.mat
%      - Folder_new_predictors: folder containing LSEG_2.xlsx and the other
%                     financial regressors (T10Y3M, VIX, WTI, iron ore, DTB3)
%      - show_popup: 1 = open a pop-up window with the list of missing data
%                    (default is 1 when MATLAB runs with its desktop, 0 otherwise)
% ---------------------------------------------------------------------------------
% DATA CHECKED:
%      1. Nominal metal prices and inventories    (LSEG)  Data/ETM_daily.xlsx
%      2. Futures prices                          (LSEG)  Data/futures_daily.xlsx
%      3. Professional forecasts          (Consensus Economics)
%                                                  Data/p_forecasts_fixed_h_imputed.mat
%      4. Financial regressors                    (LSEG)  Data/Other Predictors/LSEG_2.xlsx
%      5. Other financial regressors   (FRED and other public sources)
%      A file is considered missing if it does not exist or contains no numeric
%      values (e.g., the empty templates distributed with the replication package).
% ---------------------------------------------------------------------------------
% OUTPUT:
%      data_check.all_available = true if all the data above are available
%      data_check.groups        = missing data and results that cannot be reproduced
%      data_check.message       = text of the message (cell array of lines)
% ---------------------------------------------------------------------------------

if nargin < 3 || isempty(show_popup)
    show_popup = usejava('desktop');
end

metals = {'Copper', 'Aluminum', 'Nickel', 'Zinc'};
groups = struct('title', {}, 'source', {}, 'missing', {}, 'affected', {});

%% 1. Nominal metal prices and inventories (ETM_daily.xlsx)

etm_file = fullfile(Folder_data, 'ETM_daily.xlsx');
price_ids = {'Aluminum', 'Copper', 'Nickel', 'Zinc'};
stock_ids = strcat(price_ids, '_Stock');

T = read_table_safe(etm_file);
missing_prices = price_ids(~cellfun(@(id) column_has_data(T, id), price_ids));
missing_stocks = stock_ids(~cellfun(@(id) column_has_data(T, id), stock_ids));

missing = {};
if ~isempty(missing_prices)
    missing{end+1} = ['Nominal prices: ', strjoin(missing_prices, ', ')];
end
if ~isempty(missing_stocks)
    missing{end+1} = ['Inventories: ', strjoin(missing_stocks, ', ')];
end
if ~isempty(missing)
    groups(end+1) = make_group('Nominal metal prices and inventories (LSEG)', ...
        'Data/ETM_daily.xlsx', missing, ...
        'ALL the results of main_forecast.m: Tables 3-5, Tables S.3-S.9 and S.11-S.18, Figures 3-6 and S.1-S.10');
end

%% 2. Futures prices (futures_daily.xlsx)

futures_file = fullfile(Folder_data, 'futures_daily.xlsx');
futures_cols = { ...
    'copper_futures_3m',    'Copper 3-month'; ...
    'copper_futures_15m',   'Copper 15-month'; ...
    'aluminum_futures_3m',  'Aluminum 3-month'; ...
    'aluminum_futures_15m', 'Aluminum 15-month'; ...
    'nickel_futures_3m',    'Nickel 3-month'; ...
    'nickel_futures_15m',   'Nickel 15-month'; ...
    'zinc_futures_3m',      'Zinc 3-month'; ...
    'zinc_futures_15m',     'Zinc 15-month'};

T = read_table_safe(futures_file);
has_col = cellfun(@(id) column_has_data(T, id), futures_cols(:, 1));
if any(~has_col)
    groups(end+1) = make_group('Futures prices (LSEG)', 'Data/futures_daily.xlsx', ...
        {['Futures prices: ', strjoin(futures_cols(~has_col, 2)', ', ')]}, ...
        '"Futures" rows of Tables 3-4, S.3-S.6 and S.15-S.18');
end

%% 3. Professional forecasts (p_forecasts_fixed_h_imputed.mat)

pf_file = fullfile(Folder_data, 'p_forecasts_fixed_h_imputed.mat');
has_pf = false(1, numel(metals));
if isfile(pf_file)
    try
        S = load(pf_file, 'p_forecasts_fixed_h_imputed');
        for mm = 1:numel(metals)
            has_pf(mm) = isfield(S.p_forecasts_fixed_h_imputed, metals{mm}) && ...
                any(isfinite(S.p_forecasts_fixed_h_imputed.(metals{mm}).data(:)));
        end
    catch
        has_pf(:) = false;
    end
end
if any(~has_pf)
    groups(end+1) = make_group('Professional forecasts (Consensus Economics)', ...
        'Data/p_forecasts_fixed_h_imputed.mat (created by economic_consensus_import.m from Economic_Consensus/*.xlsx)', ...
        {['Professional forecasts for: ', strjoin(metals(~has_pf), ', ')]}, ...
        ['"Professional Forecasters" rows of Tables 3-4, S.3-S.6 and S.15-S.18; ', ...
         'professional forecasters curves in Figures 4-6, S.9 and S.10']);
end

%% 4. Financial regressors from LSEG (LSEG_2.xlsx)

lseg_file = '';
for candidate = {'LSEG_2.xlsx'}
    if isfile(fullfile(Folder_new_predictors, candidate{1}))
        lseg_file = fullfile(Folder_new_predictors, candidate{1});
        break
    end
end

lseg_defs = { ...
    'sp500',                 'Standard & Poor''s 500 index'; ...
    'gold',                  'Gold price'; ...
    'BDI',                   'Baltic Dry Index'; ...
    'COPPER FUTURE',         'Copper convenience yield (futures)'; ...
    'ALUMINUM FUTURES',      'Aluminum convenience yield (futures)'; ...
    'NICKEL FUTURES',        'Nickel convenience yield (futures)'; ...
    'ZINC FUTURES',          'Zinc convenience yield (futures)'; ...
    'Copper Top20 Stocks',   'Copper stock price index'; ...
    'Aluminum Top20 Stocks', 'Aluminum stock price index'; ...
    'Nickel Top20 Stocks',   'Nickel stock price index'; ...
    'Zinc Top20 Stocks',     'Zinc stock price index'};

has_lseg = false(size(lseg_defs, 1), 1);
if ~isempty(lseg_file)
    sheets = sheetnames(lseg_file);
    for ii = 1:size(lseg_defs, 1)
        pos = find_sheet_position(sheets, lseg_defs{ii, 1});
        if ~isempty(pos)
            has_lseg(ii) = lseg_sheet_has_data(lseg_file, sheets{pos});
        end
    end
end
if any(~has_lseg)
    labels = cell(1, sum(~has_lseg));
    idx = find(~has_lseg)';
    for kk = 1:numel(idx)
        labels{kk} = sprintf('%s [sheet "%s"]', lseg_defs{idx(kk), 2}, lseg_defs{idx(kk), 1});
    end
    groups(end+1) = make_group('Financial regressors (LSEG)', 'Data/Other Predictors/LSEG_2.xlsx', ...
        labels, 'Tables S.11-S.14 (RMSFE ratios based on financial predictors)');
end

%% 5. Other financial regressors (FRED and other public sources)

other_defs = { ...
    'T10Y3M.xlsx',          'Slope of the yield curve (T10Y3M)'; ...
    'VIX.xlsx',             'VIX'; ...
    'WTI.xlsx',             'WTI crude oil price'; ...
    'iron_ore_price.xlsx',  'Iron ore price'; ...
    'DTB3.xlsx',            '3-month Treasury bill rate (DTB3, used for the convenience yields)'};

has_other = false(size(other_defs, 1), 1);
for ii = 1:size(other_defs, 1)
    has_other(ii) = monthly_workbook_has_data(fullfile(Folder_new_predictors, other_defs{ii, 1}));
end
if any(~has_other)
    idx = find(~has_other)';
    labels = cell(1, numel(idx));
    for kk = 1:numel(idx)
        labels{kk} = sprintf('%s [file %s]', other_defs{idx(kk), 2}, other_defs{idx(kk), 1});
    end
    groups(end+1) = make_group('Other financial regressors (FRED and other sources)', ...
        'Data/Other Predictors/', labels, ...
        'Tables S.11-S.14 (RMSFE ratios based on financial predictors)');
end

%% Output and message

data_check.all_available = isempty(groups);
data_check.groups = groups;
data_check.message = {};

if data_check.all_available
    return
end

msg = {'main_forecast.m requires data that cannot be redistributed with the replication package'; ...
       '(LSEG and Consensus Economics). The following data were NOT FOUND (or are empty):'; ''};
for gg = 1:numel(groups)
    msg{end+1} = sprintf('[%d] %s', gg, groups(gg).title); 
    msg{end+1} = ['      File: ', groups(gg).source];
    msg{end+1} = '      Missing:';
    for kk = 1:numel(groups(gg).missing)
        msg{end+1} = ['         - ', groups(gg).missing{kk}];
    end
    msg{end+1} = ['      Results that CANNOT be reproduced: ', groups(gg).affected];
    msg{end+1} = '';
end
msg{end+1} = 'Please refer to the README file in the main folder of the replication package: it explains';
msg{end+1} = 'where to obtain these data and how to enter them in the corresponding Excel files.';
msg{end+1} = 'Results of main_nowcast.m (Table 2 and Figure 2) do not depend on these data.';
msg{end+1} = '';
msg{end+1} = 'Click OK: main_forecast.m will stop.';
data_check.message = msg;

fprintf('\n%s\n', strjoin(msg, newline));

if show_popup
    try
        show_message_window(msg);
    catch ME
        warning('check_nonpublic_data:popup', 'Pop-up window could not be opened: %s', ME.message);
    end
end

end

%% Local functions

function group = make_group(title, source, missing, affected)
group = struct('title', title, 'source', source, 'missing', {missing}, 'affected', affected);
end

function T = read_table_safe(file)
T = table();
if isfile(file)
    try
        T = readtable(file, 'Sheet', 'Foglio1', 'VariableNamingRule', 'preserve');
    catch
        T = table();
    end
end
end

function tf = column_has_data(T, name)
tf = ismember(name, T.Properties.VariableNames) && has_numeric(T.(name));
end

function tf = has_numeric(x)
if isnumeric(x) || islogical(x)
    tf = any(isfinite(double(x(:))));
elseif iscell(x) || isstring(x) || iscategorical(x) || ischar(x)
    values = str2double(string(x));
    tf = any(isfinite(values(:)));
else
    tf = false;
end
end

function pos = find_sheet_position(sheets, wanted)
% Same matching rule as find_sheet() in import_financial_predictors.m
keys = lower(regexprep(cellstr(sheets), '[^A-Za-z0-9]', ''));
wanted_key = lower(regexprep(wanted, '[^A-Za-z0-9]', ''));
pos = find(strcmp(keys, wanted_key), 1);
if isempty(pos)
    pos = find(strcmp(regexprep(keys, 's$', ''), regexprep(wanted_key, 's$', '')), 1);
end
end

function tf = lseg_sheet_has_data(file, sheet)
% LSEG sheets: 6 header rows, dates in the first column, data from row 7
tf = false;
try
    C = readcell(file, 'Sheet', sheet);
    if size(C, 1) >= 7 && size(C, 2) >= 2
        tf = cells_have_numeric(C(7:end, 2:end));
    end
catch
end
end

function tf = monthly_workbook_has_data(file)
% FRED-type workbooks: header in row 1, dates in column 1, values in column 2
tf = false;
if ~isfile(file)
    return
end
try
    sheets = sheetnames(file);
    if any(strcmpi(sheets, 'Monthly'))
        sheet = sheets{find(strcmpi(sheets, 'Monthly'), 1)};
    else
        sheet = sheets{min(2, numel(sheets))};
    end
    C = readcell(file, 'Sheet', sheet);
    if size(C, 1) >= 2 && size(C, 2) >= 2
        tf = cells_have_numeric(C(2:end, 2));
    end
catch
end
end

function tf = cells_have_numeric(C)
is_num = cellfun(@(v) isnumeric(v) && isscalar(v) && isfinite(v), C);
tf = any(is_num(:));
end

function show_message_window(msg)
% Modal window with the message and an OK button
screen = get(groot, 'ScreenSize');
width = min(900, screen(3) - 100);
height = min(560, screen(4) - 120);
fig = uifigure('Name', 'Missing non-public data', 'WindowStyle', 'modal', ...
    'Position', [screen(1) + (screen(3) - width) / 2, screen(2) + (screen(4) - height) / 2, width, height]);
grid = uigridlayout(fig, [2 1], 'RowHeight', {'1x', 36}, 'Padding', [12 12 12 12]);
text_area = uitextarea(grid, 'Value', msg, 'Editable', 'off', 'FontSize', 13);
text_area.Layout.Row = 1;
button = uibutton(grid, 'Text', 'OK', 'FontSize', 14, 'ButtonPushedFcn', @(~, ~) delete(fig));
button.Layout.Row = 2;
fig.CloseRequestFcn = @(~, ~) delete(fig);
drawnow
uiwait(fig);
end
