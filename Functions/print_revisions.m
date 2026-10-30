function print_revisions(print_rev, font_size, plot_size, axis_size, folder_fig)

if print_rev == 1

    variable = readtable('example_revisions.xlsx','Sheet','Foglio1','VariableNamingRule','preserve');
    
    % Import data
    rev_example.data = table2array(variable(:,2:end)); rev_example.data = rev_example.data;
    
    % Import vintages (Columns)
    rev_example.vintages = variable.Properties.VariableNames;        rev_example.vintages  (:,1) = [];         rev_example.vintages   = datetime(rev_example.vintages  , 'InputFormat', 'dd/MM/yyyy');
    
    % Import dates obs (Rows)
    rev_example.date = table2array(variable(:,1));        rev_example.date   = datetime(rev_example.date  , 'InputFormat', 'dd/MM/yyyy');

%%
first = nan(size(rev_example.data));
last = nan(size(rev_example.data));
first(1) = rev_example.data(1);
last(end) = rev_example.data(end);
    figure;
    set(gcf, 'Position', [300, 150, 800, 600]);
    plot(rev_example.vintages, first, 'o', ...
    'LineStyle', 'none', ...        
    'MarkerEdgeColor', [1 0 0], ... 
    'MarkerFaceColor', 'none', ...    
    'MarkerSize', 15, ...
    'LineWidth', 1.5); hold on
    plot(rev_example.vintages, last, 'o', ...
    'LineStyle', 'none', ...        
    'MarkerEdgeColor', [0 0 1], ...
    'MarkerFaceColor', 'none', ...    
    'MarkerSize', 15, ...
    'LineWidth', 1.5); 
    plot(rev_example.vintages,rev_example.data,'k','LineWidth', plot_size);hold off
    ax = gca;
    ax.YAxis.Exponent = 0;
    ax.FontSize = axis_size;
    grid on
    legend('First Release', 'Last Release', 'Revisions Over Time','Location', 'southeast')
    xlabel('Vintages', 'FontSize', font_size); 
    ylabel('Millions of Dollars', 'FontSize', font_size); 
    title('Figure (2)', 'FontSize', 18); 

    % Print Figure
    folder_path = folder_fig; % 
    file_name = 'example_revisions.pdf'; 
    full_path = fullfile(folder_path, file_name);
    exportgraphics(gcf, full_path, 'ContentType', 'vector', 'Resolution', 600)
    %%
end

end

