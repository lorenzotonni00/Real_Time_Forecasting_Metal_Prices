function fig = plot_cum_ratios_panel(results, forecast_comb, models_ind, models_comb, ...
    horizon, target_series, plot_size, font_size, axis_size)
% 2×2 subplot of cumulative RMSPE ratios at a given horizon.
%
%   fig = plot_cum_ratios_panel(results, forecast_comb, models_ind, models_comb,
%                               horizon, target_series, plot_size, font_size, axis_size)
%
%   Produces a 2×2 panel (one subplot per metal in target_series) with a
%   shared legend placed at the bottom of the figure.


start_idx = 12;    % trim first months for smoother curves
n_ind     = numel(models_ind);
n_comb    = numel(models_comb);
n_metals  = numel(target_series);

legend_labels = { ...
    'Professional Forecasts', 'ARDL(1,1) - NO-M', 'ARDL(1,1) - CU-P', ...
    'R. Forest', 'ARDI - 2F', 'FAVAR - 2F', ...
    'F-Comb - SSM25', 'F-comb - Top 2'};

% Internal font sizes scaled for a 4-panel layout
title_fs   = round(font_size  * 0.70);   % panel titles
sgtitle_fs = round(font_size  * 0.75);   % super-title
tick_fs    = round(axis_size  * 0.80);   % axis tick labels
legend_fs  = round(font_size  * 0.50);   % legend

fig = figure('Units', 'pixels', 'Position', [100, 80, 1150, 830]);

% --- Layout (normalized units) ---
%   leg_bot : space at the bottom for tick labels + legend
%   top_marg: space at the top for sgtitle
leg_bot  = 0.22;
top_marg = 0.12;
v_gap    = 0.09;    % vertical gap between the two rows
l_marg   = 0.09;    % left margin
r_marg   = 0.02;    % right margin
h_gap    = 0.07;    % horizontal gap between columns

pw = (1 - l_marg - r_marg - h_gap)    / 2;   % panel width
ph = (1 - leg_bot - top_marg - v_gap) / 2;   % panel height

% [left, bottom, width, height] for subplot 1–4
panel_pos = [ ...
    l_marg,              leg_bot + ph + v_gap,  pw, ph; ...  % 1 top-left
    l_marg + pw + h_gap, leg_bot + ph + v_gap,  pw, ph; ...  % 2 top-right
    l_marg,              leg_bot,               pw, ph; ...  % 3 bot-left
    l_marg + pw + h_gap, leg_bot,               pw, ph];     % 4 bot-right

ax       = gobjects(n_metals, 1);
lh_first = gobjects(n_ind + n_comb, 1);   % line handles from panel 1 (for legend)

for mm = 1:n_metals

    metal    = target_series{mm};
    OOS_ind  = size(results.RMSPE_level_cum_ratio.(metal).RW(horizon, 1:end-horizon-1), 2);
    OOS_comb = size(forecast_comb.TABLES_RMSPE_level_cum_ratio.(metal).(models_comb{1})(horizon, 1:end-horizon-1), 2);
    OOS_size = min(OOS_ind, OOS_comb);
    dates    = results.(target_series{1}).RW.dates(horizon, 1:OOS_size);

    % Individual models
    matrix_ind = NaN(n_ind, OOS_size);
    for m = 1:n_ind
        matrix_ind(m,:) = results.RMSPE_level_cum_ratio.(metal).(models_ind{m})(horizon, 1:OOS_size);
    end

    % Combined models
    matrix_comb = NaN(n_comb, OOS_size);
    for m = 1:n_comb
        matrix_comb(m,:) = forecast_comb.TABLES_RMSPE_level_cum_ratio.(metal).(models_comb{m})(horizon, 1:OOS_size);
    end

    % Create subplot and override default position
    ax(mm) = subplot(2, 2, mm);
    ax(mm).Position = panel_pos(mm, :);

    hold on
    for m = 1:n_ind
        h = plot(dates(start_idx:end), matrix_ind(m, start_idx:end), '-', 'LineWidth', plot_size);
        if mm == 1, lh_first(m) = h; end
    end
    for m = 1:n_comb
        h = plot(dates(start_idx:end), matrix_comb(m, start_idx:end), '--', 'LineWidth', plot_size);
        if mm == 1, lh_first(n_ind + m) = h; end
    end
    yline(1, '--r', 'LineWidth', 1.5);
    hold off

    title(metal, 'FontSize', title_fs, 'FontWeight', 'bold', 'Interpreter', 'none');
    ax(mm).FontSize       = tick_fs;
    ax(mm).YAxis.Exponent = 0;
    box on

end

if horizon == 6
    f_num = 4;
elseif horizon == 12
    f_num = 5;
elseif horizon == 18
    f_num = 6;
end
% Super-title
sgtitle(sprintf('Figure %d - Cumulative RMSPE ratios at horizon %d',f_num, horizon), ...
    'FontSize', sgtitle_fs, 'FontWeight', 'bold');

% --- Global legend detached from any axes, placed at the bottom ---
lgd = legend(ax(1), lh_first, legend_labels, ...
    'Orientation', 'horizontal', ...
    'NumColumns',  n_ind, ...
    'FontSize',    legend_fs, ...
    'Box',         'on');

drawnow;                   % force layout so Position is fully computed
lgd.Units  = 'normalized';
lgd.Parent = fig;          % detach from ax(1) → position now in figure coords

% Center the legend horizontally, place it near the bottom
lgd_w = lgd.Position(3);
lgd_h = lgd.Position(4);
lgd.Position = [(1 - lgd_w)/2, (leg_bot*0.30 - lgd_h/2), lgd_w, lgd_h];

end
