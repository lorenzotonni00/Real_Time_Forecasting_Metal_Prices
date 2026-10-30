function [PREDICTORS, ETM, futures] = balance_forecast(PREDICTORS_lev_nowcasted, ETM, futures)

%% Find first and last common obs
prima_predictors = PREDICTORS_lev_nowcasted.RW.obs(1);
ultima_predictors = PREDICTORS_lev_nowcasted.RW.obs(end);

prima_ETM = ETM.obs(1);
ultima_ETM = ETM.obs(end);

first = max(prima_predictors, prima_ETM);
last = min(ultima_predictors, ultima_ETM);

%% Level first observation

pos_first_pred = find(PREDICTORS_lev_nowcasted.RW.obs == first);
pos_first_ETM = find(ETM.obs == first);
pos_first_futures = find(futures.Copper.obs == first);

% Predictors
PREDICTORS_lev_nowcasted.RW.data(1:pos_first_pred-1,:,:) = [];
PREDICTORS_lev_nowcasted.RW.obs(1:pos_first_pred-1,:,:) = [];
PREDICTORS_lev_nowcasted.SA.data(1:pos_first_pred-1,:,:) = [];
PREDICTORS_lev_nowcasted.SA.obs(1:pos_first_pred-1,:,:) = [];
PREDICTORS_lev_nowcasted.AR_p.data(1:pos_first_pred-1,:,:) = [];
PREDICTORS_lev_nowcasted.AR_p.obs(1:pos_first_pred-1,:,:) = [];
PREDICTORS_lev_nowcasted.AR_IC.data(1:pos_first_pred-1,:,:) = [];
PREDICTORS_lev_nowcasted.AR_IC.obs(1:pos_first_pred-1,:,:) = [];
PREDICTORS_lev_nowcasted.BAR.data(1:pos_first_pred-1,:,:) = [];
PREDICTORS_lev_nowcasted.BAR.obs(1:pos_first_pred-1,:,:) = [];
PREDICTORS_lev_nowcasted.BAR_SV.data(1:pos_first_pred-1,:,:) = [];
PREDICTORS_lev_nowcasted.BAR_SV.obs(1:pos_first_pred-1,:,:) = [];
PREDICTORS_lev_nowcasted.BAR_SVo.data(1:pos_first_pred-1,:,:) = [];
PREDICTORS_lev_nowcasted.BAR_SVo.obs(1:pos_first_pred-1,:,:) = [];

% ETMs
ETM.data(1:pos_first_ETM-1,:,:) = [];
ETM.obs(1:pos_first_ETM-1,:,:) = [];

% Futures
futures.Copper.data(1:pos_first_futures-1,:,:) = [];
futures.Copper.obs(1:pos_first_futures-1,:,:) = [];

futures.Aluminum.data(1:pos_first_futures-1,:,:) = [];
futures.Aluminum.obs(1:pos_first_futures-1,:,:) = [];

futures.Nickel.data(1:pos_first_futures-1,:,:) = [];
futures.Nickel.obs(1:pos_first_futures-1,:,:) = [];

futures.Zinc.data(1:pos_first_futures-1,:,:) = [];
futures.Zinc.obs(1:pos_first_futures-1,:,:) = [];

%% Level last observation

pos_last_pred = find(PREDICTORS_lev_nowcasted.RW.obs == last);
pos_last_ETM = find(ETM.obs == last);
pos_last_futures = find(futures.Copper.obs == last);

% Predictors
PREDICTORS_lev_nowcasted.RW.data(pos_last_pred+1:end,:,:) = [];
PREDICTORS_lev_nowcasted.RW.obs(pos_last_pred+1:end,:,:) = [];
PREDICTORS_lev_nowcasted.SA.data(pos_last_pred+1:end,:,:) = [];
PREDICTORS_lev_nowcasted.SA.obs(pos_last_pred+1:end,:,:) = [];
PREDICTORS_lev_nowcasted.AR_p.data(pos_last_pred+1:end,:,:) = [];
PREDICTORS_lev_nowcasted.AR_p.obs(pos_last_pred+1:end,:,:) = [];
PREDICTORS_lev_nowcasted.AR_IC.data(pos_last_pred+1:end,:,:) = [];
PREDICTORS_lev_nowcasted.AR_IC.obs(pos_last_pred+1:end,:,:) = [];
PREDICTORS_lev_nowcasted.BAR.data(pos_last_pred+1:end,:,:) = [];
PREDICTORS_lev_nowcasted.BAR.obs(pos_last_pred+1:end,:,:) = [];
PREDICTORS_lev_nowcasted.BAR_SV.data(pos_last_pred+1:end,:,:) = [];
PREDICTORS_lev_nowcasted.BAR_SV.obs(pos_last_pred+1:end,:,:) = [];
PREDICTORS_lev_nowcasted.BAR_SVo.data(pos_last_pred+1:end,:,:) = [];
PREDICTORS_lev_nowcasted.BAR_SVo.obs(pos_last_pred+1:end,:,:) = [];

