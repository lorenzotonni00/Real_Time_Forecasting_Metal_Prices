function EM = EM_DFM_MF_blocks(Y,ss,init,blocks,opts)

%%%%%%%%%%%%%%%%%%%%
%% INITIALIZATION %%
%%%%%%%%%%%%%%%%%%%%

[T,N] = size(Y);                                                                                                         % size of the panel

q = init.q;                                                                                                          % n. of static factors
p = init.p;                                                                                        % n. of lags: state equation
n_b = size(blocks,2);                                                                                                    % n. of blocks

M = [2 -1  0  0  0; ...                                                                                                  % M-to-Q restrictions: see [MM03]
     3  0 -1  0  0; ...                                                                                                  % -------------------------------
     2  0  0 -1  0; ...                                                                                                  % -------------------------------
     1  0  0  0 -1];                                                                                                     % -------------------------------

c = zeros(size(M,1),1);                                                                                                  % linear constraints: see [BM14] 

w = [1 2 3 2 1];                                                                                                         % weights: M-to-Q aggregation scheme

nc = size(M,2);											                                                                                               % n. of M-to-Q constraints
pp = max(p,nc);                                                                                                          % effective n. of lags: factors, observation equation
nf = sum(q)*pp;                                                                                                          % total number of factors in state vector

idF = init.idF;                                                                                                          % location of frequencies 
idI = init.idI;                                                                                                          % location of AR idiosyncratic components

%%%%%%%%%%%%
%% E-STEP %%
%%%%%%%%%%%%
KF = kalman(Y,ss);                                                                                                       % Kalman Smoother

ZtT = KF.ZtT; PtT = KF.PtT; PtTm = KF.PtTm;                                                                              % Smoother output

Y_est = Y;                                                                                                               % estimation data

EM = ss;                                                                                                                 % initialize parameters
logl0 = KF.loglik;																																																																																															        % initial log-likelihood 
EM.converged = false;
EM.iterations = 0;
EM.loglik = logl0;
EM.relative_loglik_change = NaN;

if opts.verbose==1
  disp(repmat('=',1,45))  
  disp([repmat(' ',1,10) ' Running the EM algorithm...'])
  disp(repmat('=',1,45))  
  disp(['Iteration    ' 'Log-Likelihood' '   ' 'Absolute Change'])
  disp( '---------------------------------------------')
  disp(['   0' repmat(' ',1,12)  num2str(round(logl0,2))])
end


idn = isnan(Y_est); Y_est(idn) = 0;                                                                                      % replace NaNs with zeroes 

uB = logical(unique(blocks,"rows"));                                                                                     % locate unique blocks of loadings 
n_ub = size(uB,1);                                                                                                       % n. of unique blocks

idB_M = []; idB_Q = []; MB = []; cB = [];                                                                                % initialize indicators

for bb = 1:n_b                                                                                                           % FOR EACH BLOCK BB:
    idB_M = logical(cat(2, idB_M, repmat(uB(:,bb),1,q(bb)), zeros(n_ub,q(bb)*(pp-1))));                                  % subset monthly loadings, load zero on M-to-Q constraints
    idB_Q = logical(cat(2, idB_Q, repmat(uB(:,bb),1,q(bb)*pp)));                                                         % subset quarterly loadings, repeat for M-to-Q constraints
    MB = blkdiag(MB, kron(M,eye(q(bb))));                                                                                % repeat M-to-Q aggregation for number of factors in block bb
    cB = cat(1, cB, repmat(c,q(bb),1));                                                                                  % repeat M-to-Q constraints for number of factors in block bb
end

ids = [];                                                                                                                % STATE IDENTIFIERS
for ii=1:N                                                                                                               %------------------ 
    if idF(ii)&&idI(ii); ids = cat(1, ids, 1);                                                                           % monthly w/ idio AR: 1 state (id = 1)
    elseif ~idF(ii)&&idI(ii); ids = cat(1, ids, [2; zeros(nc-1,1)]);                                                     % quarterly w/ idio AR: 5 states (id = [2 0 0 0 0])
    else; ids = cat(1, ids, -1);                                                                                         % no AR idio, no state 
    end                                                                                                                  %------------------ 
end


