function print_nowcast_table(results_US, results_WORLD)
% Print the nowcasting RMSPE table to the command window.

% ── variable display-name mapping ────────────────────────────────────────
id_map = containers.Map( ...
    {'INDPRO','A31SNO','CPIAUCSL','AWHMAN','A35DVS', ...
     'PCU331331','PCU335911335911', ...
     'RBCLBIS','RBAUBIS','RBCNBIS','RBIDBIS','RBPEBIS','RBPHBIS','RBRUBIS', ...
     'CAPUTLG331S','CAPUTLB562A3CS','ANMNO','WIP','CLI_G7','CLI_China'}, ...
    {'IP','NO-M','CPI','HEM','MVS', ...
     'PPI-M','PPI-B', ...
     'CHL','AUS','CHN','IDN','PER','PHL','RUS', ...
     'CU-M','CU-P','NO-A','WIP','LI-G7','LI-CN'} );

% ── columns: {field name in tables_ratio_long_p_value, header, width} ────
col_fn  = {'SA_abs',  'AR_p',  'AR_IC',   'BAR',    'BAR_SV',    'BAR_SVo'  };
col_hdr = {'RW-D',   'AR(1)', 'AR(AIC)', 'BAR(1)', 'BAR(1)-SV', 'BAR(1)-SVo'};
col_w   = [8,         9,       9,         9,         11,           11         ];
n_cols  = numel(col_fn);

% ── collect variables from both result objects ────────────────────────────
pred_US    = results_US.Hsize_by_var.Properties.RowNames;
hs_US      = results_US.Hsize_by_var.Hsize;
pred_WLD   = results_WORLD.Hsize_by_var.Properties.RowNames;
hs_WLD     = results_WORLD.Hsize_by_var.Hsize;

% Build unified list: each entry = {pred_id, results_obj, var_col_idx, hsize}
n_US  = numel(pred_US);
n_WLD = numel(pred_WLD);
vars  = cell(n_US + n_WLD, 1);
for v = 1:n_US
    vars{v} = {pred_US{v}, results_US, v, hs_US(v)};
end
for v = 1:n_WLD
    vars{n_US + v} = {pred_WLD{v}, results_WORLD, v, hs_WLD(v)};
end
n_total = numel(vars);
n_left  = ceil(n_total / 2);

% ── widths & separators ───────────────────────────────────────────────────
w_id   = 6;
w_h    = 4;
half_w = w_id + w_h + sum(col_w);
div    = ' \x7C ';          % ' | '
total_w = 2*half_w + 3;     % 3 = length(' | ')

eq_bar   = repmat('=', 1, total_w);
dash_bar = [repmat('-', 1, half_w) ' | ' repmat('-', 1, half_w)];

% ── header row (repeated for both halves) ─────────────────────────────────
hdr = [sprintf('%-*s', w_id, 'ID') sprintf('%*s', w_h, 'Hor')];
for cc = 1:n_cols
    hdr = [hdr sprintf('%*s', col_w(cc), col_hdr{cc})];
end

% ── title ─────────────────────────────────────────────────────────────────
title_str = 'Table 2: Nowcasting of different predictors for each horizon and models.';
lpad = max(0, floor((total_w - numel(title_str)) / 2));
fprintf('\n%s\n%s%s\n%s\n', eq_bar, repmat(' ',1,lpad), title_str, eq_bar);
fprintf('%s | %s\n', hdr, hdr);
fprintf('%s\n', dash_bar);

% ── data rows ─────────────────────────────────────────────────────────────
for row = 1:n_left
    L = vars{row};
    R_idx = row + n_left;
    if R_idx <= n_total, R = vars{R_idx}; else, R = []; end

    h_max = L{4};
    if ~isempty(R), h_max = max(h_max, R{4}); end

    for h = 1:h_max
        L_str = make_row(L, h, h==1, id_map, col_fn, col_w, w_id, w_h);
        R_str = make_row(R, h, h==1, id_map, col_fn, col_w, w_id, w_h);
        fprintf('%s | %s\n', L_str, R_str);
    end
    fprintf('%s\n', dash_bar);
end

% ── notes ─────────────────────────────────────────────────────────────────
fprintf('%s\n', eq_bar);
fprintf('Notes: For the baseline (RW-D) model, we report the RMSFE, whereas for the other models,\n');
fprintf('the ratio relative to the baseline model. A ratio below one indicates that the model\n');
fprintf('outperforms the RW-D model. ***, **, and * indicate that ratios are significantly different\n');
fprintf('from 1 at the 1%%, 5%%, and 10%% based on the Diebold and Mariano (1995) test.\n');
fprintf('A ratio below one (in bold) indicates that the model outperforms the RW-D model.\n');
fprintf('%s\n\n', eq_bar);
end


% =========================================================================
function s = make_row(entry, h, show_id, id_map, col_fn, col_w, w_id, w_h)
% Format one printed row for variable 'entry' at horizon h.

BOLD  = char([27 91 49 109]);   % ESC[1m
RESET = char([27 91 48 109]);   % ESC[0m

n_cols = numel(col_fn);
blank  = repmat(' ', 1, w_id + w_h + sum(col_w));

if isempty(entry)
    s = blank;
    return
end

vid     = entry{1};
res     = entry{2};
v_idx   = entry{3};
Hsize_v = entry{4};

% Display name
if isKey(id_map, vid), disp_id = id_map(vid); else, disp_id = vid; end

if show_id
    id_part = sprintf('%-*s', w_id, disp_id);
else
    id_part = sprintf('%-*s', w_id, '');
end

% Horizon beyond this variable's data → all dashes
if h > Hsize_v
    s = [id_part sprintf('%*d', w_h, h)];
    for cc = 1:n_cols
        s = [s sprintf('%*s', col_w(cc), '-')];
    end
    return
end

h_part = sprintf('%*d', w_h, h);
s = [id_part h_part];

% Numeric ratios for best-model detection (skip SA_abs)
ratio_num = NaN(1, n_cols);
for cc = 1:n_cols
    fn = col_fn{cc};
    if strcmp(fn, 'SA_abs'), continue; end
    if isfield(res.tables_ratio_long, fn)
        ratio_num(cc) = res.tables_ratio_long.(fn)(h, v_idx);
    end
end
[~, best_cc] = min(ratio_num);

% Build each column
for cc = 1:n_cols
    fn = col_fn{cc};

    if strcmp(fn, 'SA_abs')
        val = res.TABLES_RMSPE_level.table_SA(h, v_idx);
        if isnan(val), cs = '-'; else, cs = sprintf('%.2f', val); end
        s = [s sprintf('%*s', col_w(cc), cs)]; 
    else
        val = NaN;
        if isfield(res.tables_ratio_long, fn)
            val = res.tables_ratio_long.(fn)(h, v_idx);
        end
        stars = '';
        if isfield(res.tables_ratio_long_p_value, fn)
            raw = res.tables_ratio_long_p_value.(fn){h, v_idx};
            if ~isempty(raw) && ~strcmp(raw, 'NaN')
                m = regexp(raw, '\*+$', 'match');
                if ~isempty(m), stars = m{1}; end
            end
        end
        if isnan(val)
            cs = '-';
        else
            cs = [sprintf('%.2f', val) stars];
        end

        padded = sprintf('%*s', col_w(cc), cs);
        if cc == best_cc && ~strcmp(cs, '-')
            k = find(padded ~= ' ', 1);
            if ~isempty(k)
                padded = [padded(1:k-1) BOLD padded(k:end) RESET];
            end
        end
        s = [s padded];
    end
end
end