% ETMs
ETM.data(pos_last_ETM+1:end,:,:) = [];
ETM.obs(pos_last_ETM+1:end,:,:) = [];

% Futures
futures.Copper.data(pos_last_futures+1:end,:,:) = [];
futures.Copper.obs(pos_last_futures+1:end,:,:) = [];
futures.Copper.data = futures.Copper.data';
futures.Copper.obs = futures.Copper.obs';

futures.Aluminum.data(pos_last_futures+1:end,:,:) = [];
futures.Aluminum.obs(pos_last_futures+1:end,:,:) = [];
futures.Aluminum.data = futures.Aluminum.data';
futures.Aluminum.obs = futures.Aluminum.obs';

futures.Nickel.data(pos_last_futures+1:end,:,:) = [];
futures.Nickel.obs(pos_last_futures+1:end,:,:) = [];
futures.Nickel.data = futures.Nickel.data';
futures.Nickel.obs = futures.Nickel.obs';

futures.Zinc.data(pos_last_futures+1:end,:,:) = [];
futures.Zinc.obs(pos_last_futures+1:end,:,:) = [];
futures.Zinc.data = futures.Zinc.data';
futures.Zinc.obs = futures.Zinc.obs';

% Pre-store
PREDICTORS = struct();
PREDICTORS.RW.id = struct();
PREDICTORS.SA.id = struct();
PREDICTORS.AR_p.id = struct();
PREDICTORS.AR_IC.id = struct();
PREDICTORS.BAR.id = struct();
PREDICTORS.BAR_SV.id = struct();
PREDICTORS.BAR_SVo.id = struct();

% Reshape
PREDICTORS.RW.id = PREDICTORS_lev_nowcasted.RW.id;
PREDICTORS.SA.id = PREDICTORS_lev_nowcasted.SA.id;
PREDICTORS.AR_p.id = PREDICTORS_lev_nowcasted.AR_p.id;
PREDICTORS.AR_IC.id = PREDICTORS_lev_nowcasted.AR_IC.id;
PREDICTORS.BAR.id = PREDICTORS_lev_nowcasted.BAR.id;
PREDICTORS.BAR_SV.id = PREDICTORS_lev_nowcasted.BAR_SV.id;
PREDICTORS.BAR_SVo.id = PREDICTORS_lev_nowcasted.BAR_SVo.id;

PREDICTORS.RW.data = PREDICTORS_lev_nowcasted.RW.data;
PREDICTORS.SA.data = PREDICTORS_lev_nowcasted.SA.data;
PREDICTORS.AR_p.data = PREDICTORS_lev_nowcasted.AR_p.data;
PREDICTORS.AR_IC.data = PREDICTORS_lev_nowcasted.AR_IC.data;
PREDICTORS.BAR.data = PREDICTORS_lev_nowcasted.BAR.data;
PREDICTORS.BAR_SV.data = PREDICTORS_lev_nowcasted.BAR_SV.data;
PREDICTORS.BAR_SVo.data = PREDICTORS_lev_nowcasted.BAR_SVo.data;
PREDICTORS.obs = PREDICTORS_lev_nowcasted.SA.obs;
PREDICTORS.vintages_nowcasted = PREDICTORS_lev_nowcasted.RW.vintages;

if isfield(PREDICTORS_lev_nowcasted, 'contains_nowcasted_values')
    PREDICTORS.contains_nowcasted_values = PREDICTORS_lev_nowcasted.contains_nowcasted_values;
end
if isfield(PREDICTORS_lev_nowcasted, 'missing_vintage_report')
    PREDICTORS.missing_vintage_report = PREDICTORS_lev_nowcasted.missing_vintage_report;
end

end
