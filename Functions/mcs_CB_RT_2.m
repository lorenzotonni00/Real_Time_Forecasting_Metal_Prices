function [model_ranking_from_worst_to_best]=mcs_CB_RT_2(losses,alpha,B,w,boot)
% Computes the model confidence set of Hansen, Lunde and Nason
%
% USAGE:
%   [INCLUDEDR] = mcs(LOSSES,ALPHA,B,W)
%   [INCLUDEDR,PVALSR,EXCLUDEDR,INCLUDEDSQ,PVALSSQ,EXCLUDEDSQ] = mcs(LOSSES,ALPHA,B,W,BOOT)
%
% INPUTS:
%   LOSSES     - T by K matrix of losses
%   ALPHA      - The final pval to use in the MCS
%   B          - Number of bootstrap replications
%   W          - Desired block length
%   BOOT       - [OPTIONAL] 'STATIONARY' or 'BLOCK'.  Stationary will be used as default.
%
% OUTPUTS:
%   INCLUDEDR  - Included models using R method
%   PVALSR     - Pvals using R method
%   EXCLUDEDR  - Excluded models using R method
%   INCLUDEDSQ - Included models using SQ method
%   PVALSSQ    - Pvals using SQ method
%   EXCLUDEDSQ - Excluded models using SQ method
%
% COMMENTS:
%   This version of the MCS operates on quantities that should be "bads", such as losses.  If the
%   quantities of interest are "goods", such as returns, simply call MCS with -1*LOSSES

%%%%%%%%%%%%%%%%%%%%%%%%%
% Input Checking
%%%%%%%%%%%%%%%%%%%%%%%%%
if nargin<4 || nargin>5
    error('4 or 5 inputs required')
end
if nargin == 4
    boot = 'STATIONARY';
end
% Get the length of the data
t=size(losses,1);
if t<2
    error('LOSSES must have at least 2 observations.')
end
if ~isscalar(alpha) || alpha>=1 || alpha<=0
    error('ALPHA must be a scalar between 0 and 1')
end
if ~isscalar(B) || B<1 || floor(B)~=B
    error('B must be a positive scalar integer')
end
if ~isscalar(w) || w<1 || floor(w)~=w
    error('W must be a positive scalar integer')
end
boot = upper(boot);
if ~ismember(boot,{'STATIONARY','BLOCK'})
    error('BOOT must be either ''STATIONARY'' or ''BLOCK''.')
end
%%%%%%%%%%%%%%%%%%%%%%%%%
% Input Checking
%%%%%%%%%%%%%%%%%%%%%%%%%

% 1. Compute the indices to use throughout the proceedure
if strcmp(boot,'BLOCK')
    [bsdata]=block_bootstrap((1:t)',B,w);
else
    [bsdata]=stationary_bootstrap((1:t)',B,w);
end

%% All of these values can be computed once
M0=size(losses,2);   % # models
% The i,j element contains the l(i,t)-l(j,t)
dijbar_tmp=zeros(M0,M0);
for j=1:M0
    dijbar_tmp(j,:) = mean(losses - repmat(losses(:,j),1,M0));
end

[~,I]=unique(dijbar_tmp,'rows');
locations=setdiff(1:height(dijbar_tmp),I);
dijbar = dijbar_tmp; dijbar(locations,:) = []; dijbar(:,locations) = [];

model_list = 1:M0; model_list(locations) = []; model_list(2,:) = 1:length(model_list);

% for each j, compute dij*-bar using the BSdata, than the compute
% var(dijbar)
% 2(a)

%
dijbarstar_tmp=zeros(M0,M0,B);
% dijbarstar=zeros(M0,M0,B);

for b=1:B
    meanworkdata=mean(losses(bsdata(:,b),:));
    for j=1:M0
        % The i,j element contains the l(b,i,t)-l(b,j,t)
        dijbarstar_tmp(j,:,b) = meanworkdata - meanworkdata(j);
        
    end
    % [~,I_star]=unique(squeeze(dijbarstar_tmp(:,:,b)),'rows');
    % locations=setdiff(1:height(squeeze(dijbarstar_tmp(:,:,b))),I_star);
    dijbarstar_2 = squeeze(dijbarstar_tmp(:,:,b)); dijbarstar_2(locations,:,:) = []; dijbarstar_2(:,locations,:) = [];
    dijbarstar(:,:,b) = dijbarstar_2;
end
%

M0 = size(dijbarstar,1);

% 2(a)
vardijbar = mean((dijbarstar-repmat(dijbar,[1 1 B])).^2,3);
vardijbar = vardijbar+diag(ones(M0,1));

% 2(b) depends on the det of models under conderations, so it will have to
% go in the loop

% These values are used in the empirical distributions and do not depend on
% the number of models
z0=(dijbarstar-repmat(dijbar,[1 1 B]))./repmat(sqrt(vardijbar),[1 1 B]);
zdata0=dijbar./sqrt(vardijbar);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
excludedSQ=zeros(M0,1);
excludedSQ_2=NaN(M0,1);
pvalsSQ=ones(M0,1);
for i=1:M0-1
    included=setdiff(1:M0,excludedSQ);
    m=length(included);
    z=z0(included,included,:);
    % Only supposed to sub every element once.  Instead sum twice and
    % divide by 2 in each matrix (B of them)
    empdistTSQ=squeeze(sum(sum(z.^2))/2);
    
    zdata=zdata0(included,included);
    TSQ=sum(sum(zdata.^2))/2;
    
    pvalsSQ(i)=mean(empdistTSQ>TSQ);
    % Finally compute the model to remove, which depends on the maximum
    % standardized average (among the remaining models)
    % 1. compute dibar
    dibar=mean(dijbar(included,included),1)*(m/(m-1));
    % 2. compute var(dibar)
    dibstar=squeeze(mean(dijbarstar(included,included,:),1))*(m/(m-1));
    vardi=mean((dibstar'-repmat(dibar,B,1)).^2);
    t=dibar./sqrt(vardi);
    % Remove the max of t
    [temp,modeltoremove] = max(t);
    excludedSQ(i)=included(modeltoremove);
    index_pos = find(model_list(2,:) == modeltoremove); model_pos = model_list(1,index_pos);
    excludedSQ_2(i)=model_pos;
end
% The MCS pval is the max up to that point
maxpval=pvalsSQ(1);
for i=2:M0
    if pvalsSQ(i)<maxpval
        pvalsSQ(i)=maxpval;
    else
        maxpval=pvalsSQ(i);
    end
end
% Add the final remaining model to excluded
A_tmp = model_list(2,:)'; B_tmp = excludedSQ;
missing = setdiff(A_tmp, B_tmp);

excludedSQ(length(excludedSQ))=missing;

% pos_models = find(model_list(2,:) == modeltoremove);
excludedSQ_2 = model_list(1,excludedSQ); 

model_ranking_from_worst_to_best = excludedSQ_2';
model_ranking_from_worst_to_best = [model_ranking_from_worst_to_best, pvalsSQ];

% The included models are all of these where the first pval is > alpha
pl=find(pvalsSQ>=alpha,1,'first');
includedSQ=excludedSQ(pl:M0);
excludedSQ=excludedSQ(1:pl-1);

%%

end
