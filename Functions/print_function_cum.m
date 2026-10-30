function print_function_cum(fig_print, variables, base, folder, horizon)
    
    for i = 1:length(variables)
            filename = [base, variables{i}, '_', num2str(horizon), '.pdf'];
            fullpath = fullfile(folder, filename);
            exportgraphics(fig_print{i}, fullpath, 'ContentType', 'vector', 'Resolution', 600)
       
    end
    
end