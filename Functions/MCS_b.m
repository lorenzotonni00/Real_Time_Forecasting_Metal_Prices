function [MCS_stat, table_export] = MCS_b(target_series, results, Hsize, B, l)

if nargin < 4 || isempty(B)
    B = 10000;
end

if nargin < 5 || isempty(l)
    l = 6;
end

% Number of Metals
n_ETM = size(target_series,2);

% Model Names
model_names = fieldnames(results.Copper);

% Waitbar count
count = 0;

%%
hx = waitbar(0,'Estimating MCS');
for ETM_index = 1:n_ETM
    model_names_temp = model_names;
    drop_1 = ['ARDL_p_' target_series{ETM_index}];
    drop_2 = ['ARDL_IC_' target_series{ETM_index}];
    pos_1 = find(strcmp(model_names_temp, drop_1));
    pos_2 = find(strcmp(model_names_temp, drop_2));
    model_names_temp([pos_1 pos_2]) = [];
    metal = target_series{ETM_index};
    n_models = size(model_names_temp,1);

    % MCS stats
    MCS_stat.(target_series{ETM_index}).stats = NaN(Hsize,n_models);
    MCS_stat.(target_series{ETM_index}).models = model_names_temp;

    for horizon_index = 1:Hsize
        count = count + 1;
        n_OOS = find(~isnan(squeeze(results.(target_series{ETM_index}).RW.eps_2(horizon_index,:))), 1, 'last');
        loss_data_full = NaN(n_OOS,n_models);

        for model_index = 1:n_models
            loss_data_full(:, model_index) = results.(target_series{ETM_index}).(model_names_temp{model_index}).eps_2(horizon_index,1:n_OOS);
        end

        valid_models = ~any(isnan(loss_data_full), 1);
        loss_data = loss_data_full(:,valid_models);

        if size(loss_data, 2) < 2
            error('MCS requires at least two models with finite losses for %s at horizon %d.', metal, horizon_index);
        end

        [model_ranking]=mcs_CB_mod(loss_data,0.25,B,l,'BLOCK');

        mcs = sortrows(model_ranking, 1); mcs(:,1) = [];
        MCS_stat.(target_series{ETM_index}).stats(horizon_index,valid_models) = mcs';

        
        waitbar(count/(n_ETM*Hsize),hx,sprintf('Estimating MCS: %2.2f',(count/(n_ETM*Hsize))*100));
    end
    table_export.(target_series{ETM_index}).models = model_names_temp;
end
close(hx)

%%

horizon_zoom = [1,3,6,9,12,15,18,21,24];

for ETM_index = 1:n_ETM
    table_export.(target_series{ETM_index}).p_values = MCS_stat.(target_series{ETM_index}).stats(horizon_zoom,:)';
end



end
