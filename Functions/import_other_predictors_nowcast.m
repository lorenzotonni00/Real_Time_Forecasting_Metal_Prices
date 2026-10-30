function [NOWCAST_PANELS, FINANCIAL_PREDICTORS, import_report] = import_other_predictors_nowcast(new_predictors_folder, ETM, nowcast_ids, financial_ids)

if nargin < 1 || isempty(new_predictors_folder)
    new_predictors_folder = fullfile(pwd, 'Data', 'Other Predictors');
end

if nargin < 3
    nowcast_ids = default_nowcast_ids();
else
    nowcast_ids = cellstr(nowcast_ids(:));
end

if nargin < 4
    financial_ids = default_financial_ids();
else
    financial_ids = cellstr(financial_ids(:));
end

exchange_folder = fullfile(new_predictors_folder, 'exchange_rates');
lseg_file = '';

import_report = struct();
import_report.lseg_file = lseg_file;
import_report.exchange_rates = struct();
import_report.missing_exchange_rates = missing_exchange_rate_table();
import_report.requested_nowcast_ids = nowcast_ids(:)';
import_report.requested_financial_ids = financial_ids(:)';

%% Nowcasted real-time panels

panels = struct('id', {}, 'obs', {}, 'vintages', {}, 'data', {}, 'source', {});
if any(strcmp(nowcast_ids, 'WIP'))
    panels(end+1) = read_wip_panel(fullfile(new_predictors_folder, 'WIP_baumeister.xlsx'));
end

[cli_panels, cli_report] = read_cli_vintage_panels(fullfile(new_predictors_folder, 'CLI_vintages.csv'), nowcast_ids);
panels = [panels, cli_panels];
import_report.cli = cli_report;

NOWCAST_PANELS = pack_panels(panels);

%% Financial variables available without publication lag

series = struct('id', {}, 'obs', {}, 'data', {}, 'source', {});

lseg_required_ids = { ...
    'SP500', 'Gold', 'BDI', ...
    'Copper_convenience_yield', 'Aluminum_convenience_yield', 'Nickel_convenience_yield', 'Zinc_convenience_yield', ...
    'Copper_equity_index_EW', 'Aluminum_equity_index_EW', 'Nickel_equity_index_EW', 'Zinc_equity_index_EW'};
if any(ismember(financial_ids, lseg_required_ids))
    lseg_file = first_existing_file(new_predictors_folder, {'LSEG_2.xlsx'});
    import_report.lseg_file = lseg_file;
end

if any(strcmp(financial_ids, 'SP500'))
    series = [series, read_lseg_direct_sheet(lseg_file, 'sp500', 'SP500')];
end
if any(strcmp(financial_ids, 'Gold'))
    series = [series, read_lseg_direct_sheet(lseg_file, 'gold', 'Gold')];
end
if any(strcmp(financial_ids, 'BDI'))
    series = [series, read_lseg_direct_sheet(lseg_file, 'BDI', 'BDI')];
end
if any(strcmp(financial_ids, 'T10Y3M'))
    series = [series, read_fred_monthly_series(fullfile(new_predictors_folder, 'T10Y3M.xlsx'), 'T10Y3M')];
end
if any(strcmp(financial_ids, 'VIX'))
    series = [series, read_fred_monthly_series(fullfile(new_predictors_folder, 'VIX.xlsx'), 'VIX')];
end
if any(strcmp(financial_ids, 'WTI'))
    series = [series, read_fred_monthly_series(fullfile(new_predictors_folder, 'WTI.xlsx'), 'WTI')];
end
if any(strcmp(financial_ids, 'Iron_Ore_Price'))
    series = [series, read_fred_monthly_series(fullfile(new_predictors_folder, 'iron_ore_price.xlsx'), 'Iron_Ore_Price')];
end

metal_defs = { ...
    'Copper', 'COPPER FUTURE', 'Copper_convenience_yield'; ...
    'Aluminum', 'ALUMINUM FUTURES', 'Aluminum_convenience_yield'; ...
    'Nickel', 'NICKEL FUTURES', 'Nickel_convenience_yield'; ...
    'Zinc', 'ZINC FUTURES', 'Zinc_convenience_yield'};

