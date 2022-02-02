using LinearAlgebra
using StaticArrays
using Infiltrator
using BenchmarkTools

const Vec3{T} = SVector{3, T}
const Mat33{T} = SMatrix{3, 3, T, 9}
const ID3 = Diagonal(@SVector [1,1,1])



# Rotate using Rodrigue's formula
@inline function rotation_matrix(Θ::AbstractVecOrMat{T}) where T
    
    Θ_norm = norm(Θ)
    if Θ_norm > 10*eps(T)
        sinΘ, cosΘ = sincos(Θ_norm)
        SΘ = skew(Θ)
        R = ID3 + sinΘ/Θ_norm*SΘ +  2*(sin(Θ_norm/2)/Θ_norm)^2 * SΘ*SΘ
        return R
    else
        return SMatrix{3,3,T,9}(1,0,0,0,1,0,0,0,1)
    end

end


@inline function local_R⁰(x₁, x₂)

    v₁ = x₂ - x₁
    l = norm(v₁)
    v₁ = v₁/l
    e₂ = @SVector [0,1,0]
    e₃ = @SVector [0,0,1]

    if ( v₁[1] > 1e-8*l ) || ( v₁[2] > 1e-8*l )
        aux = cross(e₃, v₁)
        v₂ = aux/norm(aux)
    else
        T = eltype(v₁)
        v₂ = T.(e₂)
    end
    
    v₃ = cross(v₁, v₂)

    Rₑ = [v₁ v₂ v₃]

    return Rₑ

end


    



