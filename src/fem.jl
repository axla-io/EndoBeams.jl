

# Rotate using Rodrigue's formula
@inline function rotation_matrix(Θ::AbstractVecOrMat{T}) where T
    
    Θ_norm = norm(Θ)
    if Θ_norm > 10*eps(T)
        sinΘ = sin(Θ_norm)
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
    Gᵀu₂ = -Gᵀu₁
    GᵀΘ₁ = @SMatrix [η¹²/2 -η¹¹/2 0; 0 0 0; 0 0 0]
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




Base.@propagate_inbounds function get_beam_contributions(u₁::AbstractVector{T}, R₁, u₂, R₂, ΔR₁, ΔR₂, u̇₁, u̇₂, ẇ₁, ẇ₂, ü₁, ü₂, ẅ₁, ẅ₂, Rₑ⁰, X₁, X₂, l₀, comp, mat, geom, exact=true, dynamics=true) where T

    # Superscript ¹ means matrix or vector associated to u₁
    # Superscript ² means matrix or vector associated to Θ₁
    # Superscript ³ means matrix or vector associated to u₂
    # Superscript ⁴ means matrix or vector associated to Θ₂


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
    B̄⁺¹³ = -B̄⁺¹¹
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
    Tᵢₙₜ³ = -Tᵢₙₜ¹
    Tᵢₙₜ⁴ =             B¹⁴'*T̄ᵢₙₜΘ̅₁ + B²⁴'*T̄ᵢₙₜΘ̅₂


    # if additive

    #     TₛΘ₁ = Tₛ(Θ₁)
    #     TₛΘ₂ = Tₛ(Θ₂)

    #     Tₑ¹ = Tᵢₙₜ¹
    #     Tₑ² = TₛΘ₁' * Tᵢₙₜ²
    #     Tₑ³ = Tᵢₙₜ³
    #     Tₑ⁴ = TₛΘ₂' * Tᵢₙₜ⁴


    # Force
    Tᵢₙₜ = [Tᵢₙₜ¹; Tᵢₙₜ²; Tᵢₙₜ³; Tᵢₙₜ⁴]


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


    # if additive

    #     Kᵥ₁ = compute_Kᵥ(Θ₁, Tᵢₙₜ²)
    #     Kᵥ₂ = compute_Kᵥ(Θ₂, Tᵢₙₜ⁴)

    #     Kᵢₙₜ¹² =         Kᵢₙₜ¹² * TₛΘ₁
    #     Kᵢₙₜ¹⁴ =         Kᵢₙₜ¹⁴ * TₛΘ₂

    #     Kᵢₙₜ²¹ = TₛΘ₁' * Kᵢₙₜ²¹
    #     Kᵢₙₜ²² = TₛΘ₁' * Kᵢₙₜ²² * TₛΘ₁ + Kᵥ₁
    #     Kᵢₙₜ²³ = TₛΘ₁' * Kᵢₙₜ²³
    #     Kᵢₙₜ²⁴ = TₛΘ₁' * Kᵢₙₜ²⁴ * TₛΘ₂

    #     Kᵢₙₜ³² =         Kᵢₙₜ³² * TₛΘ₁
    #     Kᵢₙₜ³⁴ =         Kᵢₙₜ³⁴ * TₛΘ₂

    #     Kᵢₙₜ⁴¹ = TₛΘ₂' * Kᵢₙₜ⁴¹
    #     Kᵢₙₜ⁴² = TₛΘ₂' * Kᵢₙₜ⁴² * TₛΘ₁
    #     Kᵢₙₜ⁴³ = TₛΘ₂' * Kᵢₙₜ⁴³
    #     Kᵢₙₜ⁴⁴ = TₛΘ₂' * Kᵢₙₜ⁴⁴ * TₛΘ₂ + Kᵥ₂

    # end


    Kᵢₙₜ = hcat(vcat(Kᵢₙₜ¹¹, Kᵢₙₜ¹²', Kᵢₙₜ¹³', Kᵢₙₜ¹⁴'), vcat(Kᵢₙₜ¹², Kᵢₙₜ²², Kᵢₙₜ²³', Kᵢₙₜ²⁴'), vcat(Kᵢₙₜ¹³, Kᵢₙₜ²³, Kᵢₙₜ³³, Kᵢₙₜ³⁴'), vcat(Kᵢₙₜ¹⁴, Kᵢₙₜ²⁴, Kᵢₙₜ³⁴, Kᵢₙₜ⁴⁴))

    if !dynamics

        return strain_energy, Tᵢₙₜ, Kᵢₙₜ

    else
        
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

        Ẇᵉ = Gᵀ¹ * U̇₁ + Gᵀ² * Ẇ₁ + Gᵀ³ * U̇₂ + Gᵀ⁴ * Ẇ₂
        SẆᵉ = skew(Ẇᵉ)

        
        rḋ = dot(r¹, u̇₁) + dot(r³, u̇₂)
        

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

            N₇lₙ = N₇/lₙ
            N₈lₙ = N₈/lₙ

            P₁P¹ = @SMatrix [0 0 0; 0 N₇lₙ 0;0 0 N₇lₙ]
            P₁P² = @SMatrix [0 0 0; 0 0 N₃;0 -N₃ 0]
            P₁P³ = -P₁P¹
            P₁P⁴ = @SMatrix [0 0 0; 0 0 N₄;0 -N₄ 0]

            H₁¹ = N₁*ID3 + P₁P¹ - Suᵗ*Gᵀ¹
            H₁² =          P₁P² - Suᵗ*Gᵀ²
            H₁³ = N₂*ID3 + P₁P³ - Suᵗ*Gᵀ³
            H₁⁴ =          P₁P⁴ - Suᵗ*Gᵀ⁴

            H₂¹ = @SMatrix [0 0 0; 0  0 -N₈lₙ;0 N₈lₙ 0]
            H₂² = Diagonal(@SVector [N₁, N₅, N₅])
            H₂³ = -H₂¹
            H₂⁴ = Diagonal(@SVector [N₂, N₆, N₆])

            u̇ᵗ =  P₁P¹ * U̇₁ +  P₁P² * Ẇ₁ + P₁P³ * U̇₂ + P₁P² * Ẇ₂

            Su̇ᵗ = skew(u̇ᵗ)
            
            N₇rḋ = N₇lₙ/lₙ * rḋ
            Ḣ₁¹ = Diagonal(@SVector [0, -N₇rḋ, -N₇rḋ]) - Su̇ᵗ * Gᵀ¹
            Ḣ₁² =                                      - Su̇ᵗ * Gᵀ²
            Ḣ₁⁴ =                                      - Su̇ᵗ * Gᵀ⁴

            N₈rḋ = N₈lₙ/lₙ * rḋ
            Ḣ₂¹ = @SMatrix [0 0 0; 0 0 N₈rḋ; 0 -N₈rḋ 0]

            h₁ = H₁¹ * U̇₁ + H₁² * Ẇ₁ + H₁³ * U̇₂ + H₁⁴ * Ẇ₂
            h₂ = H₂¹ * U̇₁ + H₂² * Ẇ₁ + H₂³ * U̇₂ + H₂⁴ * Ẇ₂
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

            H₁F₁ = H₁¹ * SU̇₁ + H₁² * SẆ₁ + H₁³ * SU̇₂ + H₁⁴ * SẆ₂
            H₂F₁ = H₂¹ * SU̇₁ + H₂² * SẆ₁ + H₂³ * SU̇₂ + H₂⁴ * SẆ₂

            A₁ḊrE¹ = @SMatrix [0 0 0; U̇₁[2]-U̇₂[2] 0 0; U̇₁[3]-U̇₂[3] 0 0]
            C₃¹ = -Sh₁*Gᵀ¹ + N₇lₙ/lₙ*A₁ḊrE¹ + SẆᵉ*P₁P¹ + H₁F₁*Gᵀ¹
            C₃² = -Sh₁*Gᵀ² +                  SẆᵉ*P₁P² + H₁F₁*Gᵀ²
            C₃³ = -C₃¹
            C₃⁴ = -Sh₁*Gᵀ⁴ +                  SẆᵉ*P₁P⁴ + H₁F₁*Gᵀ⁴

            A₂ḊrE¹ = @SMatrix [0 0 0; -U̇₁[3]+U̇₂[3] 0 0; U̇₁[2]-U̇₂[2] 0 0]
            C₄¹ = -Sh₂*Gᵀ¹ + N₈lₙ/lₙ*A₂ḊrE¹ + H₂F₁*Gᵀ¹
            C₄² = -Sh₂*Gᵀ²                  + H₂F₁*Gᵀ²
            C₄³ = -C₄¹
            C₄⁴ = -Sh₂*Gᵀ⁴                  + H₂F₁*Gᵀ⁴

            u̇₀ = Rₑ * (H₁¹ * U̇₁ + H₁² * Ẇ₁ + H₁³ * U̇₂ + H₁⁴ * Ẇ₂)

            H₁Eᵀd̈ = H₁¹ * Ü₁ + H₁² * Ẅ₁ + H₁³ * Ü₂ + H₁⁴ * Ẅ₂
            C₁Eᵀḋ = C₁¹ * U̇₁ + C₁² * Ẇ₁ + C₁³ * U̇₂ + C₁⁴ * Ẇ₂
            Rₑᵀü₀ = H₁Eᵀd̈ + C₁Eᵀḋ

            Ẇ₀ = H₂¹ * U̇₁ + H₂² * Ẇ₁ + H₂³ * U̇₂ + H₂⁴ * Ẇ₂
            ẇ₀ = Rₑ * Ẇ₀

            H₂Eᵀd̈ = H₂¹ * Ü₁ + H₂² * Ẅ₁ + H₂³ * Ü₂ + H₂⁴ * Ẅ₂
            C₂Eᵀḋ = C₂¹ * U̇₁ + C₂² * Ẇ₁ + C₂³ * U̇₂ + C₂⁴ * Ẇ₂
            Rₑᵀẅ₀ = H₂Eᵀd̈ + C₂Eᵀḋ

            SẆ₀ = skew(Ẇ₀)
            ĪᵨRₑᵀẅ₀ = Īᵨ*Rₑᵀẅ₀
            SẆ₀Īᵨ = SẆ₀*Īᵨ
            SẆ₀ĪᵨẆ₀ = SẆ₀Īᵨ*Ẇ₀
            ĪᵨRₑᵀẅ₀SẆ₀ĪᵨẆ₀ = ĪᵨRₑᵀẅ₀ + SẆ₀ĪᵨẆ₀
            Tₖ¹ += ωᴳ * (Aᵨ*H₁¹'*Rₑᵀü₀ + H₂¹'*ĪᵨRₑᵀẅ₀SẆ₀ĪᵨẆ₀)
            Tₖ² += ωᴳ * (Aᵨ*H₁²'*Rₑᵀü₀ + H₂²'*ĪᵨRₑᵀẅ₀SẆ₀ĪᵨẆ₀)
            Tₖ³ += ωᴳ * (Aᵨ*H₁³'*Rₑᵀü₀ + H₂³'*ĪᵨRₑᵀẅ₀SẆ₀ĪᵨẆ₀)
            Tₖ⁴ += ωᴳ * (Aᵨ*H₁⁴'*Rₑᵀü₀ + H₂⁴'*ĪᵨRₑᵀẅ₀SẆ₀ĪᵨẆ₀)


            H₂¹ᵀĪᵨH₂¹ = H₂¹'*Īᵨ*H₂¹
            H₂¹ᵀĪᵨH₂² = H₂¹'*Īᵨ*H₂²
            H₂¹ᵀĪᵨH₂⁴ = H₂¹'*Īᵨ*H₂⁴

            M¹¹ += ωᴳ * (Aᵨ*H₁¹'*H₁¹ + H₂¹ᵀĪᵨH₂¹)
            M¹² += ωᴳ * (Aᵨ*H₁¹'*H₁² + H₂¹ᵀĪᵨH₂²)
            M¹³ += ωᴳ * (Aᵨ*H₁¹'*H₁³ - H₂¹ᵀĪᵨH₂¹)
            M¹⁴ += ωᴳ * (Aᵨ*H₁¹'*H₁⁴ + H₂¹ᵀĪᵨH₂⁴)

            M²² += ωᴳ * (Aᵨ*H₁²'*H₁² + H₂²'*Īᵨ*H₂²)
            M²³ += ωᴳ * (Aᵨ*H₁²'*H₁³ - H₂¹ᵀĪᵨH₂²')
            M²⁴ += ωᴳ * (Aᵨ*H₁²'*H₁⁴ + H₂²'*Īᵨ*H₂⁴)

            M³³ += ωᴳ * (Aᵨ*H₁³'*H₁³ + H₂¹ᵀĪᵨH₂¹)
            M³⁴ += ωᴳ * (Aᵨ*H₁³'*H₁⁴ - H₂¹ᵀĪᵨH₂⁴)
            
            M⁴⁴ += ωᴳ * (Aᵨ*H₁⁴'*H₁⁴ + H₂⁴'*Īᵨ*H₂⁴)


            SẆ₀ĪᵨmSĪᵨẆ₀ = SẆ₀Īᵨ - skew(Īᵨ*Ẇ₀)

            AᵨC₁¹C₃¹ = Aᵨ*(C₁¹ + C₃¹)
            AᵨC₁¹C₃² = Aᵨ*(C₁² + C₃²)
            AᵨC₁¹C₃³ = Aᵨ*(C₁³ + C₃³)
            AᵨC₁¹C₃⁴ = Aᵨ*(C₁⁴ + C₃⁴)

            ĪᵨC₂¹C₄¹ = Īᵨ*(C₂¹ + C₄¹)
            ĪᵨC₂¹C₄² = Īᵨ*(C₂² + C₄²)
            ĪᵨC₂¹C₄³ = Īᵨ*(C₂³ + C₄³)
            ĪᵨC₂¹C₄⁴ = Īᵨ*(C₂⁴ + C₄⁴)

            ĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ = ĪᵨC₂¹C₄¹ + SẆ₀ĪᵨmSĪᵨẆ₀ * H₂¹
            ĪᵨC₂²C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂² = ĪᵨC₂¹C₄² + SẆ₀ĪᵨmSĪᵨẆ₀ * H₂²
            ĪᵨC₂³C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂³ = ĪᵨC₂¹C₄³ + SẆ₀ĪᵨmSĪᵨẆ₀ * H₂³
            ĪᵨC₂⁴C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂⁴ = ĪᵨC₂¹C₄⁴ + SẆ₀ĪᵨmSĪᵨẆ₀ * H₂⁴

            H₂¹ᵀĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ = H₂¹'* ĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹
            H₂¹ᵀĪᵨC₂²C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂² = H₂¹'* ĪᵨC₂²C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂²
            H₂¹ᵀĪᵨC₂⁴C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂⁴ = H₂¹'* ĪᵨC₂⁴C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂⁴
            H₂²ᵀĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ = H₂²'* ĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹
            H₂⁴ᵀĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ = H₂⁴'* ĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹

            Cₖ¹¹ += ωᴳ * (H₁¹'*AᵨC₁¹C₃¹ + H₂¹ᵀĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ )
            Cₖ¹² += ωᴳ * (H₁¹'*AᵨC₁¹C₃² + H₂¹ᵀĪᵨC₂²C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂² )
            Cₖ¹³ += ωᴳ * (H₁¹'*AᵨC₁¹C₃³ - H₂¹ᵀĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ )
            Cₖ¹⁴ += ωᴳ * (H₁¹'*AᵨC₁¹C₃⁴ + H₂¹ᵀĪᵨC₂⁴C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂⁴ )

            Cₖ²¹ += ωᴳ * (H₁²'*AᵨC₁¹C₃¹ + H₂²ᵀĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ )
            Cₖ²² += ωᴳ * (H₁²'*AᵨC₁¹C₃² + H₂²'* ĪᵨC₂²C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂² )
            Cₖ²³ += ωᴳ * (H₁²'*AᵨC₁¹C₃³ - H₂²ᵀĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ )
            Cₖ²⁴ += ωᴳ * (H₁²'*AᵨC₁¹C₃⁴ + H₂²'* ĪᵨC₂⁴C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂⁴ )

            Cₖ³¹ += ωᴳ * (H₁³'*AᵨC₁¹C₃¹ - H₂¹ᵀĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ )
            Cₖ³² += ωᴳ * (H₁³'*AᵨC₁¹C₃² - H₂¹ᵀĪᵨC₂²C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂² )
            Cₖ³³ += ωᴳ * (H₁³'*AᵨC₁¹C₃³ + H₂¹ᵀĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ )
            Cₖ³⁴ += ωᴳ * (H₁³'*AᵨC₁¹C₃⁴ - H₂¹ᵀĪᵨC₂⁴C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂⁴ )

            Cₖ⁴¹ += ωᴳ * (H₁⁴'*AᵨC₁¹C₃¹ + H₂⁴ᵀĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ )
            Cₖ⁴² += ωᴳ * (H₁⁴'*AᵨC₁¹C₃² + H₂⁴'* ĪᵨC₂²C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂² )
            Cₖ⁴³ += ωᴳ * (H₁⁴'*AᵨC₁¹C₃³ - H₂⁴ᵀĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ )
            Cₖ⁴⁴ += ωᴳ * (H₁⁴'*AᵨC₁¹C₃⁴ + H₂⁴'* ĪᵨC₂⁴C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂⁴ )



            # kinetic energy
            Īᵨᵍ = Rₑ*Īᵨ*Rₑ'
            kinetic_energy = ωᴳ/2 * (Aᵨ*u̇₀'*u̇₀ + ẇ₀'*Īᵨᵍ*ẇ₀)

        end

        l₀2Rₑ = l₀/2 * Rₑ
        Tₖ¹ = l₀2Rₑ*Tₖ¹
        Tₖ² = l₀2Rₑ*Tₖ²
        Tₖ³ = l₀2Rₑ*Tₖ³
        Tₖ⁴ = l₀2Rₑ*Tₖ⁴


        M¹¹ = l₀2Rₑ * M¹¹ * Rₑ'
        M¹² = l₀2Rₑ * M¹² * Rₑ'
        M¹³ = l₀2Rₑ * M¹³ * Rₑ'
        M¹⁴ = l₀2Rₑ * M¹⁴ * Rₑ'
        M²² = l₀2Rₑ * M²² * Rₑ'
        M²³ = l₀2Rₑ * M²³ * Rₑ'
        M²⁴ = l₀2Rₑ * M²⁴ * Rₑ'
        M³³ = l₀2Rₑ * M³³ * Rₑ'
        M³⁴ = l₀2Rₑ * M³⁴ * Rₑ'
        M⁴⁴ = l₀2Rₑ * M⁴⁴ * Rₑ'

        Cₖ¹¹ = l₀2Rₑ * Cₖ¹¹ * Rₑ'
        Cₖ¹² = l₀2Rₑ * Cₖ¹² * Rₑ'
        Cₖ¹³ = l₀2Rₑ * Cₖ¹³ * Rₑ'
        Cₖ¹⁴ = l₀2Rₑ * Cₖ¹⁴ * Rₑ'
        Cₖ²¹ = l₀2Rₑ * Cₖ²¹ * Rₑ'
        Cₖ²² = l₀2Rₑ * Cₖ²² * Rₑ'
        Cₖ²³ = l₀2Rₑ * Cₖ²³ * Rₑ'
        Cₖ²⁴ = l₀2Rₑ * Cₖ²⁴ * Rₑ'
        Cₖ³¹ = l₀2Rₑ * Cₖ³¹ * Rₑ'
        Cₖ³² = l₀2Rₑ * Cₖ³² * Rₑ'
        Cₖ³³ = l₀2Rₑ * Cₖ³³ * Rₑ'
        Cₖ³⁴ = l₀2Rₑ * Cₖ³⁴ * Rₑ'
        Cₖ⁴¹ = l₀2Rₑ * Cₖ⁴¹ * Rₑ'
        Cₖ⁴² = l₀2Rₑ * Cₖ⁴² * Rₑ'
        Cₖ⁴³ = l₀2Rₑ * Cₖ⁴³ * Rₑ'
        Cₖ⁴⁴ = l₀2Rₑ * Cₖ⁴⁴ * Rₑ'


        kinetic_energy = l₀/2* kinetic_energy

        if exact

            Θ₁ = toangle(ΔR₁)
            Θ₂ = toangle(ΔR₂)
            
            Tₛ⁻¹Θ₁ = Tₛ⁻¹(Θ₁)
            Tₛ⁻¹Θ₂ = Tₛ⁻¹(Θ₂)

            M²¹ = M¹²' * Tₛ⁻¹Θ₁'
            M²² = M²²  * Tₛ⁻¹Θ₁' 
            M²³ = M²³  * Tₛ⁻¹Θ₁'
            M²⁴ = M²⁴  * Tₛ⁻¹Θ₁'
            M³¹ = M¹³'
            M³² = M²³'
            M⁴¹ = M¹⁴' * Tₛ⁻¹Θ₂'
            M⁴² = M²⁴' * Tₛ⁻¹Θ₂' 
            M⁴³ = M³⁴' * Tₛ⁻¹Θ₂'
            M⁴⁴ = M⁴⁴  * Tₛ⁻¹Θ₂'

            Cₖ²¹ = Cₖ²¹ * Tₛ⁻¹Θ₁'
            Cₖ²² = Cₖ²² * Tₛ⁻¹Θ₁' 
            Cₖ²³ = Cₖ²³ * Tₛ⁻¹Θ₁'
            Cₖ²⁴ = Cₖ²⁴ * Tₛ⁻¹Θ₁'
            Cₖ⁴¹ = Cₖ⁴¹ * Tₛ⁻¹Θ₂'
            Cₖ⁴² = Cₖ⁴² * Tₛ⁻¹Θ₂' 
            Cₖ⁴³ = Cₖ⁴³ * Tₛ⁻¹Θ₂'
            Cₖ⁴⁴ = Cₖ⁴⁴ * Tₛ⁻¹Θ₂'

        else

            M²¹ = M¹²'
            M³¹ = M¹³'
            M³² = M²³'
            M⁴¹ = M¹⁴' 
            M⁴² = M²⁴'
            M⁴³ = M³⁴'

        end


        Tₖ = [Tₖ¹; Tₖ²; Tₖ³; Tₖ⁴]
        M = hcat(vcat(M¹¹, M²¹, M³¹, M⁴¹), vcat(M¹², M²², M³², M⁴²), vcat(M¹³, M²³, M³³, M⁴³), vcat(M¹⁴, M²⁴, M³⁴, M⁴⁴))
        Cₖ = hcat(vcat(Cₖ¹¹, Cₖ²¹, Cₖ³¹, Cₖ⁴¹), vcat(Cₖ¹², Cₖ²², Cₖ³², Cₖ⁴²), vcat(Cₖ¹³, Cₖ²³, Cₖ³³, Cₖ⁴³), vcat(Cₖ¹⁴, Cₖ²⁴, Cₖ³⁴, Cₖ⁴⁴))
        

        return strain_energy, kinetic_energy, Tᵢₙₜ, Tₖ, Kᵢₙₜ, M, Cₖ

    end

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


        #         t²₁₁ = N₇lₙ^2 * Rₑ * A₁ᵀ𝓕ᶜr₁₁ - Rₑ * Gᵀ¹' * S𝓕ᶜ * P₁P¹ * Rₑ'
        #         t²₁₂ =                         - Rₑ * Gᵀ¹' * S𝓕ᶜ * P₁P² * Rₑ'
        #         t²₁₃ = N₇lₙ^2 * Rₑ * A₁ᵀ𝓕ᶜr₁₃ - Rₑ * Gᵀ¹' * S𝓕ᶜ * P₁P³ * Rₑ'
        #         t²₁₄ =                         - Rₑ * Gᵀ¹' * S𝓕ᶜ * P₁P⁴ * Rₑ'

        #         t²₂₁ =                         - Rₑ * Gᵀ²' * S𝓕ᶜ * P₁P¹ * Rₑ'
        #         t²₂₂ =                         - Rₑ * Gᵀ²' * S𝓕ᶜ * P₁P² * Rₑ'
        #         t²₂₃ =                         - Rₑ * Gᵀ²' * S𝓕ᶜ * P₁P³ * Rₑ'
        #         t²₂₄ =                         - Rₑ * Gᵀ²' * S𝓕ᶜ * P₁P⁴ * Rₑ'

        #         t²₃₁ = N₇lₙ^2 * Rₑ * A₁ᵀ𝓕ᶜr₃₁ - Rₑ * Gᵀ³' * S𝓕ᶜ * P₁P¹ * Rₑ'
        #         t²₃₂ =                         - Rₑ * Gᵀ³' * S𝓕ᶜ * P₁P² * Rₑ'
        #         t²₃₃ = N₇lₙ^2 * Rₑ * A₁ᵀ𝓕ᶜr₃₃ - Rₑ * Gᵀ³' * S𝓕ᶜ * P₁P³ * Rₑ'
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

        #         𝓐₃¹ = I∂gₙ∂x * N₇lₙ^2 * Rₑ * A₁Ḋr¹ + Rₑ * skew(Gᵀ¹ * U̇₁) * P₁P¹ * Rₑ'
        #         𝓐₃² =                                  Rₑ * skew(Gᵀ² * Ẇ₁) * P₁P² * Rₑ'
        #         𝓐₃³ = I∂gₙ∂x * N₇lₙ^2 * Rₑ * A₁Ḋr³ + Rₑ * skew(Gᵀ³ * U̇₂) * P₁P³ * Rₑ'
        #         𝓐₃⁴ =                                  Rₑ * skew(Gᵀ⁴ * Ẇ₂) * P₁P⁴ * Rₑ'



        #         # eq110 in [2]
        #         Inn = ID3 - ∂gₙ∂x*∂gₙ∂x'
        #         dgT = Inn*Rₑ*H1G*E'*Ḋ
        #         dgTdgT = dot(dgT,dgT)
                
        #         G_eN = ∂gₙ∂x


                

        #     end


    
end




function compute_K_T!(nodes, allbeams, matrices, energy, conf, sdf, comp, sol_GP, to, T=Float64) 
    
    @timeit_debug to "Initialization" begin
        
        # initialise the matrices associate to the whole structure
        matrices.Kⁱⁿᵗ.nzval .= 0
        matrices.Cᵏ.nzval .= 0 
        matrices.M.nzval .= 0
        matrices.Kᶜᵗ.nzval .= 0
        matrices.Tⁱⁿᵗ .= 0
        matrices.Tᵏ .= 0
        matrices.Tᵈᵃᵐᵖ .= 0
        matrices.Tᶜᵗ .= 0
       
        # initialise the energy values associate to the whole structure
        energy.strain_energy = 0
        energy.kinetic_energy = 0
        energy.C_energy = 0
        
    end
    
    # cycle over the beams   
    @timeit_debug to "Compute and assemble elemental contributions" begin

        for e in LazyRows(allbeams)
            
            @timeit_debug to "Compute elemental contributions" begin
                
                # information from node 1 and 2
                X₁, X₂ = nodes.X₀[e.node1], nodes.X₀[e.node2]
                u₁, u₂ = nodes.u[e.node1], nodes.u[e.node2]
                u̇₁, u̇₂ = nodes.u̇[e.node1], nodes.u̇[e.node2]
                ü₁, ü₂ = nodes.ü[e.node1], nodes.ü[e.node2]
                ẇ₁, ẇ₂ = nodes.ẇ[e.node1], nodes.ẇ[e.node2]
                ẅ₁, ẅ₂ = nodes.ẅ[e.node1], nodes.ẅ[e.node2]
                R₁, R₂ = nodes.R[e.node1], nodes.R[e.node2]
                ΔR₁, ΔR₂ = nodes.ΔR[e.node1], nodes.ΔR[e.node2]


                #----------------------------------------
                # Compute the contibution from the e beam
                strain_energy, kinetic_energy, Tⁱⁿᵗ, Tᵏ, Kⁱⁿᵗ, M, Cᵏ = get_beam_contributions(u₁, R₁, u₂, R₂, ΔR₁, ΔR₂, u̇₁, u̇₂, ẇ₁, ẇ₂, ü₁, ü₂, ẅ₁, ẅ₂, e.Rₑ⁰, X₁, X₂, e.l₀, comp, conf.mat, conf.geom)
            
            end 

            @timeit_debug to "Assemble elemental contributions" begin

                #-----------------------
                # Assemble contributions
                
                idof1 = nodes.idof_6[e.node1]
                idof2 = nodes.idof_6[e.node2]
                
                idof = vcat(idof1, idof2)
                
                energy.strain_energy +=  strain_energy
                energy.kinetic_energy += kinetic_energy
                # energy.C_energy +=  C_energy
            
                update_spmat_sum(matrices.Kⁱⁿᵗ, e.sparsity_map, Kⁱⁿᵗ)
                update_spmat_sum(matrices.Cᵏ, e.sparsity_map, Cᵏ)
                update_spmat_sum(matrices.M, e.sparsity_map, M)
                # update_spmat_sum(matrices.Kᶜᵗ, e.sparsity_map, Kᶜᵗ)

                
                update_vec_sum(matrices.Tᵏ, idof, Tᵏ)
                # update_vec_sum(matrices.Tᵈᵃᵐᵖ, idof, Tᵈᵃᵐᵖ)
                update_vec_sum(matrices.Tⁱⁿᵗ, idof, Tⁱⁿᵗ)
                # update_vec_sum(matrices.Tᶜᵗ, idof, Tᶜᵗ)
            end
                               
        end



    end 
    
end 
