function PREDICTORS_OUT = append_vintage_predictors(PREDICTORS_IN, NEW_PANELS)
% Append observation-by-vintage predictors.

PREDICTORS_OUT = PREDICTORS_IN;

if isempty(NEW_PANELS.id)
    return
end

base_obs = month_start(PREDICTORS_IN.obs);
base_vintages = month_start(PREDICTORS_IN.vintages);

n_new = numel(NEW_PANELS.id);
new_tensor = NaN(numel(base_obs), numel(base_vintages), n_new);
new_extra_nowcast_horizon = zeros(numel(base_vintages), n_new);
new_required_nowcast_horizon = nan(numel(base_vintages), n_new);

[obs_match, obs_pos] = ismember(base_obs, month_start(NEW_PANELS.obs));
[vin_match, vin_pos] = ismember(base_vintages, month_start(NEW_PANELS.vintages));

for jj = 1:n_new
    tmp = NaN(numel(base_obs), numel(base_vintages));
    tmp(obs_match, vin_match) = NEW_PANELS.data(obs_pos(obs_match), vin_pos(vin_match), jj);
    new_tensor(:, :, jj) = tmp;
    new_extra_nowcast_horizon(:, jj) = compute_extra_nowcast_horizon(tmp);
    new_required_nowcast_horizon(:, jj) = compute_required_nowcast_horizon(tmp, base_obs, base_vintages);
end

PREDICTORS_OUT.data = cat(3, PREDICTORS_IN.data, new_tensor);
PREDICTORS_OUT.id = [cellstr(PREDICTORS_IN.id(:)); cellstr(NEW_PANELS.id(:))];

if isfield(PREDICTORS_IN, 'extra_nowcast_horizon')
    existing_extra_nowcast_horizon = PREDICTORS_IN.extra_nowcast_horizon;
else
    existing_extra_nowcast_horizon = zeros(numel(base_vintages), numel(PREDICTORS_IN.id));
end

if isfield(PREDICTORS_IN, 'required_nowcast_horizon')
    existing_required_nowcast_horizon = PREDICTORS_IN.required_nowcast_horizon;
else
    existing_required_nowcast_horizon = nan(numel(base_vintages), numel(PREDICTORS_IN.id));
end

PREDICTORS_OUT.extra_nowcast_horizon = [existing_extra_nowcast_horizon, new_extra_nowcast_horizon];
PREDICTORS_OUT.required_nowcast_horizon = [existing_required_nowcast_horizon, new_required_nowcast_horizon];

end

function d = month_start(d)

d = datetime(year(d), month(d), 1);

end

function required_nowcast_horizon = compute_required_nowcast_horizon(data_matrix, obs_dates, vintage_months)

last_obs_idx = last_observed_index(data_matrix);
required_nowcast_horizon = nan(numel(last_obs_idx), 1);

for mm = 1:numel(last_obs_idx)
    if isnan(last_obs_idx(mm))
        continue
    end

    vintage_obs_idx = find(obs_dates == vintage_months(mm), 1, 'first');
    if isempty(vintage_obs_idx)
        last_obs_date = obs_dates(last_obs_idx(mm));
        required_nowcast_horizon(mm) = calmonths(between(last_obs_date, vintage_months(mm), 'months'));
    else
        required_nowcast_horizon(mm) = vintage_obs_idx - last_obs_idx(mm);
    end
    required_nowcast_horizon(mm) = max(0, required_nowcast_horizon(mm));
end

end

function extra_nowcast_horizon = compute_extra_nowcast_horizon(data_matrix)

last_obs_idx = last_observed_index(data_matrix);
extra_nowcast_horizon = zeros(numel(last_obs_idx), 1);
first_valid_pos = find(~isnan(last_obs_idx), 1, 'first');

if isempty(first_valid_pos)
    return
end

first_origin = last_obs_idx(first_valid_pos);
for mm = first_valid_pos:numel(last_obs_idx)
    if isnan(last_obs_idx(mm))
        continue
    end
    expected_origin = first_origin + (mm - first_valid_pos);
    extra_nowcast_horizon(mm) = max(0, expected_origin - last_obs_idx(mm));
end

end

function last_obs_idx = last_observed_index(data_matrix)

last_obs_idx = nan(1, size(data_matrix, 2));

for mm = 1:size(data_matrix, 2)
    idx = find(~isnan(data_matrix(:, mm)), 1, 'last');
    if ~isempty(idx)
        last_obs_idx(mm) = idx;
    end
end

end
