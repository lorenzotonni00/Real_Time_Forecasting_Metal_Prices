function PREDICTORS_OUT = select_predictors_by_id(PREDICTORS_IN, keep_ids)

keep_ids = cellstr(keep_ids(:));
PREDICTORS_OUT = PREDICTORS_IN;

model_fields = {'RW', 'SA', 'AR_p', 'AR_IC', 'BAR', 'BAR_SV', 'BAR_SVo'};
reference_idx = [];

for ff = 1:numel(model_fields)
    field = model_fields{ff};
    if ~isfield(PREDICTORS_IN, field) || ~isfield(PREDICTORS_IN.(field), 'id')
        continue
    end

    current_id = cellstr(PREDICTORS_IN.(field).id(:));
    [is_present, idx_keep] = ismember(keep_ids, current_id);
    idx_keep = idx_keep(is_present);

    if isempty(reference_idx)
        reference_idx = idx_keep;
    end

    PREDICTORS_OUT.(field).id = current_id(idx_keep);
    if isfield(PREDICTORS_IN.(field), 'data')
        PREDICTORS_OUT.(field).data = PREDICTORS_IN.(field).data(:, :, idx_keep);
    end
end

if isfield(PREDICTORS_IN, 'best_model') && ~isempty(reference_idx)
    best_model = PREDICTORS_IN.best_model(:);
    if numel(best_model) >= max(reference_idx)
        PREDICTORS_OUT.best_model = best_model(reference_idx);
    end
end

PREDICTORS_OUT.selected_predictor_ids = keep_ids(:)';

end
