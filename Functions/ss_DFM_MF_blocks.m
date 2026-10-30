function [ss] = ss_DFM_MF_blocks(Xnan,init,opts,blocks)
% =========================================================================
% Pop-up box to choose model settings.
% ---------------------------------------------------------------------------------
% SYNTAX: settings()
% ----------------------------------------------------------------------------------
% OUTPUT:
%		 - sheet: identifier of the country
%        - IDf: frequency
%        - trans: transformation method
%        - method: imputation method
%        - q = number of factors used for imputation
% ----------------------------------------------------------------------------------

[~,N] = size(Xnan);                                                                                                      % size of the panel

if nargin < 4; blocks = true(N,1); end                                                                                   % default: no blocks
if ~isfield(init,"idI"); init.idI = false(N,1); end                                                                      % default: no model for idio
if ~isfield(opts,"method"); opts.method = 2; end                                                                         % spline NaNs
if ~isfield(opts,"k"); opts.k = 3; end                                                                                   % spline of k-th order

%%%%%%%%%%%%%%%%%%%%%%%
%% (1) SETUP OPTIONS %%
%%%%%%%%%%%%%%%%%%%%%%%
q = init.q;                                                                                                              % n. of static factors
p = init.p;                                                                                                              % n. of lags: state equation
n_b = size(blocks,2);                                                                                                    % n. of blocks

M = [2 -1  0  0  0; ...                                                                                                  % M-to-Q restrictions: see [MM03]
     3  0 -1  0  0; ...                                                                                                  % -------------------------------
     2  0  0 -1  0; ...                                                                                                  % -------------------------------
     1  0  0  0 -1];                                                                                                     % -------------------------------

c = zeros(size(M,1),1);                                                                                                  % linear constraints: see [BM14]                                                                      

nc = size(M,2);											                                                                                               % n. of M-to-Q constraints
pp = max(p,nc);                                                                                                          % effective n. of factors: observation equation

idF = init.idF;                                                                                                          % location of frequencies 
idI = init.idI;                                                                                                          % location of AR idiosyncratic components
idiM = find(logical(idF.*idI));                                                                                          % M variables in block b
idiQ = find(logical(~idF.*idI));                                                                                         % Q variables in block b

[X,idn] = spline_NaNs(Xnan,opts);                                                                                        % impute NaNs --> balanced panel

[T,N] = size(X);                                                                                                         % effective sample size

e = X;                                                                                                                   % balanced panel (for residuals)                                                                               
X(idn) = nan; eNaN = X;                                                                                                  % unbalanced panel (for residuals)
idn(1:nc-1,:) = true;                                                                                                    % nan-out first nc obs. due to M-to-Q aggregation scheme

ss.C = []; ss.A = []; ss.Q = []; ss.P00 = [];                                                                            % initialize coefficients

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% (2) STATE-SPACE MODEL %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
for bb=1:n_b                                                                                                             % iterate over blocks
    
    q_b = q(bb);                                                                                                         % n. factors in block b
    
    idM_b = find(logical(idF.*blocks(:,bb)));                                                                            % M variables in block b
    idQ_b = find(logical(~idF.*blocks(:,bb)));                                                                           % Q variables in block b

    %================%
    % (2.1) LOADINGS %
    %================%
    %---------------------%
    % (2.1.1) M variables %
    %---------------------%
    C_b = zeros(N,q_b*pp);                                                                                               % initialize loadings
    
    [v,~] = eigs(cov(e(:,idM_b)), q_b, 'LM');                                                                            % extract eigenvectors
    C_b(idM_b,1:q_b) = v;                                                                                                % eigenvectors = loadings
    f = e(:,idM_b)*v;                                                                                                    % project onto panel of data in block b

    F = []; for ll = 0:max(p+1,nc)-1; F = cat(2, F, f(nc-ll:end-ll,:)); end                                              % lagged factors: max between p (state) and nc (observation)

    M1 = kron(M,eye(q_b));                                                                                               % repeat M-to-Q constraints for each factor q
    c1 = kron(c,zeros(q_b,1));                                                                                           % repeat M-to-Q restrictions for each factor q

    Fobs = F(:,1:q_b*nc);                                                                                                % select factors: observation equation 
    
    %---------------------%
    % (2.1.2) Q variables %
    %---------------------%
    for ii = idQ_b'                                                                                                      % loop over quarterly variables in block b
        
        x_i = eNaN(nc:end,ii);                                                                                           % unbalanced panel: remove first nc entries

        if sum(~isnan(x_i)) < q_b*nc+2; x_i = e(pC:end,ii); end                                                          % use balanced panel if too many NaNs
                                                                  
        Cc = Fobs(~isnan(x_i),:)\x_i(~isnan(x_i));                                                                       % unconstrained loadings: least squares
    
        iFF_i = (Fobs(~isnan(x_i),:)'*Fobs(~isnan(x_i),:))^(-1);                                                         % (F'F)^-1
        Cc = Cc - iFF_i*M1'*((M1*iFF_i*M1')^-1)*(M1*Cc-c1);                                                              % constrained quarterly loadings
    
        C_b(ii,1:q_b*nc) = Cc';                                                                                          % place loadings in output matrix
    end

    Fobs = cat(1, zeros(nc-1,q_b*nc), Fobs);                                                                             % zeros in first pC-1 entries

    e = e - Fobs*C_b';                                                                                                   % update idiosyncratic component
    eNaN = e; eNaN(idn) = nan;                                                                                           % put NaNs back into place

    %======================%
    % (2.2) STATE MATRICES %
    %======================%
    Ft = F(:,1:q_b);                                                                                                     % factors: lag 0
    Ft1 = F(:,q_b+1:q_b*(p+1));                                                                                          % factors: lag 1
    
    A = zeros(q_b*pp,q_b*pp)';                                                                                           % initialize state matrix
    
    A_temp = Ft1\Ft;                                                                                                     % OLS estimation: state matrix, factors
    A(1:q_b,1:q_b*p) = A_temp';                                                                                          % place factor part of state matrix in output matrix
    A(q_b+1:end,1:q_b*(pp-1)) = eye(q_b*(pp-1));                                                                         % companion form
    u = Ft  - Ft1*A_temp;                                                                                                % VAR residuals
    
    Q = zeros(q_b*pp,q_b*pp);                                                                                            % initialize state var-cov matrix, latent shocks
    Q(1:q_b,1:q_b) = cov(u);                                                                                             % latent shocks var-cov matrix
    
    P00 = reshape((eye((q_b*pp)^2)^(-1)-kron(A,A))*Q(:),q_b*pp,q_b*pp);                                                  % state var-cov matrix, factors

    ss.A = blkdiag(ss.A, A);                                                                                             % concatenate blocks over main diagonal
    ss.C = cat(2, ss.C, C_b);                                                                                            % ------------------------------------- 
    ss.P00 = blkdiag(ss.P00, P00);                                                                                       % ------------------------------------- 
    ss.Q = blkdiag(ss.Q, Q);                                                                                             % ------------------------------------- 
