function [Yhat, P] = BAR_SV_new(direct, hor, Y_g, Y_d, hmax, ngibbs, nburn, tcode_y)

Yhat = NaN;
P = 1;
Y_g = Y_g(:);
Y_d = Y_d(:);
if isempty(Y_g) || isempty(Y_d)
    return
end

%% =========|| (A) Model Estimation ||======== %%
tryP = P; % candidate lag
if direct == 1
    [XX,XXlag] = lagML2(Y_d(1:end-hor,1),tryP); % Creates the matrix XX and its lag matrix
elseif direct == 0
    [XX,XXlag] = lagML2(Y_d(1:end-1,1),tryP);
end

XX = [XX, XXlag(:,1:end-1)]; 
XX = XX(1:end,:);

XXXX = [ones(size(XX,1),1),XX];
if direct == 1
    YX = [Y_g(hor+1:end,1),XXXX];  
elseif direct == 0
    YX = [Y_g(1+1:end,1),XXXX]; 
end
YX = YX(~any(isnan(YX),2),:);  

n = 1;
k_beta = n*(n-1)/2;       % dimension of B0. B0 has 1 on main diag, zero above and kb elements below
k_alp = n^2*P + n;        % dimension of A: coeff mean eq.
k = k_alp/n;       

Y = YX(:,1);
X = YX(:,2:end);
if isempty(Y) || size(YX,1) <= size(X,2) || size(Y_d,1) < P || any(~isfinite(Y_d(end-P+1:end)))
    return
end