requested_convenience = ismember(metal_defs(:, 3), financial_ids);
if any(requested_convenience)
    if nargin < 2 || isempty(ETM)
        error('ETM must be provided to compute metal convenience yields.');
    end
    risk_free = read_fred_monthly_series(fullfile(new_predictors_folder, 'DTB3.xlsx'), 'DTB3');
    for ii = find(requested_convenience)'
        spot = etm_series(ETM, metal_defs{ii, 1});
        future = read_lseg_direct_sheet(lseg_file, metal_defs{ii, 2}, [metal_defs{ii, 1}, '_future']);

        [obs, rf, fut, spot_price] = align_series({risk_free, future, spot});
        cy = (rf ./ 100) - ((fut - spot_price) ./ spot_price);
        cy(~isfinite(cy)) = NaN;

        series(end+1) = make_series(metal_defs{ii, 3}, obs, cy, 'convenience_yield');
    end
end

equity_defs = { ...
    'Copper', 'Copper Top20 Stocks', 'Copper_equity_index_EW'; ...
    'Aluminum', 'Aluminum Top20 Stocks', 'Aluminum_equity_index_EW'; ...
    'Nickel', 'Nickel Top20 Stocks', 'Nickel_equity_index_EW'; ...
    'Zinc', 'Zinc Top20 Stocks', 'Zinc_equity_index_EW'};

exchange_cache = struct();
missing_fx_tables = {};
for ii = 1:size(equity_defs, 1)
    if ~any(strcmp(financial_ids, equity_defs{ii, 3}))
        continue
    end

    metal = equity_defs{ii, 1};
    [index_series, weight_table, missing_fx_table, exchange_cache] = build_top20_equal_weight_index( ...
        lseg_file, equity_defs{ii, 2}, equity_defs{ii, 3}, exchange_folder, exchange_cache);

    series(end+1) = index_series;
    import_report.equity_equal_weights.(metal) = weight_table;

    if height(missing_fx_table) > 0
        missing_fx_table = addvars(missing_fx_table, repmat(string(metal), height(missing_fx_table), 1), ...
            'Before', 1, 'NewVariableNames', 'Metal');
        missing_fx_tables{end+1} = missing_fx_table;
    end
end

import_report.exchange_rates = exchange_cache;
if ~isempty(missing_fx_tables)
    import_report.missing_exchange_rates = vertcat(missing_fx_tables{:});
end

FINANCIAL_PREDICTORS = pack_series(series);

end

function ids = default_nowcast_ids()

ids = { ...
    'WIP'; ...
    'CLI_United_States'; ...
    'CLI_Major_four_European_countries'; ...
    'CLI_G7'; ...
    'CLI_G20'; ...
    'CLI_China'; ...
    'CLI_India'; ...
    'CLI_Major_five_Asia_economies'; ...
    'CLI_Indonesia'};

end

function ids = default_financial_ids()

