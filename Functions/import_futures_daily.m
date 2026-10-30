function [futures_daily] = import_futures_daily

raw = readtable('futures_daily.xlsx', 'Sheet', 'Foglio1', 'VariableNamingRule', 'preserve');

% Dates from first column (header 'Name' in the Excel file)
dates = raw{:, 1};
if ~isdatetime(dates)
    dates = datetime(dates, 'InputFormat', 'dd/MM/yyyy');
end

metals  = {'Copper',              'Aluminum',               'Nickel',              'Zinc'            };
col_3m  = {'copper_futures_3m',  'aluminum_futures_3m',   'nickel_futures_3m',   'zinc_futures_3m' };
col_15m = {'copper_futures_15m', 'aluminum_futures_15m',  'nickel_futures_15m',  'zinc_futures_15m'};

% Monthly grid: snap daily dates to start-of-month, then take mean within each month
month_key   = dateshift(dates, 'start', 'month');
uniq_months = unique(month_key);
n_months    = numel(uniq_months);

for m_i = 1:numel(metals)
    mn  = metals{m_i};
    v3  = double(raw.(col_3m{m_i}));
    v15 = double(raw.(col_15m{m_i}));

    data_m = NaN(n_months, 2);
    for t = 1:n_months
        idx          = (month_key == uniq_months(t));
        data_m(t, 1) = mean(v3(idx),  'omitnan');
        data_m(t, 2) = mean(v15(idx), 'omitnan');
    end

    futures_daily.(mn).data = data_m;        % col 1 = 3m, col 2 = 15m
    futures_daily.(mn).obs  = uniq_months;   % start-of-month datetimes
    futures_daily.(mn).id   = {'3m', '15m'};
end

end
