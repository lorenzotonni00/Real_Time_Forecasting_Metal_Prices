function [X, predictor_id] = align_predictor_matrix(X, predictor_id, caller_name)

predictor_id = cellstr(predictor_id);
predictor_id = predictor_id(:)';
n_ids = numel(predictor_id);

if size(X, 2) ~= n_ids
    if size(X, 1) == n_ids && size(X, 2) == 1
        X = X.';
    else
        error_id = sprintf('%s:PredictorIdMismatch', caller_name);
        error(error_id, ...
            'MACRO.id has %d entries but the predictor matrix has %d columns.', ...
            n_ids, size(X, 2));
    end
end
end
