% This script constructs the Minnesota prior
%
% See:
% Chan, J.C.C. (2022). Comparing Stochastic Volatility Specifications for 
% Large Bayesian VARs, Journal of Econometrics, forthcoming.

function [beta_Minn,V_Minn,Sig_hat,U_hat] = prior_Minn_new(p,c1,c2,c3,Y, X, tcode_y)
[Tt,n] = size(Y);
k = 1 + n*p;

if tcode_y == 0 || tcode_y == 1
    beta_Minn = [zeros(n,1) 1]'; % variable in levels
elseif tcode_y == 2 || tcode_y == 3
    beta_Minn = [zeros(n,1) 0]'; % variable in first diff
elseif tcode_y == 4 || tcode_y == 5
    beta_Minn = [zeros(n,1) 0]';
end
V_Minn = zeros(k*n,1);
sig2 = zeros(n,1);    
U_hat = zeros(Tt,n);

tmpb = X\Y;
U_hat(:,1) = Y-X*tmpb;
sig2 = mean(U_hat(:,1).^2);

Sig_hat = sig2;
count = 1;
for i=1:n
    for ii=0:k-1
        j = mod(ii,n); % variable index
        if j==0
            j = n;
        end
        l = ceil(ii/n); % lag length        
        if ii==0 % intercept
            V_Minn(count) = c3;
        elseif i==j % own lag
            V_Minn(count) = c1/l^2;
        elseif i~=j % lag of another variable        
            V_Minn(count) = c2*sig2(i)/(l^2*sig2(j));
        end
        count = count + 1;
    end
end

end