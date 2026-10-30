function [PREDICTORS_available, missing_vintage_report] = make_available_predictors(PREDICTORS_source)

[PREDICTORS_filled, missing_vintage_report] = fill_missing_vintage_columns(PREDICTORS_source);

model_fields = {'RW', 'SA', 'AR_p', 'AR_IC', 'BAR', 'BAR_SV', 'BAR_SVo'};
for ff = 1:numel(model_fields)
    field = model_fields{ff};
    PREDICTORS_available.(field).data = PREDICTORS_filled.data;
    PREDICTORS_available.(field).obs = PREDICTORS_filled.obs;
    PREDICTORS_available.(field).vintages = PREDICTORS_filled.vintages;
    PREDICTORS_available.(field).id = PREDICTORS_filled.id;
end

PREDICTORS_available.contains_nowcasted_values = false;
PREDICTORS_available.missing_vintage_report = missing_vintage_report;

end
