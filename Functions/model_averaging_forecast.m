function [Yhat, info] = model_averaging_forecast(model_name, X_train, Y_train, X_now)

model_name = char(string(model_name));
Y_train = Y_train(:);
X_now = X_now(:)';

info = struct();
info.method = model_name;
info.n_obs = size(X_train, 1);
info.n_predictors = size(X_train, 2);

if isempty(Y_train) || isempty(X_train) || size(X_train, 1) < 20 || numel(unique(Y_train)) < 2
    Yhat = mean_fallback(Y_train);
    info.fallback = 'mean';
    return
end

[X_std, X_now_std] = standardize_design(X_train, X_now);

switch model_name
    case 'BMA_MC3'
        [Yhat, details] = bma_mc3_direct(X_std, Y_train, X_now_std);
    case 'DMA'
        [Yhat, details] = dma_direct(X_std, Y_train, X_now_std);
    case 'LASSO'
        [Yhat, details] = lasso_direct(X_std, Y_train, X_now_std);
    otherwise
        error('Unknown model averaging method: %s', model_name);
end

detail_fields = fieldnames(details);
for ff = 1:numel(detail_fields)
    info.(detail_fields{ff}) = details.(detail_fields{ff});
end
info.fallback = 'none';
Yhat = Yhat(1);

end

function [Yhat, info] = bma_mc3_direct(X, Y, x0)

n = size(X, 1);
k = size(X, 2);
info = struct();
info.mc3_draws = 8000;
info.mc3_burnin = 3000;
info.max_model_size = min([8, k, max(1, n - 3)]);
info.prior_expected_model_size = min(4, info.max_model_size);
info.prior_inclusion_probability = min(0.5, max(1 / max(k, 1), info.prior_expected_model_size / max(k, 1)));

if k == 0 || info.max_model_size < 1
    Yhat = mean_fallback(Y);
    info.fallback = 'mean';
    return
end

q = info.prior_inclusion_probability;
scores = predictor_scores(X, Y);
[~, score_order] = sort(scores, 'descend');
included = false(1, k);
included(score_order(1:min(3, info.max_model_size))) = true;

cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
[current_logpost, current_pred] = score_model(included);

accepted = 0;
n_kept = 0;
pred_sum = 0;
pip = zeros(1, k);
size_sum = 0;

for draw = 1:info.mc3_draws
    proposal = included;
    toggle_idx = randi(k);
    proposal(toggle_idx) = ~proposal(toggle_idx);

    if sum(proposal) <= info.max_model_size
        [proposal_logpost, proposal_pred] = score_model(proposal);
        if log(rand) < proposal_logpost - current_logpost
            included = proposal;
            current_logpost = proposal_logpost;
            current_pred = proposal_pred;
            accepted = accepted + 1;
        end
    end

    if draw > info.mc3_burnin
        n_kept = n_kept + 1;
        pred_sum = pred_sum + current_pred;
        pip = pip + included;
        size_sum = size_sum + sum(included);
    end
end

if n_kept == 0
    Yhat = mean_fallback(Y);
else
    Yhat = pred_sum / n_kept;
end

info.acceptance_rate = accepted / info.mc3_draws;
info.posterior_mean_model_size = size_sum / max(n_kept, 1);
info.posterior_inclusion_prob = pip ./ max(n_kept, 1);
info.n_kept_draws = n_kept;

    function [logpost, pred] = score_model(mask)
        key = char('0' + mask);
        if isKey(cache, key)
            cached = cache(key);
            logpost = cached.logpost;
            pred = cached.pred;
            return
        end

        s = sum(mask);
        if s > info.max_model_size || s > n - 2
            logpost = -Inf;
            pred = mean_fallback(Y);
        else
            [pred, rss] = ols_model_predict(X, Y, x0, mask);
            rss = max(rss, realmin);
            bic = n * log(rss / n) + (s + 1) * log(n);
            log_prior = s * log(q) + (k - s) * log(1 - q);
            logpost = -0.5 * bic + log_prior;
        end

        cache(key) = struct('logpost', logpost, 'pred', pred);
    end

end

function [Yhat, info] = dma_direct(X, Y, x0)

