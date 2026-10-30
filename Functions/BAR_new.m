function [Yhat, P] = BAR_new(direct, hor, Y_g, Y_d, hmax, ngibbs, nburn, tcode_y)

Yhat = NaN;
P = 1;
Y_g = Y_g(:);
Y_d = Y_d(:);
if isempty(Y_g) || isempty(Y_d)
    return
end

%% =========|| (A) Model Estimation ||========%
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

Y = YX(:,1);
X = YX(:,2:end);
if isempty(Y) || size(YX,1) <= size(X,2) || size(Y_d,1) < P || any(~isfinite(Y_d(end-P+1:end)))
    return
end

n = 1;

c1 = .2^2; c2 = 100;
opt.hyperparam = [c1 c2];

if tcode_y == 0 || tcode_y == 1
    opt.A1prior = ones(1,n);
elseif tcode_y == 2 || tcode_y == 3
    opt.A1prior = zeros(1,n); 
elseif tcode_y == 4 || tcode_y == 5
    opt.A1prior = zeros(1,n); 
end

Tt = size(Y,1);
k = n*P+1;                                     % no. of coeff.s per equation

[A0,VA0,nu0,S0] = prior_NC_new(P,opt,Y,X);

XX = X'*X;
KA = sparse(1:k,1:k,1./VA0) + XX;
Ahat = KA\(sparse(1:k,1:k,VA0)\A0 + X'*Y);
Shat = S0 + A0'*sparse(1:k,1:k,1./VA0)*A0 + Y'*Y ...
    - Ahat'*KA*Ahat;
Shat = (Shat+Shat')/2; 
nuhat = nu0+Tt;

if direct == 1; n_hor = 1; else n_hor = hmax; end
store_ypred = zeros(ngibbs-nburn,n_hor);
store_var  = nan(ngibbs-nburn,n_hor);
for isim = 1:ngibbs
  
    % sample Sig and A  
    Sig = iwishrnd(Shat,nuhat);
    CSig = chol(Sig,'lower');
    A = Ahat + (chol(KA,'lower')'\randn(k,n))*CSig'; 
    
    if isim > nburn
        isave = isim - nburn;
        xtp1 = [1 reshape(Y_d(end:-1:end-P+1,1)',1,n*P)];

        if direct == 1
                EYtp1 = xtp1*A;    
                Ytp1 = EYtp1 + (CSig*randn(n,1))';
                store_ypred(isave,1) = Ytp1;
                store_var(isave,1) = CSig;
        elseif direct == 0
            for tt_=1:hmax
                EYtp1 = xtp1*A;    
                Ytp1 = EYtp1 + (CSig*randn(n,1))';
                xtp1 = [1 Ytp1 xtp1(2:end-n)];
                store_ypred(isave,tt_) = Ytp1;
                store_var(isave,tt_) = CSig;
            end
        end
    end
end

Yhat = squeeze(median(store_ypred,1));


end
