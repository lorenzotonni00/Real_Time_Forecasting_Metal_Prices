function pvalue=test_DM(benchmark,alternative,H,nested_flag, treatment)

if nargin < 5 || isempty(treatment)
    treatment = 0;
end

if nargin < 4 || isempty(nested_flag)
    nested_flag = 0;
end

differential_=benchmark-alternative;

% Trailing NaNs can be introduced by padding shorter OOS arrays to a common
% length. They are not part of the available evaluation sample.
last_valid = find(~isnan(differential_), 1, 'last');
if isempty(last_valid)
    pvalue = NaN;
    return
end
differential_ = differential_(1:last_valid);

if ~all(isnan(differential_))

if treatment == 1
    differential = differential_(~isnan(differential_));
else
    differential = differential_;
end

T=size(differential,1);

if size(differential,1) > H
    var=NeweyWest(differential,H);
else
    var = NaN;
end

tdm=sqrt(T)*mean(differential)/sqrt(var);

if nested_flag == 0
    % Models are not nested, 2-sided test. Compute the genuine two-sided
    % p-value regardless of the sign of tdm (tdm<0 means the benchmark
    % outperforms the alternative).
    pvalue=2*tcdf(-abs(tdm),T);
else
    % Models are nested, 1-sided test
     pvalue=1-tcdf(tdm,T);
end

if isnan(var)
    warning('There are NaNs within Professional Forecasts and D-M test variance cannot be computed')
    pvalue = NaN;
end

else
pvalue = NaN;
end

end