n = size(X, 1);
k = size(X, 2);
info = struct();
 info.max_model_size = min([6, k, max(1, n - 3)]);
 info.n_candidate_models = min(40, max(20, 2 * k));
 info.validation_share = 0.20;
 info.max_validation_obs = 24;
 info.min_validation_obs = 6;
 info.model_forgetting_factor = 0.99;
 info.variance_forgetting_factor = 0.98;

if k == 0 || info.max_model_size < 1
    Yhat = mean_fallback(Y);
    info.fallback = 'mean';
    return
end

models = dma_candidate_models(X, Y, info.max_model_size, info.n_candidate_models);
n_models = size(models, 1);
info.n_candidate_models = n_models;

n_val = round(n * info.validation_share);
n_val = min([n_val, info.max_validation_obs, n - max(20, info.max_model_size + 5)]);
n_val = max(0, n_val);
use_validation = n_val >= info.min_validation_obs;
info.validation_used = use_validation;
info.n_val = n_val;

if use_validation
    start_val = n - n_val + 1;
    weights = ones(n_models, 1) ./ n_models;
    sigma2 = var(Y(1:start_val-1), 0, 'omitnan');
    if ~isfinite(sigma2) || sigma2 <= 0
        sigma2 = var(Y, 0, 'omitnan');
    end
    sigma2 = max(sigma2, 1e-8);

    for tt = start_val:n
        preds = zeros(n_models, 1);
        for mm = 1:n_models
            preds(mm) = ols_model_predict(X(1:tt-1, :), Y(1:tt-1), X(tt, :), models(mm, :));
        end

        prior_weights = weights .^ info.model_forgetting_factor;
        prior_weights = prior_weights ./ sum(prior_weights);
        errors = Y(tt) - preds;
        sigma2 = info.variance_forgetting_factor * sigma2 + ...
            (1 - info.variance_forgetting_factor) * sum(prior_weights .* errors.^2);
        sigma2 = max(sigma2, 1e-8);

        log_weights = log(prior_weights + realmin) - 0.5 .* (log(2 * pi * sigma2) + errors.^2 ./ sigma2);
        weights = normalize_log_weights(log_weights);
    end
else
    log_scores = NaN(n_models, 1);
    for mm = 1:n_models
        [~, rss] = ols_model_predict(X, Y, x0, models(mm, :));
        model_size = sum(models(mm, :)) + 1;
        log_scores(mm) = -0.5 * (n * log(max(rss, realmin) / n) + model_size * log(n));
    end
    weights = normalize_log_weights(log_scores);
end

final_preds = zeros(n_models, 1);
for mm = 1:n_models
    final_preds(mm) = ols_model_predict(X, Y, x0, models(mm, :));
end

Yhat = sum(weights .* final_preds);
info.final_model_weights = weights(:)';
info.final_model_sizes = sum(models, 2)';
info.posterior_mean_model_size = sum(weights .* sum(models, 2));

end

function [Yhat, info] = lasso_direct(X, Y, x0)

info = struct();
 info.validation_share = 0.20;
 info.min_validation_obs = 5;
 info.min_fit_obs = 20;

if exist('lasso', 'file') ~= 2
    error('lasso is required for LASSO forecasts');
end

