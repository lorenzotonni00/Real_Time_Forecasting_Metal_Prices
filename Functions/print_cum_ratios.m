function print_cum_ratios(print, results, forecast_comb, models_ind, models_comb, horizon, target_series, plot_size, font_size, axis_size, folder_fig)
%%

% Cut initial observations to smooth the plot
start = 12;

if print == 1

    for ETM_index = 1:numel(target_series)

    metal    = target_series{ETM_index};
    OOS_ind  = size(results.RMSPE_level_cum_ratio.(metal).RW(horizon, 1:end-horizon-1), 2);
    OOS_comb = size(forecast_comb.TABLES_RMSPE_level_cum_ratio.(metal).(models_comb{1})(horizon, 1:end-horizon-1), 2);
    OOS_size = min(OOS_ind, OOS_comb);
    dates = results.(metal).RW.dates(horizon, 1:OOS_size);

    % Individual models
    matrix_individual_models = NaN(size(models_ind,2),OOS_size);
    for m = 1:size(models_ind,2)
        matrix_individual_models(m,:) = results.RMSPE_level_cum_ratio.(metal).(models_ind{m})(horizon,1:OOS_size);
    end

    % Combined forecasts
    matrix_combined_models = NaN(size(models_comb,2), OOS_size);
    for m = 1:size(models_comb,2)
        matrix_combined_models(m,:) = forecast_comb.TABLES_RMSPE_level_cum_ratio.(metal).(models_comb{m})(horizon,1:OOS_size);
    end

    % % =============== || (1) || ============== %
    fig_print{ETM_index} = figure;
    set(gcf, 'Position', [300, 150, 800, 600]);
    plot(dates(start:end),matrix_individual_models(:,start:end),'-','LineWidth', plot_size); hold on
    plot(dates(start:end),matrix_combined_models(:,start:end),'--','LineWidth', plot_size); hold off
    ax = gca;
    ax.YAxis.Exponent = 0;
    ax.FontSize = axis_size;
    yline(1, '--r', 'LineWidth', 1.5);

    end

%==================================%
%      Legend                      %
%==================================%

fig_print{ETM_index+1} = figure('Position', [150, 80, 1400, 200]);

ax1 = axes('Position',[0-.1 -0.1 1.85 1.8]); % Normal axes position

% =============== || (1) || ============== %

axes(ax1); % Set current axes to ax1
fake_line_1 = repmat(-5, 1, OOS_size)';
fake_line_2 = repmat(-6, 1, OOS_size)';
fake_line_3 = repmat(-7.5, 1, OOS_size)';
fake_line_4 = repmat(-7.5, 1, OOS_size)';
fake_line_5 = repmat(-7.5, 1, OOS_size)';
fake_line_6 = repmat(-7.5, 1, OOS_size)';
fake_line_7 = repmat(-7.5, 1, OOS_size)';
fake_line_8 = repmat(-7.5, 1, OOS_size)';

hold on
plot(dates, fake_line_1, 'LineWidth', plot_size); 
plot(dates, fake_line_2, 'LineWidth', plot_size); 
plot(dates, fake_line_3, 'LineWidth', plot_size); 
plot(dates, fake_line_4, 'LineWidth', plot_size); 
plot(dates, fake_line_5, 'LineWidth', plot_size); 
plot(dates, fake_line_6, 'LineWidth', plot_size); 
plot(dates, fake_line_7, '--', 'LineWidth', plot_size); 
plot(dates, fake_line_8, '--', 'LineWidth', plot_size);
hold off

line(get(gca, 'Xlim'), [0 0], 'Color', [1 0 0], 'LineStyle', '--', 'LineWidth', 1);
ytickformat('%,.1f');
hold off;

ylim([0 100]); 

set(gca, 'FontSize', font_size);

ax2 = axes('Position', [0.95 0.3 0.2 0.4], 'Visible', 'off'); % Invisible axes for the legend

% =============== || (1) || ============== %
lgd = legend(ax1, ...
    {'Professional Forecasts','ARDL(1,1) - NO-M','ARDL(1,1) - CU-P',...
    'R. Forest','ARDI - 2F','FAVAR - 2F','F-Comb - SSM25','F-comb - Top 2'}, ...
    'FontSize', 16, ...
    'Orientation', 'horizontal', ...
    'NumColumns', 6);

%==================================%
%      (2) set legend position     %
%==================================%

lgd.Position = [0.42 0.4 0.15 0.2];
set(lgd, 'Units', 'normalized');

% Print Options
variables = [target_series(:)', {'legend'}];
base = 'ratios_cum_';
print_function_cum(fig_print, variables, base, folder_fig, horizon)

close all

end

end
