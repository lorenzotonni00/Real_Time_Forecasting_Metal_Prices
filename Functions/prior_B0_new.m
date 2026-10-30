% This function constructs the prior for the impact matrix B0
%
% See:
% Chan, J.C.C. (2022). Comparing Stochastic Volatility Specifications for 
% Large Bayesian VARs, Journal of Econometrics, forthcoming.

function [beta0,Vbeta] = prior_B0_new(Y,X,kappa)
[T,n] = size(Y);
k_beta = n*(n-1)/2;
beta0 = zeros(k_beta,1);
Vbeta = zeros(k_beta,1);

sig2 = zeros(n,1);    
U_hat = zeros(T,n);
tmpb = X\Y;
U_hat(:,1) = Y-X*tmpb;
sig2 = mean(U_hat(:,1).^2);
count_beta = 0;

for i = 2:n
    Vbeta(count_beta+1:count_beta+i-1) = kappa*repmat(sig2(i),i-1,1)./sig2(1:i-1);
    count_beta = count_beta + i-1;
end
end