n = size(X, 1);
lambda_score = abs(X' * (Y - mean(Y, 'omitnan')));
lambda_max = max(lambda_score(:)) ./ max(n, 1);
lambda_max = double(lambda_max(1));
if ~isfinite(lambda_max) || lambda_max <= 0
    Yhat = mean_fallback(Y);
    info.fallback = 'mean';
    return
end

lambda_grid = logspace(log10(lambda_max * 1e-4), log10(lambda_max), 50);
n_val = round(n * info.validation_share);
n_val = max(info.min_validation_obs, n_val);
n_val = min(n_val, n - info.min_fit_obs);
use_validation = n_val >= info.min_validation_obs && (n - n_val) >= info.min_fit_obs;

if use_validation
    n_fit = n - n_val;
    X_fit = X(1:n_fit, :);
    Y_fit = Y(1:n_fit);
    X_val = X(n_fit+1:end, :);
    Y_val = Y(n_fit+1:end);

    [B, FitInfo] = lasso(X_fit, Y_fit, 'Lambda', lambda_grid, 'Standardize', false);
    val_pred = bsxfun(@plus, X_val * B, FitInfo.Intercept);
    val_mse = mean((val_pred - Y_val).^2, 1, 'omitnan');
    [best_mse, best_idx] = min(val_mse);
else
    n_fit = n;
    [B, FitInfo] = lasso(X, Y, 'Lambda', lambda_grid, 'Standardize', false);
    train_pred = bsxfun(@plus, X * B, FitInfo.Intercept);
    rss = sum((train_pred - Y).^2, 1, 'omitnan');
    df = sum(B ~= 0, 1) + 1;
    bic = n * log(max(rss, realmin) ./ n) + df .* log(n);
    [best_mse, best_idx] = min(bic);
end

lambda_opt = lambda_grid(best_idx);
[B_final, FitInfo_final] = lasso(X, Y, 'Lambda', lambda_opt, 'Standardize', false);
Yhat = FitInfo_final.Intercept + x0 * B_final;

info.validation_used = use_validation;
info.n_fit = n_fit;
info.n_val = max(n_val, 0);
info.lambda = lambda_opt;
info.selected_predictors = find(B_final ~= 0)';
info.n_selected_predictors = nnz(B_final);
info.selection_score = best_mse;

end

function models = dma_candidate_models(X, Y, max_model_size, n_candidates)

k = size(X, 2);
scores = predictor_scores(X, Y);
[~, order] = sort(scores, 'descend');
pool = order(1:min(k, 20));

models = false(0, k);
models(end+1, :) = false(1, k);

for ii = 1:min([numel(pool), n_candidates - 1])
    mask = false(1, k);
    mask(pool(ii)) = true;
    models(end+1, :) = mask; 
end

for ss = 2:min(max_model_size, 5)
    mask = false(1, k);
    mask(pool(1:min(ss, numel(pool)))) = true;
    models(end+1, :) = mask;
end

tries = 0;
while size(models, 1) < n_candidates && tries < n_candidates * 30
    tries = tries + 1;
    s = randi(max_model_size);
    s = min(s, numel(pool));
    idx = pool(randperm(numel(pool), s));
    mask = false(1, k);
    mask(idx) = true;
    models(end+1, :) = mask; 
    models = unique(models, 'rows', 'stable');
end

models = unique(models, 'rows', 'stable');
if size(models, 1) > n_candidates
    models = models(1:n_candidates, :);
end

end

function [X_std, x0_std] = standardize_design(X, x0)

mu = mean(X, 1, 'omitnan');
sigma = std(X, 0, 1, 'omitnan');
sigma(~isfinite(sigma) | sigma == 0) = 1;
mu(~isfinite(mu)) = 0;

X_std = (X - mu) ./ sigma;
x0_std = (x0 - mu) ./ sigma;
X_std(~isfinite(X_std)) = 0;
x0_std(~isfinite(x0_std)) = 0;

end

function scores = predictor_scores(X, Y)

Yc = Y(:) - mean(Y, 'omitnan');
Xc = X - mean(X, 1, 'omitnan');
den = sqrt(sum(Xc.^2, 1)) .* sqrt(sum(Yc.^2));
scores = abs((Xc' * Yc)' ./ den);
scores(~isfinite(scores)) = 0;

end

function [pred, rss] = ols_model_predict(X, Y, x0, mask)

Y = Y(:);
if ~any(mask)
    pred = mean_fallback(Y);
    residuals = Y - pred;
    rss = sum(residuals.^2, 'omitnan');
    return
end

X_reg = [ones(size(X, 1), 1), X(:, mask)];
x_reg = [1, x0(mask)];
if size(X_reg, 2) >= size(X_reg, 1)
    beta = pinv(X_reg) * Y;
else
    beta = X_reg \ Y;
end

pred = x_reg * beta;
residuals = Y - X_reg * beta;
rss = sum(residuals.^2, 'omitnan');

end

function weights = normalize_log_weights(log_weights)

log_weights = log_weights(:);
max_log_weight = max(log_weights);
if ~isfinite(max_log_weight)
    weights = ones(numel(log_weights), 1) ./ numel(log_weights);
    return
end

weights = exp(log_weights - max_log_weight);
weight_sum = sum(weights);
if ~isfinite(weight_sum) || weight_sum <= 0
    weights = ones(numel(log_weights), 1) ./ numel(log_weights);
else
    weights = weights ./ weight_sum;
end

end

function Yhat = mean_fallback(Y)

if isempty(Y)
    Yhat = 0;
else
    Yhat = mean(Y, 'omitnan');
    if ~isfinite(Yhat)
        Yhat = 0;
    end
end

end
