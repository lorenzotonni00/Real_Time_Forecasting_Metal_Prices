function [Yhat, model_info] = tree_ml_forecast(MACRO, ETM_prices, model_name, direct, hor, Y_g, Y_d, X_d, y)

if direct ~= 1
    error('tree_ml_forecast currently supports direct forecasts only');
end

X_tree = X_d;
[X_tree, predictor_id] = align_predictor_matrix(X_tree, MACRO.id, 'tree_ml_forecast');

drop_predictor = strcmp(predictor_id, 'CPIAUCSL') | strcmp(predictor_id, ETM_prices.id{y});
X_tree(:,drop_predictor) = [];

common_length = min([size(Y_g, 1), size(Y_d, 1), size(X_tree, 1)]);
if common_length <= hor
    Yhat = mean(Y_g, 'omitnan');
    if isnan(Yhat)
        Yhat = 0;
    end
    model_info = struct();
    model_info.method = model_name;
    model_info.n_obs = 0;
    model_info.n_predictors = size(X_tree, 2) + 1;
    model_info.fallback = 'mean';
    model_info.alignment = 'tail';
    return
end

Y_g = Y_g(end-common_length+1:end, :);
Y_d = Y_d(end-common_length+1:end, :);
X_tree = X_tree(end-common_length+1:end, :);

X_all = [Y_d, X_tree];
X_train = X_all(1:end-hor,:);
Y_train = Y_g(hor+1:end,1);
X_now = X_all(end,:);

valid_y = ~isnan(Y_train);
X_train = X_train(valid_y,:);
Y_train = Y_train(valid_y,:);

valid_cols = ~all(isnan(X_train), 1);
X_train = X_train(:,valid_cols);
X_now = X_now(:,valid_cols);

col_means = mean(X_train, 1, 'omitnan');
valid_cols = ~isnan(col_means);
X_train = X_train(:,valid_cols);
X_now = X_now(:,valid_cols);
col_means = col_means(:,valid_cols);

for jj = 1:size(X_train,2)
    missing_train = isnan(X_train(:,jj));
    X_train(missing_train,jj) = col_means(jj);
end

missing_now = isnan(X_now);
X_now(missing_now) = col_means(missing_now);

model_info = struct();
model_info.method = model_name;
model_info.n_obs = size(X_train,1);
model_info.n_predictors = size(X_train,2);

if isempty(Y_train) || isempty(X_train) || size(X_train,1) < 20 || numel(unique(Y_train)) < 2
    if isempty(Y_train)
        Yhat = 0;
    else
        Yhat = mean(Y_train, 'omitnan');
        if isnan(Yhat)
            Yhat = 0;
        end
    end
    model_info.fallback = 'mean';
    return
end

if strcmp(model_name, 'Random_Forest')
    if exist('TreeBagger', 'file') ~= 2
        error('TreeBagger is required for Random_Forest forecasts');
    end
    model_info.num_trees = 500;

    model_info.min_leaf_size = 5;
    mdl = TreeBagger(model_info.num_trees, X_train, Y_train, ...
        'Method', 'regression', ...
        'MinLeafSize', model_info.min_leaf_size);
    Yhat = predict(mdl, X_now);
elseif strcmp(model_name, 'Gradient_Boosting')
    if exist('fitrensemble', 'file') ~= 2
        error('fitrensemble is required for Gradient_Boosting forecasts');
    end
    model_info.num_learning_cycles = 1000;
    model_info.learn_rate = 0.01;
    model_info.min_leaf_size = 10;
    model_info.max_num_splits = 4;
    model_info.num_variables_to_sample = max(1, round(size(X_train, 2) / 3));
    model_info.validation_share = 0.20;
    model_info.min_validation_obs = 5;
    model_info.min_fit_obs = max(20, 2 * model_info.min_leaf_size + 1);

    n_train = size(X_train, 1);
    n_val = round(n_train * model_info.validation_share);
    n_val = max(model_info.min_validation_obs, n_val);
    n_val = min(n_val, n_train - model_info.min_fit_obs);
    use_validation = n_val >= model_info.min_validation_obs && (n_train - n_val) >= model_info.min_fit_obs;

    tree_template = templateTree( ...
        'MinLeafSize', model_info.min_leaf_size, ...
        'MaxNumSplits', model_info.max_num_splits, ...
        'NumVariablesToSample', model_info.num_variables_to_sample);

    if use_validation
        n_fit = n_train - n_val;
        X_fit = X_train(1:n_fit, :);
        Y_fit = Y_train(1:n_fit);
        X_val = X_train(n_fit+1:end, :);
        Y_val = Y_train(n_fit+1:end);
    else
        n_fit = n_train;
        X_fit = X_train;
        Y_fit = Y_train;
        X_val = [];
        Y_val = [];
    end

    mdl = fitrensemble(X_fit, Y_fit, ...
        'Method', 'LSBoost', ...
        'Learners', tree_template, ...
        'NumLearningCycles', model_info.num_learning_cycles, ...
        'LearnRate', model_info.learn_rate);

    if use_validation
        val_mse = loss(mdl, X_val, Y_val, 'Mode', 'cumulative');
        [best_val_mse, best_k] = min(val_mse);
        Yhat = predict(mdl, X_now, 'Learners', 1:best_k);
        model_info.validation_used = true;
        model_info.validation_mse_best = best_val_mse;
        model_info.validation_mse_last = val_mse(end);
    else
        best_k = model_info.num_learning_cycles;
        Yhat = predict(mdl, X_now);
        model_info.validation_used = false;
        model_info.validation_mse_best = NaN;
        model_info.validation_mse_last = NaN;
    end

    model_info.n_fit = n_fit;
    model_info.n_val = n_val;
    model_info.best_num_learning_cycles = best_k;
elseif any(strcmp(model_name, {'BMA_MC3', 'DMA', 'LASSO'}))
    [Yhat, extra_info] = model_averaging_forecast(model_name, X_train, Y_train, X_now);
    info_fields = fieldnames(extra_info);
    for ff = 1:numel(info_fields)
        model_info.(info_fields{ff}) = extra_info.(info_fields{ff});
    end
else
    error('Unknown forecasting model: %s', model_name);
end

Yhat = Yhat(1);
if ~isfield(model_info, 'fallback')
    model_info.fallback = 'none';
end

end
