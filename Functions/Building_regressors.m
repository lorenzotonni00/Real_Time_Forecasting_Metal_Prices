function [Target_lags] = Building_regressors(Y,tcode)

n_vin = size(Y,2);

        if tcode == 0
            Target_lags = Y;
        elseif tcode == 1
            Target_lags = log(Y);
        elseif tcode == 2  
            Target_lags = diff(Y);
        elseif tcode == 3
            Target_lags = diff(log(Y));
        elseif tcode == 4
            Target_lags = diff(Y,2);
        elseif tcode == 5
            Target_lags = diff(log(Y),2);
        end

end

