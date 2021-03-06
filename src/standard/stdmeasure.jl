abstract type StdMeasure <: AbstractMeasure end

StdMeasure(::typeof(rand)) = StdUniform()
StdMeasure(::typeof(randexp)) = StdExponential()

@inline check_dof(::StdMeasure, ::StdMeasure) = nothing

@inline transport_def(::MU, μ::MU, x) where {MU<:StdMeasure} = x

function transport_def(ν::StdMeasure, μ::PowerMeasure{<:StdMeasure}, x)
    return transport_def(ν, μ.parent, only(x))
end

function transport_def(ν::PowerMeasure{<:StdMeasure}, μ::StdMeasure, x)
    return Fill(transport_def(ν.parent, μ, only(x)), map(length, ν.axes)...)
end

function transport_def(
    ν::PowerMeasure{<:StdMeasure,<:NTuple{1,Base.OneTo}},
    μ::PowerMeasure{<:StdMeasure,<:NTuple{1,Base.OneTo}},
    x,
)
    return transport_to(ν.parent, μ.parent).(x)
end

function transport_def(
    ν::PowerMeasure{<:StdMeasure,<:NTuple{N,Base.OneTo}},
    μ::PowerMeasure{<:StdMeasure,<:NTuple{M,Base.OneTo}},
    x,
) where {N,M}
    return reshape(transport_to(ν.parent, μ.parent).(x), map(length, ν.axes)...)
end

# Implement transport_to(NU::Type{<:StdMeasure}, μ) and transport_to(ν, MU::Type{<:StdMeasure}):

_std_measure(::Type{M}, ::StaticInt{1}) where {M<:StdMeasure} = M()
_std_measure(::Type{M}, dof::Integer) where {M<:StdMeasure} = M()^dof
_std_measure_for(::Type{M}, μ::Any) where {M<:StdMeasure} = _std_measure(M, getdof(μ))

function transport_to(::Type{NU}, μ) where {NU<:StdMeasure}
    transport_to(_std_measure_for(NU, μ), μ)
end

function transport_to(ν, ::Type{MU}) where {MU<:StdMeasure}
    transport_to(ν, _std_measure_for(MU, ν))
end

# Transform between standard measures and Dirac:

@inline transport_def(ν::Dirac, ::PowerMeasure{<:StdMeasure}, ::Any) = ν.x

@inline function transport_def(ν::PowerMeasure{<:StdMeasure}, ::Dirac, ::Any)
    Zeros{Bool}(map(_ -> 0, ν.axes))
end
