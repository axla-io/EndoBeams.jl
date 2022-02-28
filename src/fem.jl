
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

    return Rₑ, ru₁, ru₂, η, Gᵀu₁, GᵀΘ₁, Gᵀu₂, GᵀΘ₂, D₃
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


#  Compute Kint matrix
@inline function K̄ⁱⁿᵗ_beam(mat, geom, l₀)
    
    K̄ⁱⁿᵗū = geom.A*mat.E/l₀
    K̄ⁱⁿᵗΘ̅ = Diagonal(@SVector [mat.G*geom.J/l₀, 4*mat.E*geom.I₃₃/l₀, 4*mat.E*geom.I₂₂/l₀])
    K̄ⁱⁿᵗΘ̅Θ̅ = Diagonal(@SVector [-mat.G*geom.J/l₀, 2*mat.E*geom.I₃₃/l₀, 2*mat.E*geom.I₂₂/l₀])
    
    return K̄ⁱⁿᵗū, K̄ⁱⁿᵗΘ̅, K̄ⁱⁿᵗΘ̅Θ̅
    
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




Base.@propagate_inbounds function compute_forces(u₁::AbstractVector{T}, u₂, R₁, R₂, ΔR₁, ΔR₂, u̇₁, u̇₂, ẇ₁, ẇ₂, ü₁, ü₂, ẅ₁, ẅ₂, simvars, exact=true, dynamics=true) where T

    # Superscript ¹ means matrix or vector associated to u₁
    # Superscript ² means matrix or vector associated to Θ₁
    # Superscript ³ means matrix or vector associated to u₂
    # Superscript ⁴ means matrix or vector associated to Θ₂

    mat, geom, comp, init, sdf = simvars
    X₁, X₂, l₀, Rₑ⁰ = init
    

    x₁ =  X₁ + u₁
    x₂ =  X₂ + u₂
    
    lₙ = norm(x₂ - x₁)

    ū = lₙ - l₀

    Rₑ, r¹, r³, η, Gᵀ¹, Gᵀ², Gᵀ³, Gᵀ⁴, D₃ = local_Rₑ_and_aux(x₁, x₂, R₁, R₂, Rₑ⁰[:,2], lₙ)


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
    P¹⁴ = -Gᵀ⁴
    P²⁴ = ID3-Gᵀ⁴


    # B̄⁺ = [r; PEᵀ]
    B̄⁺¹ = r¹
    B̄⁺¹¹ = P¹¹ * Rₑ'
    B̄⁺²¹ = B̄⁺¹¹
    B̄⁺¹² = P¹² * Rₑ'
    B̄⁺²² = P²² * Rₑ'
    B̄⁺¹⁴ = P¹⁴ * Rₑ'
    B̄⁺²⁴ = P²⁴ * Rₑ'

    
    # B = B̄B̄⁺
    B¹ = B̄⁺¹
    B¹¹ = exact ?  Tₛ⁻¹Θ̅₁ * B̄⁺¹¹ : B̄⁺¹¹
    B¹² = exact ?  Tₛ⁻¹Θ̅₁ * B̄⁺¹² : B̄⁺¹²
    B¹⁴ = exact ?  Tₛ⁻¹Θ̅₁ * B̄⁺¹⁴ : B̄⁺¹⁴
    B²¹ = exact ?  Tₛ⁻¹Θ̅₂ * B̄⁺²¹ : B̄⁺²¹
    B²² = exact ?  Tₛ⁻¹Θ̅₂ * B̄⁺²² : B̄⁺²²
    B²⁴ = exact ?  Tₛ⁻¹Θ̅₂ * B̄⁺²⁴ : B̄⁺²⁴

    

    K̄ⁱⁿᵗū, K̄ⁱⁿᵗΘ̅, K̄ⁱⁿᵗΘ̅Θ̅ = K̄ⁱⁿᵗ_beam(mat, geom, l₀)

    # T̄ⁱⁿᵗ = K̄ⁱⁿᵗ D̄
    T̄ⁱⁿᵗū  = K̄ⁱⁿᵗū  * ū
    T̄ⁱⁿᵗΘ̅₁ = K̄ⁱⁿᵗΘ̅  * Θ̅₁ + K̄ⁱⁿᵗΘ̅Θ̅ * Θ̅₂
    T̄ⁱⁿᵗΘ̅₂ = K̄ⁱⁿᵗΘ̅Θ̅ * Θ̅₁ + K̄ⁱⁿᵗΘ̅  * Θ̅₂

    strain_energy = (ū*T̄ⁱⁿᵗū + dot(Θ̅₁, T̄ⁱⁿᵗΘ̅₁) + dot(Θ̅₂, T̄ⁱⁿᵗΘ̅₂))/2


    # Tⁱⁿᵗ = Bᵀ T̄ⁱⁿᵗ
    Tⁱⁿᵗ¹ = B¹'*T̄ⁱⁿᵗū + B¹¹'*T̄ⁱⁿᵗΘ̅₁ + B²¹'*T̄ⁱⁿᵗΘ̅₂
    Tⁱⁿᵗ² =             B¹²'*T̄ⁱⁿᵗΘ̅₁ + B²²'*T̄ⁱⁿᵗΘ̅₂
    Tⁱⁿᵗ³ = -Tⁱⁿᵗ¹
    Tⁱⁿᵗ⁴ =             B¹⁴'*T̄ⁱⁿᵗΘ̅₁ + B²⁴'*T̄ⁱⁿᵗΘ̅₂



    # Force
    Tⁱⁿᵗ = [Tⁱⁿᵗ¹; Tⁱⁿᵗ²; Tⁱⁿᵗ³; Tⁱⁿᵗ⁴]


    kinetic_energy = zero(T)

    Tᵏ¹ = zeros(Vec3{T})
    Tᵏ² = zeros(Vec3{T})
    Tᵏ³ = zeros(Vec3{T})
    Tᵏ⁴ = zeros(Vec3{T})

    contact_energy = zero(T)
        
    Tᶜ¹ = zeros(Vec3{T})
    Tᶜ² = zeros(Vec3{T})
    Tᶜ³ = zeros(Vec3{T})
    Tᶜ⁴ = zeros(Vec3{T})

    
    contact = !isnothing(sdf)
        
    if dynamics
        
        U̇₁ = Rₑ' * u̇₁
        U̇₂ = Rₑ' * u̇₂
        Ẇ₁ = Rₑ' * ẇ₁
        Ẇ₂ = Rₑ' * ẇ₂
        
        Ü₁ = Rₑ' * ü₁
        Ü₂ = Rₑ' * ü₂
        Ẅ₁ = Rₑ' * ẅ₁
        Ẅ₂ = Rₑ' * ẅ₂

        Ẇᵉ = Gᵀ¹ * U̇₁ + Gᵀ² * Ẇ₁ + Gᵀ³ * U̇₂ + Gᵀ⁴ * Ẇ₂
        SẆᵉ = skew(Ẇᵉ)

        rḋ = dot(r¹, u̇₁) + dot(r³, u̇₂)

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
            N₇lₙ² = N₇lₙ/lₙ
            N₈lₙ = N₈/lₙ
            N₈lₙ² = N₈lₙ/lₙ

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
            
            N₇rḋ = N₇lₙ² * rḋ
            Ḣ₁¹ = Diagonal(@SVector [0, -N₇rḋ, -N₇rḋ]) - Su̇ᵗ * Gᵀ¹
            Ḣ₁² =                                      - Su̇ᵗ * Gᵀ²
            Ḣ₁⁴ =                                      - Su̇ᵗ * Gᵀ⁴

            N₈rḋ = N₈lₙ² * rḋ
            Ḣ₂¹ = @SMatrix [0 0 0; 0 0 N₈rḋ; 0 -N₈rḋ 0]

            h₁ = H₁¹ * U̇₁ + H₁² * Ẇ₁ + H₁³ * U̇₂ + H₁⁴ * Ẇ₂
            h₂ = H₂¹ * U̇₁ + H₂² * Ẇ₁ + H₂³ * U̇₂ + H₂⁴ * Ẇ₂

            C₁¹ = SẆᵉ * H₁¹ + Ḣ₁¹ - H₁¹ * SẆᵉ
            C₁² = SẆᵉ * H₁² + Ḣ₁² - H₁² * SẆᵉ
            C₁³ = -C₁¹
            C₁⁴ = SẆᵉ * H₁⁴ + Ḣ₁⁴ - H₁⁴ * SẆᵉ

            C₂¹ = SẆᵉ * H₂¹ + Ḣ₂¹ - H₂¹ * SẆᵉ
            C₂² = SẆᵉ * H₂²       - H₂² * SẆᵉ
            C₂³ = -C₂¹
            C₂⁴ = SẆᵉ * H₂⁴       - H₂⁴ * SẆᵉ

            u̇₀ = Rₑ * h₁

            H₁Eᵀd̈ = H₁¹ * Ü₁ + H₁² * Ẅ₁ + H₁³ * Ü₂ + H₁⁴ * Ẅ₂
            C₁Eᵀḋ = C₁¹ * U̇₁ + C₁² * Ẇ₁ + C₁³ * U̇₂ + C₁⁴ * Ẇ₂
            Rₑᵀü₀ = H₁Eᵀd̈ + C₁Eᵀḋ

            Ẇ₀ = h₂
            ẇ₀ = Rₑ * Ẇ₀

            H₂Eᵀd̈ = H₂¹ * Ü₁ + H₂² * Ẅ₁ + H₂³ * Ü₂ + H₂⁴ * Ẅ₂
            C₂Eᵀḋ = C₂¹ * U̇₁ + C₂² * Ẇ₁ + C₂³ * U̇₂ + C₂⁴ * Ẇ₂
            Rₑᵀẅ₀ = H₂Eᵀd̈ + C₂Eᵀḋ

            SẆ₀ = skew(Ẇ₀)
            ĪᵨRₑᵀẅ₀ = Īᵨ*Rₑᵀẅ₀
            SẆ₀Īᵨ = SẆ₀*Īᵨ
            SẆ₀ĪᵨẆ₀ = SẆ₀Īᵨ*Ẇ₀
            ĪᵨRₑᵀẅ₀SẆ₀ĪᵨẆ₀ = ĪᵨRₑᵀẅ₀ + SẆ₀ĪᵨẆ₀
            AᵨH₁¹ᵀ = Aᵨ*H₁¹'
            AᵨH₁²ᵀ = Aᵨ*H₁²'
            AᵨH₁⁴ᵀ = Aᵨ*H₁⁴'

            Tᵏ¹G = ωᴳ * (AᵨH₁¹ᵀ*Rₑᵀü₀ + H₂¹'*ĪᵨRₑᵀẅ₀SẆ₀ĪᵨẆ₀)
            Tᵏ¹ += Tᵏ¹G
            Tᵏ² += ωᴳ * (AᵨH₁²ᵀ*Rₑᵀü₀ + H₂²'*ĪᵨRₑᵀẅ₀SẆ₀ĪᵨẆ₀)
            Tᵏ³ += -Tᵏ¹G + ωᴳ * Aᵨ * Rₑᵀü₀
            Tᵏ⁴ += ωᴳ * (AᵨH₁⁴ᵀ*Rₑᵀü₀ + H₂⁴'*ĪᵨRₑᵀẅ₀SẆ₀ĪᵨẆ₀)


            if comp.damping>0
                Tᵈ¹G = ωᴳ * (comp.damping * AᵨH₁¹ᵀ*h₁ + H₂¹'*Īᵨ*h₂)
                Tᵏ¹ += Tᵈ¹G
                Tᵏ² += ωᴳ * (comp.damping * AᵨH₁²ᵀ*h₁ + H₂²'*Īᵨ*h₂)
                Tᵏ³ += -Tᵈ¹G + ωᴳ * Aᵨ * comp.damping * h₁
                Tᵏ⁴ += ωᴳ * (comp.damping * AᵨH₁⁴ᵀ*h₁ + H₂⁴'*Īᵨ*h₂)
            end


            # kinetic energy
            Īᵨᵍ = Rₑ*Īᵨ*Rₑ'
            kinetic_energy += ωᴳ/2 * (Aᵨ*u̇₀'*u̇₀ + ẇ₀'*Īᵨᵍ*ẇ₀)



            if contact

                xᴳ = N₁*x₁ + N₂*x₂ + Rₑ*uᵗ
                pₙ, _, Πₑ, _, ∂gₙ∂x, _ =  contact_gap(xᴳ, comp.εᶜ, sdf)
        
                if pₙ > 0 
        
                    I∂gₙ∂x = ID3 - ∂gₙ∂x*∂gₙ∂x'
                    ġₜ = I∂gₙ∂x*u̇₀
                    ġₜ² = dot(ġₜ, ġₜ)
        
                    contact_energy -= ωᴳ*Πₑ
                    
                    𝓖ₙ = ∂gₙ∂x
                    μʳᵉᵍ = comp.μ/sqrt(ġₜ²+comp.εᵗ)
                    𝓖ₜ = -μʳᵉᵍ*ġₜ
                    
        
                    𝓖 = 𝓖ₙ + 𝓖ₜ
                    𝓯ᶜ = pₙ * 𝓖
        
                    𝓕ᶜ = Rₑ' * 𝓯ᶜ
        
                    RₑH₁ᵀ¹ = Rₑ * H₁¹'
                    RₑH₁ᵀ² = Rₑ * H₁²'
                    RₑH₁ᵀ³ = Rₑ * H₁³'
                    RₑH₁ᵀ⁴ = Rₑ * H₁⁴'
        
                    Tᶜ¹ += ωᴳ * (RₑH₁ᵀ¹ * 𝓕ᶜ)
                    Tᶜ² += ωᴳ * (RₑH₁ᵀ² * 𝓕ᶜ)
                    Tᶜ³ += ωᴳ * (RₑH₁ᵀ³ * 𝓕ᶜ)
                    Tᶜ⁴ += ωᴳ * (RₑH₁ᵀ⁴ * 𝓕ᶜ)

    
        
                end
            
            
            end


            
        end

        l₀2 = l₀/2
        l₀2Rₑ = l₀2 * Rₑ


        Tᵏ¹ = l₀2Rₑ*Tᵏ¹
        Tᵏ² = l₀2Rₑ*Tᵏ²
        Tᵏ³ = l₀2Rₑ*Tᵏ³
        Tᵏ⁴ = l₀2Rₑ*Tᵏ⁴


        kinetic_energy = l₀2* kinetic_energy


        if contact


            Tᶜ¹ = l₀2*Tᶜ¹
            Tᶜ² = l₀2*Tᶜ²
            Tᶜ³ = l₀2*Tᶜ³
            Tᶜ⁴ = l₀2*Tᶜ⁴

            contact_energy = l₀2 * contact_energy


        end



    end

    Tᵏ = [Tᵏ¹; Tᵏ²; Tᵏ³; Tᵏ⁴]
    
    Tᶜ = [Tᶜ¹; Tᶜ²; Tᶜ³; Tᶜ⁴]

    return strain_energy, kinetic_energy, contact_energy, Tⁱⁿᵗ, Tᵏ, Tᶜ

    
end





Base.@propagate_inbounds function compute(u₁::AbstractVector{T}, u₂, R₁, R₂, ΔR₁, ΔR₂, u̇₁, u̇₂, ẇ₁, ẇ₂, ü₁, ü₂, ẅ₁, ẅ₂, simvars, exact=true, dynamics=true) where T

    # Superscript ¹ means matrix or vector associated to u₁
    # Superscript ² means matrix or vector associated to Θ₁
    # Superscript ³ means matrix or vector associated to u₂
    # Superscript ⁴ means matrix or vector associated to Θ₂

    mat, geom, comp, init, sdf = simvars
    X₁, X₂, l₀, Rₑ⁰ = init
    

    x₁ =  X₁ + u₁
    x₂ =  X₂ + u₂
    
    lₙ = norm(x₂ - x₁)

    ū = lₙ - l₀

    Rₑ, r¹, r³, η, Gᵀ¹, Gᵀ², Gᵀ³, Gᵀ⁴, D₃ = local_Rₑ_and_aux(x₁, x₂, R₁, R₂, Rₑ⁰[:,2], lₙ)


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
    P¹⁴ = -Gᵀ⁴
    P²⁴ = ID3-Gᵀ⁴


    # B̄⁺ = [r; PEᵀ]
    B̄⁺¹ = r¹
    B̄⁺¹¹ = P¹¹ * Rₑ'
    B̄⁺²¹ = B̄⁺¹¹
    B̄⁺¹² = P¹² * Rₑ'
    B̄⁺²² = P²² * Rₑ'
    B̄⁺¹⁴ = P¹⁴ * Rₑ'
    B̄⁺²⁴ = P²⁴ * Rₑ'

    
    # B = B̄B̄⁺
    B¹ = B̄⁺¹
    B¹¹ = exact ?  Tₛ⁻¹Θ̅₁ * B̄⁺¹¹ : B̄⁺¹¹
    B¹² = exact ?  Tₛ⁻¹Θ̅₁ * B̄⁺¹² : B̄⁺¹²
    B¹⁴ = exact ?  Tₛ⁻¹Θ̅₁ * B̄⁺¹⁴ : B̄⁺¹⁴
    B²¹ = exact ?  Tₛ⁻¹Θ̅₂ * B̄⁺²¹ : B̄⁺²¹
    B²² = exact ?  Tₛ⁻¹Θ̅₂ * B̄⁺²² : B̄⁺²²
    B²⁴ = exact ?  Tₛ⁻¹Θ̅₂ * B̄⁺²⁴ : B̄⁺²⁴

    

    K̄ⁱⁿᵗū, K̄ⁱⁿᵗΘ̅, K̄ⁱⁿᵗΘ̅Θ̅ = K̄ⁱⁿᵗ_beam(mat, geom, l₀)

    # T̄ⁱⁿᵗ = K̄ⁱⁿᵗ D̄
    T̄ⁱⁿᵗū  = K̄ⁱⁿᵗū  * ū
    T̄ⁱⁿᵗΘ̅₁ = K̄ⁱⁿᵗΘ̅  * Θ̅₁ + K̄ⁱⁿᵗΘ̅Θ̅ * Θ̅₂
    T̄ⁱⁿᵗΘ̅₂ = K̄ⁱⁿᵗΘ̅Θ̅ * Θ̅₁ + K̄ⁱⁿᵗΘ̅  * Θ̅₂

    strain_energy = (ū*T̄ⁱⁿᵗū + dot(Θ̅₁, T̄ⁱⁿᵗΘ̅₁) + dot(Θ̅₂, T̄ⁱⁿᵗΘ̅₂))/2


    # Tⁱⁿᵗ = Bᵀ T̄ⁱⁿᵗ
    Tⁱⁿᵗ¹ = B¹'*T̄ⁱⁿᵗū + B¹¹'*T̄ⁱⁿᵗΘ̅₁ + B²¹'*T̄ⁱⁿᵗΘ̅₂
    Tⁱⁿᵗ² =             B¹²'*T̄ⁱⁿᵗΘ̅₁ + B²²'*T̄ⁱⁿᵗΘ̅₂
    Tⁱⁿᵗ³ = -Tⁱⁿᵗ¹
    Tⁱⁿᵗ⁴ =             B¹⁴'*T̄ⁱⁿᵗΘ̅₁ + B²⁴'*T̄ⁱⁿᵗΘ̅₂



    # Force
    Tⁱⁿᵗ = [Tⁱⁿᵗ¹; Tⁱⁿᵗ²; Tⁱⁿᵗ³; Tⁱⁿᵗ⁴]


    # [N̄ M̄⁺₁ M̄⁺₂] = B̄ᵀ T̄ⁱⁿᵗ
    N̄   = T̄ⁱⁿᵗū
    M̄⁺₁ = exact ? Tₛ⁻¹Θ̅₁' * T̄ⁱⁿᵗΘ̅₁  : T̄ⁱⁿᵗΘ̅₁
    M̄⁺₂ = exact ? Tₛ⁻¹Θ̅₂' * T̄ⁱⁿᵗΘ̅₂  : T̄ⁱⁿᵗΘ̅₂


    # Qₛ = Pᵀ [M̄⁺₁ M̄⁺₂]
    Qₛ¹ = P¹¹' * M̄⁺₁ + P²¹' * M̄⁺₂
    Qₛ² = P¹²' * M̄⁺₁ + P²²' * M̄⁺₂
    Qₛ⁴ = P¹⁴' * M̄⁺₁ + P²⁴' * M̄⁺₂
    

    # Q = S(Qₛ)
    Q¹ = skew(Qₛ¹)
    Q² = skew(Qₛ²)
    Q⁴ = skew(Qₛ⁴)

    a = @SVector [0, η*(M̄⁺₁[1] + M̄⁺₂[1])/lₙ + (M̄⁺₁[2] + M̄⁺₂[2])/lₙ, (M̄⁺₁[3] + M̄⁺₂[3])/lₙ]


    # DN̄ (DN̄¹¹ = DN̄³³ = -DN̄¹³ = -DN̄³¹)
    DN̄¹¹ = D₃*N̄

    #QGᵀ
    QGᵀ¹¹ = Q¹*Gᵀ¹
    QGᵀ¹² = Q¹*Gᵀ²
    QGᵀ¹⁴ = Q¹*Gᵀ⁴

    QGᵀ²² = Q²*Gᵀ²
    QGᵀ²⁴ = Q²*Gᵀ⁴

    QGᵀ⁴⁴ = Q⁴*Gᵀ⁴


    # EGa (diagonal)
    # Note: Rₑ*Ga = 0 for Θ indices because Rₑ*GᵀΘ' has only non-zero values in the first column and a = [0 ...]
    EGa¹ = Rₑ*Gᵀ¹'*a

    # EGar (EGar¹¹ = EGar³³ = -EGar³¹ = -EGar¹³)
    EGar¹¹ = EGa¹*r¹

    # Kₘ = DN̄ - EQGᵀEᵀ + EGar
    Kₘ¹¹ = DN̄¹¹ - Rₑ*QGᵀ¹¹*Rₑ' + EGar¹¹
    Kₘ¹² =      - Rₑ*QGᵀ¹²*Rₑ'
    Kₘ¹⁴ =      - Rₑ*QGᵀ¹⁴*Rₑ'
    
    Kₘ²² =      - Rₑ*QGᵀ²²*Rₑ'
    Kₘ²⁴ =      - Rₑ*QGᵀ²⁴*Rₑ'

    Kₘ⁴⁴ =      - Rₑ*QGᵀ⁴⁴*Rₑ'


    # K̃

    if exact

        η₁, μ₁ = compute_η_μ(Θ̅₁)
        η₂, μ₂ = compute_η_μ(Θ̅₂)

        M̄₁ = T̄ⁱⁿᵗΘ̅₁
        M̄₂ = T̄ⁱⁿᵗΘ̅₂

        K̄ₕ₁ = compute_K̄ₕ(Θ̅₁, M̄₁, Tₛ⁻¹Θ̅₁, η₁, μ₁)
        K̄ₕ₂ = compute_K̄ₕ(Θ̅₂, M̄₂, Tₛ⁻¹Θ̅₂, η₂, μ₂)

    end


    K̃¹¹ = exact ?  B̄⁺¹¹' * K̄ₕ₁ * B̄⁺¹¹  +  B̄⁺²¹' * K̄ₕ₂ * B̄⁺²¹  +  Kₘ¹¹   :   Kₘ¹¹ 
    K̃¹² = exact ?  B̄⁺¹¹' * K̄ₕ₁ * B̄⁺¹²  +  B̄⁺²¹' * K̄ₕ₂ * B̄⁺²²  +  Kₘ¹²   :   Kₘ¹² 
    K̃¹⁴ = exact ?  B̄⁺¹¹' * K̄ₕ₁ * B̄⁺¹⁴  +  B̄⁺²¹' * K̄ₕ₂ * B̄⁺²⁴  +  Kₘ¹⁴   :   Kₘ¹⁴ 

    K̃²² = exact ?  B̄⁺¹²' * K̄ₕ₁ * B̄⁺¹²  +  B̄⁺²²' * K̄ₕ₂ * B̄⁺²²  +  Kₘ²²   :   Kₘ²² 
    K̃²⁴ = exact ?  B̄⁺¹²' * K̄ₕ₁ * B̄⁺¹⁴  +  B̄⁺²²' * K̄ₕ₂ * B̄⁺²⁴  +  Kₘ²⁴   :   Kₘ²⁴ 

    K̃⁴⁴ = exact ?  B̄⁺¹⁴' * K̄ₕ₁ * B̄⁺¹⁴  +  B̄⁺²⁴' * K̄ₕ₂ * B̄⁺²⁴  +  Kₘ⁴⁴   :   Kₘ⁴⁴ 


    # BᵀKⁱⁿᵗB
    
    BᵀKⁱⁿᵗB¹¹ = B¹' * K̄ⁱⁿᵗū * B¹      +      B¹¹' * (K̄ⁱⁿᵗΘ̅ * B¹¹  +  K̄ⁱⁿᵗΘ̅Θ̅ * B²¹)  +  B²¹' * (K̄ⁱⁿᵗΘ̅Θ̅ * B¹¹  +  K̄ⁱⁿᵗΘ̅ * B²¹)    
    BᵀKⁱⁿᵗB¹² =                              B¹¹' * (K̄ⁱⁿᵗΘ̅ * B¹²  +  K̄ⁱⁿᵗΘ̅Θ̅ * B²²)  +  B²¹' * (K̄ⁱⁿᵗΘ̅Θ̅ * B¹²  +  K̄ⁱⁿᵗΘ̅ * B²²)     
    BᵀKⁱⁿᵗB¹⁴ =                              B¹¹' * (K̄ⁱⁿᵗΘ̅ * B¹⁴  +  K̄ⁱⁿᵗΘ̅Θ̅ * B²⁴)  +  B²¹' * (K̄ⁱⁿᵗΘ̅Θ̅ * B¹⁴  +  K̄ⁱⁿᵗΘ̅ * B²⁴)    
        
    BᵀKⁱⁿᵗB²² =                              B¹²' * (K̄ⁱⁿᵗΘ̅ * B¹²  +  K̄ⁱⁿᵗΘ̅Θ̅ * B²²)  +  B²²' * (K̄ⁱⁿᵗΘ̅Θ̅ * B¹²  +  K̄ⁱⁿᵗΘ̅ * B²²)      
    BᵀKⁱⁿᵗB²⁴ =                              B¹²' * (K̄ⁱⁿᵗΘ̅ * B¹⁴  +  K̄ⁱⁿᵗΘ̅Θ̅ * B²⁴)  +  B²²' * (K̄ⁱⁿᵗΘ̅Θ̅ * B¹⁴  +  K̄ⁱⁿᵗΘ̅ * B²⁴)      
        
    BᵀKⁱⁿᵗB⁴⁴ =                              B¹⁴' * (K̄ⁱⁿᵗΘ̅ * B¹⁴  +  K̄ⁱⁿᵗΘ̅Θ̅ * B²⁴)  +  B²⁴' * (K̄ⁱⁿᵗΘ̅Θ̅ * B¹⁴  +  K̄ⁱⁿᵗΘ̅ * B²⁴)    

    Kⁱⁿᵗ¹¹ =  BᵀKⁱⁿᵗB¹¹   +    K̃¹¹
    Kⁱⁿᵗ¹² =  BᵀKⁱⁿᵗB¹²   +    K̃¹²
    Kⁱⁿᵗ¹³ =  -Kⁱⁿᵗ¹¹
    Kⁱⁿᵗ¹⁴ =  BᵀKⁱⁿᵗB¹⁴   +    K̃¹⁴

    Kⁱⁿᵗ²² =  BᵀKⁱⁿᵗB²²   +    K̃²²
    Kⁱⁿᵗ²³ =  -Kⁱⁿᵗ¹²'
    Kⁱⁿᵗ²⁴ =  BᵀKⁱⁿᵗB²⁴   +    K̃²⁴
    
    Kⁱⁿᵗ³³ =  Kⁱⁿᵗ¹¹
    Kⁱⁿᵗ³⁴ =  -Kⁱⁿᵗ¹⁴

    Kⁱⁿᵗ⁴⁴ =  BᵀKⁱⁿᵗB⁴⁴   +    K̃⁴⁴



    Kⁱⁿᵗ = hcat(vcat(Kⁱⁿᵗ¹¹, Kⁱⁿᵗ¹²', Kⁱⁿᵗ¹³', Kⁱⁿᵗ¹⁴'), vcat(Kⁱⁿᵗ¹², Kⁱⁿᵗ²², Kⁱⁿᵗ²³', Kⁱⁿᵗ²⁴'), vcat(Kⁱⁿᵗ¹³, Kⁱⁿᵗ²³, Kⁱⁿᵗ³³, Kⁱⁿᵗ³⁴'), vcat(Kⁱⁿᵗ¹⁴, Kⁱⁿᵗ²⁴, Kⁱⁿᵗ³⁴, Kⁱⁿᵗ⁴⁴))






    kinetic_energy = zero(T)

    Tᵏ¹ = zeros(Vec3{T})
    Tᵏ² = zeros(Vec3{T})
    Tᵏ³ = zeros(Vec3{T})
    Tᵏ⁴ = zeros(Vec3{T})


    M¹¹ = zeros(Mat33{T})
    M¹² = zeros(Mat33{T})
    M¹³ = zeros(Mat33{T})
    M¹⁴ = zeros(Mat33{T})
    M²¹ = zeros(Mat33{T})
    M²² = zeros(Mat33{T})
    M²³ = zeros(Mat33{T})
    M²⁴ = zeros(Mat33{T})
    M³¹ = zeros(Mat33{T})
    M³² = zeros(Mat33{T})
    M³³ = zeros(Mat33{T})
    M³⁴ = zeros(Mat33{T})
    M⁴¹ = zeros(Mat33{T})
    M⁴² = zeros(Mat33{T})
    M⁴³ = zeros(Mat33{T})
    M⁴⁴ = zeros(Mat33{T})

    Cᵏ¹¹ = zeros(Mat33{T})
    Cᵏ¹² = zeros(Mat33{T})
    Cᵏ¹³ = zeros(Mat33{T})
    Cᵏ¹⁴ = zeros(Mat33{T})
    Cᵏ²¹ = zeros(Mat33{T})
    Cᵏ²² = zeros(Mat33{T})
    Cᵏ²³ = zeros(Mat33{T})
    Cᵏ²⁴ = zeros(Mat33{T})
    Cᵏ³¹ = zeros(Mat33{T})
    Cᵏ³² = zeros(Mat33{T})
    Cᵏ³³ = zeros(Mat33{T})
    Cᵏ³⁴ = zeros(Mat33{T})
    Cᵏ⁴¹ = zeros(Mat33{T})
    Cᵏ⁴² = zeros(Mat33{T})
    Cᵏ⁴³ = zeros(Mat33{T})
    Cᵏ⁴⁴ = zeros(Mat33{T})




    contact_energy = zero(T)
        

    Tᶜ¹ = zeros(Vec3{T})
    Tᶜ² = zeros(Vec3{T})
    Tᶜ³ = zeros(Vec3{T})
    Tᶜ⁴ = zeros(Vec3{T})



    Kᶜ¹¹ = zeros(Mat33{T})
    Kᶜ¹² = zeros(Mat33{T})
    Kᶜ¹³ = zeros(Mat33{T})
    Kᶜ¹⁴ = zeros(Mat33{T})
    Kᶜ²¹ = zeros(Mat33{T})
    Kᶜ²² = zeros(Mat33{T})
    Kᶜ²³ = zeros(Mat33{T})
    Kᶜ²⁴ = zeros(Mat33{T})
    Kᶜ³¹ = zeros(Mat33{T})
    Kᶜ³² = zeros(Mat33{T})
    Kᶜ³³ = zeros(Mat33{T})
    Kᶜ³⁴ = zeros(Mat33{T})
    Kᶜ⁴¹ = zeros(Mat33{T})
    Kᶜ⁴² = zeros(Mat33{T})
    Kᶜ⁴³ = zeros(Mat33{T})
    Kᶜ⁴⁴ = zeros(Mat33{T})

    Cᶜ¹¹ = zeros(Mat33{T})
    Cᶜ¹² = zeros(Mat33{T})
    Cᶜ¹³ = zeros(Mat33{T})
    Cᶜ¹⁴ = zeros(Mat33{T})
    Cᶜ²¹ = zeros(Mat33{T})
    Cᶜ²² = zeros(Mat33{T})
    Cᶜ²³ = zeros(Mat33{T})
    Cᶜ²⁴ = zeros(Mat33{T})
    Cᶜ³¹ = zeros(Mat33{T})
    Cᶜ³² = zeros(Mat33{T})
    Cᶜ³³ = zeros(Mat33{T})
    Cᶜ³⁴ = zeros(Mat33{T})
    Cᶜ⁴¹ = zeros(Mat33{T})
    Cᶜ⁴² = zeros(Mat33{T})
    Cᶜ⁴³ = zeros(Mat33{T})
    Cᶜ⁴⁴ = zeros(Mat33{T})


    
    contact = !isnothing(sdf)
        
    if dynamics
        
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


        Gᵀ¹Rₑᵀ = Gᵀ¹ * Rₑ'
        Gᵀ²Rₑᵀ = Gᵀ² * Rₑ'
        Gᵀ⁴Rₑᵀ = Gᵀ⁴ * Rₑ'

        RₑG¹ = Rₑ * Gᵀ¹'
        RₑG² = Rₑ * Gᵀ²'
        RₑG⁴ = Rₑ * Gᵀ⁴'





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
            N₇lₙ² = N₇lₙ/lₙ
            N₈lₙ = N₈/lₙ
            N₈lₙ² = N₈lₙ/lₙ

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
            
            N₇rḋ = N₇lₙ² * rḋ
            Ḣ₁¹ = Diagonal(@SVector [0, -N₇rḋ, -N₇rḋ]) - Su̇ᵗ * Gᵀ¹
            Ḣ₁² =                                      - Su̇ᵗ * Gᵀ²
            Ḣ₁⁴ =                                      - Su̇ᵗ * Gᵀ⁴

            N₈rḋ = N₈lₙ² * rḋ
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
            C₃¹ = -Sh₁*Gᵀ¹ + N₇lₙ²*A₁ḊrE¹ + SẆᵉ*P₁P¹ + H₁F₁*Gᵀ¹
            C₃² = -Sh₁*Gᵀ² +                  SẆᵉ*P₁P² + H₁F₁*Gᵀ²
            C₃⁴ = -Sh₁*Gᵀ⁴ +                  SẆᵉ*P₁P⁴ + H₁F₁*Gᵀ⁴

            A₂ḊrE¹ = @SMatrix [0 0 0; -U̇₁[3]+U̇₂[3] 0 0; U̇₁[2]-U̇₂[2] 0 0]
            C₄¹ = -Sh₂*Gᵀ¹ + N₈lₙ²*A₂ḊrE¹ + H₂F₁*Gᵀ¹
            C₄² = -Sh₂*Gᵀ²                  + H₂F₁*Gᵀ²
            C₄⁴ = -Sh₂*Gᵀ⁴                  + H₂F₁*Gᵀ⁴

            u̇₀ = Rₑ * h₁

            H₁Eᵀd̈ = H₁¹ * Ü₁ + H₁² * Ẅ₁ + H₁³ * Ü₂ + H₁⁴ * Ẅ₂
            C₁Eᵀḋ = C₁¹ * U̇₁ + C₁² * Ẇ₁ + C₁³ * U̇₂ + C₁⁴ * Ẇ₂
            Rₑᵀü₀ = H₁Eᵀd̈ + C₁Eᵀḋ

            Ẇ₀ = h₂
            ẇ₀ = Rₑ * Ẇ₀

            H₂Eᵀd̈ = H₂¹ * Ü₁ + H₂² * Ẅ₁ + H₂³ * Ü₂ + H₂⁴ * Ẅ₂
            C₂Eᵀḋ = C₂¹ * U̇₁ + C₂² * Ẇ₁ + C₂³ * U̇₂ + C₂⁴ * Ẇ₂
            Rₑᵀẅ₀ = H₂Eᵀd̈ + C₂Eᵀḋ

            SẆ₀ = skew(Ẇ₀)
            ĪᵨRₑᵀẅ₀ = Īᵨ*Rₑᵀẅ₀
            SẆ₀Īᵨ = SẆ₀*Īᵨ
            SẆ₀ĪᵨẆ₀ = SẆ₀Īᵨ*Ẇ₀
            ĪᵨRₑᵀẅ₀SẆ₀ĪᵨẆ₀ = ĪᵨRₑᵀẅ₀ + SẆ₀ĪᵨẆ₀
            AᵨH₁¹ᵀ = Aᵨ*H₁¹'
            AᵨH₁²ᵀ = Aᵨ*H₁²'
            AᵨH₁³ᵀ = Aᵨ*H₁³'
            AᵨH₁⁴ᵀ = Aᵨ*H₁⁴'

            Tᵏ¹G = ωᴳ * (AᵨH₁¹ᵀ*Rₑᵀü₀ + H₂¹'*ĪᵨRₑᵀẅ₀SẆ₀ĪᵨẆ₀)
            Tᵏ¹ += Tᵏ¹G
            Tᵏ² += ωᴳ * (AᵨH₁²ᵀ*Rₑᵀü₀ + H₂²'*ĪᵨRₑᵀẅ₀SẆ₀ĪᵨẆ₀)
            Tᵏ³ += -Tᵏ¹G + ωᴳ * Aᵨ * Rₑᵀü₀
            Tᵏ⁴ += ωᴳ * (AᵨH₁⁴ᵀ*Rₑᵀü₀ + H₂⁴'*ĪᵨRₑᵀẅ₀SẆ₀ĪᵨẆ₀)


            if comp.damping>0
                Tᵈ¹G = ωᴳ * comp.damping*(AᵨH₁¹ᵀ*h₁ + H₂¹'*Īᵨ*h₂)
                Tᵏ¹ += Tᵈ¹G
                Tᵏ² += ωᴳ * comp.damping*(AᵨH₁²ᵀ*h₁ + H₂²'*Īᵨ*h₂)
                Tᵏ³ += -Tᵈ¹G + ωᴳ * Aᵨ * comp.damping * h₁
                Tᵏ⁴ += ωᴳ * comp.damping*(AᵨH₁⁴ᵀ*h₁ + H₂⁴'*Īᵨ*h₂)
            end


            M¹¹G = ωᴳ * (AᵨH₁¹ᵀ*H₁¹ + H₂¹'*Īᵨ*H₂¹)
            M¹²G = ωᴳ * (AᵨH₁¹ᵀ*H₁² + H₂¹'*Īᵨ*H₂²)
            M¹⁴G = ωᴳ * (AᵨH₁¹ᵀ*H₁⁴ + H₂¹'*Īᵨ*H₂⁴)

            M²²G = ωᴳ * (AᵨH₁²ᵀ*H₁² + H₂²'*Īᵨ*H₂²)
            M²⁴G = ωᴳ * (AᵨH₁²ᵀ*H₁⁴ + H₂²'*Īᵨ*H₂⁴)
            
            M⁴⁴G = ωᴳ * (AᵨH₁⁴ᵀ*H₁⁴ + H₂⁴'*Īᵨ*H₂⁴)


            M¹¹ += M¹¹G
            M¹² += M¹²G
            M¹³ += -M¹¹G + ωᴳ * AᵨH₁¹ᵀ
            M¹⁴ += M¹⁴G

            M²² += M²²G
            M²³ += -M¹²G' + ωᴳ * AᵨH₁²ᵀ
            M²⁴ += M²⁴G

            M³³ += M¹¹G + ωᴳ * Aᵨ * (ID3 - H₁¹ - H₁¹')
            M³⁴ += -M¹⁴G + ωᴳ * Aᵨ*H₁⁴
            
            M⁴⁴ += M⁴⁴G


            SẆ₀ĪᵨmSĪᵨẆ₀ = SẆ₀Īᵨ - skew(Īᵨ*Ẇ₀)

            AᵨC₁¹C₃¹ = Aᵨ*(C₁¹ + C₃¹)
            AᵨC₁¹C₃² = Aᵨ*(C₁² + C₃²)
            AᵨC₁¹C₃⁴ = Aᵨ*(C₁⁴ + C₃⁴)

            ĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ = Īᵨ*(C₂¹ + C₄¹) + SẆ₀ĪᵨmSĪᵨẆ₀ * H₂¹
            ĪᵨC₂²C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂² = Īᵨ*(C₂² + C₄²) + SẆ₀ĪᵨmSĪᵨẆ₀ * H₂²
            ĪᵨC₂⁴C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂⁴ = Īᵨ*(C₂⁴ + C₄⁴) + SẆ₀ĪᵨmSĪᵨẆ₀ * H₂⁴


            Cᵏ¹¹G = ωᴳ * ( H₁¹'*AᵨC₁¹C₃¹ + H₂¹'* ĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ ) 
            Cᵏ¹²G = ωᴳ * ( H₁¹'*AᵨC₁¹C₃² + H₂¹'* ĪᵨC₂²C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂² ) 
            Cᵏ¹⁴G = ωᴳ * ( H₁¹'*AᵨC₁¹C₃⁴ + H₂¹'* ĪᵨC₂⁴C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂⁴ ) 
 
            Cᵏ²¹G = ωᴳ * ( H₁²'*AᵨC₁¹C₃¹ + H₂²'* ĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ ) 
            Cᵏ²²G = ωᴳ * ( H₁²'*AᵨC₁¹C₃² + H₂²'* ĪᵨC₂²C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂² ) 
            Cᵏ²⁴G = ωᴳ * ( H₁²'*AᵨC₁¹C₃⁴ + H₂²'* ĪᵨC₂⁴C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂⁴ ) 
 
            Cᵏ⁴¹G = ωᴳ * ( H₁⁴'*AᵨC₁¹C₃¹ + H₂⁴'* ĪᵨC₂¹C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂¹ ) 
            Cᵏ⁴²G = ωᴳ * ( H₁⁴'*AᵨC₁¹C₃² + H₂⁴'* ĪᵨC₂²C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂² ) 
            Cᵏ⁴⁴G = ωᴳ * ( H₁⁴'*AᵨC₁¹C₃⁴ + H₂⁴'* ĪᵨC₂⁴C₄¹SẆ₀ĪᵨmSĪᵨẆ₀H₂⁴ ) 


            Cᵏ¹¹ += Cᵏ¹¹G
            Cᵏ¹² += Cᵏ¹²G
            Cᵏ¹⁴ += Cᵏ¹⁴G

            Cᵏ²¹ += Cᵏ²¹G
            Cᵏ²² += Cᵏ²²G
            Cᵏ²⁴ += Cᵏ²⁴G

            Cᵏ³¹ += -Cᵏ¹¹G + ωᴳ * AᵨC₁¹C₃¹
            Cᵏ³² += -Cᵏ¹²G + ωᴳ * AᵨC₁¹C₃²
            Cᵏ³⁴ += -Cᵏ¹⁴G + ωᴳ * AᵨC₁¹C₃⁴

            Cᵏ⁴¹ += Cᵏ⁴¹G
            Cᵏ⁴² += Cᵏ⁴²G
            Cᵏ⁴⁴ += Cᵏ⁴⁴G


            # kinetic energy
            Īᵨᵍ = Rₑ*Īᵨ*Rₑ'
            kinetic_energy += ωᴳ/2 * (Aᵨ*u̇₀'*u̇₀ + ẇ₀'*Īᵨᵍ*ẇ₀)



            if contact

                xᴳ = N₁*x₁ + N₂*x₂ + Rₑ*uᵗ
                pₙ, p′ₙ, Πₑ, gₙ, ∂gₙ∂x, ∂²gₙ∂x² =  contact_gap(xᴳ, comp.εᶜ, sdf)
        
                if pₙ > 0 
        
                    ġₙ = dot(u̇₀, ∂gₙ∂x)*∂gₙ∂x
                    ġₜ = u̇₀ - ġₙ
                    ġₜ² = dot(ġₜ, ġₜ)
        
                    contact_energy -= ωᴳ*Πₑ

                    γᵈᵃᵐᵖ = comp.γᵈᵃᵐᵖ
                    
                    𝓯ⁿ = pₙ * ∂gₙ∂x - γᵈᵃᵐᵖ * pₙ * ġₙ
                    μʳᵉᵍ = comp.μ/sqrt(ġₜ²+comp.εᵗ)
                    𝓯ᵗ = -μʳᵉᵍ * pₙ * ġₜ

                    𝓯ᶜ = 𝓯ⁿ + 𝓯ᵗ
        
                    𝓕ᶜ = Rₑ' * 𝓯ᶜ
        
                    RₑH₁ᵀ¹ = Rₑ * H₁¹'
                    RₑH₁ᵀ² = Rₑ * H₁²'
                    RₑH₁ᵀ³ = Rₑ * H₁³'
                    RₑH₁ᵀ⁴ = Rₑ * H₁⁴'
        
                    Tᶜ¹ += ωᴳ * (RₑH₁ᵀ¹ * 𝓕ᶜ)
                    Tᶜ² += ωᴳ * (RₑH₁ᵀ² * 𝓕ᶜ)
                    Tᶜ³ += ωᴳ * (RₑH₁ᵀ³ * 𝓕ᶜ)
                    Tᶜ⁴ += ωᴳ * (RₑH₁ᵀ⁴ * 𝓕ᶜ)

        
                    ŜH₁ᵀ𝓕ᶜ¹ = skew(H₁¹' * 𝓕ᶜ)
                    ŜH₁ᵀ𝓕ᶜ² = skew(H₁²' * 𝓕ᶜ)
                    ŜH₁ᵀ𝓕ᶜ³ = skew(H₁³' * 𝓕ᶜ)
                    ŜH₁ᵀ𝓕ᶜ⁴ = skew(H₁⁴' * 𝓕ᶜ)
        
                    RₑŜH₁ᵀ𝓕ᶜ¹ = Rₑ * ŜH₁ᵀ𝓕ᶜ¹
                    t₁¹¹ = -RₑŜH₁ᵀ𝓕ᶜ¹ * Gᵀ¹Rₑᵀ
                    t₁¹² = -RₑŜH₁ᵀ𝓕ᶜ¹ * Gᵀ²Rₑᵀ
                    t₁¹³ = -t₁¹¹
                    t₁¹⁴ = -RₑŜH₁ᵀ𝓕ᶜ¹ * Gᵀ⁴Rₑᵀ
        
                    RₑŜH₁ᵀ𝓕ᶜ² = Rₑ * ŜH₁ᵀ𝓕ᶜ²
                    t₁²¹ = -RₑŜH₁ᵀ𝓕ᶜ² * Gᵀ¹Rₑᵀ
                    t₁²² = -RₑŜH₁ᵀ𝓕ᶜ² * Gᵀ²Rₑᵀ
                    t₁²³ = -t₁²¹
                    t₁²⁴ = -RₑŜH₁ᵀ𝓕ᶜ² * Gᵀ⁴Rₑᵀ
        
                    RₑŜH₁ᵀ𝓕ᶜ³ = Rₑ * ŜH₁ᵀ𝓕ᶜ³
                    t₁³¹ = -RₑŜH₁ᵀ𝓕ᶜ³ * Gᵀ¹Rₑᵀ
                    t₁³² = -RₑŜH₁ᵀ𝓕ᶜ³ * Gᵀ²Rₑᵀ
                    t₁³³ = -t₁³¹
                    t₁³⁴ = -RₑŜH₁ᵀ𝓕ᶜ³ * Gᵀ⁴Rₑᵀ
        
                    RₑŜH₁ᵀ𝓕ᶜ⁴ = Rₑ * ŜH₁ᵀ𝓕ᶜ⁴
                    t₁⁴¹ = -RₑŜH₁ᵀ𝓕ᶜ⁴ * Gᵀ¹Rₑᵀ
                    t₁⁴² = -RₑŜH₁ᵀ𝓕ᶜ⁴ * Gᵀ²Rₑᵀ
                    t₁⁴³ = -t₁⁴¹
                    t₁⁴⁴ = -RₑŜH₁ᵀ𝓕ᶜ⁴ * Gᵀ⁴Rₑᵀ
        
        
                    v₁ = r³
                    A₁ᵀ𝓕ᶜr₁₁ = @SMatrix[0 0 0; 𝓕ᶜ[2]*v₁[1] 𝓕ᶜ[2]*v₁[2] 𝓕ᶜ[2]*v₁[3]; 𝓕ᶜ[3]*v₁[1] 𝓕ᶜ[3]*v₁[2] 𝓕ᶜ[3]*v₁[3]]
        
                    S𝓕ᶜ = skew(𝓕ᶜ)
        
                    S𝓕ᶜP₁P¹Rₑᵀ = S𝓕ᶜ * P₁P¹ * Rₑ'
                    S𝓕ᶜP₁P²Rₑᵀ = S𝓕ᶜ * P₁P² * Rₑ'
                    S𝓕ᶜP₁P⁴Rₑᵀ = S𝓕ᶜ * P₁P⁴ * Rₑ'
                    
                    t₂¹¹ = N₇lₙ² * Rₑ * A₁ᵀ𝓕ᶜr₁₁ - RₑG¹ * S𝓕ᶜP₁P¹Rₑᵀ
                    t₂¹² =                       - RₑG¹ * S𝓕ᶜP₁P²Rₑᵀ
                    t₂¹³ = -t₂¹¹
                    t₂¹⁴ =                       - RₑG¹ * S𝓕ᶜP₁P⁴Rₑᵀ
        
                    t₂²¹ =                       - RₑG² * S𝓕ᶜP₁P¹Rₑᵀ
                    t₂²² =                       - RₑG² * S𝓕ᶜP₁P²Rₑᵀ
                    t₂²³ = -t₂²¹
                    t₂²⁴ =                       - RₑG² * S𝓕ᶜP₁P⁴Rₑᵀ
        
                    t₂³¹ = t₂¹³
                    t₂³² = -t₂¹²
                    t₂³³ = t₂¹¹
                    t₂³⁴ = -t₂¹⁴
        
                    t₂⁴¹ =                       - RₑG⁴ * S𝓕ᶜP₁P¹Rₑᵀ
                    t₂⁴² =                       - RₑG⁴ * S𝓕ᶜP₁P²Rₑᵀ
                    t₂⁴³ = -t₂⁴¹
                    t₂⁴⁴ =                       - RₑG⁴ * S𝓕ᶜP₁P⁴Rₑᵀ
        
                    RₑH₁ᵀ¹S𝓕ᶜ = RₑH₁ᵀ¹ * S𝓕ᶜ
                    RₑH₁ᵀ²S𝓕ᶜ = RₑH₁ᵀ² * S𝓕ᶜ
                    RₑH₁ᵀ³S𝓕ᶜ = RₑH₁ᵀ³ * S𝓕ᶜ
                    RₑH₁ᵀ⁴S𝓕ᶜ = RₑH₁ᵀ⁴ * S𝓕ᶜ
        
                    t₃¹¹ = RₑH₁ᵀ¹S𝓕ᶜ * Gᵀ¹Rₑᵀ
                    t₃¹² = RₑH₁ᵀ¹S𝓕ᶜ * Gᵀ²Rₑᵀ
                    t₃¹³ = -t₃¹¹
                    t₃¹⁴ = RₑH₁ᵀ¹S𝓕ᶜ * Gᵀ⁴Rₑᵀ
        
                    t₃²¹ = RₑH₁ᵀ²S𝓕ᶜ * Gᵀ¹Rₑᵀ
                    t₃²² = RₑH₁ᵀ²S𝓕ᶜ * Gᵀ²Rₑᵀ
                    t₃²³ = -t₃²¹
                    t₃²⁴ = RₑH₁ᵀ²S𝓕ᶜ * Gᵀ⁴Rₑᵀ
        
                    t₃³¹ = RₑH₁ᵀ³S𝓕ᶜ * Gᵀ¹Rₑᵀ
                    t₃³² = RₑH₁ᵀ³S𝓕ᶜ * Gᵀ²Rₑᵀ
                    t₃³³ = -t₃³¹
                    t₃³⁴ = RₑH₁ᵀ³S𝓕ᶜ * Gᵀ⁴Rₑᵀ
        
                    t₃⁴¹ = RₑH₁ᵀ⁴S𝓕ᶜ * Gᵀ¹Rₑᵀ
                    t₃⁴² = RₑH₁ᵀ⁴S𝓕ᶜ * Gᵀ²Rₑᵀ
                    t₃⁴³ = -t₃⁴¹
                    t₃⁴⁴ = RₑH₁ᵀ⁴S𝓕ᶜ * Gᵀ⁴Rₑᵀ
        
        
                    
        
                    ∂gₙ∂xu̇₀∂²gₙ∂x² = dot(∂gₙ∂x, u̇₀) * ∂²gₙ∂x²
                    ∂²gₙ∂x²u̇₀ = ∂²gₙ∂x² * u̇₀
                    ∂u̇₀∂ḋ¹ = Rₑ * H₁¹ * Rₑ'
                    ∂u̇₀∂ḋ² = Rₑ * H₁² * Rₑ'
                    ∂u̇₀∂ḋ³ = Rₑ * H₁³ * Rₑ'
                    ∂u̇₀∂ḋ⁴ = Rₑ * H₁⁴ * Rₑ'
                    RₑH₁¹ᵀRₑᵀ = RₑH₁ᵀ¹ * Rₑ'
                    RₑH₁²ᵀRₑᵀ = RₑH₁ᵀ² * Rₑ'
                    RₑH₁³ᵀRₑᵀ = RₑH₁ᵀ³ * Rₑ'
                    RₑH₁⁴ᵀRₑᵀ = RₑH₁ᵀ⁴ * Rₑ'
        
                    𝓐₁¹ =  ∂gₙ∂xu̇₀∂²gₙ∂x² * ∂u̇₀∂ḋ¹ + ∂gₙ∂x * (RₑH₁¹ᵀRₑᵀ * ∂²gₙ∂x²u̇₀)'
                    𝓐₁² =  ∂gₙ∂xu̇₀∂²gₙ∂x² * ∂u̇₀∂ḋ² + ∂gₙ∂x * (RₑH₁²ᵀRₑᵀ * ∂²gₙ∂x²u̇₀)'
                    𝓐₁³ =  ∂gₙ∂xu̇₀∂²gₙ∂x² * ∂u̇₀∂ḋ³ + ∂gₙ∂x * (RₑH₁³ᵀRₑᵀ * ∂²gₙ∂x²u̇₀)'
                    𝓐₁⁴ =  ∂gₙ∂xu̇₀∂²gₙ∂x² * ∂u̇₀∂ḋ⁴ + ∂gₙ∂x * (RₑH₁⁴ᵀRₑᵀ * ∂²gₙ∂x²u̇₀)'
        

                    RₑSh₁ = Rₑ * Sh₁
                    𝓐₂¹ = - RₑSh₁ * Gᵀ¹Rₑᵀ
                    𝓐₂² = - RₑSh₁ * Gᵀ²Rₑᵀ
                    𝓐₂⁴ = - RₑSh₁ * Gᵀ⁴Rₑᵀ

                    A₁Ḋr¹ = @SMatrix [0 0 0; v₁[1]*(U̇₁[2]-U̇₂[2]) v₁[2]*(U̇₁[2]-U̇₂[2]) v₁[3]*(U̇₁[2]-U̇₂[2]);v₁[1]*(U̇₁[3]-U̇₂[3]) v₁[2]*(U̇₁[3]-U̇₂[3]) v₁[3]*(U̇₁[3]-U̇₂[3])]
        
                    RₑSGᵀḊ = Rₑ * skew(Gᵀ¹ * U̇₁ + Gᵀ² * Ẇ₁ + Gᵀ³ * U̇₂ + Gᵀ⁴ * Ẇ₂)
                    𝓐₃¹ = N₇lₙ² * Rₑ * A₁Ḋr¹ + RₑSGᵀḊ * P₁P¹ * Rₑ'
                    𝓐₃² =                      RₑSGᵀḊ * P₁P² * Rₑ'
                    𝓐₃⁴ =                      RₑSGᵀḊ * P₁P⁴ * Rₑ'
        
                    RₑH₁SḊ = Rₑ*H₁F₁
                    𝓐₄¹ = RₑH₁SḊ * Gᵀ¹Rₑᵀ
                    𝓐₄² = RₑH₁SḊ * Gᵀ²Rₑᵀ
                    𝓐₄⁴ = RₑH₁SḊ * Gᵀ⁴Rₑᵀ
        
                    ∂u̇₀∂d¹ = 𝓐₂¹ + 𝓐₃¹ + 𝓐₄¹
                    ∂u̇₀∂d² = 𝓐₂² + 𝓐₃² + 𝓐₄²
                    ∂u̇₀∂d³ = -∂u̇₀∂d¹
                    ∂u̇₀∂d⁴ = 𝓐₂⁴ + 𝓐₃⁴ + 𝓐₄⁴

                    ∂gₙgₙ∂x = ∂gₙ∂x * ∂gₙ∂x'
        
                    ∂ġₙ∂d¹ = 𝓐₁¹ + ∂gₙgₙ∂x * ∂u̇₀∂d¹
                    ∂ġₙ∂d² = 𝓐₁² + ∂gₙgₙ∂x * ∂u̇₀∂d²
                    ∂ġₙ∂d³ = 𝓐₁³ + ∂gₙgₙ∂x * ∂u̇₀∂d³
                    ∂ġₙ∂d⁴ = 𝓐₁⁴ + ∂gₙgₙ∂x * ∂u̇₀∂d⁴

                    # ġₜ = u̇₀ - ġₙ
                    ∂ġₜ∂d¹ = ∂u̇₀∂d¹ - ∂ġₙ∂d¹
                    ∂ġₜ∂d² = ∂u̇₀∂d² - ∂ġₙ∂d²
                    ∂ġₜ∂d³ = ∂u̇₀∂d³ - ∂ġₙ∂d³
                    ∂ġₜ∂d⁴ = ∂u̇₀∂d⁴ - ∂ġₙ∂d⁴


                    


                    ∂ġₙ∂ḋ¹ = ∂gₙgₙ∂x * ∂u̇₀∂ḋ¹
                    ∂ġₙ∂ḋ² = ∂gₙgₙ∂x * ∂u̇₀∂ḋ²
                    ∂ġₙ∂ḋ³ = ∂gₙgₙ∂x * ∂u̇₀∂ḋ³
                    ∂ġₙ∂ḋ⁴ = ∂gₙgₙ∂x * ∂u̇₀∂ḋ⁴

                    # ġₜ = u̇₀ - ġₙ
                    ∂ġₜ∂ḋ¹ = ∂u̇₀∂ḋ¹ - ∂ġₙ∂ḋ¹
                    ∂ġₜ∂ḋ² = ∂u̇₀∂ḋ² - ∂ġₙ∂ḋ²
                    ∂ġₜ∂ḋ³ = ∂u̇₀∂ḋ³ - ∂ġₙ∂ḋ³
                    ∂ġₜ∂ḋ⁴ = ∂u̇₀∂ḋ⁴ - ∂ġₙ∂ḋ⁴
                    
        
                    p′ₙ∂gₙgₙ∂xpₙ∂²gₙ∂x² = p′ₙ * ∂gₙgₙ∂x + pₙ * ∂²gₙ∂x²
                    p′ₙġₙ∂gₙ∂x = p′ₙ * ġₙ * ∂gₙ∂x'
                    Kᶠⁿ¹ = p′ₙ∂gₙgₙ∂xpₙ∂²gₙ∂x² * ∂u̇₀∂ḋ¹ - γᵈᵃᵐᵖ * (p′ₙġₙ∂gₙ∂x * ∂u̇₀∂ḋ¹ + pₙ * ∂ġₙ∂d¹)
                    Kᶠⁿ² = p′ₙ∂gₙgₙ∂xpₙ∂²gₙ∂x² * ∂u̇₀∂ḋ² - γᵈᵃᵐᵖ * (p′ₙġₙ∂gₙ∂x * ∂u̇₀∂ḋ² + pₙ * ∂ġₙ∂d²)
                    Kᶠⁿ³ = p′ₙ∂gₙgₙ∂xpₙ∂²gₙ∂x² * ∂u̇₀∂ḋ³ - γᵈᵃᵐᵖ * (p′ₙġₙ∂gₙ∂x * ∂u̇₀∂ḋ³ + pₙ * ∂ġₙ∂d³)
                    Kᶠⁿ⁴ = p′ₙ∂gₙgₙ∂xpₙ∂²gₙ∂x² * ∂u̇₀∂ḋ⁴ - γᵈᵃᵐᵖ * (p′ₙġₙ∂gₙ∂x * ∂u̇₀∂ḋ⁴ + pₙ * ∂ġₙ∂d⁴)

                    Cᶠⁿ¹ = - γᵈᵃᵐᵖ * pₙ * ∂ġₙ∂ḋ¹
                    Cᶠⁿ² = - γᵈᵃᵐᵖ * pₙ * ∂ġₙ∂ḋ²
                    Cᶠⁿ³ = - γᵈᵃᵐᵖ * pₙ * ∂ġₙ∂ḋ³
                    Cᶠⁿ⁴ = - γᵈᵃᵐᵖ * pₙ * ∂ġₙ∂ḋ⁴

                    pₙIμʳᵉᵍġₜġₜ = pₙ*(ID3 - μʳᵉᵍ*ġₜ*ġₜ')
                    p′ₙġₜ∂gₙ∂x = p′ₙ * ġₜ * ∂gₙ∂x'
                    Kᶠᵗ¹ = - μʳᵉᵍ * (p′ₙġₜ∂gₙ∂x * ∂u̇₀∂ḋ¹ + pₙIμʳᵉᵍġₜġₜ * ∂ġₜ∂d¹ )
                    Kᶠᵗ² = - μʳᵉᵍ * (p′ₙġₜ∂gₙ∂x * ∂u̇₀∂ḋ² + pₙIμʳᵉᵍġₜġₜ * ∂ġₜ∂d² )
                    Kᶠᵗ³ = - μʳᵉᵍ * (p′ₙġₜ∂gₙ∂x * ∂u̇₀∂ḋ³ + pₙIμʳᵉᵍġₜġₜ * ∂ġₜ∂d³ )
                    Kᶠᵗ⁴ = - μʳᵉᵍ * (p′ₙġₜ∂gₙ∂x * ∂u̇₀∂ḋ⁴ + pₙIμʳᵉᵍġₜġₜ * ∂ġₜ∂d⁴ )


                    Cᶠᵗ¹ = -μʳᵉᵍ * pₙIμʳᵉᵍġₜġₜ * ∂ġₜ∂ḋ¹
                    Cᶠᵗ² = -μʳᵉᵍ * pₙIμʳᵉᵍġₜġₜ * ∂ġₜ∂ḋ²
                    Cᶠᵗ³ = -μʳᵉᵍ * pₙIμʳᵉᵍġₜġₜ * ∂ġₜ∂ḋ³
                    Cᶠᵗ⁴ = -μʳᵉᵍ * pₙIμʳᵉᵍġₜġₜ * ∂ġₜ∂ḋ⁴


                    Kᶠᶜ¹ = Kᶠⁿ¹ + Kᶠᵗ¹
                    Kᶠᶜ² = Kᶠⁿ² + Kᶠᵗ²
                    Kᶠᶜ³ = Kᶠⁿ³ + Kᶠᵗ³
                    Kᶠᶜ⁴ = Kᶠⁿ⁴ + Kᶠᵗ⁴

  
        

                    t₄¹¹ = RₑH₁¹ᵀRₑᵀ * Kᶠᶜ¹
                    t₄¹² = RₑH₁¹ᵀRₑᵀ * Kᶠᶜ²
                    t₄¹³ = RₑH₁¹ᵀRₑᵀ * Kᶠᶜ³
                    t₄¹⁴ = RₑH₁¹ᵀRₑᵀ * Kᶠᶜ⁴
        
                    t₄²¹ = RₑH₁²ᵀRₑᵀ * Kᶠᶜ¹
                    t₄²² = RₑH₁²ᵀRₑᵀ * Kᶠᶜ²
                    t₄²³ = RₑH₁²ᵀRₑᵀ * Kᶠᶜ³
                    t₄²⁴ = RₑH₁²ᵀRₑᵀ * Kᶠᶜ⁴
        
                    t₄³¹ = RₑH₁³ᵀRₑᵀ * Kᶠᶜ¹
                    t₄³² = RₑH₁³ᵀRₑᵀ * Kᶠᶜ²
                    t₄³³ = RₑH₁³ᵀRₑᵀ * Kᶠᶜ³
                    t₄³⁴ = RₑH₁³ᵀRₑᵀ * Kᶠᶜ⁴
        
                    t₄⁴¹ = RₑH₁⁴ᵀRₑᵀ * Kᶠᶜ¹
                    t₄⁴² = RₑH₁⁴ᵀRₑᵀ * Kᶠᶜ²
                    t₄⁴³ = RₑH₁⁴ᵀRₑᵀ * Kᶠᶜ³
                    t₄⁴⁴ = RₑH₁⁴ᵀRₑᵀ * Kᶠᶜ⁴
        
        
                    Cᶠᶜ¹ = Cᶠⁿ¹ + Cᶠᵗ¹
                    Cᶠᶜ² = Cᶠⁿ² + Cᶠᵗ²
                    Cᶠᶜ³ = Cᶠⁿ³ + Cᶠᵗ³
                    Cᶠᶜ⁴ = Cᶠⁿ⁴ + Cᶠᵗ⁴
        
        
                    Kᶜ¹¹ +=  ωᴳ * (t₁¹¹ + t₂¹¹ + t₃¹¹ + t₄¹¹)
                    Kᶜ¹² +=  ωᴳ * (t₁¹² + t₂¹² + t₃¹² + t₄¹²)
                    Kᶜ¹³ +=  ωᴳ * (t₁¹³ + t₂¹³ + t₃¹³ + t₄¹³)
                    Kᶜ¹⁴ +=  ωᴳ * (t₁¹⁴ + t₂¹⁴ + t₃¹⁴ + t₄¹⁴)
        
                    Kᶜ²¹ +=  ωᴳ * (t₁²¹ + t₂²¹ + t₃²¹ + t₄²¹)
                    Kᶜ²² +=  ωᴳ * (t₁²² + t₂²² + t₃²² + t₄²²)
                    Kᶜ²³ +=  ωᴳ * (t₁²³ + t₂²³ + t₃²³ + t₄²³)
                    Kᶜ²⁴ +=  ωᴳ * (t₁²⁴ + t₂²⁴ + t₃²⁴ + t₄²⁴)
        
                    Kᶜ³¹ +=  ωᴳ * (t₁³¹ + t₂³¹ + t₃³¹ + t₄³¹)
                    Kᶜ³² +=  ωᴳ * (t₁³² + t₂³² + t₃³² + t₄³²)
                    Kᶜ³³ +=  ωᴳ * (t₁³³ + t₂³³ + t₃³³ + t₄³³)
                    Kᶜ³⁴ +=  ωᴳ * (t₁³⁴ + t₂³⁴ + t₃³⁴ + t₄³⁴)
        
                    Kᶜ⁴¹ +=  ωᴳ * (t₁⁴¹ + t₂⁴¹ + t₃⁴¹ + t₄⁴¹)
                    Kᶜ⁴² +=  ωᴳ * (t₁⁴² + t₂⁴² + t₃⁴² + t₄⁴²)
                    Kᶜ⁴³ +=  ωᴳ * (t₁⁴³ + t₂⁴³ + t₃⁴³ + t₄⁴³)
                    Kᶜ⁴⁴ +=  ωᴳ * (t₁⁴⁴ + t₂⁴⁴ + t₃⁴⁴ + t₄⁴⁴)
        
        
                    Cᶜ¹¹ +=  ωᴳ * RₑH₁¹ᵀRₑᵀ * Cᶠᶜ¹
                    Cᶜ¹² +=  ωᴳ * RₑH₁¹ᵀRₑᵀ * Cᶠᶜ²
                    Cᶜ¹³ +=  ωᴳ * RₑH₁¹ᵀRₑᵀ * Cᶠᶜ³
                    Cᶜ¹⁴ +=  ωᴳ * RₑH₁¹ᵀRₑᵀ * Cᶠᶜ⁴
        
                    Cᶜ²¹ +=  ωᴳ * RₑH₁²ᵀRₑᵀ * Cᶠᶜ¹
                    Cᶜ²² +=  ωᴳ * RₑH₁²ᵀRₑᵀ * Cᶠᶜ²
                    Cᶜ²³ +=  ωᴳ * RₑH₁²ᵀRₑᵀ * Cᶠᶜ³
                    Cᶜ²⁴ +=  ωᴳ * RₑH₁²ᵀRₑᵀ * Cᶠᶜ⁴
        
                    Cᶜ³¹ +=  ωᴳ * RₑH₁³ᵀRₑᵀ * Cᶠᶜ¹
                    Cᶜ³² +=  ωᴳ * RₑH₁³ᵀRₑᵀ * Cᶠᶜ²
                    Cᶜ³³ +=  ωᴳ * RₑH₁³ᵀRₑᵀ * Cᶠᶜ³
                    Cᶜ³⁴ +=  ωᴳ * RₑH₁³ᵀRₑᵀ * Cᶠᶜ⁴
        
                    Cᶜ⁴¹ +=  ωᴳ * RₑH₁⁴ᵀRₑᵀ * Cᶠᶜ¹
                    Cᶜ⁴² +=  ωᴳ * RₑH₁⁴ᵀRₑᵀ * Cᶠᶜ²
                    Cᶜ⁴³ +=  ωᴳ * RₑH₁⁴ᵀRₑᵀ * Cᶠᶜ³
                    Cᶜ⁴⁴ +=  ωᴳ * RₑH₁⁴ᵀRₑᵀ * Cᶠᶜ⁴
        
                end
            
            
            end


            
        end

        l₀2 = l₀/2
        l₀2Rₑ = l₀2 * Rₑ


        Tᵏ¹ = l₀2Rₑ*Tᵏ¹
        Tᵏ² = l₀2Rₑ*Tᵏ²
        Tᵏ³ = l₀2Rₑ*Tᵏ³
        Tᵏ⁴ = l₀2Rₑ*Tᵏ⁴



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

        Cᵏ¹¹ = l₀2Rₑ * Cᵏ¹¹ * Rₑ' 
        Cᵏ¹² = l₀2Rₑ * Cᵏ¹² * Rₑ' 
        Cᵏ¹³ = -Cᵏ¹¹             
        Cᵏ¹⁴ = l₀2Rₑ * Cᵏ¹⁴ * Rₑ' 
        Cᵏ²¹ = l₀2Rₑ * Cᵏ²¹ * Rₑ' 
        Cᵏ²² = l₀2Rₑ * Cᵏ²² * Rₑ' 
        Cᵏ²³ = -Cᵏ²¹            
        Cᵏ²⁴ = l₀2Rₑ * Cᵏ²⁴ * Rₑ' 
        Cᵏ³¹ = l₀2Rₑ * Cᵏ³¹ * Rₑ'
        Cᵏ³² = l₀2Rₑ * Cᵏ³² * Rₑ' 
        Cᵏ³³ = -Cᵏ³¹              
        Cᵏ³⁴ = l₀2Rₑ * Cᵏ³⁴ * Rₑ' 
        Cᵏ⁴¹ = l₀2Rₑ * Cᵏ⁴¹ * Rₑ' 
        Cᵏ⁴² = l₀2Rₑ * Cᵏ⁴² * Rₑ' 
        Cᵏ⁴³ = -Cᵏ⁴¹
        Cᵏ⁴⁴ = l₀2Rₑ * Cᵏ⁴⁴ * Rₑ' 



        kinetic_energy = l₀2*kinetic_energy

        if comp.damping>0
            Cᵏ¹¹ += comp.damping*M¹¹
            Cᵏ¹² += comp.damping*M¹²
            Cᵏ¹³ += comp.damping*M¹³
            Cᵏ¹⁴ += comp.damping*M¹⁴
            Cᵏ²¹ += comp.damping*M¹²'
            Cᵏ²² += comp.damping*M²²
            Cᵏ²³ += comp.damping*M²³
            Cᵏ²⁴ += comp.damping*M²⁴
            Cᵏ³¹ += comp.damping*M¹³'
            Cᵏ³² += comp.damping*M²³'
            Cᵏ³³ += comp.damping*M³³
            Cᵏ³⁴ += comp.damping*M³⁴
            Cᵏ⁴¹ += comp.damping*M¹⁴'
            Cᵏ⁴² += comp.damping*M²⁴'
            Cᵏ⁴³ += comp.damping*M³⁴'
            Cᵏ⁴⁴ += comp.damping*M⁴⁴
        end



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

            Cᵏ²¹ = Cᵏ²¹ * Tₛ⁻¹Θ₁'
            Cᵏ²² = Cᵏ²² * Tₛ⁻¹Θ₁' 
            Cᵏ²³ = Cᵏ²³ * Tₛ⁻¹Θ₁'
            Cᵏ²⁴ = Cᵏ²⁴ * Tₛ⁻¹Θ₁'
            Cᵏ⁴¹ = Cᵏ⁴¹ * Tₛ⁻¹Θ₂'
            Cᵏ⁴² = Cᵏ⁴² * Tₛ⁻¹Θ₂' 
            Cᵏ⁴³ = Cᵏ⁴³ * Tₛ⁻¹Θ₂'
            Cᵏ⁴⁴ = Cᵏ⁴⁴ * Tₛ⁻¹Θ₂'

        else

            M²¹ = M¹²'
            M³¹ = M¹³'
            M³² = M²³'
            M⁴¹ = M¹⁴' 
            M⁴² = M²⁴'
            M⁴³ = M³⁴'

        end




        if contact


            Tᶜ¹ = l₀2*Tᶜ¹
            Tᶜ² = l₀2*Tᶜ²
            Tᶜ³ = l₀2*Tᶜ³
            Tᶜ⁴ = l₀2*Tᶜ⁴


            Cᶜ¹¹ = l₀2 * Cᶜ¹¹ 
            Cᶜ¹² = l₀2 * Cᶜ¹² 
            Cᶜ¹³ = l₀2 * Cᶜ¹³ 
            Cᶜ¹⁴ = l₀2 * Cᶜ¹⁴ 
            Cᶜ²¹ = l₀2 * Cᶜ²¹ 
            Cᶜ²² = l₀2 * Cᶜ²² 
            Cᶜ²³ = l₀2 * Cᶜ²³ 
            Cᶜ²⁴ = l₀2 * Cᶜ²⁴ 
            Cᶜ³¹ = l₀2 * Cᶜ³¹ 
            Cᶜ³² = l₀2 * Cᶜ³² 
            Cᶜ³³ = l₀2 * Cᶜ³³ 
            Cᶜ³⁴ = l₀2 * Cᶜ³⁴ 
            Cᶜ⁴¹ = l₀2 * Cᶜ⁴¹ 
            Cᶜ⁴² = l₀2 * Cᶜ⁴² 
            Cᶜ⁴³ = l₀2 * Cᶜ⁴³ 
            Cᶜ⁴⁴ = l₀2 * Cᶜ⁴⁴ 

            Kᶜ¹¹ = l₀2 * Kᶜ¹¹
            Kᶜ¹² = l₀2 * Kᶜ¹²
            Kᶜ¹³ = l₀2 * Kᶜ¹³
            Kᶜ¹⁴ = l₀2 * Kᶜ¹⁴
            Kᶜ²¹ = l₀2 * Kᶜ²¹
            Kᶜ²² = l₀2 * Kᶜ²²
            Kᶜ²³ = l₀2 * Kᶜ²³
            Kᶜ²⁴ = l₀2 * Kᶜ²⁴
            Kᶜ³¹ = l₀2 * Kᶜ³¹
            Kᶜ³² = l₀2 * Kᶜ³²
            Kᶜ³³ = l₀2 * Kᶜ³³
            Kᶜ³⁴ = l₀2 * Kᶜ³⁴
            Kᶜ⁴¹ = l₀2 * Kᶜ⁴¹
            Kᶜ⁴² = l₀2 * Kᶜ⁴²
            Kᶜ⁴³ = l₀2 * Kᶜ⁴³
            Kᶜ⁴⁴ = l₀2 * Kᶜ⁴⁴

            contact_energy = l₀2 * contact_energy


            if exact

                Cᶜ²¹ = Cᶜ²¹ * Tₛ⁻¹Θ₁'
                Cᶜ²² = Cᶜ²² * Tₛ⁻¹Θ₁' 
                Cᶜ²³ = Cᶜ²³ * Tₛ⁻¹Θ₁'
                Cᶜ²⁴ = Cᶜ²⁴ * Tₛ⁻¹Θ₁'
                Cᶜ⁴¹ = Cᶜ⁴¹ * Tₛ⁻¹Θ₂'
                Cᶜ⁴² = Cᶜ⁴² * Tₛ⁻¹Θ₂' 
                Cᶜ⁴³ = Cᶜ⁴³ * Tₛ⁻¹Θ₂'
                Cᶜ⁴⁴ = Cᶜ⁴⁴ * Tₛ⁻¹Θ₂'

            end


        end



    end


    Tᵏ = [Tᵏ¹; Tᵏ²; Tᵏ³; Tᵏ⁴]
    
    M = hcat(vcat(M¹¹, M²¹, M³¹, M⁴¹), vcat(M¹², M²², M³², M⁴²), vcat(M¹³, M²³, M³³, M⁴³), vcat(M¹⁴, M²⁴, M³⁴, M⁴⁴))
    Cᵏ = hcat(vcat(Cᵏ¹¹, Cᵏ²¹, Cᵏ³¹, Cᵏ⁴¹), vcat(Cᵏ¹², Cᵏ²², Cᵏ³², Cᵏ⁴²), vcat(Cᵏ¹³, Cᵏ²³, Cᵏ³³, Cᵏ⁴³), vcat(Cᵏ¹⁴, Cᵏ²⁴, Cᵏ³⁴, Cᵏ⁴⁴))

    
    Tᶜ = [Tᶜ¹; Tᶜ²; Tᶜ³; Tᶜ⁴]
    Kᶜ = hcat(vcat(Kᶜ¹¹, Kᶜ²¹, Kᶜ³¹, Kᶜ⁴¹), vcat(Kᶜ¹², Kᶜ²², Kᶜ³², Kᶜ⁴²), vcat(Kᶜ¹³, Kᶜ²³, Kᶜ³³, Kᶜ⁴³), vcat(Kᶜ¹⁴, Kᶜ²⁴, Kᶜ³⁴, Kᶜ⁴⁴))
    Cᶜ = hcat(vcat(Cᶜ¹¹, Cᶜ²¹, Cᶜ³¹, Cᶜ⁴¹), vcat(Cᶜ¹², Cᶜ²², Cᶜ³², Cᶜ⁴²), vcat(Cᶜ¹³, Cᶜ²³, Cᶜ³³, Cᶜ⁴³), vcat(Cᶜ¹⁴, Cᶜ²⁴, Cᶜ³⁴, Cᶜ⁴⁴))


    return strain_energy, kinetic_energy, contact_energy, Tⁱⁿᵗ, Tᵏ, Tᶜ, Kⁱⁿᵗ, Kᶜ, M, Cᵏ, Cᶜ




    
end





function assemble_forces!(nodes, beams, matrices, energy, conf, sdf, comp) 
    
        
    # initialise the matrices associate to the whole structure
    fill!(matrices.Tⁱⁿᵗ, 0)
    fill!(matrices.Tᵏ, 0)
    fill!(matrices.Tᶜ, 0)
    
    # initialise the energy values associate to the whole structure
    energy.strain_energy = 0
    energy.kinetic_energy = 0
    energy.contact_energy = 0
        
    lk = Threads.SpinLock()

    Threads.@threads for b in LazyRows(beams)
        
            
        # information from node 1 and 2
        X₁, X₂ = nodes.X₀[b.node1], nodes.X₀[b.node2]
        u₁, u₂ = nodes.u[b.node1], nodes.u[b.node2]
        u̇₁, u̇₂ = nodes.u̇[b.node1], nodes.u̇[b.node2]
        ü₁, ü₂ = nodes.ü[b.node1], nodes.ü[b.node2]
        ẇ₁, ẇ₂ = nodes.ẇ[b.node1], nodes.ẇ[b.node2]
        ẅ₁, ẅ₂ = nodes.ẅ[b.node1], nodes.ẅ[b.node2]
        R₁, R₂ = nodes.R[b.node1], nodes.R[b.node2]
        ΔR₁, ΔR₂ = nodes.ΔR[b.node1], nodes.ΔR[b.node2]


        #----------------------------------------
        # Compute the contibution from the e beam
        init = (X₁, X₂, b.l₀, b.Rₑ⁰)
        simvars = (conf.mat, conf.geom, comp, init, sdf)

        strain_energy, kinetic_energy, contact_energy, Tⁱⁿᵗ, Tᵏ, Tᶜ = compute_forces(u₁, u₂, R₁, R₂, ΔR₁, ΔR₂, u̇₁, u̇₂, ẇ₁, ẇ₂, ü₁, ü₂, ẅ₁, ẅ₂, simvars)
    

        #-----------------------
        # Assemble contributions
        

        idof1 = nodes.idof_6[b.node1]
        idof2 = nodes.idof_6[b.node2]
        
        dofs = vcat(idof1, idof2)


        lock(lk) do
        
            energy.strain_energy +=  strain_energy
            energy.kinetic_energy += kinetic_energy
            energy.contact_energy +=  contact_energy


            @inbounds for (i, dof) in enumerate(dofs)
                matrices.Tᵏ[dof] += Tᵏ[i]
                matrices.Tⁱⁿᵗ[dof] += Tⁱⁿᵗ[i]
                matrices.Tᶜ[dof] += Tᶜ[i]
            end

        end

                            
    end



    
end 





function assemble!(nodes, beams, matrices, energy, conf, sdf, comp) 
    
        
    # initialise the matrices associate to the whole structure
    fill!(matrices.K, 0)
    fill!(matrices.C, 0)
    fill!(matrices.M, 0)
    fill!(matrices.Tⁱⁿᵗ, 0)
    fill!(matrices.Tᵏ, 0)
    fill!(matrices.Tᶜ, 0)
    
    # initialise the energy values associate to the whole structure
    energy.strain_energy = 0
    energy.kinetic_energy = 0
    energy.contact_energy = 0
        
    lk = Threads.SpinLock()

    @batch for b in LazyRows(beams)
        
        n1 = b.node1
        n2 = b.node2
        # information from node 1 and 2
        X₁, X₂ = nodes.X₀[n1], nodes.X₀[n2]
        u₁, u₂ = nodes.u[n1], nodes.u[n2]
        u̇₁, u̇₂ = nodes.u̇[n1], nodes.u̇[n2]
        ü₁, ü₂ = nodes.ü[n1], nodes.ü[n2]
        ẇ₁, ẇ₂ = nodes.ẇ[n1], nodes.ẇ[n2]
        ẅ₁, ẅ₂ = nodes.ẅ[n1], nodes.ẅ[n2]
        R₁, R₂ = nodes.R[n1], nodes.R[n2]
        ΔR₁, ΔR₂ = nodes.ΔR[n1], nodes.ΔR[n2]


        #----------------------------------------
        # Compute the contibution from the e beam
        init = (X₁, X₂, b.l₀, b.Rₑ⁰)
        simvars = (conf.mat, conf.geom, comp, init, sdf)

        strain_energy, kinetic_energy, contact_energy, Tⁱⁿᵗ, Tᵏ, Tᶜ, Kⁱⁿᵗ, Kᶜ, M, Cᵏ, Cᶜ = compute(u₁, u₂, R₁, R₂, ΔR₁, ΔR₂, u̇₁, u̇₂, ẇ₁, ẇ₂, ü₁, ü₂, ẅ₁, ẅ₂, simvars)
    
        K = Kⁱⁿᵗ - Kᶜ
        C = Cᵏ-(1+comp.α)*Cᶜ

        #-----------------------
        # Assemble contributions
        

        idof1 = nodes.idof_6[n1]
        idof2 = nodes.idof_6[n2]
        
        dofs = vcat(idof1, idof2)


        lock(lk)
        try
            energy.strain_energy +=  strain_energy
            energy.kinetic_energy += kinetic_energy
            energy.contact_energy += contact_energy

            matrices.Tᵏ[dofs] += Tᵏ
            matrices.Tⁱⁿᵗ[dofs] += Tⁱⁿᵗ
            matrices.Tᶜ[dofs] += Tᶜ

            matrices.K[b.sparsity_map] += vec(K)
            matrices.C[b.sparsity_map] += vec(C)
            matrices.M[b.sparsity_map] += vec(M)

        finally
            unlock(lk)
        end

                            
    end



    
end 