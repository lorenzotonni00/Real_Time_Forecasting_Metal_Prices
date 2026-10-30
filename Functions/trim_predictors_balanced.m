function PREDICTORS_balanced = trim_predictors_balanced(PREDICTORS_balanced, first_date, last_date)
% TRIM_PREDICTORS_BALANCED Trims the PREDICTORS_balanced structure based on a
% date range, applied to both "vintages" and
% "obs", and removes the final rows containing all NaN values.

    first_date = datetime(first_date);
    last_date  = datetime(last_date);

    %% 1) Select observation in the interval [first_date, last_date]
    obs_mask = PREDICTORS_balanced.obs >= first_date & ...
               PREDICTORS_balanced.obs <= last_date;

    if ~any(obs_mask)
        error('No observation within the interval [%s, %s].', ...
            datestr(first_date), datestr(last_date));
    end

    % Cut obs
    PREDICTORS_balanced.obs = PREDICTORS_balanced.obs(obs_mask);

    %% 2) Select vintages in the interval [first_date, last_date]
    vint_mask = PREDICTORS_balanced.vintages >= first_date & ...
                PREDICTORS_balanced.vintages <= last_date;

    if ~any(vint_mask)
        error('No vintage found within the interval [%s, %s].', ...
            datestr(first_date), datestr(last_date));
    end

    PREDICTORS_balanced.vintages = PREDICTORS_balanced.vintages(vint_mask);

    %% 3) Cut "data" on both dimensions (389x135x17 -> Nx Kx17)
    
    PREDICTORS_balanced.data = PREDICTORS_balanced.data(obs_mask, vint_mask, :);

    %% 4) Cut rows of extra_nowcast_horizon
    PREDICTORS_balanced.extra_nowcast_horizon = ...
        PREDICTORS_balanced.extra_nowcast_horizon(vint_mask, :);
    PREDICTORS_balanced.required_nowcast_horizon = ...
        PREDICTORS_balanced.required_nowcast_horizon(vint_mask, :);

    %% 5) Remove final NaN rows of "data"
    n_obs = size(PREDICTORS_balanced.data, 1);
    all_nan_row = false(n_obs, 1);
    for t = 1:n_obs
        all_nan_row(t) = all(isnan(PREDICTORS_balanced.data(t, :, :)), 'all');
    end

    n_trail_nan = 0;
    for t = n_obs:-1:1
        if all_nan_row(t)
            n_trail_nan = n_trail_nan + 1;
        else
            break
        end
    end

    if n_trail_nan > 0
        keep_idx = 1:(n_obs - n_trail_nan);
        PREDICTORS_balanced.data = PREDICTORS_balanced.data(keep_idx, :, :);
        PREDICTORS_balanced.obs  = PREDICTORS_balanced.obs(keep_idx);
    end

end