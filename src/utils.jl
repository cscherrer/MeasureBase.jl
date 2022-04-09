const EmptyNamedTuple = NamedTuple{(),Tuple{}}

function Base.show(io::IO, μ::AbstractMeasure)
    io = IOContext(io, :compact => true)
    Pretty.pprint(io, μ)
end

showparams(io::IO, ::EmptyNamedTuple) = print(io, "()")
showparams(io::IO, nt::NamedTuple) = print(io, nt)


export testvalue
testvalue(μ::AbstractMeasure) = testvalue(basemeasure(μ))
testvalue(::Type{T}) where {T} = zero(T)

export rootmeasure

basemeasure(μ, x) = basemeasure(μ)

"""
    rootmeasure(μ::AbstractMeasure)

It's sometimes important to be able to find the fix point of a measure under
`basemeasure`. That is, to start with some measure and apply `basemeasure`
repeatedly until there's no change. That's what this does.
"""
@inline function rootmeasure(μ)
    n = basemeasure_depth(μ)
    _rootmeasure(μ, static(n))
end

@generated function _rootmeasure(μ, ::StaticInt{n}) where {n}
    q = quote end
    foreach(1:n) do _
        push!(q.args, :(μ = basemeasure(μ)))
    end
    return q
end

# Base on the Tricks.jl README
using Tricks
struct Iterable end
struct NonIterable end
function isiterable(::Type{T}) where {T}
    static_hasmethod(iterate, Tuple{T}) ? Iterable() : NonIterable()
end

# issingletontype(@nospecialize(t)) = (@_pure_meta; isa(t, DataType) && isdefined(t, :instance))


@generated function instance(::Type{T}) where {T}
    return getfield(T, :instance)::T
end

# See https://github.com/cscherrer/KeywordCalls.jl/issues/22
@inline instance_type(f::F) where {F} = F
@inline instance_type(T::UnionAll) = Type{<:T}
@inline instance_type(T::DataType) = Type{T}

export basemeasure_depth

@inline function basemeasure_depth(μ::M) where {M}
    b_0 = μ
    Base.Cartesian.@nexprs 10 i -> begin  # 10 is just some "big enough" number
        b_{i} = basemeasure(b_{i-1})
        if b_{i} isa typeof(b_{i-1})
            return static(i-1)
        end
    end
    return static(10)
end

"""
    basemeasure_sequence(m)

Construct the longest `Tuple` starting with `m` having each term as the base
measure of the previous term, and with no repeated entries.
"""
@inline function basemeasure_sequence(μ::M) where {M}
    b_1 = μ
    done = false
    Base.Cartesian.@nexprs 10 i -> begin  # 10 is just some "big enough" number
        b_{i+1} = if done nothing else basemeasure(b_{i}) end
        if b_{i+1} isa typeof(b_{i})
            done = true
            b_{i+1} = nothing
        end
    end
    return filter(!isnothing, Base.Cartesian.@ntuple 10 b)
end

@inline function commonbase(μ, ν)
    return commonbase(basemeasure_sequence(μ), basemeasure_sequence(ν))
end

@generated function commonbase(μ::M, ν::N) where {M<:Tuple,N<:Tuple}
    m = schema(M)
    n = schema(N)

    sols = Iterators.filter(((i,j),) ->  static_hasmethod(logdensity_def, Tuple{m[i], n[j], Any}), Iterators.product(1:length(m), 1:length(n))) 
    isempty(sols) && return :(nothing)
    minsol = static.(argmin(((i,j),) -> i+j, sols))
    quote
        $minsol
    end
end

mymap(f, gen::Base.Generator) = mymap(f ∘ gen.f, gen.iter)
mymap(f, inds...) = Iterators.map(f, inds...)

function infer_zero(f, args...)
    inferred_type = Core.Compiler.return_type(f, typeof.(args))
    zero(typeintersect(AbstractFloat, inferred_type))
end

@inline function allequal(f, x::AbstractArray)
    val = f(first(x))
    @simd for xj in x
        f(xj) == val || return false
    end
    return true
end


allequal(x::AbstractArray) = allequal(identity, x)
