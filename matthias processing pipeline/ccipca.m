function [V, D, n] = ccipca(X, k, nIterations, oldV, passNumber)

%CCIPCA --- Candid Covariance-free Increment Principal Component Analysis
%[V,D]=ccipca(X)  ,Batch mode: take input matrix return the eigenvector 
%matrix
%[V,D]=ccipca(X,k) , Batch mode: take input matrix and number of
%eigenvector and return the eigenvector and eigenvalue
%[V,D]=ccipca(X,k,iteration,oldV,access) , Incremental mode: Take input matirx and
%number of eigenvector and number of iteration, and the old eigenvector
%matrix, return the eigenvector and eigenvalue matrix
%
%[V,D]=ccipca(...) return both the eigenvector and eigenvalue matrix
%V=ccipca(...) return only the eigenvector matrix
%Algorithm

%ARGUMENTS:
%INPUT
%X --- Sample matrix, samples are column vectors. Note the samples must be
%centered (subtracted by mean)
%k --- number of eigenvectors that will be computed
%nIterations --- number of times the data are used
%oldV --- old eigen vector matrix, column wise
%passNumber --- the number of updatings of the old eigenvector matrix, starts at 1.
%OUTPUT
%V --- Eigenvector matrix, column-wise
%D --- Diagonal matrix of eigenvalue
%n --- Updating occurance

%get sample matrix dimensinality
	
[datadim, samplenum]=size(X);

%samplemean=mean(X,2);
%scatter=X-samplemean*ones(1, samplenum); %subtract the sample set by its mean
vectornum = datadim;
repeats=1;
n=2; % the number of times the eigenvector matrix get updated. Magic number to prevent div by 0 error

if nargin == 1
    % batch	mode, init the eigenvector matrix with samples
    if datadim>samplenum
        error('No. of samples is less than the dimension. You have to choose how many eigenvectors to compute. ');
    end
    V = X(:,1:datadim);
elseif nargin ==2
    % number of eigenvector given
    if k > datadim
        k=datadim;
    end
    vectornum=k;
    V=X(:,1:vectornum);
elseif nargin ==3
    % number of eigenvector given, number of iteration given
    if k > datadim
        k=datadim;
    end
    vectornum=k;
    V=X(:,1:vectornum);
    repeats = nIterations;
elseif nargin >=4
    if isempty(oldV)
        vectornum=k;
        V=X(:,1:vectornum);
    elseif datadim~=size(oldV,1)
        error('The dimensionality of sample data and eigenvector are not match. Program ends.');	
    else
        % If given oldV the the argument k will not take effect.
        V=oldV;
        vectornum = size(V, 2);
    end
    repeats = nIterations;
    
    if passNumber < 1
        error('Number of passes must be a positive integer.');
    else
        n = max(passNumber, 2); % n must be at least 2, as stated above...damn that was a stupid bug.
    end
end

% Replace nans with zeros:
% Not sure if this is the best way to deal with them, but since a different
% subset of pixels are Nans in each frame, it's inefficient to actually
% remove those pixels.
if any(isnan(V(:)))
    V(isnan(V)) = 0;
end
if any(isnan(X(:)))
    X(isnan(X)) = 0;
end

Vnorm=sqrt(sum(V.^2)); 

for iter = 1:repeats
    for  i = 1:samplenum
        residue = X(:, i);  % get the image 
        [w1, w2] = amnesic(n);
        n = n+1;
        for j= 1:vectornum
            V(: , j) = w1 * V(:,j) + w2 * V(:,j)' * residue * residue / Vnorm(j);
            Vnorm(j) = norm(V(:,j)); % update the norm of eigenvector
            normedV = V(:,j)/Vnorm(j);
            residue = residue - residue' * normedV * normedV; 
        end
    end
end

D=sqrt(sum(V.^2)); %length of the updated eigen vector, aka eigen value
[Y,I]=sort(-D);
V=V(:,I);
V=normc(V); %normalize V
if nargout==2
    D=D(I);
    D=diag(D);
end
    
return
    

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [w1, w2] = amnesic(i)
%AMNESIC --- Calculate the amnesic weight
%
%INPUT 
%i --- accessing time
%OUTPUT
%w1, w2 ---two amnesic weights

n1 = 1e4; % Bootstrap...after this many iterations, the new samples become proportionally more important.
n2 = 1e5; % Remembrance: How many iterations before we start forgetting older iterations). (If we know the number of samples we have, we never really want to forget the early ones, so this is hight).
m = 1e5;
if i < n1
    L=0;
elseif i >= n1 && i < n2
    L=2*(i-n1)/(n2-n1);
else 
    L=2+(i-n2)/m;
end
w1=(i-1-L)/i;    
w2=(1+L)/i;
return
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        