function plot_favar_factors(results_US_WORLD, metal, folder_fig)
% Plot first and second estimated FAVAR factors for a given metal.
% Reproduces Figure 3: 1x2 subplot with stacked bar contributions
% and the smoothed factor as a black line overlay.
%
% Data source: results_US_WORLD.(metal).FAVAR_specific_p_1F.factors_stat
%   .st_data   [1 x n_vars x T_plot]  standardised regressors
%   .loadings  [n_vars x n_factors x T_plot]
%   .factors   [T_in x n_factors x T_plot]
% Time axis: results_US_WORLD.(metal).ARDI_p_1F.dates(12, 1:T_plot)

% ── variable groups (same definition as forecasting.m) ───────────────────
group_metals   = {'Aluminum','Copper','Nickel','Zinc'};
group_inv      = {'Zinc_Stock','Nickel_Stock','Aluminum_Stock','Copper_Stock'};
group_et       = {'PCU335911335911','A35DVS'};
group_ex_rates = {'RBCLBIS','RBAUBIS','RBCNBIS','RBIDBIS','RBPEBIS','RBPHBIS','RBRUBIS'};
group_real_act = {'INDPRO','ANMNO','AWHMAN'};
group_cu       = {'CAPUTLG331S','CAPUTLB562A3CS'};
group_PPIs     = {'PCU331331'};
group_w_act    = {'WIP','CLI_G7','CLI_China'};

% remove the target metal and its stock from groups
group_metals(strcmp(group_metals, metal))          = [];
group_inv(strcmp(group_inv, [metal '_Stock']))     = [];

% ── load factor statistics ────────────────────────────────────────────────
favar  = results_US_WORLD.(metal).FAVAR_specific_p_1F.factors_stat;
id     = favar.id;          % {1 x n_vars} cell of variable names
n_vars = numel(id);

[~, idx_inv]  = ismember(group_inv,      id);
[~, idx_cu]   = ismember(group_cu,       id);
[~, idx_et]   = ismember(group_et,       id);
[~, idx_ex]   = ismember(group_ex_rates, id);
[~, idx_ppi]  = ismember(group_PPIs,     id);
[~, idx_real] = ismember(group_real_act, id);
[~, idx_met]  = ismember(group_metals,   id);
[~, idx_wact] = ismember(group_w_act,    id);

% grp(i) = group number for variable i in factors_stat.id
grp = zeros(1, n_vars);
grp(idx_inv( idx_inv  > 0)) = 1;
grp(idx_cu(  idx_cu   > 0)) = 2;
grp(idx_et(  idx_et   > 0)) = 3;
grp(idx_ex(  idx_ex   > 0)) = 4;
grp(idx_ppi( idx_ppi  > 0)) = 5;
grp(idx_real(idx_real > 0)) = 6;
grp(idx_met( idx_met  > 0)) = 7;
grp(idx_wact(idx_wact > 0)) = 8;

% ── colours and labels ────────────────────────────────────────────────────
clrs   = {'#1b9e77','#d95f02','#7570b3','#A6761D', ...
           '#e7298a','#66a61e','#e6ab02','#666666'};
lbls   = {'Inventories','CU','ET','Ex. Rates', ...
           'PPI','Real Activity','Metal Prices','World Activity'};

% ── time axis ─────────────────────────────────────────────────────────────
T_plot       = size(favar.st_data, 3);
time         = results_US_WORLD.(metal).ARDI_p_1F.dates(12, 1:T_plot);
time_last_obs = time - calmonths(12);

mavg = 3;

% ── figure ────────────────────────────────────────────────────────────────
fig = figure('Units','normalized','Position',[0.05 0.15 0.88 0.55]);
tl  = tiledlayout(fig, 1, 2, 'TileSpacing', 'tight', 'Padding', 'compact');

title(tl, sprintf( ...
    'Figure 3: First (left) and second (right) estimated factors from the FAVAR model for real %s price', ...
    lower(metal)), 'FontSize', 11, 'FontWeight', 'normal');

bb_handles = [];

for F = 1:2
    loadings_F = squeeze(favar.loadings(:, F, :));   % [n_vars x T_plot]

    % grouped loading contributions
    gloadings = NaN(8, T_plot);
    for jj = 1:T_plot
        for g = 1:8
            mask = (grp == g);
            if any(mask)
                gloadings(g, jj) = favar.st_data(end, mask, jj) * loadings_F(mask, jj);
            end
        end
    end

    y1       = movmean(gloadings', mavg, 1);                             % [T_plot x 8]
    F_smooth = movmean(squeeze(favar.factors(end, F, :)), mavg, 1);      % [T_plot x 1]

    ax = nexttile;
    bb = bar(ax, time_last_obs, y1, 'stacked', 'EdgeColor', 'none');
    hold(ax, 'on');
    for g = 1:8
        bb(g).FaceColor    = clrs{g};
        bb(g).DisplayName  = lbls{g};
    end
    plot(ax, time_last_obs, F_smooth, 'LineWidth', 2, 'Color', 'k', ...
         'HandleVisibility', 'off');
    grid(ax, 'on');
    hold(ax, 'off');

    if F == 1
        bb_handles = bb;   % save handles for shared legend
    end
end

% ── shared legend at bottom ───────────────────────────────────────────────
lg = legend(nexttile(1), bb_handles, lbls, ...
    'Orientation', 'horizontal', 'Box', 'off');
lg.Layout.Tile = 'South';

% ── save ──────────────────────────────────────────────────────────────────
base = fullfile(folder_fig, ['FAVAR_' metal '_factors']);
exportgraphics(fig, [base '.pdf'], 'ContentType', 'vector');
exportgraphics(fig, [base '.png'], 'Resolution', 600);
end
