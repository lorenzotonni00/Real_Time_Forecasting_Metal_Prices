function data = use_final_vintage_with_rt_mask(data)

availability_mask = ~isnan(data);
final_vintage = data(:,end,:);

data = repmat(final_vintage, 1, size(data,2), 1);
data(~availability_mask) = NaN;

end