T = size(Y,1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% priors
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
kappa1 = .2^2; % prior  variance own lags
kappa2 = (.2^2)^2; % prior variance  cross lags
kappa3 = 100; % prior variance intercept
kappa4 = .2^2; % prior variance B0 

[Hyper.alp0,Hyper.Valp,sig2_hat] = prior_Minn_new(P,kappa1,kappa2,kappa3,Y, X, tcode_y);
[Hyper.beta0,Hyper.Vbeta] = prior_B0_new(Y,X,kappa4);
Hyper.c0 = [1 1/.2^2; 1 1/.2^2; 1 1]; % parameters gamma prior for hyperparam k1,k2,k4 for A and b b
Hyper.nuh = 3*ones(n,1); 
Hyper.Sh = .1*(Hyper.nuh-1);
Hyper.mu0 = zeros(n,1); % intercept SV
Hyper.Vmu = 100*ones(n,1);
Hyper.phi0 = .98*ones(n,1); % AR param SV
Hyper.Vphi = .05^2*ones(n,1);     

% initalize storage

% Store objects

if direct == 1; n_hor = 1; else n_hor = hmax; end
store_ypred = zeros(ngibbs-nburn,n_hor);
store_var  = nan(ngibbs-nburn,n_hor);


count_phi = zeros(n,1); %

%%%%%%%%%%%%%%%%%%%%
% initialize the Markov chain
%%%%%%%%%%%%%%%%%%%%

mu = log(sig2_hat);
sig2 = 1./gamrnd(Hyper.nuh,1./Hyper.Sh);
phi = Hyper.phi0;
A = zeros(k,n);
h = zeros(T,n);
XX = X'*X;

iValpi = sparse(1:k,1:k,1./Hyper.Valp((0)*k+1:k));
A(:,1) = (XX + iValpi)\(X'*Y(:,1));
s2i = (Y(:,1) - X*A(:,1)).^2;
mu = mean(log(s2i));
h(:,1) = getARh_approx1N(s2i,mu,phi,sig2);    

alp = reshape(A,k_alp,1);
beta = zeros(k_beta,1);
B0_id = nonzeros(tril(reshape(1:n^2,n,n),-1)');
B0 = eye(n);
[C_alp,idx_kappa1,idx_kappa2] = get_C_original(n,P,sig2_hat);
C_beta = Hyper.Vbeta/kappa4; % the constant part of Vbeta

%%%%%%%%%%%%%%%%%%%%
% MCMC starts here
%%%%%%%%%%%%%%%%%%%%

for isim = 1:ngibbs
    %%%%%%%%%%%%%%%%%%%%
    % sample alp: VAR coef
    %%%%%%%%%%%%%%%%%%%%
    [~,Hyper.Valp] = prior_Minn_new(P,kappa1,kappa2,kappa3,Y, X, tcode_y);
    sqrt_exph = exp(h/2);
    for ii = 1:n        
        A(:,ii) = 0;
        Lambda = vec(sqrt_exph(:,ii:n));
        yi = vec((Y-X*A)*B0(ii:n,:)')./Lambda;    
        Wi = kron(B0(ii:n,ii),X)./Lambda;        
        iValpi = sparse(1:k,1:k,1./Hyper.Valp((ii-1)*k+1:ii*k));
        alpi0 = Hyper.alp0((ii-1)*k+1:ii*k);
        Kalpi = iValpi + Wi'*Wi;
        CKalpi = chol(Kalpi,'lower');        
        alpi_hat = (CKalpi')\(CKalpi\(iValpi*alpi0 + Wi'*yi));        
        alpi = alpi_hat + CKalpi'\randn(k,1);
        A(:,ii) = alpi;        % var coef
    end
    alp = reshape(A,k_alp,1);
    
    %%%%%%%%%%%%%%%%%%%%
    % sample beta: B0
    %%%%%%%%%%%%%%%%%%%%
    [~,Hyper.Vbeta] = prior_B0_new(Y,X,kappa4);
    E = Y - X*A;  % residuals 
    count_beta = 0;
    for ii=2:n
        X_betai = -E(:,1:ii-1);   
        iD = sparse(1:T,1:T,exp(-h(:,ii)));
        iVbetai = sparse(1:ii-1,1:ii-1,1./Hyper.Vbeta(count_beta+1:count_beta+ii-1));         
        Kbetai = iVbetai + X_betai'*iD*X_betai;
        betai_hat = Kbetai\(X_betai'*iD*E(:,ii));
        betai = betai_hat + chol(Kbetai,'lower')'\randn(ii-1,1);
        beta(count_beta+1:count_beta+ii-1) = betai;        
        count_beta = count_beta + ii-1;
    end
    
    %%%%%%%%%%%%%%%%%%%%
    % sample h
    %%%%%%%%%%%%%%%%%%%%
    B0(B0_id) = beta;    
    B0E= E*B0';
    for ii=1:n
        ystar = log(B0E(:,ii).^2 + .0001);
        h(:,ii) = sample_SV(ystar,h(:,ii),mu(ii),phi(ii),sig2(ii)); 
    end    

    %%%%%%%%%%%%%%%%%%%%
    % sample mu, phi and sig2; sv param
    %%%%%%%%%%%%%%%%%%%%
    [mu,phi,sig2,flag_phi] = sample_SVpara(h,mu,phi,Hyper);
    count_phi = count_phi + flag_phi;   
    
    %%%%%%%%%%%%%%%%%%%%
    % sample kappa1, kappa2 and kappa4
    %%%%%%%%%%%%%%%%%%%%
    tmpc4 = sum(beta.^2./C_beta);
    kappa4 = gigrnd(Hyper.c0(3,1)-n*(n-1)/4,2*Hyper.c0(3,2),tmpc4,1);

        tmpc1 = sum(alp(idx_kappa1).^2./C_alp(idx_kappa1));
        tmpc2 = sum(alp(idx_kappa2).^2./C_alp(idx_kappa2));
        kappa1 = gigrnd(Hyper.c0(1,1)-n*P/2,2*Hyper.c0(1,2),tmpc1,1);
        kappa2 = gigrnd(Hyper.c0(2,1)-(n-1)*n*P/2,2*Hyper.c0(2,2),tmpc2,1);         

    
    
    if isim > nburn    
        isave = isim-nburn;         
   
        hT = h(end,:)';
        xtp1 = [1 reshape(Y_d(end:-1:end-P+1,1)',1,n*P)];

        if direct == 1
                EYtp1 = xtp1*A;
                hT=mu+phi.*(hT-mu)+(randn(1,n)*diag(sqrt(sig2)))'; % nx1
                DT05 = diag(exp(hT/2)); % nxn
                ETtilde = (randn(1,n)*DT05)'; %
                ET = (B0)\ETtilde; % nx1

                Ytp1 = EYtp1 + ET';
                store_ypred(isave,1) = Ytp1;
                store_var(isave,1) = DT05;
        elseif direct == 0
            for tt_=1:hmax
                EYtp1 = xtp1*A; 
                hT=mu+phi.*(hT-mu)+(randn(1,n)*diag(sqrt(sig2)))'; % nx1
                DT05 = diag(exp(hT/2)); % nxn
                ETtilde = (randn(1,n)*DT05)'; %
                ET = (B0)\ETtilde; % nx1

                Ytp1 = EYtp1 + ET';                
                xtp1 = [1 Ytp1 xtp1(2:end-n)];
                store_ypred(isave,tt_) = Ytp1;
                store_var(isave,tt_) = DT05;
            end
        end


    end
end

Yhat = squeeze(median(store_ypred,1)); % hmax x 1if numel(opt.Index)<n


end
