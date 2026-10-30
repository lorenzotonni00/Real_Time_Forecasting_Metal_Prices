function PREDICTORS_OUT = append_nowcasted_predictors(PREDICTORS_BASE, PREDICTORS_ADD)
% Append already-nowcasted predictor blocks.

PREDICTORS_OUT = PREDICTORS_BASE;

model_fields = {'RW', 'SA', 'AR_p', 'AR_IC', 'BAR', 'BAR_SV', 'BAR_SVo'};

for ff = 1:numel(model_fields)
    field = model_fields{ff};
    if ~isfield(PREDICTORS_BASE, field) || ~isfield(PREDICTORS_ADD, field)
        continue
    end

    base_data = PREDICTORS_BASE.(field).data;
    add_data = align_tensor_to_base(PREDICTORS_BASE.(field).obs, PREDICTORS_BASE.(field).vintages, ...
        PREDICTORS_ADD.(field).obs, PREDICTORS_ADD.(field).vintages, PREDICTORS_ADD.(field).data, ...
        size(base_data, 1), size(base_data, 2));

    PREDICTORS_OUT.(field).data = cat(3, base_data, add_data);
    PREDICTORS_OUT.(field).id = [cellstr(PREDICTORS_BASE.(field).id(:)); cellstr(PREDICTORS_ADD.(field).id(:))];
end

if isfield(PREDICTORS_BASE, 'best_model')
    n_base = numel(PREDICTORS_BASE.RW.id);
    n_add = numel(PREDICTORS_ADD.RW.id);
    base_best_model = normalize_best_model(PREDICTORS_BASE.best_model, n_base, 0);
    add_best_model = normalize_best_model(PREDICTORS_ADD.best_model, n_add, 1);
    PREDICTORS_OUT.best_model = [base_best_model; add_best_model];
end

end

function best_model = normalize_best_model(best_model, n_ids, default_model)

best_model = best_model(:);
if numel(best_model) >= n_ids
    best_model = best_model(1:n_ids);
else
    best_model = [best_model; repmat(default_model, n_ids - numel(best_model), 1)];
end

end

function out = align_tensor_to_base(base_obs, base_vintages, add_obs, add_vintages, add_data, n_base_obs, n_base_vintages)

base_obs = month_start(resize_datetime_axis(base_obs, n_base_obs));
base_vintages = month_start(resize_datetime_axis(base_vintages, n_base_vintages));
add_obs = month_start(add_obs);
add_vintages = month_start(add_vintages);

n_new = size(add_data, 3);
out = NaN(n_base_obs, n_base_vintages, n_new);

[obs_match, obs_pos] = ismember(base_obs, add_obs);
[vin_match, vin_pos] = ismember(base_vintages, add_vintages);

for jj = 1:n_new
    tmp = NaN(numel(base_obs), numel(base_vintages));
    tmp(obs_match, vin_match) = add_data(obs_pos(obs_match), vin_pos(vin_match), jj);
    out(:, :, jj) = tmp;
end

end

function d = resize_datetime_axis(d, n)

d = d(:);
if numel(d) >= n
    d = d(1:n);
    return
end

d = [d; NaT(n - numel(d), 1)];

end

function d = month_start(d)

d = datetime(year(d), month(d), 1);

end
