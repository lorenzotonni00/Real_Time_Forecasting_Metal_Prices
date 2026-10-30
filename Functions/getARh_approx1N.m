% This function approximates the SV model using a linear Gaussian state 
% space model where the log chi^2 errors are modeled as N(-1.27,4.94)
%
% See:
% Chan, J.C.C. (2022). Comparing Stochastic Volatility Specifications for 
% Large Bayesian VARs, Journal of Econometrics, forthcoming.

function h_hat = getARh_approx1N(s2i,mu,phi,sig2)
    ystar = log(s2i); % log residuals
    T = length(s2i);
    Hrhoh = speye(T) - phi*sparse(2:T,1:(T-1),ones(1,T-1),T,T);
    HiSH = Hrhoh'*sparse(1:T,1:T,[1-phi^2, ones(1,T-1)])*Hrhoh;
    Kh = HiSH/sig2 + speye(T)/4.94;
    h_hat = Kh\(mu/sig2*HiSH*ones(T,1) + (ystar+1.27)/4.94);
end