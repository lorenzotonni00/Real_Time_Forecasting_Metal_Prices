function PREDICTORS_lev_now = fill_nowcast_level_edges(PREDICTORS_lev_now, PREDICTORS_available, results, pred_id, transformations, Hsize_by_var, base_Hsize_by_var, extra_nowcast_horizon, required_nowcast_horizon)

if nargin < 8 || isempty(extra_nowcast_horizon)
    extra_nowcast_horizon = zeros(size(PREDICTORS_available.data, 2), numel(pred_id));
end
if nargin < 9 || isempty(required_nowcast_horizon)
    required_nowcast_horizon = nan(size(PREDICTORS_available.data, 2), numel(pred_id));
end

model_fields = {'AR_p', 'AR_IC', 'RW', 'SA', 'BAR', 'BAR_SV', 'BAR_SVo'};
max_horizon = max(Hsize_by_var);

for mm = 1:numel(model_fields)
    model_name = model_fields{mm};
    if ~isfield(PREDICTORS_lev_now, model_name) || ~isfield(PREDICTORS_lev_now.(model_name), 'data')
        PREDICTORS_lev_now.(model_name).data = PREDICTORS_available.data;
    end
    if ~isfield(PREDICTORS_lev_now.(model_name), 'data_real')
        PREDICTORS_lev_now.(model_name).data_real = NaN(size(PREDICTORS_available.data));
    end
    if ~isfield(PREDICTORS_lev_now.(model_name), 'eps')
        PREDICTORS_lev_now.(model_name).eps = NaN(max_horizon, size(PREDICTORS_available.data, 2), numel(pred_id));
    end
end

for yy = 1:numel(pred_id)
    Hsize_var = Hsize_by_var(yy);
    if Hsize_var == 0
        continue
    end

    Y_temp = squeeze(PREDICTORS_available.data(:, :, yy));
    pos_1st_obs = find(~all(isnan(Y_temp), 2), 1);
    pos_1st_vin = find(~all(isnan(Y_temp), 1), 1);
    if isempty(pos_1st_obs) || isempty(pos_1st_vin)
        continue
    end

    Y = Y_temp(pos_1st_obs:end, pos_1st_vin:end);
    n_vintages = min(size(Y, 2), size(results.(pred_id{yy}).SA.y_hat, 2));
    first_origin = find(~isnan(Y(:, 1)), 1, 'last');
    if isempty(first_origin)
        continue
    end
    
    Y_obs_level = Y_temp(:, end);

    for tt = 1:n_vintages
        col = pos_1st_vin + tt - 1;
        origin_local = find(~isnan(Y(:, tt)), 1, 'last');
        if isempty(origin_local)
            continue
        end

        origin_row = pos_1st_obs + origin_local - 1;
        if origin_row < 1 || origin_row > size(Y_temp, 1)
            continue
        end

        lastx = Y_temp(origin_row, col);
        if origin_row > 1
            lastx_1 = Y_temp(origin_row - 1, col);
        else
            lastx_1 = NaN;
        end

        for hh = 1:Hsize_var
            target_row = origin_row + hh;
            if target_row > size(Y_temp, 1)
                continue
            end

            if ~isnan(Y_temp(target_row, col))
                continue
            end

            % Actual published level from the last vintage — identical for all models.
            data_real_val = Y_obs_level(target_row);

            for mm = 1:numel(model_fields)
                model_name = model_fields{mm};
                if hh > size(results.(pred_id{yy}).(model_name).y_hat, 1) || tt > size(results.(pred_id{yy}).(model_name).y_hat, 2)
                    continue
                end

                y_hat = results.(pred_id{yy}).(model_name).y_hat(hh, tt);

                PREDICTORS_lev_now.(model_name).data(target_row, col, yy) = nowcast_level_value(transformations(yy), model_name, y_hat, lastx, lastx_1, hh);
                PREDICTORS_lev_now.(model_name).data_real(target_row, col, yy) = data_real_val;
                PREDICTORS_lev_now.(model_name).eps(hh, tt, yy) = ...
                    data_real_val - PREDICTORS_lev_now.(model_name).data(target_row, col, yy);
            end
        end
    end
end

%% Consistency check: data_real must be identical across all models
n_active = numel(model_fields);
if n_active > 1
    for yy_chk = 1:numel(pred_id)
        ref_mat = squeeze(PREDICTORS_lev_now.(model_fields{1}).data_real(:, :, yy_chk));
        for mm_chk = 2:n_active
            alt_mat = squeeze(PREDICTORS_lev_now.(model_fields{mm_chk}).data_real(:, :, yy_chk));
            diff_vals = ref_mat(:) - alt_mat(:);
            max_diff = max(abs(diff_vals(isfinite(diff_vals))));
            if ~isempty(max_diff) && max_diff > 1e-10
                warning('fill_nowcast_level_edges:inconsistentBenchmark', ...
                    '[%s] data_real differs between %s and %s: max|diff| = %.2e', ...
                    pred_id{yy_chk}, model_fields{1}, model_fields{mm_chk}, max_diff);
            end
        end
    end
end

end

function value = nowcast_level_value(tcode, model_name, transformed_value, lastx, lastx_1, hh)

if isnan(transformed_value) || isnan(lastx)
    value = NaN;
    return
end

if ismember(model_name, {'RW', 'SA'})
    if lastx <= 0
        value = NaN;
    else
        value = lastx .* exp(transformed_value);
    end
elseif tcode == 0
    % Level variable (CLI and similar): AR predicts the level directly.
    value = transformed_value;
elseif tcode == 1
    value = exp(transformed_value);
elseif tcode == 3
    value = lastx .* exp(transformed_value);
elseif tcode == 5
    if isnan(lastx_1) || lastx <= 0 || lastx_1 <= 0
        value = NaN;
    else
        delta_1 = log(lastx) - log(lastx_1);
        value = exp(log(lastx) + hh * delta_1 + transformed_value);
    end
else
    value = transformed_value;
end

end
