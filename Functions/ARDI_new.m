function [Yhat, P_ic, factors_stat] = ARDI_new(MACRO, ETM_prices, lags, direct, IC, hor, Pn, K_f, P_custom_ARDI, Y_g, Y_d, X_d, y)

%%

% Custom lag structure
P_custom = P_custom_ARDI*ones(1,  K_f + 1);

[X_d, macro_id] = align_predictor_matrix(X_d, MACRO.id, 'ARDI_new');

% Drop CPI and the forecasted ETM from factor extraction.
drop_predictor = strcmp(macro_id, 'CPIAUCSL') | strcmp(macro_id, ETM_prices.id{y});
X_d(:,drop_predictor) = [];
macro_id(drop_predictor) = [];
MACRO.id = macro_id;

common_length = min([size(Y_g, 1), size(Y_d, 1), size(X_d, 1)]);
if common_length <= hor
    P_ic = P_custom;
    Yhat = mean(Y_g, 'omitnan');
    if isnan(Yhat)
        Yhat = 0;
    end
    factors_stat = struct('factors', [], 'loadings', [], 'st_data', [], 'id', {MACRO.id});
    return
end

Y_g = Y_g(end-common_length+1:end, :);
Y_d = Y_d(end-common_length+1:end, :);
X_d = X_d(end-common_length+1:end, :);

% Estimate Factors
[factors, loadings, st_data] = pca(X_d,10);
factors_stat.factors = factors;
factors_stat.loadings = loadings;
factors_stat.st_data = st_data;
factors_stat.id = MACRO.id;

dimSizes = repmat(Pn, 1, K_f + 1);
Betas = cell(dimSizes);
BICs = NaN(dimSizes);
AICs = NaN(dimSizes);

%==============================================%
%    Bloc 1: Choice of model specification     %
%==============================================%

% =========|| (A) Estimate all possible models ||========%

allIndices = nestedLoops(Pn, K_f + 1, 1, zeros(1, K_f + 1), []);

for ss=1:size(allIndices,1)
    specification = allIndices(ss,:);

            % AR part

            tryP = specification(1); % candidate lag
            if direct == 1
                [XX,XXlag] = lagML2(Y_d(1:end-hor,1),tryP); % Creates the matrix XX and its lag matrix
            elseif direct == 0
                [XX,XXlag] = lagML2(Y_d(1:end-1,1),tryP);
            end
            XX = [XX, XXlag(:,1:end-1)]; 
            XX_y = XX(1:end,:);

            % DI part

            for u = 1:K_f
                if direct == 1
                    [XX,XXlag] = lagML2(factors(1:end-hor,u),specification(1+u)); % Creates the matrix XX and its lag matrix
                elseif direct == 0
                    [XX,XXlag] = lagML2(factors(1:end-1,u),specification(1+u));
                end
                XX = [XX, XXlag(:,1:end-1)];
                eval(sprintf('XX_%d =  XX(1:end,:);', u));
            end

            XXXX = [ones(size(XX,1),1),XX_y];

            for i = 1:K_f
                eval(sprintf('XXXX = [XXXX, XX_%d];', i));
            end

            if direct == 1
                YX = [Y_g(hor+1:end,1),XXXX]; 
            elseif direct == 0
                YX = [Y_g(1+1:end,1),XXXX]; 
            end
            YX = YX(~any(isnan(YX),2),:);  

            % Regression
            beta = YX(:,2:end)\YX(:,1);  % ------> OLS estimator
            SpecificationCell = num2cell(specification);
            Betas{SpecificationCell{:}} = beta; 

            % In-sample fit
            par = size(XXXX,2); 
            ttt = size(YX,1); 

            if par - ttt > 0
                error('Warning: more parameters than observations! Increase sample size')
            end 

            yin = YX(:,2:end)*beta; 
            res = YX(:,1) - yin; 
            sigma2 = res'*res/(ttt-par); 

            % Compute Information Criteria
            BICs(sub2ind(dimSizes, SpecificationCell{:})) = log(sigma2)+ par*log(ttt)/ttt;
            AICs(sub2ind(dimSizes, SpecificationCell{:})) = log(sigma2)+ 2*par/ttt;
end

% =========|| (B) Select best model ||========%

if strcmp("i_criteria",lags)==1
    if Pn == 1 
        P_ic = ones(1,K_f + 1);
    else 
        if strcmp("BIC",IC)==1
            [C,I]   = min(BICs(:));
            coords = cell(1, ndims(BICs)); 
            [coords{:}] = ind2sub(size(BICs), I); 
            P_ic = cell2mat(coords);
        elseif strcmp("AIC",IC)==1
            [C,I]   = min(AICs(:));
            coords = cell(1, ndims(AICs)); 
            [coords{:}] = ind2sub(size(AICs), I); 
            P_ic = cell2mat(coords);
        end
    end
elseif strcmp("manual",lags)==1
    P_ic = P_custom;
end

%===============================================%
%    Bloc 2: Model estimation and forecasting   %
%===============================================%

% =========|| (A) Model Estimation ||========%

if strcmp("manual",lags)==1

    specification = P_ic;

    % AR part

    tryP = specification(1); % candidate lag
    if direct == 1
        [XX,XXlag] = lagML2(Y_d(1:end-hor,1),tryP); % Creates the matrix XX and its lag matrix
    elseif direct == 0
        [XX,XXlag] = lagML2(Y_d(1:end-1,1),tryP);
    end
    XX = [XX, XXlag(:,1:end-1)]; 
    XX_y = XX(1:end,:);

    % DL part

    for u = 1:K_f
        if direct == 1
            [XX,XXlag] = lagML2(factors(1:end-hor,u),specification(1+u)); % Creates the matrix XX and its lag matrix
        elseif direct == 0
            [XX,XXlag] = lagML2(factors(1:end-1,u),specification(1+u));
        end
        XX = [XX, XXlag(:,1:end-1)]; 
        eval(sprintf('XX_%d =  XX(1:end,:);', u));
    end

    XXXX = [ones(size(XX,1),1),XX_y];

    for i = 1:K_f
        eval(sprintf('XXXX = [XXXX, XX_%d];', i)); 
    end

    if direct == 1
        YX = [Y_g(hor+1:end,1),XXXX]; 
    elseif direct == 0
        YX = [Y_g(1+1:end,1),XXXX]; 
    end
    YX = YX(~any(isnan(YX),2),:);  

    % Regression
    beta = YX(:,2:end)\YX(:,1);  % ------> OLS estimator

elseif strcmp("i_criteria",lags)==1
    beta_index = num2cell(P_ic);
    beta = Betas{beta_index{:}};
end

% =========|| (B) Forecasting ||========%

variables = [Y_d, factors(:,1:K_f)];

for f=1:K_f+1
    [out_y,out_ylag] = lagML2(variables(:,f),P_ic(f)-1);
    eval(sprintf('y_%d = [out_y, out_ylag];', f));
end

const = ones(size(variables,1),1);
y = const;

for ff=1:K_f+1
    eval(sprintf('y = [y, y_%d];', ff));
end

lastx = y(end,:);

if direct == 1
    Yhat = lastx*beta;
elseif direct == 0
    error('Insert code for exogenous variables forecast')
    for h = 1:hor
        Yhat = lastx*beta;
        lastx = [1,y_end];
    end
end

end
