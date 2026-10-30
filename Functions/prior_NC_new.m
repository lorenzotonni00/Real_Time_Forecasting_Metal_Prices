%% This script constructs the natural conjugate prior
%
% See:
% Chan, J.C.C. (2020). Large Bayesian Vector Autoregressions. In: P. Fuleky (Eds),
% Macroeconomic Forecasting in the Era of Big Data, 95-125, Springer, Cham

function [A0,VA0,nu0,S0] = prior_NC_new(p,opt,Y,X)
c1 = opt.hyperparam(1);
c2 = opt.hyperparam(2);

[Tt,n] = size(Y);
k = 1+ n*p;

A1prior = opt.A1prior;

% prior for beta
A1 = diag(A1prior);
A0 = [zeros(n,1) A1 zeros(n,n*(p-1))]';

VA0 = zeros(k,1);

    % construct VA0

    %%

tmpb = X\Y;
sig2 = mean((Y-X*tmpb).^2);
%%

for i=1:k
    l = ceil((i-1)/n);
    idx = mod(i-1,n); 
    if idx==0
        idx = n;
    end
    if i==1 % intercept
        VA0(1) = c2;
    else
        VA0(i) = c1/(l^2*sig2(idx));
    end
end
S0 = diag(sig2);
nu0 = n+3; % degrees of freedom
end