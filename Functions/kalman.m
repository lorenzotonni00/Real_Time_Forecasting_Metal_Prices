function KF = kalman(Y,pars)
% ----------------------------------------------------------------
% Apply Kalman Filter and Smoother to a panel of time series with
% potential missing data. The model takes the form:
%  
% Y_{t} = beta_1 + beta_2*t + C Z_t + e_{t},					e_{t} ~ N(0,R),
% Z_{t} = mu + A Z_{t-1} + u_{t},																u_{t} ~ N(0,Q)
% 
% with: 
%      Z_{t}|y_{t-1} ~ N(Z_{t|t-1},P_{t|t-1})
%      Y_{t}|Y^{t-1} ~ N(Y_{t|t-1},C*P_{t|t-1}*C'+R)
% ----------------------------------------------------------------
% SYNTAX: KF = KF(Y,pars)
% where:  
%       Y = matrix of data with NaNs (TxN)  
%       pars = structure containing:
%														C: matrix of loadings (Nxns)
%														R: var-cov matrix of idio (NxN)	  
%														A: transition matrix (nsxns)
%														Q: var-cov matrix of latent errors (nsxns)
%														Z00: initial vector of states (Tx1)
%														P00: initial var-cov states (nsxnsxT)
%------------------------------------------------------------------
% OUTPUT: KF (structure)
% with:
%     KF:
%							Zttm: predicted states Z_{t|t-1} (ns x T)
%       Pttm: predicted var-cov states P_{t|t-1} (ns x ns x T)
%       Ztt: filtered states Z_{t|t} (ns x (T+1))
%							Ptt: filtered var-cov states P_{t|t} (ns x ns x (T+1))
%							Kt: Kalman gain (with 0s as missings) (ns x N x T)
%							vt: prediction error (with 0s as missings) (N x T)
%							loglik: log-likelihood from Kalman filter
%							ZtT: smoothed states Z_{t|T} (ns x T)
%							PtT: smoothed var-cov stated P_{t|T} (ns x ns x T)	  
%							PtTm: smoother autocovariance (ns x ns)
% ------------------------------------------------------------------
% REFERENCES:
%						---------------------------------------------------------------------------
%  [1] Harvey, Andrew C. "Forecasting, Structural Time Series Models and
%						the Kalman Filter". Cambridge Books, Cambridge University Press.      [H90]
% ---------------------------------------------------------------------------------

A = pars.A; C = pars.C; R = pars.R; Q = pars.Q; 

if isfield(pars,'Z00'); Z0 = pars.Z00; else; Z0 = zeros(size(C,2),1); end																																																% if no initial state, initialize with 0
if isfield(pars,'P00'); P0 = pars.P00; else; P0 = 10*eye(size(C,2)); end																																																	% if no initial state var-cov, initialize with large variance

if isfield(pars,'mu'); mu = pars.mu; else; mu=zeros(size(C,2),1); end																																																				% if no constant in state equation, set to 0
if isfield(pars,'beta'); beta = pars.beta; else; beta=zeros(1,2); end																																																				% if no deterministic term in observation equation, set to 0

[~,ns] = size(C);																																																																																																								% number of states

Y = Y'; [N,T] = size(Y); 																																																																																																% size of the panel

%% Initialization
KF.Zttm = nan(ns,T); KF.Pttm = nan(ns,ns,T);																																																																							      % Z_{t|t-1} and P_{t|t-1}
KF.Ztt = nan(ns,T+1); KF.Ptt = nan(ns,ns,T+1);																																																																											% Z_{t|t} and % P_{t|t} 
KF.Kt = zeros(ns,N,T);  KF.vt = zeros(N,T);																																																																														% Kalman gain and prediction error
KF.loglik = 0;																																																																																																											% log-likelihood
KF.Ztt(:,1) = Z0; KF.Ptt(:,:,1) = P0;																																																																																				% Z_{0} and V_{0} 
mu = [zeros(ns,1),repmat(mu,1,T-1)];																																																																																				 % set initial mu to 0 

%%---------------%%
%% KALMAN FILTER %%
%%---------------%%																																																																																																						
%------------------------------------------------------------------------------------------------------------												% ================== 		
for t = 1:T
					%-----------------%
					% Prediction Step %		
     %-----------------%																																																																																																	% ---------------																																																														
     KF.Zttm(:,t) = mu(:,t) + A*KF.Ztt(:,t);																																																																													% Z_{t|t-1}
     KF.Pttm(:,:,t) = A*KF.Ptt(:,:,t)*A' + Q;																																																																												% P_{t|t-1}
     KF.Pttm(:,:,t) = 0.5*(KF.Pttm(:,:,t)+KF.Pttm(:,:,t)');																																																														% ensure symmetry
					
					%-------------%																																																																																																					
					% Update Step %		
     %-------------%																																																																																																					% ------------------------------------------------
					idx = ~isnan(Y(:,t));																																																																																															% identify series without NaN
					yt = Y(idx,t); Ct = C(idx,:); Rt = R(idx,idx);	if(sum(beta(:)))~=0; bt = beta(idx,:); else; bt=beta; end												% remove NaNs from parameters in the obs. equation

					%----------------------------------------------------------------------------																																							% --------------- 					
					if isempty(yt)																																																																																																						% if no data, no update ---> use prediction values
					%----------------------------------------------------------------------------																																							% --------------- 
          KF.Ztt(:,t+1) = KF.Zttm(:,t);																																																																																		% Z_{t|t}
          KF.Ptt(:,:,t+1) = KF.Pttm(:,:,t);																																																																																% P_{t|t}
					%----------------------------------------------------------------------------																																						 % --------------- 
					else																																																																																																																% if data, update
					%----------------------------------------------------------------------------																																							% --------------- 
										KF.Kt(:,idx,t) = KF.Pttm(:,:,t)*Ct'/(Ct*KF.Pttm(:,:,t)*Ct' + Rt);																																														% Kalman gain 
										KF.vt(idx,t) = yt - Ct*KF.Zttm(:,t) - bt*[1;t];																																																																% prediction error v_{t|t-1}
										KF.Ztt(:,t+1) = KF.Zttm(:,t) + KF.Kt(:,:,t)*KF.vt(:,t);																																																								% Z_{t|t}
										KF.Ptt(:,:,t+1) = KF.Pttm(:,:,t) - KF.Kt(:,idx,t)*Ct*KF.Pttm(:,:,t);																																											% P_{t|t}
										KF.Ptt(:,:,t+1) = 0.5*(KF.Ptt(:,:,t+1)+KF.Ptt(:,:,t+1)');																																																						% ensure symmetry
										
										KF.loglik = KF.loglik + 0.5*(log(det(inv(Ct*KF.Pttm(:,:,t)*Ct'+Rt))) -...																																						% compute log-likelihood
														        KF.vt(idx,t)'/(Ct*KF.Pttm(:,:,t)*Ct'+Rt)*KF.vt(idx,t));																																												% ----------------------
					%-----------------------------------------------------------------------------																																						% --------------- 
					end
					%-----------------------------------------------------------------------------																																						% ------------------------------------------------
end
%------------------------------------------------------------------------------------------------------------												% ================== 		
KF.Z00 = Z0; KF.P00=P0;																																																																																																		% initial values

%%-------------------------%%
%%					KALMAN SMOOTHER					%%																																																																																																		  
% (FIXED-INTERVAL SMOOTHER)	%
%%-------------------------%%	 
%------------------------------------------------------------------------------------------------------------												% ============================= 		
KF.ZtT = zeros(ns,T); KF.PtT = zeros(ns,ns,T); KF.PtTm = zeros(ns,ns,T);																																																	% Z_{t|T}, P_{t|T}, P_{t,t-1|T}
																																																																																																			
KF.ZtT(:,T) = KF.Ztt(:,T+1); KF.PtT(:,:,T) = KF.Ptt(:,:,T+1); 																																																											% initial smoothed states and variances
KF.PtTm(:,:,T) = (eye(ns) - KF.Kt(:,:,T)*C)*A*KF.Ptt(:,:,T);																																																													% initial smoothed autocovariance
Pts = zeros(ns,ns,T);																																																																																																				% 	
Pts(:,:,T) = KF.Ptt(:,:,T)*A'*pinv(KF.Pttm(:,:,T));																																																																						% initial update matrix
%--------------------------------------------------------------------------------------------------------------          %----------------------
for t=T:-1:2
    KF.ZtT(:,t-1) = KF.Ztt(:,t) + Pts(:,:,t)*(KF.ZtT(:,t) - KF.Zttm(:,t));																																															% Z_{t|T}  
    KF.PtT(:,:,t-1) = KF.Ptt(:,:,t) + Pts(:,:,t)*(KF.PtT(:,:,t) - KF.Pttm(:,:,t))*Pts(:,:,t)';																											% P_{t|T}
				%----------------------------------------------------------------------------------------------------------
				if t>1
							Pts(:,:,t-1) = KF.Ptt(:,:,t-1)*A'*pinv(KF.Pttm(:,:,t-1));																																																									% update matrix 
							KF.PtTm(:,:,t-1) = KF.Ptt(:,:,t)*Pts(:,:,t-1)'+Pts(:,:,t)*(KF.PtTm(:,:,t)-A*KF.Ptt(:,:,t))*Pts(:,:,t-1)';									% P_{t,t-1|T}
				end
				%-----------------------------------------------------------------------------------------------------------
end
%---------------------------------------------------------------------------------------------------------------         % ============================= 
	KF.ZtT = KF.ZtT';																																																																																																							% smoothed states


end
