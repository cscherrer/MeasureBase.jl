export ProductMeasure

using MappedArrays
using Base: @propagate_inbounds

struct ProductMeasure{F,I} <: AbstractMeasure
    f::F
    pars::I
end

ProductMeasure(nt::NamedTuple) = ProductMeasure(identity, nt)

Base.size(μ::ProductMeasure) = size(marginals(μ))

Base.length(m::ProductMeasure{T}) where {T} = length(marginals(μ))

# TODO: Pull weights outside
basemeasure(d::ProductMeasure) = ProductMeasure(basemeasure ∘ d.f, d.pars)


export marginals

function marginals(d::ProductMeasure{F,I}) where {F,I}
    _marginals(d, isiterable(I))
end

function _marginals(d::ProductMeasure{F,I}, ::Iterable) where {F,I}
    return (d.f(i) for i in d.pars)
end

function _marginals(d::ProductMeasure{F,I}, ::NonIterable) where {F,I}
    error("Type $I is not iterable. Add an `iterate` or `marginals` method to fix.")
end

testvalue(d::ProductMeasure) = map(testvalue, marginals(d))

function Base.show(io::IO, μ::ProductMeasure{NamedTuple{N,T}}) where {N,T}
    io = IOContext(io, :compact => true)
    print(io, "Product(",μ.data, ")")
end




function Base.show_unquoted(io::IO, μ::ProductMeasure, indent::Int, prec::Int)
    io = IOContext(io, :compact => true)
    if Base.operator_precedence(:*) ≤ prec
        print(io, "(")
        show(io, μ)
        print(io, ")")
    else
        show(io, μ)
    end
    return nothing
end


###############################################################################
# I <: Tuple

export ⊗
⊗(μs::AbstractMeasure...) = ProductMeasure(identity, μs)

marginals(d::ProductMeasure{F,T}) where {F, T<:Tuple} = map(d.f, d.pars)

function Base.show(io::IO, μ::ProductMeasure{F,T}) where {F,T <: Tuple}
    io = IOContext(io, :compact => true)
    print(io, join(string.(marginals(μ)), " ⊗ "))
end

function logdensity(d::ProductMeasure{F,T}, x::Tuple) where {F,T<:Tuple}
    mapreduce(logdensity, +, d.f.(d.pars), x)
end

function Base.rand(rng::AbstractRNG, ::Type{T}, d::ProductMeasure{F,I}) where {T,F,I<:Tuple}
    rand.(d.pars)
end

###############################################################################
# I <: AbstractArray

marginals(d::ProductMeasure{F,A}) where {F,A<:AbstractArray} = mappedarray(d.f, d.pars)

function logdensity(d::ProductMeasure, x)
    mapreduce(logdensity, +, marginals(d), x)
end

function Base.show(io::IO, d::ProductMeasure{F,A}) where {F,A<:AbstractArray}
    io = IOContext(io, :compact => true)
    print(io, "For(")
    print(io, d.f, ", ")
    print(io, d.pars, ")")
end


###############################################################################
# I <: CartesianIndices

function Base.show(io::IO, d::ProductMeasure{F,I}) where {F, I<:CartesianIndices}
    io = IOContext(io, :compact => true)
    print(io, "For(")
    print(io, d.f, ", ")
    join(io, size(d.pars), ", ")
    print(io, ")")
end


# function Base.rand(rng::AbstractRNG, ::Type{T}, d::ProductMeasure{F,I}) where {T,F,I<:CartesianIndices}

# end

###############################################################################
# I <: Base.Generator


export rand!
using Random: rand!, GLOBAL_RNG, AbstractRNG


function logdensity(d::ProductMeasure{F,I}, x) where {F, I<:Base.Generator}
    sum((logdensity(dj, xj) for (dj, xj) in zip(marginals(d), x)))
end


function Base.rand(rng::AbstractRNG, ::Type{T}, d::ProductMeasure{F,I}) where {T,F,I<:Base.Generator}
    mar = marginals(d)
    elT = typeof(rand(rng, T, first(mar)))

    sz = size(mar)
    r = ResettableRNG(rng, rand(rng, UInt))
    Base.Generator(s -> rand(r, d.pars.f(s)), d.pars.iter)
end


@propagate_inbounds function Random.rand!(rng::AbstractRNG, d::ProductMeasure, x::AbstractArray)
    # TODO: Generalize this
    T = Float64
    for(j,m) in zip(eachindex(x), marginals(d))
        @inbounds x[j] = rand(rng, T, m)
    end
    return x
end






export rand!
using Random: rand!, GLOBAL_RNG, AbstractRNG

function Base.rand(rng::AbstractRNG, ::Type{T}, d::ProductMeasure) where {T}
    d1 = d.f(first(d.pars))
    rand(rng, T, d, d1)
end

function Base.rand(rng::AbstractRNG, ::Type{T}, d::ProductMeasure, d1::AbstractMeasure) where {T}
    mar = marginals(d)
    elT = typeof(rand(rng, T, first(mar)))

    sz = size(mar)
    x = Array{elT, length(sz)}(undef, sz)
    rand!(rng, d, x)
end

# TODO: 
# function Base.rand(rng::AbstractRNG, d::ProductMeasure)
#     return rand(rng, sampletype(d), d)
# end

# function Base.rand(T::Type, d::ProductMeasure)
#     return rand(Random.GLOBAL_RNG, T, d)
# end

# function Base.rand(d::ProductMeasure)
#     T = sampletype(d)
#     return rand(Random.GLOBAL_RNG, T, d)
# end

function sampletype(d::ProductMeasure{A}) where {T,N,A <: AbstractArray{T,N}}
    S = @inbounds sampletype(marginals(d)[1])
    Array{S, N}
end

function sampletype(d::ProductMeasure{<: Tuple}) 
    Tuple{sampletype.(marginals(d))...}
end


# function logdensity(μ::ProductMeasure{Aμ}, x::Ax) where {Aμ <: MappedArray, Ax <: AbstractArray}
#     μ.data
# end

function ConstructionBase.constructorof(::Type{P}) where {F,I,P <: ProductMeasure{F,I}}
    p -> ProductMeasure(d.f, p)
end

# function Accessors.set(d::ProductMeasure{N}, ::typeof(params), p) where {N}
#     setproperties(d, NamedTuple{N}(p...))
# end


# function Accessors.set(d::ProductMeasure{F,T}, ::typeof(params), p::Tuple) where {F, T<:Tuple}
#     set.(marginals(d), params, p)
# end