function [Yhat, P_ic] = AR_new(lags, direct, IC, hor, Pn, P_AR, Y_g, Y_d)

Yhat = NaN;
P_ic = NaN;
Y_g = Y_g(:);
Y_d = Y_d(:);

if isempty(Y_g) || isempty(Y_d)
    if strcmp("manual",lags)==1
        P_ic = P_AR;
    end
    return
end

Betas = cell(Pn,1);
BICs = NaN(Pn,1);
AICs = NaN(Pn,1);
sigma2 = NaN(Pn,1);

%========================================================%
%    Bloc 1: Choice of model specification               %
%========================================================%

% =========|| (A) Estimate all possible models ||========%

for p = 1:Pn                                                       
            tryP = p; % candidate lag
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

            par = size(XXXX,2); 
            ttt = size(YX,1); 
            if ttt <= par
                continue
            end

            % Regression
            beta = YX(:,2:end)\YX(:,1);  % ------> OLS estimator
            Betas{p,1} = beta; 

            % In-sample fit
            yin = YX(:,2:end)*beta; 
            res = YX(:,1) - yin;
            sigma2(p,1) = res'*res/(ttt-par);
            if ~isfinite(sigma2(p,1)) || sigma2(p,1) <= 0
                continue
            end

            % Compute Information Criteria
            BICs(p,1) = log(sigma2(p,1))+ par*log(ttt)/ttt;
            AICs(p,1) = log(sigma2(p,1))+ 2*par/ttt;

end

% =========|| (B) Select best model ||========%

if strcmp("i_criteria",lags)==1
    if Pn == 1   
        P_ic = 1; 
    else  
        if strcmp("BIC",IC)==1
            valid_criteria = isfinite(BICs) & ~cellfun(@isempty, Betas);
            if ~any(valid_criteria)
                return
            end
            valid_idx = find(valid_criteria);
            [~,I] = min(BICs(valid_idx)); 
            P_ic = valid_idx(I);           
        elseif strcmp("AIC",IC)==1
            valid_criteria = isfinite(AICs) & ~cellfun(@isempty, Betas);
            if ~any(valid_criteria)
                return
            end
            valid_idx = find(valid_criteria);
            [~,I] = min(AICs(valid_idx));
            P_ic = valid_idx(I);
        end
    end
elseif strcmp("manual",lags)==1
    P_ic = P_AR;
end

%===============================================%
%    Bloc 3: Model estimation and forecasting   %
%===============================================%

% =========|| (A) Model Estimation ||========%

if strcmp("manual",lags)==1

    tryP = P_ic; % candidate lag
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
    par = size(XXXX,2);
    if size(YX,1) <= par
        return
    end
    
    % Regression
    beta = YX(:,2:end)\YX(:,1);  % ------> OLS estimator

elseif strcmp("i_criteria",lags)==1
    beta = Betas{P_ic};
end

if isempty(beta) || any(~isfinite(beta))
    return
end

% =========|| (B) Forecasting ||========%

[y,ylag] = lagML2(Y_d,P_ic);    
y = [y(:,1),ylag(:,1:end-1)];
if isempty(y)
    return
end
y_end = y(end,:); 
lastx = [1,y_end]; 

if direct == 1
    Yhat = lastx*beta; % Forecast
elseif direct == 0
    for h = 1:hor
    Yhat = lastx*beta;
    y_end = [Yhat, y_end(1,1:end-1)];
    lastx = [1,y_end];
    end
end

end
