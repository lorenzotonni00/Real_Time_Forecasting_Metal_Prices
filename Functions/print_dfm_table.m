function print_dfm_table(results_bm_dfm, target_series)
% Print a single table with BM-DFM results (1, 2, 3 factors) for all metals.
%
% Data:  results_bm_dfm.tables_ratio_long_p_value.(metal){row, h}
%        h = actual horizon number (1..Hsize)
% RW-D:  results_bm_dfm.TABLES_RMSPE_level.RW(h, metal_col)
% Bold:  ratio < 1

BOLD  = char([27 91 49 109]);   % ESC[1m
RESET = char([27 91 48 109]);   % ESC[0m

% ── identify DFM models (BM_DFM_nF, exclude ARDI) ─────────────────────
modelli = fieldnames(results_bm_dfm.TABLES_level);
is_dfm  = ~cellfun(@isempty, regexp(modelli, '^BM_DFM_\d+F$', 'once'));
dfm_fns = modelli(is_dfm);
n_dfm   = numel(dfm_fns);

% sort by factor count
factor_k = cellfun(@(s) str2double(regexp(s, '(\d+)(?=F$)', 'match', 'once')), dfm_fns);
[factor_k, sort_idx] = sort(factor_k);
dfm_fns = dfm_fns(sort_idx);

% row indices and display names
dfm_rows    = zeros(n_dfm, 1);
dfm_lbls    = cell(n_dfm, 1);
for mm = 1:n_dfm
    dfm_rows(mm) = find(strcmp(modelli, dfm_fns{mm}), 1);
    if factor_k(mm) == 1
        dfm_lbls{mm} = 'DFM - 1 Factor';
    else
        dfm_lbls{mm} = sprintf('DFM - %d Factors', factor_k(mm));
    end
end

% ── horizons ─────────────────────────────────────────────────────────────
horizons_DM = [1, 3, 6, 9, 12, 15, 18, 21, 24];
n_hor = numel(horizons_DM);

% ── layout ───────────────────────────────────────────────────────────────
w_metal = 12;
w_model = 18;
w_hor   = 11;
total_w = w_metal + w_model + n_hor * w_hor;
thick   = repmat('=', 1, total_w);
thin    = repmat('-', 1, total_w);

hdr = [sprintf('%-*s', w_metal, 'Metal') sprintf('%-*s', w_model, 'Model')];
for hh = 1:n_hor
    hdr = [hdr sprintf('%*s', w_hor, ['Horizon ' num2str(horizons_DM(hh))])];
end

% ── print ────────────────────────────────────────────────────────────────
fprintf('\n%s\n', thick);
fprintf('Table A2: RMPSE ratios based on the Banbura-Modugno DFM.\n');
fprintf('%s\n', thick);
fprintf('%s\n', hdr);
fprintf('%s\n', thin);

for mt = 1:numel(target_series)
    metal     = target_series{mt};
    metal_col = find(strcmp(target_series, metal), 1);

    % ── RW-D row ─────────────────────────────────────────────────────────
    row = [sprintf('%-*s', w_metal, metal) sprintf('%-*s', w_model, 'RW-D')];
    for hh = 1:n_hor
        h   = horizons_DM(hh);
        val = results_bm_dfm.TABLES_RMSPE_level.RW(h, metal_col);
        if isnan(val), cs = '-'; else, cs = sprintf('%.2f', val); end
        row = [row sprintf('%*s', w_hor, cs)];
    end
    fprintf('%s\n', row);
    fprintf('%s\n', thin);

    % ── DFM model rows ────────────────────────────────────────────────────
    for md = 1:n_dfm
        row_idx = dfm_rows(md);
        disp_nm = dfm_lbls{md};
        row = [sprintf('%-*s', w_metal, '') sprintf('%-*s', w_model, disp_nm)];

        for hh = 1:n_hor
            h   = horizons_DM(hh);
            raw = results_bm_dfm.tables_ratio_long_p_value.(metal){row_idx, h};
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
