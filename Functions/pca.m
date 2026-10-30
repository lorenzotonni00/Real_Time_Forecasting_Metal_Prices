function [pc, A, finaldata]=pca(data,r)

% Standardize data
[finaldata, ~] =standardize(data); 

T=size(finaldata,1); % # of observations

% Estimate Factors and Common Components
Sigma = cov(finaldata);
opts.disp = 0;
[ A, L ] = eigs(Sigma,r,'LM',opts); L = diag(L); % A --> E-Vectors / L --> E-Values 
pc = finaldata*A; % Factors 

end