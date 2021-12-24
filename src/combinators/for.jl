
export For
using Random
import Base

struct For{T, F, I} <: AbstractProductMeasure
    f::F
    inds::I

    function For(f::F, inds::I) where {F,I<:Tuple}
        T = Core.Compiler.return_type(f, Tuple{_eltype.(inds)...})
        new{T,instance_type(f),I}(f, inds)
    end

    For{T,F,I}(f::F, inds::I) where {T,F,I} = new{T,F,I}(f,inds)
end

# For(f, gen::Base.Generator) = ProductMeasure(Base.Generator(f ∘ gen.f, gen.iter))

function logdensity_def(d::For{T,F,I}, x) where {N,T,F,I<:NTuple{N,<:Base.Generator}}
    sum(zip(x, d.inds...)) do (xⱼ, dⱼ...)
        logdensity_def(d.f(dⱼ...), xⱼ)
    end
end

function marginals(d::For{T,F,I}) where {N,T,F,I<:NTuple{N,<:Base.Generator}}
    Iterators.map(d.f, d.inds...)
end


function basemeasure(μ::For{T,F,I}) where {T,F,I}
    mar = marginals(μ)
    if static_hasmethod(tbasemeasure_type, Tuple{Type{T}})
        B = tbasemeasure_type(T)
        if Base.issingletontype(B)
            b = instance(B)::B
            return b ^ axes(mar)
        else
            new_f = basemeasure ∘ μ.f
            For{B,typeof(new_f),I}(new_f, μ.inds)
        end
    else
        return productmeasure(basemeasure.(mar))
    end
end

function basemeasure(d::For{T,F,I}) where {N,T,F,I<:NTuple{N,<:Base.Generator}}
    B = tbasemeasure_type(T)
    if static_hasmethod(tbasemeasure_type, Tuple{Type{T}}) && Base.issingletontype(B) 
        b = instance(B)
        return quote
            $b ^ minimum(length, d.inds)
        end
    else
        return quote
            For(basekleisli(d.f), d.inds)
        end
    end   
end

@inline function tbasemeasure_type(::Type{For{T, F, I}}) where {T,F,I}
    B = tbasemeasure_type(T)
    return tbasemeasure_type(For{T, F, I}, B)
end

@inline function tbasemeasure_type(::Type{For{T, F, I}}, ::Type{B}) where {B,T,F,I}
    _tbasemeasure_type(For{T, F, I}, B, static(Base.issingletontype(B)))
end

@inline function _tbasemeasure_type(::Type{For{T, F, I}}, ::Type{B}, ::True) where {B,T,F,I}
    return PowerMeasure{B, I}
end

@inline function _tbasemeasure_type(::Type{For{T, F, I}}, ::Type{B}, ::False) where {B,T,F,I}
    return For{B, typeof(basekleisli(instance(F))), I}
end

@inline function basemeasure_depth(d::For{T,F,I}) where {N,T,F,I<:NTuple{N,<:Base.Generator}}
    invoke(basemeasure_depth, Tuple{AbstractMeasure}, d)
end

function Pretty.tile(d::For{T}) where {T}
    result = Pretty.literal("For{")
    result *= Pretty.tile(T)
    result *= Pretty.literal("}(")
    result *= Pretty.literal(func_string(d.f, Tuple{_eltype.(d.inds)...}))
    for ind in d.inds
        result *= Pretty.literal(", ")
        result *= Pretty.tile(ind)
    end
    result *= Pretty.literal(")")
end

marginals(d::For) = mappedarray(d.f, d.inds...)



"""
    For(f, base...)

`For` provides a convenient way to construct a `ProductMeasure`. There are
several options for the `base`. With Julia's `do` notation, this can look very
similar to a standard `for` loop, while maintaining semantics structure that's
easier to work with.

------------

# `For(f, base::Int...)`

When one or several `Int` values are passed for `base`, the result is treated as
depending on `CartesianIndices(base)`. 

```
julia> For(3) do λ Exponential(λ) end |> marginals
3-element mappedarray(MeasureBase.var"#17#18"{var"#15#16"}(var"#15#16"()), ::CartesianIndices{1, Tuple{Base.OneTo{Int64}}}) with eltype Exponential{(:λ,), Tuple{Int64}}:
 Exponential(λ = 1,)
 Exponential(λ = 2,)
 Exponential(λ = 3,)
```

```
julia> For(4,3) do μ,σ Normal(μ,σ) end |> marginals
4×3 mappedarray(MeasureBase.var"#17#18"{var"#11#12"}(var"#11#12"()), ::CartesianIndices{2, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}}) with eltype Normal{(:μ, :σ), Tuple{Int64, Int64}}:
 Normal(μ = 1, σ = 1)  Normal(μ = 1, σ = 2)  Normal(μ = 1, σ = 3)
 Normal(μ = 2, σ = 1)  Normal(μ = 2, σ = 2)  Normal(μ = 2, σ = 3)
 Normal(μ = 3, σ = 1)  Normal(μ = 3, σ = 2)  Normal(μ = 3, σ = 3)
 Normal(μ = 4, σ = 1)  Normal(μ = 4, σ = 2)  Normal(μ = 4, σ = 3)
```

-------

# `For(f, base::AbstractArray...)``

In this case, `base` behaves as if the arrays are `zip`ped together before
applying the map.

```
julia> For(randn(3)) do x Exponential(x) end |> marginals
3-element mappedarray(x->Main.Exponential(x), ::Vector{Float64}) with eltype Exponential{(:λ,), Tuple{Float64}}:
 Exponential(λ = -0.268256,)
 Exponential(λ = 1.53044,)
 Exponential(λ = -1.08839,)
```

```
julia> For(1:3, 1:3) do μ,σ Normal(μ,σ) end |> marginals
3-element mappedarray((:μ, :σ)->Main.Normal(μ, σ), ::UnitRange{Int64}, ::UnitRange{Int64}) with eltype Normal{(:μ, :σ), Tuple{Int64, Int64}}:
 Normal(μ = 1, σ = 1)
 Normal(μ = 2, σ = 2)
 Normal(μ = 3, σ = 3)
```

----

# `For(f, base::Base.Generator)`

For `Generator`s, the function maps over the values of the generator:

```
julia> For(eachrow(rand(4,2))) do x Normal(x[1], x[2]) end |> marginals |> collect
4-element Vector{Normal{(:μ, :σ), Tuple{Float64, Float64}}}:
 Normal(μ = 0.255024, σ = 0.570142)
 Normal(μ = 0.970706, σ = 0.0776745)
 Normal(μ = 0.731491, σ = 0.505837)
 Normal(μ = 0.563112, σ = 0.98307)
```

"""
For(f, inds...) = For(f, inds)
For(f, n::Integer) = For(f, Base.OneTo(n))
For(f, inds::Integer...) = For(i -> f(Tuple(i)...), Base.CartesianIndices(inds))
# For(f, inds::Base.Generator) = productmeasure(mymap(f, inds))

function Random.rand!(rng::AbstractRNG, d::For, x) 
    mar = marginals(d)
    @inbounds for (dⱼ, j) in zip(marginals(d), eachindex(x))
        x[j] = rand(rng,dⱼ)
    end
    return x
end

