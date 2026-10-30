function Hsize = infer_nowcast_horizon(Y_temp, pos_1st_obs, pos_1st_vin, base_Hsize, extra_nowcast_horizon, required_nowcast_horizon)

if nargin < 5 || isempty(extra_nowcast_horizon)
    extra_nowcast_horizon = 0;
end
if nargin < 6 || isempty(required_nowcast_horizon)
    required_nowcast_horizon = [];
end

Hsize = base_Hsize;
if base_Hsize == 0 || isempty(pos_1st_obs) || isempty(pos_1st_vin)
    return
end

if ~isempty(required_nowcast_horizon)
    Hsize = max(Hsize, max(required_nowcast_horizon(:), [], 'omitnan'));
    Hsize = max(base_Hsize, min(Hsize, size(Y_temp, 1)));
    return
else
    Hsize = max(Hsize, base_Hsize + max(extra_nowcast_horizon(:), [], 'omitnan'));
end

Y = Y_temp(pos_1st_obs:end, pos_1st_vin:end);
first_vintage = Y(:, 1);
first_origin = find(~isnan(first_vintage), 1, 'last');
if isempty(first_origin)
    return
end

for tt = 1:size(Y, 2)
    origin = find(~isnan(Y(:, tt)), 1, 'last');
    if isempty(origin)
        continue
    end

    normal_origin = first_origin + tt - 1;
    needed_horizon = normal_origin + base_Hsize - origin;
    Hsize = max(Hsize, needed_horizon);
end

Hsize = max(base_Hsize, min(Hsize, size(Y, 1)));

end
