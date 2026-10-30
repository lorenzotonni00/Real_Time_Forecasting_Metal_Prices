function [Yhat, P_ic, factors_X, factors_stat] = FAVAR_new(MACRO, lags, direct, IC, hor, Pn, K_f, P_custom_VAR,  Y_g_sel, Y_g_var, X_d_sel, X_d, y, regressors_var_temp)
                          
Betas = cell(Pn,1);
BICs = NaN(Pn,1);
AICs = NaN(Pn,1);

[X_d, macro_id] = align_predictor_matrix(X_d, MACRO.id, 'FAVAR_new');
[Y_g_var, ~] = align_predictor_matrix(Y_g_var, macro_id, 'FAVAR_new');

% Drop CPI and all endogenous VAR variables from factor extraction.
drop_predictor = strcmp(macro_id, 'CPIAUCSL') | ismember(macro_id, regressors_var_temp);
X_d(:,drop_predictor) = [];
Y_g_var(:,drop_predictor) = [];
macro_id(drop_predictor) = [];
MACRO.id = macro_id;

common_length = min([size(Y_g_sel, 1), size(Y_g_var, 1), size(X_d_sel, 1), size(X_d, 1)]);
if common_length <= hor
    P_ic = P_custom_VAR;
    Yhat = mean(Y_g_sel, 1, 'omitnan');
    Yhat(isnan(Yhat)) = 0;
    factors_X = [];
    factors_stat = struct('factors', [], 'loadings', [], 'st_data', [], 'id', {MACRO.id});
    return
end

Y_g_sel = Y_g_sel(end-common_length+1:end, :);
Y_g_var = Y_g_var(end-common_length+1:end, :);
X_d_sel = X_d_sel(end-common_length+1:end, :);
X_d = X_d(end-common_length+1:end, :);

% Estimate Factors
[factors_X, loadings, st_data] = pca(X_d,10);
factors_Y = pca(Y_g_var,10);

factors_stat.factors = factors_X;
factors_stat.loadings = loadings;
factors_stat.st_data = st_data;
factors_stat.id = MACRO.id;

% Update Endogenous Variables
Y_g_sel = [Y_g_sel, factors_Y(:,1:K_f)];
X_d_sel = [X_d_sel, factors_X(:,1:K_f)];

%=============================================%
%    Bloc 1: Choice of model specification    %
%=============================================%

% =========|| (A) Estimate all possible models ||========%

n = size(X_d_sel,2);

for ss=1:Pn

            tryP = ss; % candidate lag

            % Build Regressors Matrix
            for u = 1:size(X_d_sel,2)
                if direct == 1
                    [XX,XXlag] = lagML2(X_d_sel(1:end-hor,u),tryP); % Creates the matrix XX and its lag matrix
                elseif direct == 0
                    [XX,XXlag] = lagML2(X_d_sel(1:end-1,u),tryP);
                end
                XX = [XX, XXlag(:,1:end-1)];
                eval(sprintf('XX_%d =  XX(1:end,:);', u));
            end

            XXXX = [ones(size(XX,1),1)];

            for i = 1:size(X_d_sel,2)
                eval(sprintf('XXXX = [XXXX, XX_%d];', i));
            end

            % Build Dependent Matrix
            if direct == 1
                YX = [Y_g_sel(hor+1:end,:),XXXX]; 
            elseif direct == 0
                YX = [Y_g_sel(1+1:end,:),XXXX]; 
            end
            YX = YX(~any(isnan(YX),2),:);  

            % Regression
            %  pi_hat=(YX(:,n+1:end)'*YX(:,n+1:end))\YX(:,n+1:end)'*YX(:,1:n); % Check 
            beta = YX(:,n+1:end)\YX(:,1:n);  % ------> OLS estimator
            Betas{ss,1} = beta; 

            % In-sample fit
            par = size(XXXX,2)*n;
            ttt = size(YX,1);

            if par - ttt > 0
                error('Warning: more parameters than observations in the VAR model! Increase sample size')
            end 

            Yfit=YX(:,n+1:end)*beta; %Fitted value of Y
            err=YX(:,1:n)-Yfit; %Residuals
            sigma2 = err'*err/(ttt-par); % var-cov

            % Compute Information Criteria
            BICs(ss,1) = log(det(sigma2)) + par*log(ttt)/ttt;
            AICs(ss,1) = log(det(sigma2)) + 2*par/ttt;

end

% =========|| (B) Select best model ||========%

if strcmp("i_criteria",lags)==1
    if Pn == 1 
        P_ic = 1;
    else 
        if strcmp("BIC",IC)==1
            [C,I]   = min(BICs(:));
            P_ic = I;
        elseif strcmp("AIC",IC)==1
            [C,I]   = min(AICs(:));
            P_ic = I;
        end
    end
elseif strcmp("manual",lags)==1
    P_ic = P_custom_VAR;
end

%===============================================%
%    Bloc 2: Model estimation and forecasting   %
%===============================================%

% =========|| (A) Model Estimation ||========%

if strcmp("manual",lags)==1

    specification = P_ic; tryP = specification;

    % Build Regressors Matrix
    for u = 1:size(X_d_sel,2)
        if direct == 1
            [XX,XXlag] = lagML2(X_d_sel(1:end-hor,u),tryP); % Creates the matrix XX and its lag matrix
        elseif direct == 0
            [XX,XXlag] = lagML2(X_d_sel(1:end-1,u),tryP);
        end
        XX = [XX, XXlag(:,1:end-1)];
        eval(sprintf('XX_%d =  XX(1:end,:);', u));
    end

    XXXX = [ones(size(XX,1),1)];

    for i = 1:size(X_d_sel,2)
        eval(sprintf('XXXX = [XXXX, XX_%d];', i));
    end

    % Build Dependent Matrix
    if direct == 1
        YX = [Y_g_sel(hor+1:end,:),XXXX]; 
    elseif direct == 0
        YX = [Y_g_sel(1+1:end,:),XXXX]; 
    end
    YX = YX(~any(isnan(YX),2),:);  

    % Regression
    %  pi_hat=(YX(:,n+1:end)'*YX(:,n+1:end))\YX(:,n+1:end)'*YX(:,1:n); % Check 
    beta = YX(:,n+1:end)\YX(:,1:n);  % ------> OLS estimator

    if par - ttt > 0
        error('Warning: more parameters than observations in the VAR model! Increase sample size')
    end 

elseif strcmp("i_criteria",lags)==1
    beta_index = P_ic;
    beta = Betas{beta_index};
end

% =========|| (B) Forecasting ||========%

variables = X_d_sel;

for f=1:size(X_d_sel,2)
    [out_y,out_ylag] = lagML2(variables(:,f),P_ic - 1);
    eval(sprintf('y_%d = [out_y, out_ylag];', f));
end

const = ones(size(variables,1),1);
y= const;

for ff=1:size(X_d_sel,2)
    eval(sprintf('y = [y, y_%d];', ff));
end

lastx = y(end,:);

if direct == 1
    Yhat = lastx*beta;
elseif direct == 0
    error('missing code for the iterative version')
    for h = 1:hor
        Yhat = lastx*beta;
        lastx = [1,y_end];
    end
end

%%

end
