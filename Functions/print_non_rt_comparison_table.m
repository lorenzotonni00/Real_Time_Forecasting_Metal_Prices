function print_non_rt_comparison_table(results_non_real_time, results_US_WORLD, target_series)
% Print a single table comparing non-real-time vs real-time RMSPE ratios.
% Style matches Tables 3 and 4.
%
% Main values:  results_non_real_time.tables_ratio_long_DM.(metal){row, col}
%               col 1-9 = horizons [1,3,6,9,12,15,18,21,24]
% Differences:  non_rt - rt ratio
% RW-D:         results_non_real_time.TABLES_RMSPE_level.RW(h, metal_col)
% Avg Diff:     mean(non_rt - rt) over ALL estimated models per horizon,
%               restricted to models whose non-real-time ratio < 1
% Bold:         non-real-time ratio < 1 (model beats the RW-D benchmark)

BOLD  = char([27 91 49 109]);   % ESC[1m
RESET = char([27 91 48 109]);   % ESC[0m

% ── display model list (12 models) ───────────────────────────────────────
model_fn = { ...
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
    'Gradient_Boosting',    'Gradient Boosting' ...
};
n_display = size(model_fn, 1);

% map model names to row indices in tables_ratio_long_DM
modelli = fieldnames(results_US_WORLD.TABLES_level);

model_rows = zeros(n_display, 1);
for mm = 1:n_display
    idx = find(strcmp(modelli, model_fn{mm, 1}), 1);
    if ~isempty(idx), model_rows(mm) = idx; end
end

% ── horizons ─────────────────────────────────────────────────────────────
horizons_DM = [1, 3, 6, 9, 12, 15, 18, 21, 24];
n_hor = numel(horizons_DM);

% ── layout ───────────────────────────────────────────────────────────────
w_metal = 12;
w_model = 26;
w_hor   = 13;
total_w = w_metal + w_model + n_hor * w_hor;
thick   = repmat('=', 1, total_w);
thin    = repmat('-', 1, total_w);

hdr = [sprintf('%-*s', w_metal, 'Metal') sprintf('%-*s', w_model, 'Model')];
for hh = 1:n_hor
    hdr = [hdr sprintf('%*s', w_hor, ['Horizon ' num2str(horizons_DM(hh))])]; %#ok<AGROW>
end

% ── print ────────────────────────────────────────────────────────────────
fprintf('\n%s\n', thick);
fprintf(['Table A1: Non-real-time RMSPE ratios.\n']);
fprintf('%s\n', thick);
fprintf('%s\n', hdr);
fprintf('%s\n', thin);

for mt = 1:numel(target_series)
    metal     = target_series{mt};
    metal_col = find(strcmp(target_series, metal), 1);

    % ── RW-D (two-line: absolute RMSPE from non_rt + parenthetical diff) ─
    fprintf('%s\n', thin);
    l1_rwd = [sprintf('%-*s', w_metal, metal) sprintf('%-*s', w_model, 'RW-D')];
    l2_rwd = [sprintf('%-*s', w_metal, '')    sprintf('%-*s', w_model, '')];
    for hh = 1:n_hor
        h     = horizons_DM(hh);
        v_nrt = results_non_real_time.TABLES_RMSPE_level.RW(h, metal_col);
        v_rt  = results_US_WORLD.TABLES_RMSPE_level.RW(h, metal_col);
        diff  = v_nrt - v_rt;
        if isnan(v_nrt)
            l1_rwd = [l1_rwd sprintf('%*s', w_hor, '-')]; 
            l2_rwd = [l2_rwd sprintf('%*s', w_hor, '')]; 
        else
            l1_rwd = [l1_rwd sprintf('%*s', w_hor, sprintf('%.2f', v_nrt))]; 
            l2_rwd = [l2_rwd sprintf('%*s', w_hor, sprintf('(%+.2f)', diff))];
        end
    end
    fprintf('%s\n%s\n', l1_rwd, l2_rwd);
    fprintf('%s\n', thin);

    % ── model rows (two-line each: main value + parenthetical diff) ───────
    for md = 1:n_display
        row_idx = model_rows(md);
        disp_nm = model_fn{md, 2};
        l1 = [sprintf('%-*s', w_metal, '') sprintf('%-*s', w_model, disp_nm)];
        l2 = [sprintf('%-*s', w_metal, '') sprintf('%-*s', w_model, '')];

        for hh = 1:n_hor
            if row_idx == 0
                l1 = [l1 sprintf('%*s', w_hor, '-')];
                l2 = [l2 sprintf('%*s', w_hor, '')];
            else
                raw_nrt = results_non_real_time.tables_ratio_long_DM.(metal){row_idx, hh};
                raw_rt  = results_US_WORLD.tables_ratio_long_DM.(metal){row_idx, hh};

                num_nrt = extract_num(raw_nrt);
                num_rt  = extract_num(raw_rt);
                diff    = num_nrt - num_rt;

                if isnan(num_nrt)
                    l1 = [l1 sprintf('%*s', w_hor, '-')];
                    l2 = [l2 sprintf('%*s', w_hor, '')];
                else
                    stars = extract_stars(raw_nrt);
                    cs1   = [sprintf('%.2f', num_nrt) stars];
                    cs2   = sprintf('(%+.2f)', diff);

                    pad1  = sprintf('%*s', w_hor, cs1);
                    pad2  = sprintf('%*s', w_hor, cs2);

                    if num_nrt < 1
                        k1   = find(pad1 ~= ' ', 1);
                        pad1 = [pad1(1:k1-1) BOLD pad1(k1:end) RESET];
                        k2   = find(pad2 ~= ' ', 1);
                        pad2 = [pad2(1:k2-1) BOLD pad2(k2:end) RESET];
                    end

                    l1 = [l1 pad1];
                    l2 = [l2 pad2];
                end
            end
        end
        fprintf('%s\n%s\n', l1, l2);
    end

    % Average Difference row: mean(non_rt - rt) across ALL estimated models
    % for this metal/horizon in tables_ratio_long_DM, restricted to models
    % whose non-real-time ratio is below 1 (i.e., beats the RW-D benchmark).
    fprintf('%s\n', thin);
    l_avg = [sprintf('%-*s', w_metal, '') sprintf('%-*s', w_model, 'Average Difference')];
    n_models_all = size(results_non_real_time.tables_ratio_long_DM.(metal), 1);
    for hh = 1:n_hor
        diffs_sub = NaN(n_models_all, 1);
        for r = 1:n_models_all
            raw_nrt_s = results_non_real_time.tables_ratio_long_DM.(metal){r, hh};
            raw_rt_s  = results_US_WORLD.tables_ratio_long_DM.(metal){r, hh};
            num_nrt_s = extract_num(raw_nrt_s);
            if ~isnan(num_nrt_s) && num_nrt_s < 1
                diffs_sub(r) = num_nrt_s - extract_num(raw_rt_s);
            end
        end
        avg_d = mean(diffs_sub, 'omitnan');
        if isnan(avg_d)
            l_avg = [l_avg sprintf('%*s', w_hor, '-')];                    
        else
            l_avg = [l_avg sprintf('%*s', w_hor, sprintf('%.3f', avg_d))];
        end
    end
    fprintf('%s\n', l_avg);
    fprintf('%s\n', thin);
end

fprintf('%s\n', thick);
fprintf('Notes: For the RW-D row, we report the RMSPE from the non-real-time (last vintage)\n');
fprintf('exercise (real price in USD per metric ton, February 2015 CPI as base year). For all\n');
fprintf('other models, we report the RMSPE ratio relative to the non-real-time RW-D. Values in\n');
fprintf('parentheses are the difference between the non-real-time and real-time ratios (i.e.,\n');
fprintf('results_non_real_time minus results_US_WORLD). Ratios below 1, highlighted in bold,\n');
fprintf('indicate that the model outperforms the RW-D benchmark in the non-real-time exercise.\n');
fprintf('Asterisks denote DM-test significance at 1%% (***), 5%% (**) and 10%% (*). The ''Average\n');
fprintf('Difference'' row reports the mean parenthetical difference across all estimated models\n');
fprintf('for that metal/horizon whose non-real-time ratio is below 1.\n');
fprintf('%s\n\n', thick);
end

% ── local helpers ─────────────────────────────────────────────────────────
function val = extract_num(raw)
if isempty(raw), val = NaN; return; end
val = str2double(regexprep(raw, '\*+$', ''));
end

function stars = extract_stars(raw)
if isempty(raw), stars = ''; return; end
m = regexp(raw, '\*+$', 'match');
if ~isempty(m), stars = m{1}; else, stars = ''; end
end