@inline function local_Rₑ_and_aux(x₁, x₂, R₁, R₂, Rₑ⁰E₂, lₙ)

    v₁ = (x₂ - x₁)/lₙ
    p₁ = R₁ * Rₑ⁰E₂
    p₂ = R₂ * Rₑ⁰E₂
    p = (p₁+p₂)/2
    v₃ = cross(v₁, p)
    v₃ = v₃ / norm(v₃)
    v₂ = cross(v₃, v₁)

    Rₑ = [v₁ v₂ v₃]

    ru₁ = -v₁'
    ru₂ = v₁'

    Rₑ¹²ᵀ = Rₑ[:, SOneTo(2)]'

    q₁, q₂ = Rₑ¹²ᵀ*p
    q¹¹, q¹² = Rₑ¹²ᵀ*p₁
    q²¹, q²² = Rₑ¹²ᵀ*p₂
    
    η = q₁/q₂
    η¹¹ = q¹¹/q₂
    η¹² = q¹²/q₂
    η²¹ = q²¹/q₂
    η²² = q²²/q₂

    Gᵀu₁ = @SMatrix [0 0 η/lₙ; 0 0 1/lₙ; 0 -1/lₙ 0]
    GᵀΘ₁ = @SMatrix [η¹²/2 -η¹¹/2 0; 0 0 0; 0 0 0]
    Gᵀu₂ = -Gᵀu₁
    GᵀΘ₂ = @SMatrix [η²²/2 -η²¹/2 0; 0 0 0; 0 0 0]

    D₃ = (ID3 - v₁*v₁')/lₙ

    return Rₑ, ru₁, ru₂, η, (η¹¹, η¹², η²¹, η²²), Gᵀu₁, GᵀΘ₁, Gᵀu₂, GᵀΘ₂, D₃
end




@inline function toangle(R::AbstractMatrix{T}) where T

    if abs((tr(R)-1)/2) < 1
        norm_v = max(acos((tr(R)-1)/2), 10*eps(T))
    else
        norm_v = 10*eps(T)
    end

    n_v = (1/(2*sin(norm_v))) * @SVector [R[3,2]-R[2,3], R[1,3]-R[3,1], R[2,1]-R[1,2]]

    return norm_v*n_v

end


@inline function skew(vec)

    return @SMatrix [0       -vec[3] vec[2] ;
                     vec[3]  0       -vec[1];
                     -vec[2] vec[1]  0      ]

end

# Get the inverse of skew symmetric matrix from toangle
@inline function Tₛ⁻¹(Θ::AbstractVector{T}) where T

    Θ_norm = norm(Θ)

    if Θ_norm < 10*eps(T)
        Tₛ⁻¹ = SMatrix{3,3,T,9}(1,0,0,0,1,0,0,0,1)
    else
        SΘ = skew(Θ)
        sinΘ2, cosΘ2 = sincos(Θ_norm/2)
        Tₛ⁻¹ = ID3 - SΘ/2 + (sinΘ2-Θ_norm/2*cosΘ2)/(sinΘ2*Θ_norm^2)*SΘ*SΘ
    end

    return Tₛ⁻¹

end


@inline function Tₛ(Θ::AbstractVector{T}) where T

    Θ_norm = norm(Θ)

    if Θ_norm < 10*eps(T)
        Tₛ = SMatrix{3,3,T,9}(1, 0, 0, 0, 1, 0, 0, 0, 1)
    else
        sinΘ, cosΘ = sincos(Θ_norm)
        SΘ = skew(Θ)
        Tₛ = ID3 + 2*(sin(Θ_norm/2)/Θ_norm)^2*SΘ + (1-sin(Θ_norm)/Θ_norm)/Θ_norm^2*(SΘ*SΘ)
    end

    return Tₛ

end


@inline function compute_Kᵥ(Θ::AbstractVector{T}, v) where T

    Θnorm = norm(Θ)

    if Θnorm < 10*eps(T)
        Kᵥ = skew(v)/2
    else
        sinΘ, cosΘ = sincos(Θnorm)
        sinΘ2 = sin(Θnorm/2)
        aux₁ = (2*sinΘ2/Θnorm)^2

        u = Θ/Θnorm
        uvᶜ = cross(u, v)
        uvᵈ = dot(u,v)
        UU = u*u'
        VU = v*u'
        UV = u*v'
    
        Kᵥ =  (cosΘ-sinΘ/Θnorm)/Θnorm * (VU-uvᵈ*UU) + 
              (1-sinΘ/Θnorm)/Θnorm * (UV - 2*uvᵈ*UU + uvᵈ*ID3) -
              (sinΘ/Θnorm-aux₁) * (uvᶜ*u') +
              aux₁ * skew(v)/2
    
    end

    return Kᵥ

end


#  Compute Kⁱⁿᵗ matrix
@inline function K̄ᵢₙₜ_beam(mat, geom, l₀)
    
    K̄ᵢₙₜū = geom.A*mat.E/l₀
    K̄ᵢₙₜΘ̅ = Diagonal(@SVector [mat.G*geom.J/l₀, 4*mat.E*geom.I₃₃/l₀, 4*mat.E*geom.I₂₂/l₀])
    K̄ᵢₙₜΘ̅Θ̅ = Diagonal(@SVector [-mat.G*geom.J/l₀, 2*mat.E*geom.I₃₃/l₀, 2*mat.E*geom.I₂₂/l₀])
    
    return K̄ᵢₙₜū, K̄ᵢₙₜΘ̅, K̄ᵢₙₜΘ̅Θ̅
    
end


@inline function K̄ᵢₙₜ_beam12(mat, geom, l₀)
    
    K̄ᵢₙₜū = geom.A*mat.E/l₀
    K̄ᵢₙₜΘ̅ = @SMatrix [mat.G*geom.J/l₀ 0 0;
                      0 4*mat.E*geom.I₃₃/l₀ 0;
                      0 0 4*mat.E*geom.I₂₂/l₀]
    K̄ᵢₙₜΘ̅Θ̅ = @SMatrix [-mat.G*geom.J/l₀ 0 0;
                       0 2*mat.E*geom.I₃₃/l₀ 0;
                       0 0 2*mat.E*geom.I₂₂/l₀]

    O13 = @SMatrix zeros(1,3)
    O31 = @SMatrix zeros(3,1)

    K̄ᵢₙₜ = vcat(
        hcat(K̄ᵢₙₜū, O13, O13),
        hcat(O31, K̄ᵢₙₜΘ̅,  K̄ᵢₙₜΘ̅Θ̅),
        hcat(O31, K̄ᵢₙₜΘ̅Θ̅, K̄ᵢₙₜΘ̅))

    
    return K̄ᵢₙₜ
    
end


@inline function compute_η_μ(Θ̄::AbstractVector{T}) where T

    Θ = norm(Θ̄)

    if Θ<10*eps(T)
        η = T(1/12)
        μ = T(1/360)
    else
        sinΘ, cosΘ = sincos(Θ)
        sinΘ2 = sin(Θ/2)
        η = ((2*sinΘ)-Θ*(1+cosΘ))/(2*(Θ^2)*sinΘ)
        μ = (Θ*(Θ+sinΘ)-8*(sinΘ2)^2)/(4*(Θ^4)*(sinΘ2)^2)
    end
    
    return η, μ

end




@inline function compute_K̄ₕ(Θ̅, M̄, Tₛ⁻¹Θ̅, η, μ)

    Θ̅M̄ᵀ = Θ̅*M̄'
    M̄Θ̅ᵀ = Θ̅M̄ᵀ'

    SΘ̅ = skew(Θ̅)
    SM̄ = skew(M̄)

    K̄ₕ =  ( η*(Θ̅M̄ᵀ - 2*M̄Θ̅ᵀ + dot(Θ̅, M̄)*ID3) + μ*(SΘ̅*SΘ̅*M̄Θ̅ᵀ) - SM̄/2 ) * Tₛ⁻¹Θ̅

    return K̄ₕ

end




@inline function Pmatrices(N₁, N₂, N₃, N₄, N₅, N₆, lₙ, η, η₁₁, η₁₂, η₂₁, η₂₂)

    P₁P¹ = @SMatrix [0 0 0; 0 (N₃+N₄)/lₙ 0; 0 0 (N₃+N₄)/lₙ]
    P₁P² = @SMatrix [0 0 0; 0 0 N₃; 0 -N₃ 0]
    P₁P³ = -P₁P¹
    P₁P⁴ = @SMatrix [0 0 0; 0 0 N₄; 0 -N₄ 0]

    P₂P¹ = @SMatrix [0 0 -η*(N₁+N₂)/lₙ; 0 0 -(N₅+N₆)/lₙ; 0 (N₅+N₆)/lₙ 0]
    P₂P² = @SMatrix [-(N₂*η₁₂)/2-N₁*(η₁₂/2 - 1) (η₁₁*(N₁+N₂))/2 0; 0 N₅ 0; 0 0 N₆]
    P₂P³ = -P₂P¹
    P₂P⁴ = @SMatrix [-(N₁*η₂₂)/2-N₂*(η₂₂/2 - 1) (η₂₁*(N₁+N₂))/2 0; 0 N₅ 0; 0 0 N₆]


    return P₁P¹, P₁P², P₁P³, P₁P⁴, P₂P¹, P₂P², P₂P³, P₂P⁴

end




function compute(u₁, Θ₁, u₂, Θ₂, u̇₁, u̇₂, ẇ₁, ẇ₂, ü₁, ü₂, ẅ₁, ẅ₂, exact=false, additive=false, symmetrize=true)

    # Superscript ¹ means matrix or vector associated to u₁
    # Superscript ² means matrix or vector associated to Θ₁
    # Superscript ³ means matrix or vector associated to u₂
    # Superscript ⁴ means matrix or vector associated to Θ₂

    R₁ = rotation_matrix(Θ₁)
    R₂ = rotation_matrix(Θ₂)

    x₁ =  X₁ + u₁
    x₂ =  X₂ + u₂
    
    lₙ = norm(x₂ - x₁)

    ū = lₙ - l₀

    Rₑ, r¹, r³, η, ηs, Gᵀ¹, Gᵀ², Gᵀ³, Gᵀ⁴, D₃ = local_Rₑ_and_aux(x₁, x₂, R₁, R₂, Rₑ⁰[:,2], lₙ)


    R̅₁ = Rₑ' * R₁ * Rₑ⁰
    R̅₂ = Rₑ' * R₂ * Rₑ⁰

    Θ̅₁ = toangle(R̅₁)
    Θ̅₂ = toangle(R̅₂)

    if exact
        Tₛ⁻¹Θ̅₁ = Tₛ⁻¹(Θ̅₁)
        Tₛ⁻¹Θ̅₂ = Tₛ⁻¹(Θ̅₂)
    end


    P¹¹ = -Gᵀ¹ 
    P²¹ = P¹¹
    P¹² = ID3-Gᵀ²
    P²² = -Gᵀ²
    P¹³ = -Gᵀ³
    P²³ = P¹³
    P¹⁴ = -Gᵀ⁴
    P²⁴ = ID3-Gᵀ⁴


    # B̄⁺ = [r; PEᵀ]
    B̄⁺¹ = r¹
    B̄⁺³ = r³
    B̄⁺¹¹ = P¹¹ * Rₑ'
    B̄⁺²¹ = B̄⁺¹¹
    B̄⁺¹² = P¹² * Rₑ'
    B̄⁺²² = P²² * Rₑ'
    B̄⁺¹³ = P¹³ * Rₑ'
    B̄⁺²³ = B̄⁺¹³
    B̄⁺¹⁴ = P¹⁴ * Rₑ'
    B̄⁺²⁴ = P²⁴ * Rₑ'

    
    # B = B̄B̄⁺
    B¹ = B̄⁺¹
    B³ = B̄⁺³
    B¹¹ = exact ?  Tₛ⁻¹Θ̅₁ * B̄⁺¹¹ : B̄⁺¹¹
    B¹² = exact ?  Tₛ⁻¹Θ̅₁ * B̄⁺¹² : B̄⁺¹²
    B¹³ = exact ?  Tₛ⁻¹Θ̅₁ * B̄⁺¹³ : B̄⁺¹³
    B¹⁴ = exact ?  Tₛ⁻¹Θ̅₁ * B̄⁺¹⁴ : B̄⁺¹⁴
    B²¹ = exact ?  Tₛ⁻¹Θ̅₂ * B̄⁺²¹ : B̄⁺²¹
    B²² = exact ?  Tₛ⁻¹Θ̅₂ * B̄⁺²² : B̄⁺²²
    B²³ = exact ?  Tₛ⁻¹Θ̅₂ * B̄⁺²³ : B̄⁺²³
    B²⁴ = exact ?  Tₛ⁻¹Θ̅₂ * B̄⁺²⁴ : B̄⁺²⁴

    

    K̄ᵢₙₜū, K̄ᵢₙₜΘ̅, K̄ᵢₙₜΘ̅Θ̅ = K̄ᵢₙₜ_beam(mat, geom, l₀)

    # T̄ᵢₙₜ = K̄ᵢₙₜ D̄
    T̄ᵢₙₜū  = K̄ᵢₙₜū  * ū
    T̄ᵢₙₜΘ̅₁ = K̄ᵢₙₜΘ̅  * Θ̅₁ + K̄ᵢₙₜΘ̅Θ̅ * Θ̅₂
    T̄ᵢₙₜΘ̅₂ = K̄ᵢₙₜΘ̅Θ̅ * Θ̅₁ + K̄ᵢₙₜΘ̅  * Θ̅₂

    strain_energy = (ū*T̄ᵢₙₜū + dot(Θ̅₁, T̄ᵢₙₜΘ̅₁) + dot(Θ̅₂, T̄ᵢₙₜΘ̅₂))/2


    # Tᵢₙₜ = Bᵀ T̄ᵢₙₜ
    Tᵢₙₜ¹ = B¹'*T̄ᵢₙₜū + B¹¹'*T̄ᵢₙₜΘ̅₁ + B²¹'*T̄ᵢₙₜΘ̅₂
    Tᵢₙₜ² =             B¹²'*T̄ᵢₙₜΘ̅₁ + B²²'*T̄ᵢₙₜΘ̅₂
    Tᵢₙₜ³ = B³'*T̄ᵢₙₜū + B¹³'*T̄ᵢₙₜΘ̅₁ + B²³'*T̄ᵢₙₜΘ̅₂
    Tᵢₙₜ⁴ =             B¹⁴'*T̄ᵢₙₜΘ̅₁ + B²⁴'*T̄ᵢₙₜΘ̅₂

    if additive

        TₛΘ₁ = Tₛ(Θ₁)
        TₛΘ₂ = Tₛ(Θ₂)

        Tₑ¹ = Tᵢₙₜ¹
        Tₑ² = TₛΘ₁' * Tᵢₙₜ²
        Tₑ³ = Tᵢₙₜ³
        Tₑ⁴ = TₛΘ₂' * Tᵢₙₜ⁴

    else

        Tₑ¹ = Tᵢₙₜ¹
        Tₑ² = Tᵢₙₜ²
        Tₑ³ = Tᵢₙₜ³
        Tₑ⁴ = Tᵢₙₜ⁴

    end

    # Force
    Tₑ = [Tₑ¹; Tₑ²; Tₑ³; Tₑ⁴]


    # [N̄ M̄⁺₁ M̄⁺₂] = B̄ᵀ T̄ᵢₙₜ
    N̄   = T̄ᵢₙₜū
    M̄⁺₁ = exact ? Tₛ⁻¹Θ̅₁' * T̄ᵢₙₜΘ̅₁  : T̄ᵢₙₜΘ̅₁
    M̄⁺₂ = exact ? Tₛ⁻¹Θ̅₂' * T̄ᵢₙₜΘ̅₂  : T̄ᵢₙₜΘ̅₂


    # Qₛ = Pᵀ [M̄⁺₁ M̄⁺₂]
    Qₛ¹ = P¹¹' * M̄⁺₁ + P²¹' * M̄⁺₂
    Qₛ² = P¹²' * M̄⁺₁ + P²²' * M̄⁺₂
    Qₛ³ = P¹³' * M̄⁺₁ + P²³' * M̄⁺₂
    Qₛ⁴ = P¹⁴' * M̄⁺₁ + P²⁴' * M̄⁺₂
    

    # Q = S(Qₛ)
    Q¹ = skew(Qₛ¹)
    Q² = skew(Qₛ²)
    Q³ = skew(Qₛ³)
    Q⁴ = skew(Qₛ⁴)

    a = @SVector [0, η*(M̄⁺₁[1] + M̄⁺₂[1])/lₙ + (M̄⁺₁[2] + M̄⁺₂[2])/lₙ, (M̄⁺₁[3] + M̄⁺₂[3])/lₙ]


    # DN̄ (DN̄¹¹ = DN̄³³ = -DN̄¹³ = -DN̄³¹)
    DN̄¹¹ = D₃*N̄

    #QGᵀ
    QGᵀ¹¹ = Q¹*Gᵀ¹
    QGᵀ¹² = Q¹*Gᵀ²
    QGᵀ¹⁴ = Q¹*Gᵀ⁴

    QGᵀ²² = Q²*Gᵀ²
    QGᵀ²³ = Q²*Gᵀ³
    QGᵀ²⁴ = Q²*Gᵀ⁴

    QGᵀ³⁴ = Q³*Gᵀ⁴

    QGᵀ⁴⁴ = Q⁴*Gᵀ⁴

    if !symmetrize
        QGᵀ²¹ = Q²*Gᵀ¹
        QGᵀ³² = Q³*Gᵀ²
        QGᵀ⁴¹ = Q⁴*Gᵀ¹
        QGᵀ⁴² = Q⁴*Gᵀ²
        QGᵀ⁴³ = -QGᵀ⁴¹
    end


    # EGa (diagonal)
    # Note: Rₑ*Ga = 0 for Θ indices because Rₑ*GᵀΘ' has only non-zero values in the first column and a = [0 ...]
    EGa¹ = Rₑ*Gᵀ¹'*a

    # EGar (EGar¹¹ = EGar³³ = -EGar³¹ = -EGar¹³)
    EGar¹¹ = EGa¹*r¹

    # Kₘ = DN̄ - EQGᵀEᵀ + EGar
    Kₘ¹¹ = DN̄¹¹ - Rₑ*QGᵀ¹¹*Rₑ' + EGar¹¹
    Kₘ¹² =      - Rₑ*QGᵀ¹²*Rₑ'
    Kₘ¹³ = -Kₘ¹¹
    Kₘ¹⁴ =      - Rₑ*QGᵀ¹⁴*Rₑ'
    
    Kₘ²² =      - Rₑ*QGᵀ²²*Rₑ'
    Kₘ²³ =      - Rₑ*QGᵀ²³*Rₑ'
    Kₘ²⁴ =      - Rₑ*QGᵀ²⁴*Rₑ'

    Kₘ³³ = Kₘ¹¹
    Kₘ³⁴ =      - Rₑ*QGᵀ³⁴*Rₑ'

    Kₘ⁴⁴ =      - Rₑ*QGᵀ⁴⁴*Rₑ'

    if !symmetrize
        Kₘ²¹ =      - Rₑ*QGᵀ²¹*Rₑ'
        Kₘ³¹ = Kₘ¹³
        Kₘ³² =      - Rₑ*QGᵀ³²*Rₑ'
        Kₘ⁴¹ =      - Rₑ*QGᵀ⁴¹*Rₑ'
        Kₘ⁴² =      - Rₑ*QGᵀ⁴²*Rₑ'
        Kₘ⁴³ =      - Rₑ*QGᵀ⁴³*Rₑ'
    end


    # K̃

    if exact

        η₁, μ₁ = compute_η_μ(Θ̅₁)
        η₂, μ₂ = compute_η_μ(Θ̅₂)

        M̄₁ = T̄ᵢₙₜΘ̅₁
        M̄₂ = T̄ᵢₙₜΘ̅₂

        K̄ₕ₁ = compute_K̄ₕ(Θ̅₁, M̄₁, Tₛ⁻¹Θ̅₁, η₁, μ₁)
        K̄ₕ₂ = compute_K̄ₕ(Θ̅₂, M̄₂, Tₛ⁻¹Θ̅₂, η₂, μ₂)

    end


    K̃¹¹ = exact ?  B̄⁺¹¹' * K̄ₕ₁ * B̄⁺¹¹  +  B̄⁺²¹' * K̄ₕ₂ * B̄⁺²¹  +  Kₘ¹¹   :   Kₘ¹¹ 
    K̃¹² = exact ?  B̄⁺¹¹' * K̄ₕ₁ * B̄⁺¹²  +  B̄⁺²¹' * K̄ₕ₂ * B̄⁺²²  +  Kₘ¹²   :   Kₘ¹² 
    K̃¹³ = exact ?  B̄⁺¹¹' * K̄ₕ₁ * B̄⁺¹³  +  B̄⁺²¹' * K̄ₕ₂ * B̄⁺²³  +  Kₘ¹³   :   Kₘ¹³ 
    K̃¹⁴ = exact ?  B̄⁺¹¹' * K̄ₕ₁ * B̄⁺¹⁴  +  B̄⁺²¹' * K̄ₕ₂ * B̄⁺²⁴  +  Kₘ¹⁴   :   Kₘ¹⁴ 

    K̃²² = exact ?  B̄⁺¹²' * K̄ₕ₁ * B̄⁺¹²  +  B̄⁺²²' * K̄ₕ₂ * B̄⁺²²  +  Kₘ²²   :   Kₘ²² 
    K̃²³ = exact ?  B̄⁺¹²' * K̄ₕ₁ * B̄⁺¹³  +  B̄⁺²²' * K̄ₕ₂ * B̄⁺²³  +  Kₘ²³   :   Kₘ²³ 
    K̃²⁴ = exact ?  B̄⁺¹²' * K̄ₕ₁ * B̄⁺¹⁴  +  B̄⁺²²' * K̄ₕ₂ * B̄⁺²⁴  +  Kₘ²⁴   :   Kₘ²⁴ 

    K̃³³ = exact ?  B̄⁺¹³' * K̄ₕ₁ * B̄⁺¹³  +  B̄⁺²³' * K̄ₕ₂ * B̄⁺²³  +  Kₘ³³   :   Kₘ³³ 
    K̃³⁴ = exact ?  B̄⁺¹³' * K̄ₕ₁ * B̄⁺¹⁴  +  B̄⁺²³' * K̄ₕ₂ * B̄⁺²⁴  +  Kₘ³⁴   :   Kₘ³⁴ 

    K̃⁴⁴ = exact ?  B̄⁺¹⁴' * K̄ₕ₁ * B̄⁺¹⁴  +  B̄⁺²⁴' * K̄ₕ₂ * B̄⁺²⁴  +  Kₘ⁴⁴   :   Kₘ⁴⁴ 

    if !symmetrize

        K̃²¹ = exact ?  B̄⁺¹²' * K̄ₕ₁ * B̄⁺¹¹  +  B̄⁺²²' * K̄ₕ₂ * B̄⁺²¹  +  Kₘ²¹   :   Kₘ²¹ 
        K̃³¹ = exact ?  B̄⁺¹³' * K̄ₕ₁ * B̄⁺¹¹  +  B̄⁺²³' * K̄ₕ₂ * B̄⁺²¹  +  Kₘ³¹   :   Kₘ³¹ 
        K̃³² = exact ?  B̄⁺¹³' * K̄ₕ₁ * B̄⁺¹²  +  B̄⁺²³' * K̄ₕ₂ * B̄⁺²²  +  Kₘ³²   :   Kₘ³² 
        K̃⁴¹ = exact ?  B̄⁺¹⁴' * K̄ₕ₁ * B̄⁺¹¹  +  B̄⁺²⁴' * K̄ₕ₂ * B̄⁺²¹  +  Kₘ⁴¹   :   Kₘ⁴¹ 
        K̃⁴² = exact ?  B̄⁺¹⁴' * K̄ₕ₁ * B̄⁺¹²  +  B̄⁺²⁴' * K̄ₕ₂ * B̄⁺²²  +  Kₘ⁴²   :   Kₘ⁴² 
        K̃⁴³ = exact ?  B̄⁺¹⁴' * K̄ₕ₁ * B̄⁺¹³  +  B̄⁺²⁴' * K̄ₕ₂ * B̄⁺²³  +  Kₘ⁴³   :   Kₘ⁴³ 

    end


    # BᵀKᵢₙₜB
    
    BᵀKᵢₙₜB¹¹ = B¹' * K̄ᵢₙₜū * B¹      +      B¹¹' * (K̄ᵢₙₜΘ̅ * B¹¹  +  K̄ᵢₙₜΘ̅Θ̅ * B²¹)  +  B²¹' * (K̄ᵢₙₜΘ̅Θ̅ * B¹¹  +  K̄ᵢₙₜΘ̅ * B²¹)    
    BᵀKᵢₙₜB¹² =                              B¹¹' * (K̄ᵢₙₜΘ̅ * B¹²  +  K̄ᵢₙₜΘ̅Θ̅ * B²²)  +  B²¹' * (K̄ᵢₙₜΘ̅Θ̅ * B¹²  +  K̄ᵢₙₜΘ̅ * B²²)    
    BᵀKᵢₙₜB¹³ = B¹' * K̄ᵢₙₜū * B³      +      B¹¹' * (K̄ᵢₙₜΘ̅ * B¹³  +  K̄ᵢₙₜΘ̅Θ̅ * B²³)  +  B²¹' * (K̄ᵢₙₜΘ̅Θ̅ * B¹³  +  K̄ᵢₙₜΘ̅ * B²³)    
    BᵀKᵢₙₜB¹⁴ =                              B¹¹' * (K̄ᵢₙₜΘ̅ * B¹⁴  +  K̄ᵢₙₜΘ̅Θ̅ * B²⁴)  +  B²¹' * (K̄ᵢₙₜΘ̅Θ̅ * B¹⁴  +  K̄ᵢₙₜΘ̅ * B²⁴)    
        
    BᵀKᵢₙₜB²² =                              B¹²' * (K̄ᵢₙₜΘ̅ * B¹²  +  K̄ᵢₙₜΘ̅Θ̅ * B²²)  +  B²²' * (K̄ᵢₙₜΘ̅Θ̅ * B¹²  +  K̄ᵢₙₜΘ̅ * B²²)    
    BᵀKᵢₙₜB²³ =                              B¹²' * (K̄ᵢₙₜΘ̅ * B¹³  +  K̄ᵢₙₜΘ̅Θ̅ * B²³)  +  B²²' * (K̄ᵢₙₜΘ̅Θ̅ * B¹³  +  K̄ᵢₙₜΘ̅ * B²³)    
    BᵀKᵢₙₜB²⁴ =                              B¹²' * (K̄ᵢₙₜΘ̅ * B¹⁴  +  K̄ᵢₙₜΘ̅Θ̅ * B²⁴)  +  B²²' * (K̄ᵢₙₜΘ̅Θ̅ * B¹⁴  +  K̄ᵢₙₜΘ̅ * B²⁴)    
       
    BᵀKᵢₙₜB³³ = B³' * K̄ᵢₙₜū * B³      +      B¹³' * (K̄ᵢₙₜΘ̅ * B¹³  +  K̄ᵢₙₜΘ̅Θ̅ * B²³)  +  B²³' * (K̄ᵢₙₜΘ̅Θ̅ * B¹³  +  K̄ᵢₙₜΘ̅ * B²³)    
    BᵀKᵢₙₜB³⁴ =                              B¹³' * (K̄ᵢₙₜΘ̅ * B¹⁴  +  K̄ᵢₙₜΘ̅Θ̅ * B²⁴)  +  B²³' * (K̄ᵢₙₜΘ̅Θ̅ * B¹⁴  +  K̄ᵢₙₜΘ̅ * B²⁴)    
        
    BᵀKᵢₙₜB⁴⁴ =                              B¹⁴' * (K̄ᵢₙₜΘ̅ * B¹⁴  +  K̄ᵢₙₜΘ̅Θ̅ * B²⁴)  +  B²⁴' * (K̄ᵢₙₜΘ̅Θ̅ * B¹⁴  +  K̄ᵢₙₜΘ̅ * B²⁴)    

    Kᵢₙₜ¹¹ =  BᵀKᵢₙₜB¹¹   +    K̃¹¹
    Kᵢₙₜ¹² =  BᵀKᵢₙₜB¹²   +    K̃¹²
    Kᵢₙₜ¹³ =  BᵀKᵢₙₜB¹³   +    K̃¹³
    Kᵢₙₜ¹⁴ =  BᵀKᵢₙₜB¹⁴   +    K̃¹⁴

    Kᵢₙₜ²² =  BᵀKᵢₙₜB²²   +    K̃²²
    Kᵢₙₜ²³ =  BᵀKᵢₙₜB²³   +    K̃²³
    Kᵢₙₜ²⁴ =  BᵀKᵢₙₜB²⁴   +    K̃²⁴
    
    Kᵢₙₜ³³ =  BᵀKᵢₙₜB³³   +    K̃³³
    Kᵢₙₜ³⁴ =  BᵀKᵢₙₜB³⁴   +    K̃³⁴

    Kᵢₙₜ⁴⁴ =  BᵀKᵢₙₜB⁴⁴   +    K̃⁴⁴

    if !symmetrize
        Kᵢₙₜ²¹ =  BᵀKᵢₙₜB¹²'  +    K̃²¹
        Kᵢₙₜ³¹ =  BᵀKᵢₙₜB¹³'  +    K̃³¹
        Kᵢₙₜ³² =  BᵀKᵢₙₜB²³'  +    K̃³²
        Kᵢₙₜ⁴¹ =  BᵀKᵢₙₜB¹⁴'  +    K̃⁴¹
        Kᵢₙₜ⁴² =  BᵀKᵢₙₜB²⁴'  +    K̃⁴²
        Kᵢₙₜ⁴³ =  BᵀKᵢₙₜB³⁴'  +    K̃⁴³
    end

    if additive

        Kᵥ₁ = compute_Kᵥ(Θ₁, Tᵢₙₜ²)
        Kᵥ₂ = compute_Kᵥ(Θ₂, Tᵢₙₜ⁴)

        Kᵢₙₜ¹² =         Kᵢₙₜ¹² * TₛΘ₁
        Kᵢₙₜ¹⁴ =         Kᵢₙₜ¹⁴ * TₛΘ₂

        Kᵢₙₜ²¹ = TₛΘ₁' * Kᵢₙₜ²¹
        Kᵢₙₜ²² = TₛΘ₁' * Kᵢₙₜ²² * TₛΘ₁ + Kᵥ₁
        Kᵢₙₜ²³ = TₛΘ₁' * Kᵢₙₜ²³
        Kᵢₙₜ²⁴ = TₛΘ₁' * Kᵢₙₜ²⁴ * TₛΘ₂

        Kᵢₙₜ³² =         Kᵢₙₜ³² * TₛΘ₁
        Kᵢₙₜ³⁴ =         Kᵢₙₜ³⁴ * TₛΘ₂

        Kᵢₙₜ⁴¹ = TₛΘ₂' * Kᵢₙₜ⁴¹
        Kᵢₙₜ⁴² = TₛΘ₂' * Kᵢₙₜ⁴² * TₛΘ₁
        Kᵢₙₜ⁴³ = TₛΘ₂' * Kᵢₙₜ⁴³
        Kᵢₙₜ⁴⁴ = TₛΘ₂' * Kᵢₙₜ⁴⁴ * TₛΘ₂ + Kᵥ₂

    end

    if symmetrize
        K = hcat(vcat(Kᵢₙₜ¹¹, Kᵢₙₜ¹²', Kᵢₙₜ¹³', Kᵢₙₜ¹⁴'), vcat(Kᵢₙₜ¹², Kᵢₙₜ²², Kᵢₙₜ²³', Kᵢₙₜ²⁴'), vcat(Kᵢₙₜ¹³, Kᵢₙₜ²³, Kᵢₙₜ³³, Kᵢₙₜ³⁴'), vcat(Kᵢₙₜ¹⁴, Kᵢₙₜ²⁴, Kᵢₙₜ³⁴, Kᵢₙₜ⁴⁴))
    else
        K = hcat(vcat(Kᵢₙₜ¹¹, Kᵢₙₜ²¹, Kᵢₙₜ³¹, Kᵢₙₜ⁴¹), vcat(Kᵢₙₜ¹², Kᵢₙₜ²², Kᵢₙₜ³², Kᵢₙₜ⁴²), vcat(Kᵢₙₜ¹³, Kᵢₙₜ²³, Kᵢₙₜ³³, Kᵢₙₜ⁴³), vcat(Kᵢₙₜ¹⁴, Kᵢₙₜ²⁴, Kᵢₙₜ³⁴, Kᵢₙₜ⁴⁴))
    end


    # 
    U̇₁ = Rₑ' * u̇₁
    U̇₂ = Rₑ' * u̇₂
    Ẇ₁ = Rₑ' * ẇ₁
    Ẇ₂ = Rₑ' * ẇ₂
    
    Ü₁ = Rₑ' * ü₁
    Ü₂ = Rₑ' * ü₂
    Ẅ₁ = Rₑ' * ẅ₁
    Ẅ₂ = Rₑ' * ẅ₂

    SU̇₁ = skew(U̇₁)
    SU̇₂ = skew(U̇₂)
    SẆ₁ = skew(Ẇ₁)
    SẆ₂ = skew(Ẇ₂)

    Su̇₁ = skew(u̇₁)
    Su̇₂ = skew(u̇₂)
    Sẇ₁ = skew(ẇ₁)
    Sẇ₂ = skew(ẇ₂)

    Ẇᵉ = Gᵀ¹ * U̇₁ + Gᵀ² * Ẇ₁ + Gᵀ³ * U̇₂ + Gᵀ⁴ * Ẇ₂
    SẆᵉ = skew(Ẇᵉ)

    
    rḋ = dot(r¹, u̇₁) + dot(r³, u̇₂)
    
    

    
    
    T = Float64
    # initialise the local matrices used in the Gauss loop
    kinetic_energy = zero(T)
    
    Tₖ¹ = zeros(Vec3{T})
    Tₖ² = zeros(Vec3{T})
    Tₖ³ = zeros(Vec3{T})
    Tₖ⁴ = zeros(Vec3{T})

    M¹¹ = zeros(Mat33{T})
    M¹² = zeros(Mat33{T})
    M¹³ = zeros(Mat33{T})
    M¹⁴ = zeros(Mat33{T})
    M²² = zeros(Mat33{T})
    M²³ = zeros(Mat33{T})
    M²⁴ = zeros(Mat33{T})
    M³³ = zeros(Mat33{T})
    M³⁴ = zeros(Mat33{T})
    M⁴⁴ = zeros(Mat33{T})
    

    Cₖ¹¹ = zeros(Mat33{T})
    Cₖ¹² = zeros(Mat33{T})
    Cₖ¹³ = zeros(Mat33{T})
    Cₖ¹⁴ = zeros(Mat33{T})
    Cₖ²¹ = zeros(Mat33{T})
    Cₖ²² = zeros(Mat33{T})
    Cₖ²³ = zeros(Mat33{T})
    Cₖ²⁴ = zeros(Mat33{T})
    Cₖ³¹ = zeros(Mat33{T})
    Cₖ³² = zeros(Mat33{T})
    Cₖ³³ = zeros(Mat33{T})
    Cₖ³⁴ = zeros(Mat33{T})
    Cₖ⁴¹ = zeros(Mat33{T})
    Cₖ⁴² = zeros(Mat33{T})
    Cₖ⁴³ = zeros(Mat33{T})
    Cₖ⁴⁴ = zeros(Mat33{T})

    # cycle among the Gauss positions
    for iG in 1:comp.nᴳ

        zᴳ = comp.zᴳ[iG]
        ωᴳ = comp.ωᴳ[iG]

        ξ = l₀*(zᴳ+1)/2

        # Shape functions
        N₁ = 1-ξ/l₀
        N₂ = 1-N₁
        N₃ = ξ*(1-ξ/l₀)^2
        N₄ = -(1-ξ/l₀)*((ξ^2)/l₀)
        N₅ = (1-3*ξ/l₀)*(1-ξ/l₀)
        N₆ = (3*ξ/l₀-2)*(ξ/l₀)
        N₇ = N₃+N₄
        N₈ = N₅+N₆-1


        uᵗ = @SVector [0, N₃*Θ̅₁[3] + N₄*Θ̅₂[3], -N₃*Θ̅₁[2] + -N₄*Θ̅₂[2]]
        Θ̄  = @SVector [N₁*Θ̅₁[1] + N₂*Θ̅₂[1], N₅*Θ̅₁[2] + N₆*Θ̅₂[2], N₅*Θ̅₁[3] + N₆*Θ̅₂[3]]

        Suᵗ = skew(uᵗ)
        SΘ̄ = skew(Θ̄)

        R̄ = ID3 + SΘ̄

        Īᵨ = R̄*mat.Jᵨ*R̄'
        Aᵨ = mat.Aᵨ

        P₁P¹ = @SMatrix [0 0 0; 0 N₇/lₙ 0;0 0 N₇/lₙ]
        P₁P² = @SMatrix [0 0 0; 0 0 N₃;0 -N₃ 0]
        P₁P³ = -P₁P¹
        P₁P⁴ = @SMatrix [0 0 0; 0 0 N₄;0 -N₄ 0]

        H₁¹ = N₁*ID3 + P₁P¹ - Suᵗ*Gᵀ¹
        H₁² =          P₁P² - Suᵗ*Gᵀ²
        H₁³ = N₂*ID3 + P₁P³ - Suᵗ*Gᵀ³
        H₁⁴ =          P₁P⁴ - Suᵗ*Gᵀ⁴

        H₂¹ = @SMatrix [0 0 0; 0  0 -N₈/lₙ;0 N₈/lₙ 0]
        H₂² = Diagonal(@SVector [N₁, N₅, N₅])
        H₂³ = -H₂¹
        H₂⁴ = Diagonal(@SVector [N₂, N₆, N₆])

        u̇ᵗ =  P₁P¹ * U̇₁ +  P₁P² * Ẇ₁ + P₁P³ * U̇₂ + P₁P² * Ẇ₂

        Su̇ᵗ = skew(u̇ᵗ)
        
        N₇rḋ = N₇/lₙ^2 * rḋ
        Ḣ₁¹ = Diagonal(@SVector [0, -N₇rḋ, -N₇rḋ]) - Su̇ᵗ * Gᵀ¹
        Ḣ₁² =                                      - Su̇ᵗ * Gᵀ²
        Ḣ₁⁴ =                                      - Su̇ᵗ * Gᵀ⁴

        N₈rḋ = N₈/lₙ^2 * rḋ
        Ḣ₂¹ = @SMatrix [0 0 0; 0 0 N₈rḋ; 0 -N₈rḋ 0]

        # h₁ = H₁¹ * U̇₁ + H₁² * Ẇ₁ + H₁³ * U̇₂ + H₁⁴ * Ẇ₂
        # h₂ = H₂¹ * U̇₁ + H₂² * Ẇ₁ + H₂³ * U̇₂ + H₂⁴ * Ẇ₂
        h₁ = H₁¹ * u̇₁ + H₁² * ẇ₁ + H₁³ * u̇₂ + H₁⁴ * ẇ₂
        h₂ = H₂¹ * u̇₁ + H₂² * ẇ₁ + H₂³ * u̇₂ + H₂⁴ * ẇ₂
        Sh₁ = skew(h₁)
        Sh₂ = skew(h₂)

        C₁¹ = SẆᵉ * H₁¹ + Ḣ₁¹ - H₁¹ * SẆᵉ
        C₁² = SẆᵉ * H₁² + Ḣ₁² - H₁² * SẆᵉ
        C₁³ = -C₁¹
        C₁⁴ = SẆᵉ * H₁⁴ + Ḣ₁⁴ - H₁⁴ * SẆᵉ

        C₂¹ = SẆᵉ * H₂¹ + Ḣ₂¹ - H₂¹ * SẆᵉ
        C₂² = SẆᵉ * H₂²       - H₂² * SẆᵉ
        C₂³ = -C₂¹
        C₂⁴ = SẆᵉ * H₂⁴       - H₂⁴ * SẆᵉ

        # H₁F₁ = H₁¹ * SU̇₁ + H₁² * SẆ₁ + H₁³ * SU̇₂ + H₁⁴ * SẆ₂
        # H₂F₁ = H₂¹ * SU̇₁ + H₂² * SẆ₁ + H₂³ * SU̇₂ + H₂⁴ * SẆ₂
        H₁F₁ = H₁¹ * Su̇₁ + H₁² * Sẇ₁ + H₁³ * Su̇₂ + H₁⁴ * Sẇ₂
        H₂F₁ = H₂¹ * Su̇₁ + H₂² * Sẇ₁ + H₂³ * Su̇₂ + H₂⁴ * Sẇ₂

        A₁ḊrE¹ = @SMatrix [0 0 0; u̇₁[2]-u̇₂[2] 0 0; u̇₁[3]-u̇₂[3] 0 0]
        C₃¹ = -Sh₁*Gᵀ¹ + N₇/lₙ^2*A₁ḊrE¹ + SẆᵉ*P₁P¹ + H₁F₁*Gᵀ¹
        C₃² = -Sh₁*Gᵀ² +                  SẆᵉ*P₁P² + H₁F₁*Gᵀ²
        C₃³ = -C₃¹
        C₃⁴ = -Sh₁*Gᵀ⁴ +                  SẆᵉ*P₁P⁴ + H₁F₁*Gᵀ⁴

        A₂ḊrE¹ = @SMatrix [0 0 0; -u̇₁[3]+u̇₂[3] 0 0; u̇₁[2]-u̇₂[2] 0 0]
        C₄¹ = -Sh₂*Gᵀ¹ + N₈/lₙ^2*A₂ḊrE¹ + H₂F₁*Gᵀ¹
        C₄² = -Sh₂*Gᵀ²                  + H₂F₁*Gᵀ²
        C₄³ = -C₄¹
        C₄⁴ = -Sh₂*Gᵀ⁴                  + H₂F₁*Gᵀ⁴

        u̇₀ = Rₑ * (H₁¹ * U̇₁ + H₁² * Ẇ₁ + H₁³ * U̇₂ + H₁⁴ * Ẇ₂)

        H₁Eᵀd̈ = H₁¹ * Ü₁ + H₁² * Ẅ₁ + H₁³ * Ü₂ + H₁⁴ * Ẅ₂
        C₁Eᵀḋ = C₁¹ * U̇₁ + C₁² * Ẇ₁ + C₁³ * U̇₂ + C₁⁴ * Ẇ₂
        Rₑᵀü₀ = H₁Eᵀd̈ + C₁Eᵀḋ

        ẇ₀ = Rₑ * (H₂¹ * U̇₁ + H₂² * Ẇ₁ + H₂³ * U̇₂ + H₂⁴ * Ẇ₂)

        H₂Eᵀd̈ = H₂¹ * Ü₁ + H₂² * Ẅ₁ + H₂³ * Ü₂ + H₂⁴ * Ẅ₂
        C₂Eᵀḋ = C₂¹ * U̇₁ + C₂² * Ẇ₁ + C₂³ * U̇₂ + C₂⁴ * Ẇ₂
        Rₑᵀẅ₀ = H₂Eᵀd̈ + C₂Eᵀḋ

        Ẇ₀ = Gᵀ¹ * U̇₁ + Gᵀ² * Ẇ₁ + Gᵀ³ * U̇₂ + Gᵀ⁴ * Ẇ₂ 
        SẆ₀ = skew(Ẇ₀)
        ĪᵨRₑᵀẅ₀ = Īᵨ*Rₑᵀẅ₀
        SẆ₀Īᵨ = SẆ₀*Īᵨ
        SẆ₀ĪᵨẆ₀ = SẆ₀Īᵨ*Ẇ₀
        Tₖ¹ += ωᴳ * (Aᵨ*H₁¹'*Rₑᵀü₀ + H₂¹'*(ĪᵨRₑᵀẅ₀ + SẆ₀ĪᵨẆ₀))
        Tₖ² += ωᴳ * (Aᵨ*H₁²'*Rₑᵀü₀ + H₂²'*(ĪᵨRₑᵀẅ₀ + SẆ₀ĪᵨẆ₀))
        Tₖ³ += ωᴳ * (Aᵨ*H₁³'*Rₑᵀü₀ + H₂³'*(ĪᵨRₑᵀẅ₀ + SẆ₀ĪᵨẆ₀))
        Tₖ⁴ += ωᴳ * (Aᵨ*H₁⁴'*Rₑᵀü₀ + H₂⁴'*(ĪᵨRₑᵀẅ₀ + SẆ₀ĪᵨẆ₀))


        M¹¹ += ωᴳ * (Aᵨ*H₁¹'*H₁¹ + H₂¹'*Īᵨ*H₂¹)
        M¹² += ωᴳ * (Aᵨ*H₁¹'*H₁² + H₂¹'*Īᵨ*H₂²)
        M¹³ += ωᴳ * (Aᵨ*H₁¹'*H₁³ + H₂¹'*Īᵨ*H₂³)
        M¹⁴ += ωᴳ * (Aᵨ*H₁¹'*H₁⁴ + H₂¹'*Īᵨ*H₂⁴)

        M²² += ωᴳ * (Aᵨ*H₁²'*H₁² + H₂²'*Īᵨ*H₂²)
        M²³ += ωᴳ * (Aᵨ*H₁²'*H₁³ + H₂²'*Īᵨ*H₂³)
        M²⁴ += ωᴳ * (Aᵨ*H₁²'*H₁⁴ + H₂²'*Īᵨ*H₂⁴)

        M³³ += ωᴳ * (Aᵨ*H₁³'*H₁³ + H₂³'*Īᵨ*H₂³)
        M³⁴ += ωᴳ * (Aᵨ*H₁³'*H₁⁴ + H₂³'*Īᵨ*H₂⁴)

        M⁴⁴ += ωᴳ * (Aᵨ*H₁⁴'*H₁⁴ + H₂⁴'*Īᵨ*H₂⁴)


        SẆ₀ĪᵨmSĪᵨẆ₀ = SẆ₀Īᵨ - skew(Īᵨ*Ẇ₀)

        Cₖ¹¹ += ωᴳ * (Aᵨ*H₁¹'*(C₁¹ + C₃¹) + H₂¹'*Īᵨ*(C₂¹ + C₄¹) + H₂¹' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂¹ )
        Cₖ¹² += ωᴳ * (Aᵨ*H₁¹'*(C₁² + C₃²) + H₂¹'*Īᵨ*(C₂² + C₄²) + H₂¹' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂² )
        Cₖ¹³ += ωᴳ * (Aᵨ*H₁¹'*(C₁³ + C₃³) + H₂¹'*Īᵨ*(C₂³ + C₄³) + H₂¹' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂³ )
        Cₖ¹⁴ += ωᴳ * (Aᵨ*H₁¹'*(C₁⁴ + C₃⁴) + H₂¹'*Īᵨ*(C₂⁴ + C₄⁴) + H₂¹' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂⁴ )

        Cₖ²¹ += ωᴳ * (Aᵨ*H₁²'*(C₁¹ + C₃¹) + H₂²'*Īᵨ*(C₂¹ + C₄¹) + H₂²' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂¹ )
        Cₖ²² += ωᴳ * (Aᵨ*H₁²'*(C₁² + C₃²) + H₂²'*Īᵨ*(C₂² + C₄²) + H₂²' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂² )
        Cₖ²³ += ωᴳ * (Aᵨ*H₁²'*(C₁³ + C₃³) + H₂²'*Īᵨ*(C₂³ + C₄³) + H₂²' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂³ )
        Cₖ²⁴ += ωᴳ * (Aᵨ*H₁²'*(C₁⁴ + C₃⁴) + H₂²'*Īᵨ*(C₂⁴ + C₄⁴) + H₂²' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂⁴ )

        Cₖ³¹ += ωᴳ * (Aᵨ*H₁³'*(C₁¹ + C₃¹) + H₂³'*Īᵨ*(C₂¹ + C₄¹) + H₂³' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂¹ )
        Cₖ³² += ωᴳ * (Aᵨ*H₁³'*(C₁² + C₃²) + H₂³'*Īᵨ*(C₂² + C₄²) + H₂³' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂² )
        Cₖ³³ += ωᴳ * (Aᵨ*H₁³'*(C₁³ + C₃³) + H₂³'*Īᵨ*(C₂³ + C₄³) + H₂³' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂³ )
        Cₖ³⁴ += ωᴳ * (Aᵨ*H₁³'*(C₁⁴ + C₃⁴) + H₂³'*Īᵨ*(C₂⁴ + C₄⁴) + H₂³' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂⁴ )

        Cₖ⁴¹ += ωᴳ * (Aᵨ*H₁⁴'*(C₁¹ + C₃¹) + H₂⁴'*Īᵨ*(C₂¹ + C₄¹) + H₂⁴' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂¹ )
        Cₖ⁴² += ωᴳ * (Aᵨ*H₁⁴'*(C₁² + C₃²) + H₂⁴'*Īᵨ*(C₂² + C₄²) + H₂⁴' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂² )
        Cₖ⁴³ += ωᴳ * (Aᵨ*H₁⁴'*(C₁³ + C₃³) + H₂⁴'*Īᵨ*(C₂³ + C₄³) + H₂⁴' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂³ )
        Cₖ⁴⁴ += ωᴳ * (Aᵨ*H₁⁴'*(C₁⁴ + C₃⁴) + H₂⁴'*Īᵨ*(C₂⁴ + C₄⁴) + H₂⁴' * SẆ₀ĪᵨmSĪᵨẆ₀ * H₂⁴ )



        # kinetic energy
        Īᵨᵍ = Rₑ*Īᵨ*Rₑ'
        kinetic_energy += ωᴳ * (Aᵨ*u̇₀'*u̇₀ + ẇ₀'*Īᵨᵍ*ẇ₀)

    end

    Tₖ¹ = l₀/2*Rₑ*Tₖ¹
    Tₖ² = l₀/2*Rₑ*Tₖ²
    Tₖ³ = l₀/2*Rₑ*Tₖ³
    Tₖ⁴ = l₀/2*Rₑ*Tₖ⁴


    M¹¹ = l₀/2* Rₑ * M¹¹ * Rₑ'
    M¹² = l₀/2* Rₑ * M¹² * Rₑ'
    M¹³ = l₀/2* Rₑ * M¹³ * Rₑ'
    M¹⁴ = l₀/2* Rₑ * M¹⁴ * Rₑ'
    M²² = l₀/2* Rₑ * M²² * Rₑ'
    M²³ = l₀/2* Rₑ * M²³ * Rₑ'
    M²⁴ = l₀/2* Rₑ * M²⁴ * Rₑ'
    M³³ = l₀/2* Rₑ * M³³ * Rₑ'
    M³⁴ = l₀/2* Rₑ * M³⁴ * Rₑ'
    M⁴⁴ = l₀/2* Rₑ * M⁴⁴ * Rₑ'

    Cₖ¹¹ = l₀/2* Rₑ * Cₖ¹¹ * Rₑ'
    Cₖ¹² = l₀/2* Rₑ * Cₖ¹² * Rₑ'
    Cₖ¹³ = l₀/2* Rₑ * Cₖ¹³ * Rₑ'
    Cₖ¹⁴ = l₀/2* Rₑ * Cₖ¹⁴ * Rₑ'
    Cₖ²¹ = l₀/2* Rₑ * Cₖ²¹ * Rₑ'
    Cₖ²² = l₀/2* Rₑ * Cₖ²² * Rₑ'
    Cₖ²³ = l₀/2* Rₑ * Cₖ²³ * Rₑ'
    Cₖ²⁴ = l₀/2* Rₑ * Cₖ²⁴ * Rₑ'
    Cₖ³¹ = l₀/2* Rₑ * Cₖ³¹ * Rₑ'
    Cₖ³² = l₀/2* Rₑ * Cₖ³² * Rₑ'
    Cₖ³³ = l₀/2* Rₑ * Cₖ³³ * Rₑ'
    Cₖ³⁴ = l₀/2* Rₑ * Cₖ³⁴ * Rₑ'
    Cₖ⁴¹ = l₀/2* Rₑ * Cₖ⁴¹ * Rₑ'
    Cₖ⁴² = l₀/2* Rₑ * Cₖ⁴² * Rₑ'
    Cₖ⁴³ = l₀/2* Rₑ * Cₖ⁴³ * Rₑ'
    Cₖ⁴⁴ = l₀/2* Rₑ * Cₖ⁴⁴ * Rₑ'

    kinetic_energy = l₀/2* kinetic_energy


    Tₖ = [Tₖ¹; Tₖ²; Tₖ³; Tₖ⁴]
    M = hcat(vcat(M¹¹, M¹²', M¹³', M¹⁴'), vcat(M¹², M²², M²³', M²⁴'), vcat(M¹³, M²³, M³³, M³⁴'), vcat(M¹⁴, M²⁴, M³⁴, M⁴⁴))
    Cₖ = hcat(vcat(Cₖ¹¹, Cₖ²¹, Cₖ³¹, Cₖ⁴¹), vcat(Cₖ¹², Cₖ²², Cₖ³², Cₖ⁴²), vcat(Cₖ¹³, Cₖ²³, Cₖ³³, Cₖ⁴³), vcat(Cₖ¹⁴, Cₖ²⁴, Cₖ³⁴, Cₖ⁴⁴))
    

    return strain_energy, kinetic_energy, Tₑ, Tₖ, K, M, Cₖ



        # if !isnothing(sdf)

        #     xᴳ = N₁*x₁ + N₂*x₂ + Rₑ*uᵗ
        #     pₙ, p′ₙ, Pic_eps, gₙ, ∂gₙ∂x, ∂²gₙ∂x² =  get_contact_GP(xᴳ, comp.εᶜ, sdf, T)

        #     sol_GP.xGP[e.indGP[iG]] = xᴳ
        #     sol_GP.gGP[e.indGP[iG]] = gₙ/sdf.r
        #     sol_GP.status[e.indGP[iG]] = 0
        #     sol_GP.fGP_N[e.indGP[iG]] = zeros(Vec3{T})
        #     sol_GP.fGP_T[e.indGP[iG]] = zeros(Vec3{T})

        #     if pₙ != 0

        #         I∂gₙ∂x = ID3 - ∂gₙ∂x*∂gₙ∂x'
        #         ġₜ = I∂gₙ∂x*Rₑ*h₁
        #         ġₜ² = dot(ġₜ, ġₜ)
                
        #         𝓖ₙ = ∂gₙ∂x
        #         𝓖ₜ = -comp.μ*ġₜ/sqrt(ġₜ²+comp.εₜ)

        #         sol_GP.fGP_N[e.indGP[iG]] = pₙ*𝓖ₙ
        #         sol_GP.fGP_T[e.indGP[iG]] = pₙ*𝓖ₜ
        #         sol_GP.status[e.indGP[iG]] = 1

        #         𝓖 = 𝓖ₙ + 𝓖ₜ
        #         𝓯ᶜ = pₙ * 𝓖

        #         𝓕ᶜ = Rₑ' * 𝓯ᶜ

        #         H₁ᵀ𝓕ᶜ¹ = H₁¹' * 𝓕ᶜ
        #         H₁ᵀ𝓕ᶜ² = H₁²' * 𝓕ᶜ
        #         H₁ᵀ𝓕ᶜ³ = H₁³' * 𝓕ᶜ
        #         H₁ᵀ𝓕ᶜ⁴ = H₁⁴' * 𝓕ᶜ

        #         Tᶜ¹ += ωᴳ*l₀/2 * (Rₑ * H₁ᵀ𝓕ᶜ¹)
        #         Tᶜ² += ωᴳ*l₀/2 * (Rₑ * H₁ᵀ𝓕ᶜ²)
        #         Tᶜ³ += ωᴳ*l₀/2 * (Rₑ * H₁ᵀ𝓕ᶜ³)
        #         Tᶜ⁴ += ωᴳ*l₀/2 * (Rₑ * H₁ᵀ𝓕ᶜ⁴)

        #         ŜH₁ᵀ𝓕ᶜ¹ = skew(H₁ᵀ𝓕ᶜ¹)
        #         ŜH₁ᵀ𝓕ᶜ² = skew(H₁ᵀ𝓕ᶜ²)
        #         ŜH₁ᵀ𝓕ᶜ³ = skew(H₁ᵀ𝓕ᶜ³)
        #         ŜH₁ᵀ𝓕ᶜ⁴ = skew(H₁ᵀ𝓕ᶜ⁴)

        #         t¹₁₁ = -Rₑ * ŜH₁ᵀ𝓕ᶜ¹ * Gᵀ¹ * Rₑ'
        #         t¹₁₂ = -Rₑ * ŜH₁ᵀ𝓕ᶜ¹ * Gᵀ² * Rₑ'
        #         t¹₁₃ = -Rₑ * ŜH₁ᵀ𝓕ᶜ¹ * Gᵀ³ * Rₑ'
        #         t¹₁₄ = -Rₑ * ŜH₁ᵀ𝓕ᶜ¹ * Gᵀ⁴ * Rₑ'

        #         t¹₂₁ = -Rₑ * ŜH₁ᵀ𝓕ᶜ² * Gᵀ¹ * Rₑ'
        #         t¹₂₂ = -Rₑ * ŜH₁ᵀ𝓕ᶜ² * Gᵀ² * Rₑ'
        #         t¹₂₃ = -Rₑ * ŜH₁ᵀ𝓕ᶜ² * Gᵀ³ * Rₑ'
        #         t¹₂₄ = -Rₑ * ŜH₁ᵀ𝓕ᶜ² * Gᵀ⁴ * Rₑ'

        #         t¹₃₁ = -Rₑ * ŜH₁ᵀ𝓕ᶜ³ * Gᵀ¹ * Rₑ'
        #         t¹₃₂ = -Rₑ * ŜH₁ᵀ𝓕ᶜ³ * Gᵀ² * Rₑ'
        #         t¹₃₃ = -Rₑ * ŜH₁ᵀ𝓕ᶜ³ * Gᵀ³ * Rₑ'
        #         t¹₃₄ = -Rₑ * ŜH₁ᵀ𝓕ᶜ³ * Gᵀ⁴ * Rₑ'

        #         t¹₄₁ = -Rₑ * ŜH₁ᵀ𝓕ᶜ⁴ * Gᵀ¹ * Rₑ'
        #         t¹₄₂ = -Rₑ * ŜH₁ᵀ𝓕ᶜ⁴ * Gᵀ² * Rₑ'
        #         t¹₄₃ = -Rₑ * ŜH₁ᵀ𝓕ᶜ⁴ * Gᵀ³ * Rₑ'
        #         t¹₄₄ = -Rₑ * ŜH₁ᵀ𝓕ᶜ⁴ * Gᵀ⁴ * Rₑ'



        #         A = @SMatrix[0 0 0; 𝓕ᶜ[2]*v₁[1] 𝓕ᶜ[2]*v₁[2] 𝓕ᶜ[2]*v₁[3]; 𝓕ᶜ[3]*v₁[1] 𝓕ᶜ[3]*v₁[2] 𝓕ᶜ[3]*v₁[3]]

        #         A₁ᵀ𝓕ᶜr₁₁ = A
        #         A₁ᵀ𝓕ᶜr₁₃ = -A
        #         A₁ᵀ𝓕ᶜr₃₁ = -A
        #         A₁ᵀ𝓕ᶜr₃₃ = A

        #         S𝓕ᶜ = skew(𝓕ᶜ)


        #         t²₁₁ = N₇/lₙ^2 * Rₑ * A₁ᵀ𝓕ᶜr₁₁ - Rₑ * Gᵀ¹' * S𝓕ᶜ * P₁P¹ * Rₑ'
        #         t²₁₂ =                         - Rₑ * Gᵀ¹' * S𝓕ᶜ * P₁P² * Rₑ'
        #         t²₁₃ = N₇/lₙ^2 * Rₑ * A₁ᵀ𝓕ᶜr₁₃ - Rₑ * Gᵀ¹' * S𝓕ᶜ * P₁P³ * Rₑ'
        #         t²₁₄ =                         - Rₑ * Gᵀ¹' * S𝓕ᶜ * P₁P⁴ * Rₑ'

        #         t²₂₁ =                         - Rₑ * Gᵀ²' * S𝓕ᶜ * P₁P¹ * Rₑ'
        #         t²₂₂ =                         - Rₑ * Gᵀ²' * S𝓕ᶜ * P₁P² * Rₑ'
        #         t²₂₃ =                         - Rₑ * Gᵀ²' * S𝓕ᶜ * P₁P³ * Rₑ'
        #         t²₂₄ =                         - Rₑ * Gᵀ²' * S𝓕ᶜ * P₁P⁴ * Rₑ'

        #         t²₃₁ = N₇/lₙ^2 * Rₑ * A₁ᵀ𝓕ᶜr₃₁ - Rₑ * Gᵀ³' * S𝓕ᶜ * P₁P¹ * Rₑ'
        #         t²₃₂ =                         - Rₑ * Gᵀ³' * S𝓕ᶜ * P₁P² * Rₑ'
        #         t²₃₃ = N₇/lₙ^2 * Rₑ * A₁ᵀ𝓕ᶜr₃₃ - Rₑ * Gᵀ³' * S𝓕ᶜ * P₁P³ * Rₑ'
        #         t²₃₄ =                         - Rₑ * Gᵀ³' * S𝓕ᶜ * P₁P⁴ * Rₑ'

        #         t²₄₁ =                         - Rₑ * Gᵀ⁴' * S𝓕ᶜ * P₁P¹ * Rₑ'
        #         t²₄₂ =                         - Rₑ * Gᵀ⁴' * S𝓕ᶜ * P₁P² * Rₑ'
        #         t²₄₃ =                         - Rₑ * Gᵀ⁴' * S𝓕ᶜ * P₁P³ * Rₑ'
        #         t²₄₄ =                         - Rₑ * Gᵀ⁴' * S𝓕ᶜ * P₁P⁴ * Rₑ'



        #         t³₁₁ = -Rₑ * H₁¹ * S𝓕ᶜ * Gᵀ¹ * Rₑ'
        #         t³₁₂ = -Rₑ * H₁¹ * S𝓕ᶜ * Gᵀ² * Rₑ'
        #         t³₁₃ = -Rₑ * H₁¹ * S𝓕ᶜ * Gᵀ³ * Rₑ'
        #         t³₁₄ = -Rₑ * H₁¹ * S𝓕ᶜ * Gᵀ⁴ * Rₑ'

        #         t³₂₁ = -Rₑ * H₁² * S𝓕ᶜ * Gᵀ¹ * Rₑ'
        #         t³₂₂ = -Rₑ * H₁² * S𝓕ᶜ * Gᵀ² * Rₑ'
        #         t³₂₃ = -Rₑ * H₁² * S𝓕ᶜ * Gᵀ³ * Rₑ'
        #         t³₂₄ = -Rₑ * H₁² * S𝓕ᶜ * Gᵀ⁴ * Rₑ'

        #         t³₃₁ = -Rₑ * H₁³ * S𝓕ᶜ * Gᵀ¹ * Rₑ'
        #         t³₃₂ = -Rₑ * H₁³ * S𝓕ᶜ * Gᵀ² * Rₑ'
        #         t³₃₃ = -Rₑ * H₁³ * S𝓕ᶜ * Gᵀ³ * Rₑ'
        #         t³₃₄ = -Rₑ * H₁³ * S𝓕ᶜ * Gᵀ⁴ * Rₑ'

        #         t³₄₁ = -Rₑ * H₁⁴ * S𝓕ᶜ * Gᵀ¹ * Rₑ'
        #         t³₄₂ = -Rₑ * H₁⁴ * S𝓕ᶜ * Gᵀ² * Rₑ'
        #         t³₄₃ = -Rₑ * H₁⁴ * S𝓕ᶜ * Gᵀ³ * Rₑ'
        #         t³₄₄ = -Rₑ * H₁⁴ * S𝓕ᶜ * Gᵀ⁴ * Rₑ'




        #         ∂gₙ∂xRₑh₁∂²gₙ∂x² = -dot(∂gₙ∂x, Rₑ * h₁) * ∂²gₙ∂x²
        #         Rₑᵀ∂²gₙ∂x²Rₑh₁ = Rₑ' * ∂²gₙ∂x² * Rₑ * h₁
        #         𝓐₁¹ =  ∂gₙ∂xRₑh₁∂²gₙ∂x² * Rₑ * H₁¹ * Rₑ' - ∂gₙ∂x * (Rₑ * H₁¹ * Rₑᵀ∂²gₙ∂x²Rₑh₁)'
        #         𝓐₁² =  ∂gₙ∂xRₑh₁∂²gₙ∂x² * Rₑ * H₁² * Rₑ' - ∂gₙ∂x * (Rₑ * H₁² * Rₑᵀ∂²gₙ∂x²Rₑh₁)'
        #         𝓐₁³ =  ∂gₙ∂xRₑh₁∂²gₙ∂x² * Rₑ * H₁³ * Rₑ' - ∂gₙ∂x * (Rₑ * H₁³ * Rₑᵀ∂²gₙ∂x²Rₑh₁)'
        #         𝓐₁⁴ =  ∂gₙ∂xRₑh₁∂²gₙ∂x² * Rₑ * H₁⁴ * Rₑ' - ∂gₙ∂x * (Rₑ * H₁⁴ * Rₑᵀ∂²gₙ∂x²Rₑh₁)'

        #         I∂gₙ∂xRₑSh₁ = - I∂gₙ∂x * Rₑ * Sh₁
        #         𝓐₂¹ = I∂gₙ∂xRₑSh₁ * Gᵀ¹ * Rₑ'
        #         𝓐₂² = I∂gₙ∂xRₑSh₁ * Gᵀ² * Rₑ'
        #         𝓐₂³ = I∂gₙ∂xRₑSh₁ * Gᵀ³ * Rₑ'
        #         𝓐₂⁴ = I∂gₙ∂xRₑSh₁ * Gᵀ⁴ * Rₑ'

        #         𝓐₃¹ = I∂gₙ∂x * N₇/lₙ^2 * Rₑ * A₁Ḋr¹ + Rₑ * skew(Gᵀ¹ * U̇₁) * P₁P¹ * Rₑ'
        #         𝓐₃² =                                  Rₑ * skew(Gᵀ² * Ẇ₁) * P₁P² * Rₑ'
        #         𝓐₃³ = I∂gₙ∂x * N₇/lₙ^2 * Rₑ * A₁Ḋr³ + Rₑ * skew(Gᵀ³ * U̇₂) * P₁P³ * Rₑ'
        #         𝓐₃⁴ =                                  Rₑ * skew(Gᵀ⁴ * Ẇ₂) * P₁P⁴ * Rₑ'



        #         # eq110 in [2]
        #         Inn = ID3 - ∂gₙ∂x*∂gₙ∂x'
        #         dgT = Inn*Rₑ*H1G*E'*Ḋ
        #         dgTdgT = dot(dgT,dgT)
                
        #         G_eN = ∂gₙ∂x


                

        #     end


    
end


# # information from node 1 and 2
const X₁ = @SVector [0.91, 0.58, 0.68]
const X₂ = @SVector [0.97, 0.04, 0.41]

const l₀ = norm(X₂-X₁)

u₁ = @SVector [0.8, 0.5, 0.1]
u₂ = @SVector [0.9, 0.52, 0.14]

Θ₁ = @SVector [-0.2423, 0.9047, 0.5896]
Θ₂ = @SVector [-0.2394, 0.8994, 0.5902]


u̇₁ = @SVector [0.01, 0.02, -0.01]
u̇₂ = @SVector [0.013, -0.02, -0.015]

ẇ₁ = @SVector [-0.02423, 0.009047, 0.005896]
ẇ₂ = @SVector [-0.002394, 0.008994, 0.005902]

ü₁ = @SVector [0.008, 0.005, 0.001]
ü₂ = @SVector [0.009, 0.0052, 0.0014]

ẅ₁ = @SVector [-0.002423, 0.009047, 0.005896]
ẅ₂ = @SVector [-0.002394, 0.008994, 0.005902]


const mat = (E = 1., G = 0.1, Jᵨ = Diagonal(@SVector [20, 10, 10]), Aᵨ = 0.01)
const geom = (A = 0.01, J = 0.01, I₃₃ = 0.01, I₂₂ = 0.01)
const comp = (nᴳ = 3, zᴳ = @SVector[-sqrt(3/5), 0, sqrt(3/5)], ωᴳ = @SVector[5/9, 8/9, 5/9] )


const Rₑ⁰ = local_R⁰(X₁, X₂)


# using BenchmarkTools

# @btime Tⁱⁿᵗ($x)
# @btime Kⁱⁿᵗ($x)



function compare(test, correct, disp=true)
    m = maximum(correct)
    if disp
        display(test)
        display(correct)
        display(test - correct)
    end
    return maximum(abs.(test - correct))/m
end


function finitediff_statics(exact=false, additive=false, symmetrize=true)

    _, _, ftest, _, Ktest, _, _ = compute(u₁, Θ₁, u₂, Θ₂, u̇₁, u̇₂, ẇ₁, ẇ₂, ü₁, ü₂, ẅ₁, ẅ₂, exact, additive, symmetrize)

    H = zeros(12,12)
    F = zeros(12)
    ε = 1e-6


    for i in 1:12
        u₁⁺ = u₁⁻ = u₁
        Θ₁⁺ = Θ₁⁻ = Θ₁
        u₂⁺ = u₂⁻ = u₂
        Θ₂⁺ = Θ₂⁻ = Θ₂
        if i in [1,2,3,7,8,9]
            Δ = @SVector [k==mod1(i,3) ? ε : 0 for k in 1:3]
            if i in [1,2,3]
                u₁⁺ = u₁ + Δ
                u₁⁻ = u₁ - Δ
            else
                u₂⁺ = u₂ + Δ
                u₂⁻ = u₂ - Δ
            end
        else
            Θ = i in [4,5,6] ? Θ₁ : Θ₂
            Δ = @SVector [k==mod1(i,3) ? ε : 0 for k in 1:3]
            if additive
                Θ⁺ = Δ
                Θ⁻ = -Δ
            else
                Θ⁺ = toangle(rotation_matrix(Δ) * rotation_matrix(Θ))
                Θ⁻ = toangle(rotation_matrix(-Δ) * rotation_matrix(Θ))
            end
            if i in [4,5,6]
                Θ₁⁺ = Θ⁺
                Θ₁⁻ = Θ⁻
            else
                Θ₂⁺ = Θ⁺
                Θ₂⁻ = Θ⁻
            end
        end

        e⁺, _, f⁺, _, _, _, _ = compute(u₁⁺, Θ₁⁺, u₂⁺, Θ₂⁺, u̇₁, u̇₂, ẇ₁, ẇ₂, ü₁, ü₂, ẅ₁, ẅ₂, true, false, false)
        e⁻, _, f⁻, _, _, _, _ = compute(u₁⁻, Θ₁⁻, u₂⁻, Θ₂⁻, u̇₁, u̇₂, ẇ₁, ẇ₂, ü₁, ü₂, ẅ₁, ẅ₂, true, false, false)
        F[i] = (e⁺-e⁻)/(2*ε)
        H[:, i] .= (f⁺-f⁻)/(2*ε)
    end

    return compare(ftest, F), compare(Ktest, H)

end





finitediff_statics(true, false, false)






function finitediff_dynamic(exact=false, additive=false, symmetrize=true)

    _, _, _, ftest, _, _, _ = compute(u₁, Θ₁, u₂, Θ₂, u̇₁, u̇₂, ẇ₁, ẇ₂, ü₁, ü₂, ẅ₁, ẅ₂, exact, additive, symmetrize)

    H = zeros(12,12)
    F = zeros(12)
    ε = 1e-6


    for i in 1:12
        u₁⁺ = u₁⁻ = u₁
        Θ₁⁺ = Θ₁⁻ = Θ₁
        u₂⁺ = u₂⁻ = u₂
        Θ₂⁺ = Θ₂⁻ = Θ₂
        if i in [1,2,3,7,8,9]
            Δ = @SVector [k==mod1(i,3) ? ε : 0 for k in 1:3]
            if i in [1,2,3]
                u₁⁺ = u₁ + Δ
                u₁⁻ = u₁ - Δ
            else
                u₂⁺ = u₂ + Δ
                u₂⁻ = u₂ - Δ
            end
        else
            Θ = i in [4,5,6] ? Θ₁ : Θ₂
            Δ = @SVector [k==mod1(i,3) ? ε : 0 for k in 1:3]
            if additive
                Θ⁺ = Δ
                Θ⁻ = -Δ
            else
                Θ⁺ = toangle(rotation_matrix(Δ) * rotation_matrix(Θ))
                Θ⁻ = toangle(rotation_matrix(-Δ) * rotation_matrix(Θ))
            end
            if i in [4,5,6]
                Θ₁⁺ = Θ⁺
                Θ₁⁻ = Θ⁻
            else
                Θ₂⁺ = Θ⁺
                Θ₂⁻ = Θ⁻
            end
        end

        _, e⁺, _, _, _, _, _ = compute(u₁⁺, Θ₁⁺, u₂⁺, Θ₂⁺, u̇₁, u̇₂, ẇ₁, ẇ₂, ü₁, ü₂, ẅ₁, ẅ₂, true, false, false)
        _, e⁻, _, _, _, _, _ = compute(u₁⁻, Θ₁⁻, u₂⁻, Θ₂⁻, u̇₁, u̇₂, ẇ₁, ẇ₂, ü₁, ü₂, ẅ₁, ẅ₂, true, false, false)
        F[i] = (e⁺-e⁻)/(2*ε)
    end

    return compare(ftest, F)

end

finitediff_dynamic()