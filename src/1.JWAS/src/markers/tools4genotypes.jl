#the function below using pointers is deprecated
function get_column(X,j)
    nrow,ncol = size(X)
    if j>ncol||j<0
        error("column number is wrong!")
    end
    indx = 1 + (j-1)*nrow
    ptr = pointer(X,indx)
    #pointer_to_array(ptr,nrow) #deprected in Julia 0.5
    unsafe_wrap(Array,ptr,nrow)
end

function get_column_ref(X)
    ncol = size(X)[2]
    xArray = Array{Array{Float64,1}}(undef,ncol)
    for i=1:ncol
        xArray[i] = get_column(X,i)
    end
    return xArray
end

function center!(X)
    nrow,ncol = size(X)
    colMeans = mean(X,dims=1)
    BLAS.axpy!(-1,ones(nrow)*colMeans,X)
    return colMeans
end

function getXpRinvX(X, Rinv)
    ncol = size(X)[2]
    XpRinvX = [((X[:,i].*Rinv)'X[:,i])[1]::Float64 for i=1:ncol]
    return XpRinvX
end

function getXpRinvX(X)
    XpRinvX = [dot(X[:,i],X[:,i]) for i=1:size(X,2)]
    return XpRinvX
end

mutable struct GibbsMats
    X::Array{Float64,2}
    nrows::Int64
    ncols::Int64
    xArray::Array{Array{Float64,1},1}
    xpx::Array{Float64,1}
    function GibbsMats(X::Array{Float64,2}) ###More
        nrows,ncols = size(X)
        xArray = get_column_ref(X)
        XpX = getXpRinvX(X)
        new(X,nrows,ncols,xArray,XpX)
    end
end

################################################################################
#align genotypes with phenotyps given IDs #MAY USE TOO MUCH MEMORY
################################################################################
function align_genotypes(mme::MME)
    Mfull    = mme.M.genotypes #imputed genotype in SSBR
    obsIDfull= deepcopy(mme.M.obsID)
    if mme.obsID != mme.M.obsID  #align genotypes with phenotypes
        Z  = mkmat_incidence_factor(mme.obsID,obsIDfull)
        mme.M.genotypes = Z*Mfull
        mme.M.obsID     = mme.obsID
        mme.M.nObs      = length(mme.M.obsID)
    end
    if mme.output_ID != 0  #get genotypes for outputEBV individuals
        if mme.output_ID == mme.M.obsID
            mme.output_genotypes = mme.M.genotypes
        else
            Zo  = mkmat_incidence_factor(mme.output_ID,obsIDfull)
            mme.output_genotypes = Zo*Mfull
        end
    end
end

#y=Zu (complete genomic data)
function mkmat_incidence_factor(yID,uID)
    Z = spzeros(length(yID),length(uID))

    uIDdict = Dict()
    for (index,id) in enumerate(uID)
        uIDdict[id]=index
    end

    rowi = 1
    for id in yID
        if haskey(uIDdict,id)
            index = uIDdict[id]
        else
            error("IDs are wrong!")
        end
        Z[rowi,index]=1
        rowi = rowi+1
    end
    return Z
end