end

%===============================%
% (2.3) IDIOSYNCRATIC COMPONENT %
%===============================%
%------------------------------%
% (2.3.1) OBSERVATION EQUATION %
%------------------------------%
R = var(eNaN,"omitmissing");                                                                                             % var-cov idiosyncratic component

rho0 = .1;                                                                                                               % initial state parameter: Q variables, AR idiosyncratic component
sigma_e0 = R(idiQ)/19;                                                                                                   % initial state var-cov: Q variables, AR idiosyncratic component

R(idI) = 10^-2;                                                                                                          % var-cov AR idiosyncratic component, see [OvD23]
ss.R = diag(R);                                                                                                          % var-cov matrix: idiosyncratic component

%------------------------%
% (2.3.2) STATE EQUATION %
%------------------------%
for ii=find(idI)'                                                                                                        % iterate over AR idiosyncratic components 

     if ismember(ii,idiM)                                                                                                % M variables
        %----------------                                                                                                %============ 
        C = zeros(N,1); C(ii,:) = 1;                                                                                     % loadings: 1 

        eNaN_i = eNaN(:,ii);                                                                                             % idiosyncratic component variable ii
        ln = find((1:T)'==cumsum(isnan(eNaN_i)),1,"last");                                                               % remove leading NaNs
        en = find((1:T)'==cumsum(isnan(eNaN_i(end:-1:1))),1,"last");                                                     % remove closing NaNs        
        eNaN_i = e(:,ii);                                                                                                % balanced panel of idiosyncratic components
        eNaN_i(end-en + 1:end) = []; eNaN_i(1:ln) = [];                                                                  % remove leading and closing NaNs

        alpha = eNaN_i(1:end-1)\eNaN_i(2:end);                                                                           % state parameter: AR idiosyncratic components
        sigma_e = cov(eNaN_i(2:end) - alpha*eNaN_i(1:end-1));                                                            % residuals variance: AR idiosyncratic components
        P00_e = diag(1./diag(1-alpha^2))*sigma_e;                                                                        % state variance: AR idiosyncratic components

     elseif ismember(ii,idiQ)                                                                                            % Q variables 
        %--------------------                                                                                            %============ 
        C = zeros(N,nc); C(ii,:) = [1 2 3 2 1];                                                                          % loadings: [1 2 3 2 1] 

        alpha = cat(1,[rho0 zeros(1,nc-1)],[eye(nc-1),zeros(nc-1,1)]);                                                   % state parameter: AR idiosyncratic components
        sigma_e = blkdiag(sigma_e0,zeros(nc-1));                                                                         % residuals variance: AR idiosyncratic components
        P00_e = reshape((eye(nc^2)-kron(alpha,alpha))*sigma_e(:),nc,nc);                                                 % state variance: AR idiosyncratic components
     end

     ss.C = cat(2,ss.C,C);                                                                                               % concatenate blocks over main diagonal
     ss.A = blkdiag(ss.A,alpha);                                                                                         % ------------------------------------- 
     ss.Q = blkdiag(ss.Q,sigma_e);                                                                                       % ------------------------------------- 
     ss.P00 = blkdiag(ss.P00, P00_e);                                                                                    % ------------------------------------- 
end

ss.Z00 = zeros(size(ss.A,1),1);                                                                                          % initial state estimates (== 0, mean)


end