ids = { ...
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

end

function panel = read_wip_panel(file)

if exist(file, 'file') ~= 2
    error('Cannot find WIP workbook: %s', file);
end

C = readcell(file, 'Sheet', 'WIP');
obs = month_start(cell_to_datetime(C(2:end, 1)));
vintages = month_start(cell_to_datetime(C(1, 2:end)));
data = cell_to_double(C(2:end, 2:end), false);

panel = make_panel('WIP', obs, vintages, data, file);

end

function [panels, report] = read_cli_vintage_panels(file, requested_ids)

if exist(file, 'file') ~= 2
    error('Cannot find CLI vintage CSV: %s', file);
end

selected = { ...
    'United States', 'CLI_United_States'; ...
    'Major four European countries', 'CLI_Major_four_European_countries'; ...
    'G7', 'CLI_G7'; ...
    'G20', 'CLI_G20'; ...
    'China (People''s Republic of)', 'CLI_China'; ...
    'China (People’s Republic of)', 'CLI_China'; ...
    'India', 'CLI_India'; ...
    'Major five Asia economies', 'CLI_Major_five_Asia_economies'; ...
    'Indonesia', 'CLI_Indonesia'};

if nargin >= 2
    requested_ids = cellstr(requested_ids(:));
    selected = selected(ismember(selected(:, 2), requested_ids), :);
end

opts = detectImportOptions(file, 'VariableNamingRule', 'preserve');
T = readtable(file, opts);
area = string(T.('Reference area'));
measure = string(T.MEASURE);

panels = struct('id', {}, 'obs', {}, 'vintages', {}, 'data', {}, 'source', {});
matched = strings(0, 2);
missing = strings(0, 2);
exported_ids = strings(0, 1);

for ii = 1:size(selected, 1)
    output_id = string(selected{ii, 2});
    if any(exported_ids == output_id)
        continue
    end

    row_filter = strcmpi(area, selected{ii, 1}) & strcmpi(measure, 'LI_AA');
    if ~any(row_filter)
        missing(end+1, :) = [output_id, string(selected{ii, 1})];
        continue
    end

    sub = T(row_filter, :);
    obs = time_period_to_datetime(string(sub.TIME_PERIOD));
    vintages = edition_to_datetime(sub.EDITION);
    values = double(sub.OBS_VALUE);

    valid = ~isnat(obs) & ~isnat(vintages) & isfinite(values);
    obs = obs(valid);
    vintages = vintages(valid);
    values = values(valid);

    [obs_unique, ~, obs_idx] = unique(obs);
    [vin_unique, ~, vin_idx] = unique(vintages);
    data = NaN(numel(obs_unique), numel(vin_unique));
    for rr = 1:numel(values)
        data(obs_idx(rr), vin_idx(rr)) = values(rr);
    end

    panels(end+1) = make_panel(output_id, obs_unique, vin_unique, data, file);
    matched(end+1, :) = [output_id, string(sub.('Reference area'){1})];
    exported_ids(end+1, 1) = output_id;
end

if ~isempty(missing)
    unresolved = missing(~ismember(missing(:, 1), exported_ids), 2);
else
    unresolved = strings(0, 1);
end

if ~isempty(unresolved)
    warning('CLI_vintages.csv does not contain requested areas: %s', strjoin(cellstr(unique(unresolved)), ', '));
end

report = struct();
report.matched = array2table(matched, 'VariableNames', {'ExportedID', 'ReferenceArea'});
report.missing_requested_areas = unique(unresolved);

end

function dates = time_period_to_datetime(values)

dates = NaT(numel(values), 1);
for ii = 1:numel(values)
    txt = strtrim(char(values(ii)));
    if isempty(txt) || strcmpi(txt, '<missing>')
        continue
    end
    try
        dates(ii) = datetime(txt, 'InputFormat', 'yyyy-MM');
    catch
        try
            dates(ii) = datetime(txt, 'InputFormat', 'yyyy-MM-dd');
        catch
        end
    end
end
dates = month_start(dates);

end

function dates = edition_to_datetime(values)

values = double(values);
dates = NaT(numel(values), 1);
for ii = 1:numel(values)
    if ~isfinite(values(ii))
        continue
    end

    txt = sprintf('%06.0f', values(ii));
    yy = str2double(txt(1:4));
    mm = str2double(txt(5:6));
    if isfinite(yy) && isfinite(mm) && mm >= 1 && mm <= 12
        dates(ii) = datetime(yy, mm, 1);
    end
end

end

function series = read_lseg_direct_sheet(file, sheet_name, output_id)

sheet = find_sheet(file, sheet_name);
C = readcell(file, 'Sheet', sheet);
dates = month_start(cell_to_datetime(C(7:end, 1)));
values = cell_to_double(C(7:end, 2), false);
series = make_series(output_id, dates, values, sheet);

end

function series = read_fred_monthly_series(file, output_id)

if exist(file, 'file') ~= 2
    error('Cannot find monthly workbook: %s', file);
end

sheets = sheetnames(file);
if any(strcmpi(sheets, 'Monthly'))
    sheet = sheets{find(strcmpi(sheets, 'Monthly'), 1)};
else
    sheet = sheets{min(2, numel(sheets))};
end

C = readcell(file, 'Sheet', sheet);
dates = month_start(cell_to_datetime(C(2:end, 1)));
values = cell_to_double(C(2:end, 2), false);
series = make_series(output_id, dates, values, file);

end

function series = etm_series(ETM, id)

pos = find(strcmp(ETM.id, id), 1);
if isempty(pos)
    error('ETM series %s not found.', id);
end

series = make_series(id, month_start(ETM.obs), ETM.data(:, pos), 'ETM');

end

function [index_series, weight_table, missing_fx_table, exchange_cache] = build_top20_equal_weight_index(lseg_file, top20_sheet, output_id, exchange_folder, exchange_cache)

C = readcell(lseg_file, 'Sheet', find_sheet(lseg_file, top20_sheet));
dates = month_start(cell_to_datetime(C(7:end, 1)));
names = C(4, 2:end);
currencies = C(6, 2:end);

valid_cols = find(~cellfun(@is_empty_cell, names));
names = names(valid_cols);
currencies = currencies(valid_cols);
local_prices = cell_to_double(C(7:end, valid_cols + 1), false);
quoted = isfinite(local_prices) & local_prices > 0;

usd_prices = NaN(size(local_prices));
missing_fx = false(size(local_prices));
fx_first_obs = NaT(numel(names), 1);
fx_last_obs = NaT(numel(names), 1);

for jj = 1:numel(names)
    currency = normalize_currency(currencies{jj});
    company_quoted = quoted(:, jj);

    if is_usd_currency(currency)
        company_usd_prices = local_prices(:, jj);
    else
        [fx, has_fx, exchange_cache] = get_exchange_series(currency, exchange_folder, exchange_cache);
        if has_fx
            finite_fx = find(isfinite(fx.data));
            if ~isempty(finite_fx)
                fx_first_obs(jj) = fx.obs(finite_fx(1));
                fx_last_obs(jj) = fx.obs(finite_fx(end));
            end
            fx_aligned = align_one_series(fx, dates);
            missing_fx(:, jj) = company_quoted & ~isfinite(fx_aligned);
            company_usd_prices = local_prices(:, jj) ./ fx_aligned;
        else
            missing_fx(:, jj) = company_quoted;
            company_usd_prices = NaN(size(local_prices(:, jj)));
        end
    end

    company_usd_prices(~company_quoted) = NaN;
    company_usd_prices(company_quoted & ~isfinite(company_usd_prices)) = NaN;
    usd_prices(:, jj) = company_usd_prices;
end

[price_relatives, base_prices, base_dates] = price_relatives_to_first_price(dates, usd_prices);
active = isfinite(price_relatives);
weights = dynamic_weights_equal(active);
index_values = 100 .* sum(weights .* price_relatives, 2, 'omitnan');
index_values(~any(active, 2)) = NaN;

index_series = make_series(output_id, dates, index_values, top20_sheet);

weight_table = array2table(100 .* weights, 'VariableNames', company_weight_variable_names(names));
weight_table = addvars(weight_table, dates(:), 'Before', 1, 'NewVariableNames', 'Date');
base_table = table(string(names(:)), string(currencies(:)), base_dates(:), base_prices(:), ...
    'VariableNames', {'Name', 'Currency', 'BaseDate', 'BasePriceUSD'});
weight_table.Properties.UserData.base_prices = base_table;

missing_fx_table = missing_exchange_rate_table(names, currencies, dates, quoted, missing_fx, fx_first_obs, fx_last_obs);

end

function [price_relatives, base_prices, base_dates] = price_relatives_to_first_price(dates, prices)

n_companies = size(prices, 2);
price_relatives = NaN(size(prices));
base_prices = NaN(n_companies, 1);
base_dates = NaT(n_companies, 1);

for jj = 1:n_companies
    idx = find(isfinite(prices(:, jj)) & prices(:, jj) > 0, 1, 'first');
    if isempty(idx)
        continue
    end

    base_prices(jj) = prices(idx, jj);
    base_dates(jj) = dates(idx);
    price_relatives(:, jj) = prices(:, jj) ./ base_prices(jj);
end

end

function weights = dynamic_weights_equal(active)

weights = zeros(size(active));
n_active = sum(active, 2);

for tt = 1:size(active, 1)
    if n_active(tt) > 0
        weights(tt, active(tt, :)) = 1 ./ n_active(tt);
    else
        weights(tt, :) = NaN;
    end
end

end

function [fx, has_fx, exchange_cache] = get_exchange_series(currency, exchange_folder, exchange_cache)

currency = normalize_currency(currency);
field = matlab.lang.makeValidName(currency);

if isfield(exchange_cache, field)
    fx = exchange_cache.(field).series;
    has_fx = exchange_cache.(field).has_fx;
    return
end

[file, has_fx] = exchange_rate_file(currency, exchange_folder);
if ~has_fx
    warning('No exchange-rate file found for currency %s in %s. Related companies are omitted from the EW index.', currency, exchange_folder);
    fx = make_series(currency, NaT(0, 1), NaN(0, 1), '');
    exchange_cache.(field).series = fx;
    exchange_cache.(field).has_fx = false;
    exchange_cache.(field).mean_rate = NaN;
    exchange_cache.(field).source_file = '';
    return
end

[~, ~, ext] = fileparts(file);
if strcmpi(ext, '.xlsx')
    sheets = sheetnames(file);
    if any(strcmpi(sheets, 'Monthly'))
        sheet = sheets{find(strcmpi(sheets, 'Monthly'), 1)};
    else
        sheet = sheets{min(2, numel(sheets))};
    end
    C = readcell(file, 'Sheet', sheet);
    dates = month_start(cell_to_datetime(C(2:end, 1)));
    values = cell_to_double(C(2:end, 2), false);
elseif strcmpi(ext, '.csv')
    opts = detectImportOptions(file, 'VariableNamingRule', 'preserve');
    date_var = find(strcmpi(opts.VariableNames, 'Date'), 1);
    if ~isempty(date_var)
        opts = setvaropts(opts, opts.VariableNames{date_var}, 'InputFormat', 'MM/dd/yyyy');
    end
    T = readtable(file, opts);
    dates = month_start(table_date_column(T));
    open_name = find(strcmpi(T.Properties.VariableNames, 'Open'), 1);
    if isempty(open_name)
        error('CSV exchange-rate file %s does not contain an Open column.', file);
    end
    values = table2array(T(:, open_name));
else
    error('Unsupported exchange-rate file: %s', file);
end

values(~isfinite(values)) = NaN;
mean_rate = mean(values, 'omitnan');
if isfinite(mean_rate) && mean_rate <= 1
    values = 1 ./ values;
    mean_rate = mean(values, 'omitnan');
end

fx = make_series(currency, dates, values, file);
exchange_cache.(field).series = fx;
exchange_cache.(field).has_fx = true;
exchange_cache.(field).mean_rate = mean_rate;
exchange_cache.(field).source_file = file;

end

function [file, found] = exchange_rate_file(currency, exchange_folder)

currency = normalize_currency(currency);
candidate_xlsx = fullfile(exchange_folder, [currency, '.xlsx']);
candidate_csv = fullfile(exchange_folder, [currency, '.csv']);

if exist(candidate_xlsx, 'file') == 2
    file = candidate_xlsx;
    found = true;
elseif exist(candidate_csv, 'file') == 2
    file = candidate_csv;
    found = true;
else
    file = '';
    found = false;
end

end

function currency = normalize_currency(currency)

currency = upper(strtrim(char(string(currency))));

if any(strcmp(currency, {'U$', 'US$', '$', 'USD'}))
    currency = 'USD';
elseif strcmp(currency, 'C$')  % OK
    currency = 'CA';
elseif strcmp(currency, 'A$') % OK
    currency = 'AU';
elseif strcmp(currency, 'Y') % OK
    currency = 'JP';
elseif strcmp(currency, 'CH') % OK
    currency = 'CHN';
elseif strcmp(currency, 'K$') % OK
    currency = 'HK';
elseif strcmp(currency, 'Q') % OK
    currency = 'QA';
elseif strcmp(currency, 'RL') % OK
    currency = 'RO';
elseif strcmp(currency, 'IR') % OK
    currency = 'INDI';
elseif strcmp(currency, 'RI') % OK
    currency = 'INDO';
elseif strcmp(currency, 'PP') % OK
    currency = 'PH';
elseif strcmp(currency, 'SK') % OK
    currency = 'SW';
elseif strcmp(currency, 'R') % OK
    currency = 'SF';
end

end

function tf = is_usd_currency(currency)

currency = normalize_currency(currency);
tf = any(strcmp(currency, {'USD', 'NA'}));

end

function T = missing_exchange_rate_table(names, currencies, dates, quoted, missing_fx, fx_first_obs, fx_last_obs)

var_names = {'Top20Name', 'Currency', 'NQuotedObs', 'FirstQuoted', 'LastQuoted', ...
    'NMissingFXWhenQuoted', 'FirstMissingFX', 'LastMissingFX', 'FXFirstObs', 'FXLastObs'};

if nargin == 0
    T = table('Size', [0, numel(var_names)], ...
        'VariableTypes', {'string', 'string', 'double', 'datetime', 'datetime', ...
        'double', 'datetime', 'datetime', 'datetime', 'datetime'}, ...
        'VariableNames', var_names);
    return
end

rows = {};
for jj = 1:numel(names)
    missing_idx = find(missing_fx(:, jj));
    if isempty(missing_idx)
        continue
    end

    quoted_idx = find(quoted(:, jj));
    rows(end+1, :) = {string(names{jj}), string(normalize_currency(currencies{jj})), ...
        numel(quoted_idx), dates(quoted_idx(1)), dates(quoted_idx(end)), ...
        numel(missing_idx), dates(missing_idx(1)), dates(missing_idx(end)), ...
        fx_first_obs(jj), fx_last_obs(jj)}; %#ok<AGROW>
end

if isempty(rows)
    T = missing_exchange_rate_table();
else
    T = cell2table(rows, 'VariableNames', var_names);
end

end

function P = pack_panels(panels)

if isempty(panels)
    P = struct();
    P.data = NaN(0, 0, 0);
    P.obs = NaT(0, 1);
    P.vintages = NaT(0, 1);
    P.id = {};
    P.source = {};
    return
end

ids = {panels.id};
if numel(unique(ids)) ~= numel(ids)
    error('Duplicate nowcast-panel ids: %s', strjoin(ids, ', '));
end

all_obs = unique(vertcat(panels.obs));
all_vintages = unique(vertcat(panels.vintages));
all_obs = all_obs(~isnat(all_obs));
all_vintages = all_vintages(~isnat(all_vintages));

data = NaN(numel(all_obs), numel(all_vintages), numel(panels));
for jj = 1:numel(panels)
    [obs_match, obs_pos] = ismember(month_start(all_obs), month_start(panels(jj).obs));
    [vin_match, vin_pos] = ismember(month_start(all_vintages), month_start(panels(jj).vintages));
    tmp = NaN(numel(all_obs), numel(all_vintages));
    tmp(obs_match, vin_match) = panels(jj).data(obs_pos(obs_match), vin_pos(vin_match));
    data(:, :, jj) = tmp;
end

P = struct();
P.data = data;
P.obs = all_obs;
P.vintages = all_vintages;
P.id = ids;
P.source = {panels.source};

end

function P = make_panel(id, obs, vintages, data, source)

P = struct();
P.id = matlab.lang.makeValidName(char(string(id)));
P.obs = month_start(obs(:));
P.vintages = month_start(vintages(:));
P.data = double(data);
P.source = source;

valid_obs = ~isnat(P.obs);
valid_vintages = ~isnat(P.vintages);
P.obs = P.obs(valid_obs);
P.vintages = P.vintages(valid_vintages);
P.data = P.data(valid_obs, valid_vintages);

[P.obs, obs_idx] = unique(P.obs, 'last');
[P.vintages, vin_idx] = unique(P.vintages, 'last');
P.data = P.data(obs_idx, vin_idx);

end

function S = pack_series(series)

if isempty(series)
    S = struct();
    S.data = NaN(0, 0);
    S.obs = NaT(0, 1);
    S.id = {};
    S.source = {};
    return
end

ids = {series.id};
if numel(unique(ids)) ~= numel(ids)
    error('Duplicate financial predictor ids: %s', strjoin(ids, ', '));
end

all_dates = unique(vertcat(series.obs));
all_dates = all_dates(~isnat(all_dates));
obs = (min(all_dates):calmonths(1):max(all_dates))';
data = NaN(numel(obs), numel(series));

for jj = 1:numel(series)
    data(:, jj) = align_one_series(series(jj), obs);
end

S = struct();
S.data = data;
S.obs = obs;
S.id = ids;
S.source = {series.source};

end

function values = align_one_series(series, obs)

[in_sample, pos] = ismember(month_start(obs), month_start(series.obs));
values = NaN(numel(obs), 1);
values(in_sample) = series.data(pos(in_sample));

end

function [obs, varargout] = align_series(series_cell)

obs = month_start(series_cell{1}.obs);
for ii = 2:numel(series_cell)
    obs = intersect(obs, month_start(series_cell{ii}.obs));
end
obs = sort(obs);

varargout = cell(1, numel(series_cell));
for ii = 1:numel(series_cell)
    varargout{ii} = align_one_series(series_cell{ii}, obs);
end

end

function s = make_series(id, obs, data, source)

s = struct();
s.id = matlab.lang.makeValidName(char(string(id)));
s.obs = month_start(obs(:));
s.data = double(data(:));
s.source = source;

valid = ~isnat(s.obs);
s.obs = s.obs(valid);
s.data = s.data(valid);

[s.obs, order] = sort(s.obs);
s.data = s.data(order);

[s.obs, unique_idx] = unique(s.obs, 'last');
s.data = s.data(unique_idx);

end

function sheet = find_sheet(file, wanted)

sheets = sheetnames(file);
keys = cellfun(@normalize_text_key, cellstr(sheets), 'UniformOutput', false);
wanted_key = normalize_text_key(wanted);
pos = find(strcmp(keys, wanted_key), 1);

if isempty(pos)
    wanted_key_no_s = regexprep(wanted_key, 's$', '');
    keys_no_s = regexprep(keys, 's$', '');
    pos = find(strcmp(keys_no_s, wanted_key_no_s), 1);
end

if isempty(pos)
    error('Workbook %s does not contain sheet "%s".', file, wanted);
end

sheet = sheets{pos};

end

function file = first_existing_file(folder, candidates)

for ii = 1:numel(candidates)
    file = fullfile(folder, candidates{ii});
    if exist(file, 'file') == 2
        return
    end
end

error('Cannot find any expected file in %s: %s', folder, strjoin(candidates, ', '));

end

function values = cell_to_double(c, na_as_zero)

if isnumeric(c)
    values = double(c);
    values(~isfinite(values)) = NaN;
    if na_as_zero
        values(isnan(values)) = 0;
    end
    return
end

values = NaN(size(c));
for ii = 1:numel(c)
    x = c{ii};
    if is_empty_cell(x)
        if na_as_zero
            values(ii) = 0;
        end
    elseif isnumeric(x)
        values(ii) = double(x);
    else
        txt = strtrim(char(string(x)));
        if any(strcmpi(txt, {'NA', 'N/A', '#N/A', ''}))
            if na_as_zero
                values(ii) = 0;
            end
        else
            values(ii) = str2double(strrep(txt, ',', ''));
        end
    end
end

values(~isfinite(values)) = NaN;
if na_as_zero
    values(isnan(values)) = 0;
end

end

function dates = cell_to_datetime(c)

if ~iscell(c)
    c = num2cell(c);
end

dates = NaT(numel(c), 1);
for ii = 1:numel(c)
    x = c{ii};
    if is_empty_cell(x)
        continue
    elseif isdatetime(x)
        dates(ii) = x;
    elseif isnumeric(x)
        dates(ii) = datetime(x, 'ConvertFrom', 'excel');
    else
        txt = strtrim(char(string(x)));
        formats = {'yyyy-MM-dd', 'dd-MMM-yyyy', 'MM/dd/yyyy', 'dd/MM/yyyy'};
        for ff = 1:numel(formats)
            try
                dates(ii) = datetime(txt, 'InputFormat', formats{ff});
                break
            catch
            end
        end
    end
end
dates = month_start(dates);

end

function dates = table_date_column(T)

date_idx = find(strcmpi(T.Properties.VariableNames, 'Date'), 1);
if isempty(date_idx)
    date_idx = 1;
end

raw = T{:, date_idx};
if isdatetime(raw)
    dates = raw;
elseif iscell(raw) || isstring(raw) || ischar(raw)
    dates = datetime(raw, 'InputFormat', 'MM/dd/yyyy');
else
    dates = datetime(raw, 'ConvertFrom', 'excel');
end

end

function tf = is_empty_cell(x)

tf = false;
if any(ismissing(x))
    tf = true;
elseif isempty(x)
    tf = true;
elseif ischar(x) || isstring(x)
    tf = strlength(strtrim(string(x))) == 0;
end

end

function d = month_start(d)

d = datetime(year(d), month(d), 1);

end

function key = normalize_text_key(x)

if is_empty_cell(x)
    key = '';
    return
end

txt = lower(char(string(x)));
key = regexprep(txt, '[^a-z0-9]', '');

end

function var_names = company_weight_variable_names(names)

var_names = matlab.lang.makeValidName("w_" + string(names(:))');
var_names = matlab.lang.makeUniqueStrings(var_names);
var_names = cellstr(var_names);

end
