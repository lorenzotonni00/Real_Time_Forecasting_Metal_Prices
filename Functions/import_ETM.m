function [ETM] = import_ETM


% Import raw data
RAW = readtable('ETM_daily.xlsx','Sheet','Foglio1','VariableNamingRule','preserve');
raw = table2array(RAW(:,2:end));

% Import IDs
id_raw = RAW.Properties.VariableNames;
id_raw(:,1) =[];

% Import dates
dates_raw = table2array(RAW(:,1));        
dates_raw = datetime(dates_raw, 'InputFormat', 'dd/MM/yyyy');

% create month id
anno = year(dates_raw);
mese = month(dates_raw);
index_month = mese + (anno - anno(1)) * 12;

% monthly averages
T = max(index_month) - index_month(1) +1;
raw_monthly = zeros(T, size(raw, 2));
for i = index_month(1):index_month(end)
    single_month = (index_month == i); 
    raw_monthly(i - index_month(1) + 1, :) = mean(raw(single_month, :), 1); 
end

% monthly dates
first_obs = datetime(year(dates_raw(1)), month(dates_raw(1)), 1);
obs_raw_monthly = (first_obs:calmonths(1):dates_raw(end))';

%-----------------------------------------
ETM.data = raw_monthly;
ETM.obs = obs_raw_monthly;
ETM.id = id_raw;
%-----------------------------------------

end