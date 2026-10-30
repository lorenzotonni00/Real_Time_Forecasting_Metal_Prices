function [X,idn] = spline_NaNs(X,opts)
% =================================================================================
% Treat missing values across cross-sectional units in a T x N panel of data
% ---------------------------------------------------------------------------------
% SYNTAX: spline_NaNs(X,opts)
% where:  
%      - X: T x N matrix of data containing missing values (NaNs)
%      - opts: structure containing
%            - method = how to treat missing values
%                1: only remove leading/closing NaNs (default)
%                2: replace all missing values after removing leading/closing NaNs 
%                3: replace all missing values
%            - k = regulates the dynamics within the filtering procedure used to 
%                  replace missing values (see built-in function filter())
%                  (default is k=3)
%            - s = share of missing values along the cross-section to deem NaNs as
%                  leading/closing (default is 80\%, i.e. s = .8)
% ---------------------------------------------------------------------------------
% OUTPUT: 
%								X = T x N matrix of data with treated missing values
%        idn = T x N logical indicator for missing values in X
% ---------------------------------------------------------------------------------
% REFERENCES: 
%  
% 1. Banbura, M., Giannone, D., and Reichlin, L. (2010). Nowcasting. 
%    Oxford Handbook on Economic Forecasting                                [BGR10]         
% ---------------------------------------------------------------------------------


if nargin<2||~isfield(opts,"method"); opts.method = 1; end                                                               % default: only remove leading/closing NaNs    
if ~isfield(opts,"k"); opts.k = 3; end                                                                                   % default: k = 3 
if ~isfield(opts,"s"); opts.s = .8; end                                                                                  % default: >80% NaNs --> remove row

[T,N] = size(X);                                                                                                         % size of the panel

idn = isnan(X);                                                                                                          % locate missing values

if opts.method < 3                                                                                                       % METHODS 1-2
   %----------                                                                                                           %============
   loc = (sum(idn,2)>opts.s*N);                                                                                          % locate rows with more than 100*s\% NaNs
   Lnan = (cumsum(loc)==(1:T)');                                                                                         % locate leading NaNs
   Enan = flipud(cumsum(loc(end:-1:1))==(1:T)');                                                                         % locate closing NaNs
   X(Lnan|Enan,:) = [];                                                                                                  % remove leading/closing NaNs
   idn = isnan(X);                                                                                                       % update location missing values
end

if opts.method > 1                                                                                                       % METHODS 2-3
   %----------                                                                                                           %============
   for nn = 1:N  
       x_n = X(:,nn);                                                                                                    % locate series nn
       t1 = find(~isnan(x_n),1,"first");                                                                                 % first non-NaN entry 
       t2 = find(~isnan(x_n),1,"last");                                                                                  % last non-NaN entry
       x_n(t1:t2) = spline(find(~isnan(x_n)),x_n(~isnan(x_n)),(t1:t2)');                                                 % spline without missing valus
       idn_nn = isnan(x_n);                                                                                              % update NaNs location 
       x_n(idn_nn) = median(x_n,"omitmissing");                                                                          % replace NaNs with median of non-NaNs
       weights = ones(2*opts.k+1,1)/(2*opts.k+1);                                                                        % weights for transfer function       
       temp = [x_n(1)*ones(opts.k,1); x_n ; x_n(end)*ones(opts.k,1)];                                                    % augment data --> no information loss
       x_MA = filter(weights, 1, temp);                                                                                  % filter data 
       x_MA = x_MA(2*opts.k+1:end);                                                                                      % remove extra initial data
       x_n(idn_nn) = x_MA(idn_nn);                                                                                       % replace NaNs with filtered data 
       X(:,nn) = x_n;                                                                                                    % series with imputed NaNs
   end
end


end




