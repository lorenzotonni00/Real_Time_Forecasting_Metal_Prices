function print_forecast_tables(results_US_WORLD, target_series)
% Print Tables 3 and 4 to the command window.
%   Table 3: Copper and Aluminum
%   Table 4: Zinc and Nickel
%
% Data: results_US_WORLD.tables_ratio_long_DM.(metal)  [n_models x 9]
%       columns 1-9 = horizons [1,3,6,9,12,15,18,21,24]
% RW-D: results_US_WORLD.(metal).RW.RMSPE_level(1, h)
% Bold: ratio < 1 printed in bold via ANSI codes

BOLD  = char([27 91 49 109]);   % ESC[1m
RESET = char([27 91 48 109]);   % ESC[0m

% ── models to display ─────────────────────────────────────────────────────
model_fn = { ...
    'futures',              'Futures'; ...
    'p_forecasts',          'Professional Forecasters'; ...
    'ARDL_p_real_activity', 'ARDL(1) - Ec. Activity'; ...
    'ARDL_p_ex_rates',      'ARDL(1) - Ex. Rates'; ...
    'ARDL_p_etm',           'ARDL(1) - ETM Prices'; ...
    'ARDL_p_et',            'ARDL(1) - ET'; ...
    'ARDL_p_cu',            'ARDL(1) - CU'; ...
    'ARDL_p_inventories',   'ARDL(1) - Inventories'; ...
    'ARDL_p_w_act',         'ARDL(1) - World. Act.'; ...
    'VAR_p_specific',       'VAR(1)'; ...
    'ARDI_p_2F',            'ARDI(1) - 2 Factors'; ...
    'FAVAR_specific_p_2F',  'FAVAR(1) - 2 Factors'; ...
    'Random_Forest',        'Random Forest'; ...
    'Gradient_Boosting',    'Gradient Boosting'  ...
};
n_display = size(model_fn, 1);

% map each display model to its row index in tables_ratio_long_DM
modelli = fieldnames(results_US_WORLD.TABLES_level);
model_rows = zeros(n_display, 1);
for mm = 1:n_display
    idx = find(strcmp(modelli, model_fn{mm, 1}), 1);
    if ~isempty(idx), model_rows(mm) = idx; end
end

% ── horizons ──────────────────────────────────────────────────────────────
horizons_DM = [1, 3, 6, 9, 12, 15, 18, 21, 24];
n_hor = numel(horizons_DM);

% ── column widths ─────────────────────────────────────────────────────────
w_metal = 12;
w_model = 26;
w_hor   = 11;
total_w = w_metal + w_model + n_hor * w_hor;
thick   = repmat('=', 1, total_w);
thin    = repmat('-', 1, total_w);

% header (printed once per table, same for both)
hdr = [sprintf('%-*s', w_metal, 'Metal') sprintf('%-*s', w_model, 'Model')];
for hh = 1:n_hor
    hdr = [hdr sprintf('%*s', w_hor, ['Horizon ' num2str(horizons_DM(hh))])];
end

% ── table definitions ─────────────────────────────────────────────────────
tables_def = { ...
    {'Copper','Aluminum'}, 3, 'Copper and aluminum real prices point forecasts based on different models and horizons.'; ...
    {'Zinc',  'Nickel'},   4, 'Zinc and nickel real prices point forecasts based on different models and horizons.' ...
};

% ── print tables ──────────────────────────────────────────────────────────
for tt = 1:2
    metals    = tables_def{tt, 1};
    tbl_num   = tables_def{tt, 2};
    tbl_title = tables_def{tt, 3};

    fprintf('\n%s\n', thick);
    fprintf('Table %d: %s\n', tbl_num, tbl_title);
    fprintf('%s\n', thick);
    fprintf('%s\n', hdr);
    fprintf('%s\n', thin);

    for mm = 1:numel(metals)
        metal = metals{mm};

        % ── RW-D row (absolute RMSPE) ──────────────────────────────────
        metal_col = find(strcmp(target_series, metal), 1);
        row = [sprintf('%-*s', w_metal, metal) sprintf('%-*s', w_model, 'RW-D')];
        for hh = 1:n_hor
            h = horizons_DM(hh);
            val = results_US_WORLD.TABLES_RMSPE_level.RW(h, metal_col);
            if isnan(val), cs = '-'; else, cs = sprintf('%.2f', val); end
            row = [row sprintf('%*s', w_hor, cs)];
        end
        fprintf('%s\n', row);
        fprintf('%s\n', thin);

        % ── model rows ────────────────────────────────────────────────
        for md = 1:n_display
            row_idx  = model_rows(md);
            disp_nm  = model_fn{md, 2};
            row = [sprintf('%-*s', w_metal, '') sprintf('%-*s', w_model, disp_nm)];

            for hh = 1:n_hor
                if row_idx == 0
                    padded = sprintf('%*s', w_hor, '-');
                else
                    raw = results_US_WORLD.tables_ratio_long_DM.(metal){row_idx, hh};
                    if isempty(raw)
                        padded = sprintf('%*s', w_hor, '-');
                    else
                        % extract numeric part and stars
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
        fprintf('%s\n', thin);
    end

    fprintf('%s\n', thick);
    fprintf('Notes: For the RW-D model, we report the RMSPE, while for all other models, we present\n');
    fprintf('the RMSPE ratio relative to the RW-D model. RMSPE refers to the real price in USD per\n');
    fprintf('metric ton, with February 2015 CPI as base year. A ratio below one (in bold) indicates\n');
    fprintf('that the model outperforms the RW-D model. Asterisks denote statistical significance at\n');
    fprintf('the 1%% (***), 5%% (**) and 10%% (*) based on the Diebold and Mariano (1995) test.\n');
    fprintf('%s\n', thick);
end
end
