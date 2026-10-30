function PREDICTORS_OUT = append_financial_predictors_realtime(PREDICTORS_IN, FINANCIAL_PREDICTORS)
% Append no-lag financial predictors.


PREDICTORS_OUT = PREDICTORS_IN;

if isempty(FINANCIAL_PREDICTORS.id)
    return
end

model_fields = {'RW', 'SA', 'AR_p', 'AR_IC', 'BAR', 'BAR_SV', 'BAR_SVo'};
base_obs = month_start(PREDICTORS_IN.RW.obs);
base_vintages = month_start(PREDICTORS_IN.RW.vintages);
new_tensor = financial_series_to_realtime_tensor(FINANCIAL_PREDICTORS, base_obs, base_vintages);

for ff = 1:numel(model_fields)
    field = model_fields{ff};
    if ~isfield(PREDICTORS_OUT, field) || ~isfield(PREDICTORS_OUT.(field), 'data')
        continue
    end

    PREDICTORS_OUT.(field).data = cat(3, PREDICTORS_OUT.(field).data, new_tensor);
    PREDICTORS_OUT.(field).id = [cellstr(PREDICTORS_OUT.(field).id(:)); cellstr(FINANCIAL_PREDICTORS.id(:))];
end

if isfield(PREDICTORS_OUT, 'best_model')
    n_existing = numel(PREDICTORS_IN.RW.id);
    existing_best_model = normalize_best_model(PREDICTORS_OUT.best_model, n_existing, 0);
    PREDICTORS_OUT.best_model = [existing_best_model; zeros(numel(FINANCIAL_PREDICTORS.id), 1)];
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

function tensor = financial_series_to_realtime_tensor(FINANCIAL_PREDICTORS, base_obs, base_vintages)

base_obs = month_start(base_obs);
base_vintages = month_start(base_vintages);
financial_obs = month_start(FINANCIAL_PREDICTORS.obs);

aligned = NaN(numel(base_obs), numel(FINANCIAL_PREDICTORS.id));
[in_sample, pos] = ismember(base_obs, financial_obs);
aligned(in_sample, :) = FINANCIAL_PREDICTORS.data(pos(in_sample), :);

n_new = numel(FINANCIAL_PREDICTORS.id);
tensor = NaN(numel(base_obs), numel(base_vintages), n_new);

for vv = 1:numel(base_vintages)
    available = base_obs <= base_vintages(vv);
    for jj = 1:n_new
        temp = NaN(numel(base_obs), 1);
        temp(available) = aligned(available, jj);
        tensor(:, vv, jj) = temp;
    end
end

end

function d = month_start(d)

d = datetime(year(d), month(d), 1);

end
