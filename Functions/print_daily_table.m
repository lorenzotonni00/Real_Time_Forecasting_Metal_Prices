function print_daily_table(results_DAILY, target_series)
% Print one table per metal with BM-DFM results for financial (daily) predictors.
%
% Data:  results_DAILY.tables_ratio_long_DM.(metal){row, col}
%        col 1-9 = horizons [1,3,6,9,12,15,18,21,24]
% RW-D:  results_DAILY.TABLES_RMSPE_level.RW(h, metal_col)
% Bold:  ratio < 1

BOLD  = char([27 91 49 109]);   % ESC[1m
RESET = char([27 91 48 109]);   % ESC[0m

% ── short display names for financial predictors ──────────────────────────
pred_short = containers.Map( ...
    {'SP500',   'Gold',  'BDI',  'T10Y3M', 'VIX',  'WTI',  'Iron_Ore_Price', ...
     'Copper_convenience_yield',  'Aluminum_convenience_yield', ...
     'Nickel_convenience_yield',  'Zinc_convenience_yield', ...
     'Copper_equity_index_EW',    'Aluminum_equity_index_EW', ...
     'Nickel_equity_index_EW',    'Zinc_equity_index_EW'}, ...
    {'S&P 500', 'Gold',  'BDI',  'T10Y3M', 'VIX',  'WTI',  'Iron Ore', ...
     'CY-Cu',  'CY-Al', 'CY-Ni', 'CY-Zn', ...
     'Eq-Cu',  'Eq-Al', 'Eq-Ni', 'Eq-Zn'});

% Grouped ARDL names (NaN in DAILY because those regressor lists are empty)
grouped_ardl = { ...
    'ARDL_p_real_activity', 'ARDL_IC_real_activity', ...
    'ARDL_p_ex_rates',      'ARDL_IC_ex_rates', ...
    'ARDL_p_etm',           'ARDL_IC_etm', ...
    'ARDL_p_et',            'ARDL_IC_et', ...
    'ARDL_p_cu',            'ARDL_IC_cu', ...
    'ARDL_p_inventories',   'ARDL_IC_inventories', ...
    'ARDL_p_w_act',         'ARDL_IC_w_act' ...
};

% ── field names in the results struct ─────────────────────────────────────
modelli = fieldnames(results_DAILY.TABLES_level);

sections_static = { ...
    'Machine Learning', ...
        {{'Random_Forest',    'Random Forest'}, ...
         {'Gradient_Boosting','Gradient Boosting'}}; ...
    'Factor', ...
        {{'ARDI_p_1F',          'ARDI(1) - 1 Factor'}, ...
         {'ARDI_IC_1F',         'ARDI(AIC) - 1 Factor'}, ...
         {'ARDI_p_2F',          'ARDI(1) - 2 Factors'}, ...
         {'ARDI_IC_2F',         'ARDI(AIC) - 2 Factors'}} ...
};

% ── horizons ─────────────────────────────────────────────────────────────
horizons_DM = [1, 3, 6, 9, 12, 15, 18, 21, 24];
n_hor = numel(horizons_DM);

% ── layout ───────────────────────────────────────────────────────────────
w_model = 26;
w_hor   = 11;
total_w = w_model + n_hor * w_hor;
thick   = repmat('=', 1, total_w);
thin    = repmat('-', 1, total_w);

hdr = sprintf('%-*s', w_model, 'Model');
for hh = 1:n_hor
    hdr = [hdr sprintf('%*s', w_hor, ['Horizon ' num2str(horizons_DM(hh))])]; %#ok<AGROW>
end

% ── one table per metal ───────────────────────────────────────────────────
for mt = 1:numel(target_series)
    metal     = target_series{mt};
    metal_col = find(strcmp(target_series, metal), 1);

    % Build ARDL section for this metal
    ardl_section = {};
    seen_preds   = {};
    for mm_f = 1:numel(modelli)
        fn_f = modelli{mm_f};
        if ~startsWith(fn_f, 'ARDL_p_') || ismember(fn_f, grouped_ardl), continue; end
        pred = fn_f(8:end);
        if ismember(pred, seen_preds), continue; end
        if endsWith(pred, '_convenience_yield') && ~startsWith(pred, metal), continue; end
        if endsWith(pred, '_equity_index_EW')   && ~startsWith(pred, metal), continue; end
        if strcmp(pred, 'Iron_Ore_Price')        && ~strcmp(metal, 'Nickel'),  continue; end
        seen_preds{end+1} = pred; 
        if isKey(pred_short, pred)
            short = pred_short(pred);
        else
            short = strrep(pred, '_', ' ');
        end
        ardl_section{end+1} = {fn_f,              ['ARDL(1) - '   short]}; 
        ic_fn = ['ARDL_IC_' pred];
        if ismember(ic_fn, modelli)
            ardl_section{end+1} = {ic_fn, ['ARDL(AIC) - ' short]};
        end
    end
    sections = [{'ARDL', ardl_section}; sections_static];
    n_sec = size(sections, 1);

    fprintf('\n%s\n', thick);
    fprintf('Table S.X: %s real prices point forecasts based on financial data models and horizons.\n', metal);
    fprintf('%s\n', thick);
    fprintf('%s\n', hdr);

    % RW-D
    fprintf('%s\n', thin);
    fprintf('%s\n', cstr('RMSPE', total_w));
    fprintf('%s\n', thin);
    rwd = sprintf('%-*s', w_model, 'RW-D');
    for hh = 1:n_hor
        h   = horizons_DM(hh);
        val = results_DAILY.TABLES_RMSPE_level.RW(h, metal_col);
        if isnan(val), cs = '-'; else, cs = sprintf('%.2f', val); end
        rwd = [rwd sprintf('%*s', w_hor, cs)];
    end
    fprintf('%s\n', rwd);

    % Ratio sections
    fprintf('%s\n', thin);
    fprintf('%s\n', cstr('RMSPE Ratios', total_w));

    for ss = 1:n_sec
        sec_name   = sections{ss, 1};
        sec_models = sections{ss, 2};

        % skip entire section if no model has data for this metal
        has_data = false;
        for mm = 1:numel(sec_models)
            idx = find(strcmp(modelli, sec_models{mm}{1}), 1);
            if isempty(idx), continue; end
            for hh = 1:n_hor
                raw = results_DAILY.tables_ratio_long_DM.(metal){idx, hh};
                if ~isempty(raw) && ~isnan(str2double(regexprep(raw, '\*+$', '')))
                    has_data = true; break;
                end
            end
            if has_data, break; end
        end
        if ~has_data, continue; end

        fprintf('%s\n', thin);
        fprintf('%s\n', cstr(sec_name, total_w));
        fprintf('%s\n', thin);

        for mm = 1:numel(sec_models)
            fn      = sec_models{mm}{1};
            disp_nm = sec_models{mm}{2};
            row_idx = find(strcmp(modelli, fn), 1);
            row     = sprintf('%-*s', w_model, disp_nm);

            for hh = 1:n_hor
                if isempty(row_idx)
                    padded = sprintf('%*s', w_hor, '-');
                else
                    raw = results_DAILY.tables_ratio_long_DM.(metal){row_idx, hh};
                    if isempty(raw)
                        padded = sprintf('%*s', w_hor, '-');
                    else
                        stars_m = regexp(raw, '\*+$', 'match');
                        if ~isempty(stars_m), stars = stars_m{1}; else, stars = ''; end
                        num_val = str2double(regexprep(raw, '\*+$', ''));
                        if isnan(num_val)
                            padded = sprintf('%*s', w_hor, '-');
                        else
                            cs     = [sprintf('%.2f', num_val) stars];
                            padded = sprintf('%*s', w_hor, cs);
                            if num_val < 1
                                k = find(padded ~= ' ', 1);
                                padded = [padded(1:k-1) BOLD padded(k:end) RESET];
                            end
                        end
                    end
                end
                row = [row padded];
            end
            fprintf('%s\n', row);
        end
    end

    fprintf('%s\n', thin);
    fprintf('%s\n', thick);
    fprintf('Notes: For the RW-D model, we report the RMSPE, while for all other models, we present\n');
    fprintf('the RMSPE ratio relative to the RW-D model. RMSPE refers to the real price in USD per\n');
    fprintf('metric ton, with February 2015 CPI as base year. A ratio below one (in bold) indicates\n');
    fprintf('that the model outperforms the RW-D model. Asterisks denote statistical significance at\n');
    fprintf('the 1%% (***), 5%% (**) and 10%% (*) based on the Diebold and Mariano (1995) test.\n');
    fprintf('%s\n', thick);
end
end

% ── local helper ──────────────────────────────────────────────────────────
function s = cstr(label, width)
pad = max(0, floor((width - numel(label)) / 2));
s = [repmat(' ', 1, pad) label];
end
