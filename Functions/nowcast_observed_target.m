function [value, value_tr_3, target_idx] = nowcast_observed_target(Y_observed, origin_idx, hor, tcode, target_scheme)

value = NaN;
value_tr_3 = NaN;
target_idx = NaN;

if isempty(origin_idx) || isnan(origin_idx)
    return
end

Y_observed = Y_observed(:);
origin_idx = round(origin_idx);
target_idx = origin_idx + hor;

if origin_idx < 1 || target_idx > numel(Y_observed)
    return
end

if strcmp(target_scheme, 'SW')
    value = transformed_sw_value(Y_observed, origin_idx, target_idx, hor, tcode);
    value_tr_3 = safe_log_diff(Y_observed, target_idx, origin_idx);
elseif strcmp(target_scheme, 'SinglePeriod')
    value = transformed_single_period_value(Y_observed, target_idx, tcode);
    value_tr_3 = safe_log_diff(Y_observed, target_idx, target_idx - 1);
else
    error('Unknown target scheme: %s', target_scheme);
end

end

function value = transformed_sw_value(Y, origin_idx, target_idx, hor, tcode)

value = NaN;
if tcode == 0
    value = Y(target_idx);
elseif tcode == 1
    value = safe_log(Y(target_idx));
elseif tcode == 2
    value = Y(target_idx) - Y(origin_idx);
elseif tcode == 3
    value = safe_log_diff(Y, target_idx, origin_idx);
elseif tcode == 4
    if origin_idx <= 1
        return
    end
    value = (Y(target_idx) - Y(origin_idx)) - hor * (Y(origin_idx) - Y(origin_idx - 1));
elseif tcode == 5
    if origin_idx <= 1
        return
    end
    value = safe_log_diff(Y, target_idx, origin_idx) - hor * safe_log_diff(Y, origin_idx, origin_idx - 1);
end

end

function value = transformed_single_period_value(Y, target_idx, tcode)

value = NaN;
if tcode == 0
    value = Y(target_idx);
elseif tcode == 1
    value = safe_log(Y(target_idx));
elseif tcode == 2
    if target_idx <= 1
        return
    end
    value = Y(target_idx) - Y(target_idx - 1);
elseif tcode == 3
    value = safe_log_diff(Y, target_idx, target_idx - 1);
elseif tcode == 4
    if target_idx <= 2
        return
    end
    value = (Y(target_idx) - Y(target_idx - 1)) - (Y(target_idx - 1) - Y(target_idx - 2));
elseif tcode == 5
    if target_idx <= 2
        return
    end
    value = safe_log_diff(Y, target_idx, target_idx - 1) - safe_log_diff(Y, target_idx - 1, target_idx - 2);
end

end

function value = safe_log(x)

if ~isfinite(x) || x <= 0
    value = NaN;
else
    value = log(x);
end

end

function value = safe_log_diff(Y, idx_a, idx_b)

if idx_a < 1 || idx_b < 1 || idx_a > numel(Y) || idx_b > numel(Y)
    value = NaN;
else
    value = safe_log(Y(idx_a)) - safe_log(Y(idx_b));
end

end
