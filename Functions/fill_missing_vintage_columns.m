function [PREDICTORS_filled, missing_vintage_report] = fill_missing_vintage_columns(PREDICTORS_in)

PREDICTORS_filled = PREDICTORS_in;
data = PREDICTORS_in.data;
filled_data = data;

ids = PREDICTORS_in.id(:);
if isstring(ids)
    ids = cellstr(ids);
end

report_rows = {};

for jj = 1:size(data, 3)
    for vv = 2:size(data, 2)
        original_missing = all(isnan(data(:, vv, jj)));
        previous_has_data = any(~isnan(filled_data(:, vv - 1, jj)));

        if ~original_missing || ~previous_has_data
            continue
        end

        last_observed = find(~isnan(filled_data(:, vv - 1, jj)), 1, 'last');
        if isempty(last_observed)
            continue
        end

        filled_data(1:last_observed, vv, jj) = filled_data(1:last_observed, vv - 1, jj);

        last_observed_date = NaT;
        if isfield(PREDICTORS_in, 'obs') && numel(PREDICTORS_in.obs) >= last_observed
            last_observed_date = PREDICTORS_in.obs(last_observed);
        end

        vintage_date = NaT;
        previous_vintage_date = NaT;
        if isfield(PREDICTORS_in, 'vintages') && numel(PREDICTORS_in.vintages) >= vv
            vintage_date = PREDICTORS_in.vintages(vv);
            previous_vintage_date = PREDICTORS_in.vintages(vv - 1);
        end

        report_rows(end + 1, :) = {ids{jj}, vintage_date, previous_vintage_date, last_observed_date, last_observed};
    end
end

PREDICTORS_filled.data = filled_data;

if isempty(report_rows)
    missing_vintage_report = table(string.empty(0, 1), NaT(0, 1), NaT(0, 1), NaT(0, 1), zeros(0, 1), ...
        'VariableNames', {'predictor', 'vintage', 'previous_vintage', 'last_observed_date', 'last_observed_row'});
else
    missing_vintage_report = cell2table(report_rows, ...
        'VariableNames', {'predictor', 'vintage', 'previous_vintage', 'last_observed_date', 'last_observed_row'});
    missing_vintage_report.predictor = string(missing_vintage_report.predictor);
end

end
