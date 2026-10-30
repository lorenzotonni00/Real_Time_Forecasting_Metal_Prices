function [x, xlag] = lagML2(X,pmax)

[t, k] = size(X);
x = X;
xlag = nan(t, k * pmax);
for p = 1:pmax
    xl = nan(t,k);
    if p < t
        xl(p+1:end,:) = X(1:t-p,:);
    end
    cols = (p - 1) * k + (1:k);
    xlag(:, cols) = xl;
end

end