jj = 1;
while jj<=opts.maxiter
      %%%%%%%%%%%%
      %% M-STEP %%
      %%%%%%%%%%%%
      
      %%%%%%%%%%%%%%%%%%%%%%%%%%
      %% OBSERVATION EQUATION %%
      %%%%%%%%%%%%%%%%%%%%%%%%%%
      
      %==========%
      % LOADINGS %
      %==========%
      for nn = 1:n_ub                                                                                                    % for each unique block...
          
          %-------------------%
          % MONTHLY VARIABLES %
          %-------------------%
          qs = sum(q(uB(nn,:)));                                                                                         % n. of blocks loaded
          idb = ismember(blocks, uB(nn,:), "rows");                                                                      % locate variables in block nn
          idM_n = find(idF.*idb);                                                                                        % locate M variables in block nn
          nM_n = numel(idM_n);                                                                                           % n. of M series in block nn
      
          FtFt = zeros(nM_n*qs,nM_n*qs);                                                                                 % initialize denominator in [BGR10] eq. 13
          ytFt = zeros(nM_n,qs);                                                                                         % initialize numerator in [BGR10] eq. 13
      
          idI_Mn = logical(idF.*idI.*idb);                                                                               % identify M variables with AR idio in block nn
          idI_Mn = idI_Mn(idM_n);                                                                                        % consider only subset in block nn
      
          temp = false(size(ids));                                                                                       % identify states for M variables in block nn...
          temp(ids~=0) = (ids(ids~=0).*idF.*idb)==1;                                                                     % ... corresponding to AR idio
          temp(ids==-1) = [];                                                                                            % remove variables with idio no AR --> no state! 
          ids_Mn = nf + find(temp);                                                                                      % skip factors 
      
          for tt = 1:T
              Wt = diag(~idn(tt,idM_n));                                                                                 % selection matrix non-missing values at time t
              
              FtFt = FtFt + kron(ZtT(tt, idB_M(nn,:))'*ZtT(tt, idB_M(nn,:))...                                           % denominator in [BGR10], eq. 13
                                 + PtT(idB_M(nn,:), idB_M(nn,:), tt), Wt);                                               % \sum_{t=1}^{T} E(F_{t}F_{t}'|P) x W_t
              
              ytFt = ytFt + Y_est(tt, idM_n)'*ZtT(tt, idB_M(nn,:))...                                                    % numerator in [BGR10], eq. 13
                          - Wt(:, idI_Mn)*(ZtT(tt, ids_Mn)'*ZtT(tt, idB_M(nn,:))...                                      % \sum_{t=1}^{T} [W_{t}y_{t}E(F_{t}'|P) x W_{t}
                                        + PtT(ids_Mn, idB_M(nn,:), tt));                                                 % + W_{t}E(e_{t}F_{t}'|P)]
          end
      
          vec_C = FtFt\ytFt(:);                                                                                          % vectorized loadings
          EM.C(idM_n,idB_M(nn,:)) = reshape(vec_C, nM_n, qs);                                                            % N_n x q_n loadings for block nn
      
          %---------------------%
          % QUARTERLY VARIABLES %
          %---------------------%
          idQ_n = find(~idF.*idb);                                                                                       % locate Q variables in block nn
      
          MB_n = MB(:,idB_Q(nn,:));                                                                                      % M-to-Q aggregation scheme in block nn
          c_n = cB;                                                                                                      % M-to-Q constraints in block nn 
      
          c_n(~(any(MB_n,2)),:) = []; MB_n(~(any(MB_n,2)),:) = [];                                                       % remove rows with no constraints (i.e. other blocks)
          
          idI_Qn = logical(~idF.*idI.*idb);                                                                              % identify Q variables with AR idio in block nn
          idI_Qn = idI_Qn(idQ_n);                                                                                        % consider only subset in block nn
      
          temp = false(size(ids));                                                                                       % identify states for Q variables in block nn...
          temp(ids~=0) = (ids(ids~=0).*~idF.*idb)==2;                                                                    % ... corresponding to AR idio
          temp(ids==-1) = [];                                                                                            % remove variables with idio no AR --> no state! 
          ids_Qn = nf + find(temp);                                                                                      % locate position skipping factors

          for ii = 1:numel(idQ_n)                                                                                        % loop over Q variables in block nn
              
              qsp = qs*pp;                                                                                               % n. factors in block nn x size aggregation scheme
              FtFt = zeros(qsp,qsp);                                                                                     % initialize denominator in [BGR10] eq. 13
              ytFt = zeros(1,qsp);                                                                                       % initialize numerator in [BGR10] eq. 13
       
              for tt = 1:T
                  Wt = diag(~idn(tt,idQ_n(ii)));                                                                         % selection matrix: non-missing values at time t

                  FtFt = FtFt + kron(ZtT(tt, idB_Q(nn,:))'*ZtT(tt, idB_Q(nn,:))...                                       % denominator in [BGR10], eq. 13
                                     + PtT(idB_Q(nn,:), idB_Q(nn,:), tt), Wt);                                           % \sum_{t=1}^{T} E(F_{t}F_{t}'|P) x W_t
                            
                  ytFt = ytFt + Y_est(tt,idQ_n(ii))'*ZtT(tt, idB_Q(nn,:));                                               % \sum_{t=1}^{T} [W_{t}y_{t}E(F_{t}'|P) x W_{t}
                         
                  if any(ids_Qn)                                                                                         % if at least one Q variable with AR idio:
                     loc_ii = ids_Qn(ii):ids_Qn(ii)+(pp-1);                                                              % locate nc states for AR idio ii 
      
                     ytFt = ytFt - Wt(:, idI_Qn(ii))*w*(ZtT(tt, loc_ii)'*ZtT(tt, idB_Q(nn,:))...                         % - W_{t}(w \sum_{t=1}^{T} E(e_{t}F_{t}'|P)]
                                                          + PtT(loc_ii, idB_Q(nn,:), tt));                               % where w = [1 2 3 2 1] (M-to-Q aggregation) 
                  end                                    
              end

              uC_ii = FtFt\ytFt';                                                                                        % unconstrained Q loadings
              iF = FtFt^(-1);                                                                                            % (F'F)^-1

              EM.C(idQ_n(ii),idB_Q(nn,:)) = uC_ii - iF*MB_n'*((MB_n*iF*MB_n')^(-1))*(MB_n*uC_ii - c_n);                  % constrained Q loadings
      
          end
      end

      %=========================%
      % IDIOSYNCRATIC COMPONENT %
      %=========================%
      R0 = zeros(N,N);                                                                                                   % initialize idiosyncratic var-cov matrix
      for tt = 1:T
          Wt = diag(~idn(tt,:));                                                                                         % selection matrix: non-missing values at time t
          R0 = R0 + (Y_est(tt,:)' - Wt*EM.C*ZtT(tt,:)')*(Y_est(tt,:)' - Wt*EM.C*ZtT(tt,:)')'...
                + Wt*EM.C*PtT(:,:,tt)*EM.C'*Wt + (eye(N)-Wt)*EM.R*(eye(N)-Wt);     %[BM] eq 12
      end
      
      R0 = diag(R0/T);                                                                                                   % diagonal, scaled by T
      R0(idI) = 10^-2;                                                                                                   % non-zero idiosyncratic variance AR idio, see [OvD23]
      EM.R = diag(R0);                                                                                                   % idiosyncratic var-cov matrix, diagonal
      
      %%%%%%%%%%%%%%%%%%%%
      %% STATE EQUATION %%
      %%%%%%%%%%%%%%%%%%%%
      %=========%
      % FACTORS %
      %=========%
      qbp = cumsum([1,q(1:end-1)*pp]);                                                                                   % locate first factor in state matrix within each block
      
      for nn = 1:n_b                                                                                                     % loop over blocks
      
          qb = q(nn);                                                                                                    % n. of factors in block nn
          locF = qbp(nn):qbp(nn)+q(nn)-1;                                                                                % locate lag 0 factors, state matrix
          locF1 = qbp(nn):qbp(nn)+q(nn)*p - 1;                                                                           % locate lag 1 factors, state matrix
      
          FtFt = ZtT(2:end,locF)'*ZtT(2:end,locF) + sum(PtT(locF,locF,2:end),3);                                         % \sum_{t=1}^{T} E(F_{t}F_{t}'|P) 
          Ft1Ft1 = ZtT(1:end-1,locF)'*ZtT(1:end-1,locF) + sum(PtT(locF,locF,1:end-1),3);                                 % \sum_{t=1}^{T} E(F_{t-1}F_{t-1}'|P)
          FtFt1 = ZtT(2:end,locF)'*ZtT(1:end-1,locF) + sum(PtTm(locF,locF,:),3);                                         % \sum_{t=1}^{T} E(F_{t}F_{t-1}'|P) x W_t
       
          EM.A(locF,locF1) = (Ft1Ft1\FtFt1')';                                                                           % EQ. ...
      
          EM.Q(locF,locF) = (FtFt(1:qb,1:qb) - EM.A(locF,locF1)*FtFt1(1:qb,1:qb*p)')/T;                                  % EQ. ...
      
          ls = qbp(nn); le = qbp(nn) + q(nn)*pp - 1;                                                                     % locate factors, with M-to-Q aggregation (pp)
          EM.P00(ls:le,ls:le) = PtT(ls:le,ls:le,1);                                                                      % state initial var-cov matrix: factors
      end
      
      %=============================%
      % AR IDIOSYNCRATIC COMPONENTS %
      %=============================%
      temp = ids;                                                                                                        % identify states for AR(1) idio
      temp(temp<0) = [];                                                                                                 % remove no states (ids: -1)
      locE = find(temp>0);                                                                                               % states AR(1) (ids = 1,2)
      
      etet = diag(diag(ZtT(2:end, nf+1:end)'*ZtT(2:end, nf+1:end)))...
             + diag(diag(sum(PtT(nf+1:end, nf+1:end, 2:end),3)));
      
      et1et1 = diag(diag(ZtT(1:end-1, nf+1:end)'*ZtT(1:end-1, nf+1:end)))...
               + diag(diag(sum(PtT(nf+1:end, nf+1:end, 1:end-1), 3)));
      
      etet1 = diag(diag(ZtT(2:end, nf+1:end)'*ZtT(1:end-1,nf+1:end)))...
             + diag(diag(sum(PtTm(nf+1:end, nf+1:end, :), 3)));
      
      tempA = etet1*diag(1./diag(et1et1));                                                                               % AR(1) coefficients
      EM.A(nf+locE, nf+locE) = tempA(locE, locE);                                                                        % place coefficients in output matrix
      
      tempQ = (etet - tempA*etet1')/T;                                                                                   % var-cov matrix AR(1) idiosyncratic components
      EM.Q(nf+locE, nf+locE) = tempQ(locE, locE);                                                                        % place var-cov in output matrix
      
      locEM = find(temp==1);                                                                                             % find AR(1) states for M variables (ids = 1)
      EM.P00(nf+locEM, nf+locEM) = diag(diag(PtT(nf+locEM, nf+locEM, 1)));                                               % update initial state var-cov matrix
      
      locEQ = find(temp==2|temp==0);                                                                                     % find AR(1) states for Q variables (ids = 2,0)
      EM.P00(nf+locEQ, nf+locEQ) = PtT(nf+locEQ, nf+locEQ, 1);                                                           % update initial state var-cov matrix

      %%%%%%%%%%%%
      %% E-STEP %%
      %%%%%%%%%%%%
      KF = kalman(Y,EM);                                                                                                 % Kalman Smoother
      EM.Z00 = ZtT(1,:)'; EM.P00 = zeros(size(PtT(:,:,1)));                                                              % update initial conditions

      ZtT = KF.ZtT; PtT = KF.PtT; PtTm = KF.PtTm;                                                                        % Smoother output
      logl = KF.loglik;                                                                                                  % update log-likelihood

      %%%%%%%%%%%%%%%%%
      %% CONVERGENCE %%
      %%%%%%%%%%%%%%%%%
      if opts.maxiter>1
         if opts.verbose==1																																																																																																				
				        disp(['   ' num2str(jj) repmat(' ',1,13-numel(num2str(jj)))  num2str(round(logl,2))...																							% display output
					             repmat(' ',1,12)... 																													% --------------
                  num2str(round((abs(logl - logl0)/((abs(logl) + abs(logl0))/2)),4))])																																			% --------------
         end
					    rel_change = abs(logl - logl0)/((abs(logl) + abs(logl0))/2);
					    EM.iterations = jj;
					    EM.loglik = logl;
					    EM.relative_loglik_change = rel_change;
					    if rel_change < opts.thresh 	                                             % assess convergence: [DGR12]
            EM.converged = true;
            if opts.verbose==1; disp(['EM algorithm converged after ' num2str(jj) ' iterations']); end                   % if converged, break algorithm
            break; 
         end																																				
					    if opts.maxiter>1&&jj==opts.maxiter; disp('No convergence'); end                                                % if max iteration reached, no convergene
					    logl0 = logl;																																																																																																	 	% update previous log- likelihood
		    end
      jj = jj + 1;																																																																																																	 	    % if no convergence at iteration jj, keep iterating
end

EM.ZtT = ZtT;	EM.PtT = PtT; EM.PtTm = PtTm;																																																																														% store quantities
EM.Chi = EM.ZtT(:,1:nf)*EM.C(:,1:nf)';

end
