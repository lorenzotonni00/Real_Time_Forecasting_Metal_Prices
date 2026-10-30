function data = remove_nowcasted_edge(data, ids)

missing_lags = ragged_edge_missing_lags(ids);

for jj = 1:numel(ids)
    n_missing = missing_lags(jj);
    if n_missing == 0
        continue
    end

    for vin = 1:size(data,2)
        observed_idx = find(~isnan(data(:,vin,jj)));
        if isempty(observed_idx)
            continue
        end

        n_remove = min(n_missing, numel(observed_idx));
        data(observed_idx(end-n_remove+1:end), vin, jj) = NaN;
    end
end

end
