function print_forecast_comb_table(forecast_comb, target_series, results_US_WORLD)
% Print Table 5 to the command window.
%   One section per metal (Copper, Aluminum, Nickel, Zinc).
%   Each section: RW-D row (absolute RMSPE, integer) + SSM25 + Top 2.
%
% Data: forecast_comb.tables_ratio_long_f_comb_p_value.(metal){row, h}
%       column h = actual horizon number (1..24)
% RW-D: forecast_comb.(metal).RW.RMSPE_level(1, h)
% Bold: ratio < 1

BOLD  = char([27 91 49 109]);   % ESC[1m
RESET = char([27 91 48 109]);   % ESC[0m

% ── models ────────────────────────────────────────────────────────────────
model_fn  = {'threshold'; 'top_2'};
model_lbl = {'SSM25';     'Top 2'};
n_models  = numel(model_fn);

modelli = fieldnames(forecast_comb.TABLES_level);
model_rows = zeros(n_models, 1);
for mm = 1:n_models
    idx = find(strcmp(modelli, model_fn{mm}), 1);
    if ~isempty(idx), model_rows(mm) = idx; end
end

% ── horizons ──────────────────────────────────────────────────────────────
horizons_DM = [1, 3, 6, 9, 12, 15, 18, 21, 24];
n_hor = numel(horizons_DM);

% ── layout ────────────────────────────────────────────────────────────────
w_model = 10;
w_hor   = 11;
total_w = w_model + n_hor * w_hor;
thick   = repmat('=', 1, total_w);
thin    = repmat('-', 1, total_w);

hdr = sprintf('%-*s', w_model, 'Model');
for hh = 1:n_hor
    hdr = [hdr sprintf('%*s', w_hor, ['Horizon ' num2str(horizons_DM(hh))])]; %#ok<AGROW>
end

% ── print ─────────────────────────────────────────────────────────────────
fprintf('\n%s\n', thick);
fprintf('Table 5: Point forecasting measures by combining the forecasting based on MCS procedures.\n');
fprintf('%s\n', thick);
fprintf('%s\n', hdr);
fprintf('%s\n', thin);

for mt = 1:numel(target_series)
    metal = target_series{mt};

    % centered metal label
    pad = max(0, floor((total_w - numel(metal)) / 2));
    fprintf('%s%s\n', repmat(' ', 1, pad), metal);

    % RW-D row 
    metal_col = find(strcmp(target_series, metal), 1);
    row = sprintf('%-*s', w_model, 'RW-D');
    for hh = 1:n_hor
        h   = horizons_DM(hh);
        val = results_US_WORLD.TABLES_RMSPE_level.RW(h, metal_col);
        if isnan(val), cs = '-'; else, cs = sprintf('%d', round(val)); end
        row = [row sprintf('%*s', w_hor, cs)]; 
    end
    fprintf('%s\n', row);

    % SSM25 / Top 2 rows
    for md = 1:n_models
        row_idx = model_rows(md);
        row = sprintf('%-*s', w_model, model_lbl{md});
        for hh = 1:n_hor
            h = horizons_DM(hh);
            if row_idx == 0
                padded = sprintf('%*s', w_hor, '-');
            else
                raw = forecast_comb.tables_ratio_long_f_comb_p_value.(metal){row_idx, h};
                if isempty(raw)
                    padded = sprintf('%*s', w_hor, '-');
                else
                    stars_m = regexp(raw, '\*+$', 'match');
                    if ~isempty(stars_m), stars = stars_m{1}; else, stars = ''; end
                    num_val = str2double(regexprep(raw, '\*+$', ''));
                    if isnan(num_val)
                        padded = sprintf('%*s', w_hor, '-');
                    else
                        cs     = [sprintf('%.3f', num_val) stars];
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
fprintf('metric ton, with February 2015 CPI as base year. A ratio below one indicates that the\n');
fprintf('model outperforms the RW-D model. Asterisks denote statistical significance at the\n');
fprintf('1%% (***), 5%% (**) and 10%% (*) based on the Diebold and Mariano (1995) test.\n');
fprintf('Forecast combinations that outperform the RW-D model are highlighted in bold.\n');
fprintf('%s\n\n', thick);
end
