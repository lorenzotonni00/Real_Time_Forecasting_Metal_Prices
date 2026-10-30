function [Target] = Building_target(Y,tcode,type,h)

n_vin = size(Y,2);

switch type

    % Horizon-h growth rates
     case "SW"
        if tcode == 0 % no transformation
            Target = Y; 
        elseif tcode == 1 % log-level
            Target = log(Y);
        elseif tcode == 2  % first difference
            Target = (Y(h+1:end,:)-Y(1:end-h,:));
        elseif tcode == 3  % first log-difference
            Target = (log(Y(h+1:end,:))-log(Y(1:end-h,:)));
        elseif tcode == 4 % second difference
            Yg = (Y(h+1:end,:)-Y(1:end-h,:));
            Target = Yg(2:end,:)-h*(Y(1+1:end-h,:) - Y(1:end-h-1,:));   
        elseif tcode == 5 % second log-difference
            Yg = (log(Y(h+1:end,:))-log(Y(1:end-h,:)));
            Target = Yg(2:end,:)-h*(log(Y(1+1:end-h,:)) - log(Y(1:end-h-1,:))); 
        end
        
    case "SinglePeriod" % Growth rates with respect to previous period
        if tcode == 0
            Target = Y;
        elseif tcode == 1
            Target = log(Y);
        elseif tcode == 2
            Target = diff(Y);
        elseif tcode == 3
            Target = diff(log(Y));
        elseif tcode == 4
            Target = diff(Y,2);
        elseif tcode == 5
            Target = diff(log(Y),2);
        end
end


end