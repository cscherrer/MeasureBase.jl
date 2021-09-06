
###############################################################################
# Affine

affine(f::AffineTransform, μ::AbstractMeasure) = Affine(f, μ)

affine(nt::NamedTuple, μ::AbstractMeasure) = affine(AffineTransform(nt), μ)

affine(f) = μ -> affine(f, μ)

function affine(f::AffineTransform, parent::WeightedMeasure)
    WeightedMeasure(parent.logweight, affine(f, parent.base))
end

function affine(f::AffineTransform, parent::FactoredBase)
    finv = inv(f)
    inbounds(x) = parent.inbounds(finv(x))
    constℓ = parent.constℓ
    varℓ = parent.varℓ
    base = AffineTransform(f, parent.base)
    FactoredBase(inbounds, constℓ, varℓ, base)
end


###############################################################################
# Half

half(μ::AbstractMeasure) = Half(μ)

###############################################################################
# PointwiseProductMeasure

pointwiseproduct(μ::AbstractMeasure...) = PointwiseProductMeasure(μ)

function pointwiseproduct(μ::PointwiseProductMeasure{X}, ν::PointwiseProductMeasure{Y}) where {X,Y}
    data = (μ.data..., ν.data...)
    pointwiseproduct(data...)
end

function pointwiseproduct(μ::AbstractMeasure, ν::PointwiseProductMeasure)
    data = (μ, ν.data...)
    return pointwiseproduct(data...)
end

function pointwiseproduct(μ::PointwiseProductMeasure, ν::N) where {N <: AbstractMeasure}
    data = (μ.data..., ν)
    return pointwiseproduct(data...)
end

function pointwiseproduct(μ::M, ν::N) where {M <: AbstractMeasure, N <: AbstractMeasure}
    data = (μ, ν)
    return pointwiseproduct(data...)
end

function pointwiseproduct(μ::AbstractMeasure, ℓ::Likelihood)
    data = (μ, ℓ)
    return pointwiseproduct(data...)
end

###############################################################################
# PowerMeaure

function powermeasure(μ::M, dims::NTuple{N,I}) where {M<:AbstractMeasure,N,I<:Integer}
    productmeasure(identity, Fill(μ, dims))
end

function powermeasure(μ::WeightedMeasure, dims::NTuple{N,I}) where {N,I<:Integer}
    k = prod(dims) * μ.logweight
    return weightedmeasure(k, μ.base^dims)
end

###############################################################################
# ProductMeasure

productmeasure(f, pars) = ProductMeasure(f, pars)

productmeasure(nt::NamedTuple) = productmeasure(identity, nt)

###############################################################################
# RestrictedMeasure

restrict(f, b) = RestrictedMeasure(f, b)

###############################################################################
# SuperpositionMeasure

function superpose(μ...)
end

function superpose(μ::AbstractMeasure, ν::AbstractMeasure)
    components = (μ, ν)
    superpose(components)
end

###############################################################################
# WeightedMeasure

function weightedmeasure(ℓ::R, b::M) where {R,M}
    WeightedMeasure{R,M}(ℓ, b)
end 

function weightedmeasure(ℓ, b::WeightedMeasure)
    weightedmeasure(ℓ + b.logweight, b.base)
end 
