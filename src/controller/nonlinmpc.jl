struct NonLinMPC{S<:StateEstimator, JEFunc<:Function} <: PredictiveController
    estim::S
    optim::JuMP.Model
    con::ControllerConstraint
    ΔŨ::Vector{Float64}
    x̂d::Vector{Float64}
    x̂s::Vector{Float64}
    ŷ ::Vector{Float64}
    Hp::Int
    Hc::Int
    M_Hp::Diagonal{Float64, Vector{Float64}}
    Ñ_Hc::Diagonal{Float64, Vector{Float64}}
    L_Hp::Diagonal{Float64, Vector{Float64}}
    C::Float64
    E::Float64
    JE::JEFunc
    R̂u::Vector{Float64}
    R̂y::Vector{Float64}
    S̃_Hp::Matrix{Bool}
    T_Hp::Matrix{Bool}
    T_Hc::Matrix{Bool}
    Ẽ ::Matrix{Float64}
    F ::Vector{Float64}
    G ::Matrix{Float64}
    J ::Matrix{Float64}
    Kd::Matrix{Float64}
    Q ::Matrix{Float64}
    P̃ ::Hermitian{Float64, Matrix{Float64}}
    q̃ ::Vector{Float64}
    Ks::Matrix{Float64}
    Ps::Matrix{Float64}
    d0::Vector{Float64}
    D̂0::Vector{Float64}
    Uop::Vector{Float64}
    Yop::Vector{Float64}
    Dop::Vector{Float64}
    function NonLinMPC{S, JEFunc}(
        estim::S, Hp, Hc, Mwt, Nwt, Lwt, Cwt, Ewt, JE::JEFunc, ru, optim
    ) where {S<:StateEstimator, JEFunc<:Function}
        model = estim.model
        nu, nxd, nxs, ny, nd = model.nu, model.nx, estim.nxs, model.ny, model.nd
        x̂d, x̂s, ŷ = zeros(nxd), zeros(nxs), zeros(ny)
        validate_weights(model, Hp, Hc, Mwt, Nwt, Lwt, Cwt, ru, Ewt)
        M_Hp = Diagonal(convert(Vector{Float64}, repeat(Mwt, Hp)))
        N_Hc = Diagonal(convert(Vector{Float64}, repeat(Nwt, Hc)))
        L_Hp = Diagonal(convert(Vector{Float64}, repeat(Lwt, Hp)))
        C = Cwt
        # manipulated input setpoint predictions are constant over Hp :
        R̂u = ~iszero(Lwt) ? repeat(ru, Hp) : R̂u = Float64[] 
        R̂y = zeros(ny* Hp) # dummy R̂y (updated just before optimization)
        S_Hp, T_Hp, S_Hc, T_Hc = init_ΔUtoU(nu, Hp, Hc)
        E, F, G, J, Kd, Q = init_deterpred(model, Hp, Hc)
        con, S̃_Hp, Ñ_Hc, Ẽ = init_defaultcon(model, Hp, Hc, C, S_Hp, S_Hc, N_Hc, E)
        nvar = size(Ẽ, 2)
        P̃, q̃ = init_quadprog(model, Ẽ, S̃_Hp, M_Hp, Ñ_Hc, L_Hp)
        Ks, Ps = init_stochpred(estim, Hp)
        d0, D̂0 = zeros(nd), zeros(nd*Hp)
        Uop, Yop, Dop = repeat(model.uop, Hp), repeat(model.yop, Hp), repeat(model.dop, Hp)
        ΔŨ = zeros(nvar)
        mpc = new(
            estim, optim, con,
            ΔŨ, x̂d, x̂s, ŷ,
            Hp, Hc, 
            M_Hp, Ñ_Hc, L_Hp, Cwt, Ewt, JE, R̂u, R̂y,
            S̃_Hp, T_Hp, T_Hc, 
            Ẽ, F, G, J, Kd, Q, P̃, q̃,
            Ks, Ps,
            d0, D̂0,
            Uop, Yop, Dop,
        )
        @variable(optim, ΔŨ[1:nvar])
        A = con.A[con.i_b, :]
        b = con.b[con.i_b]
        @constraint(optim, linconstraint, A*ΔŨ .≤ b)
        J = let mpc=mpc, model=model # capture mpc and model variables
            (ΔŨ...) -> obj_nonlinprog(mpc, model, ΔŨ)
        end
        register(mpc.optim, :J, nvar, J, autodiff=true)
        @NLobjective(mpc.optim, Min, J(ΔŨ...))
        nonlinconstraint = let mpc=mpc, model=model # capture mpc and model variables
            (ΔŨ...) -> con_nonlinprog(mpc, model, ΔŨ)
        end
        nonlincon_memoized = memoize(nonlinconstraint, 2*ny*Hp)
        for i=1:ny*Hp
            register(mpc.optim, Symbol("C_Ŷmin_$(i)"), nvar, nonlincon_memoized[i], autodiff=true)
        end
        for i=1:ny*Hp
            register(mpc.optim, Symbol("C_Ŷmax_$(i)"), nvar, nonlincon_memoized[ny*Hp+i], autodiff=true)
        end
        set_silent(optim)
        return mpc
    end
end

@doc raw"""
    NonLinMPC(model::SimModel; <keyword arguments>)

Construct a nonlinear predictive controller based on [`SimModel`](@ref) `model`.

Both [`NonLinModel`](@ref) and [`LinModel`](@ref) are supported (see Extended Help). The 
controller minimizes the following objective function at each discrete time ``k``:
```math
\min_{\mathbf{ΔU}, ϵ}    \mathbf{(R̂_y - Ŷ)}' \mathbf{M}_{H_p} \mathbf{(R̂_y - Ŷ)}   
                       + \mathbf{(ΔU)}'      \mathbf{N}_{H_c} \mathbf{(ΔU)}  
                       + \mathbf{(R̂_u - U)}' \mathbf{L}_{H_p} \mathbf{(R̂_u - U)} 
                       + C ϵ^2  +  E J_E(\mathbf{U}_E, \mathbf{Ŷ}_E, \mathbf{D̂}_E)
```
See [`LinMPC`](@ref) for the variable definitions. The custom economic function ``J_E`` can
penalizes solutions with high economic costs. Setting all the weights to 0 except ``E`` 
creates a pure economic model predictive controller (EMPC). The arguments of ``J_E`` are 
the manipulated inputs, the predicted outputs and measured disturbances from ``k`` to 
``k+H_p`` inclusively:
```math
    \mathbf{U}_E = \begin{bmatrix} \mathbf{U}      \\ \mathbf{u}(k+H_p-1)   \end{bmatrix}  \text{,} \qquad
    \mathbf{Ŷ}_E = \begin{bmatrix} \mathbf{ŷ}(k)   \\ \mathbf{Ŷ}            \end{bmatrix}  \text{,} \qquad
    \mathbf{D̂}_E = \begin{bmatrix} \mathbf{d}(k)   \\ \mathbf{D̂}            \end{bmatrix}
```
since ``H_c ≤ H_p`` implies that ``\mathbf{u}(k+H_p) = \mathbf{u}(k+H_p-1)``. The vector
``\mathbf{D̂}`` includes the predicted measured disturbance over ``H_p``.

!!! tip
    Replace any of the 3 arguments with `_` if not needed (see `JE` default value below).

This method uses the default state estimator, an [`UnscentedKalmanFilter`](@ref) with 
default arguments.

# Arguments
- `model::SimModel` : model used for controller predictions and state estimations.
- `Hp=10`: prediction horizon ``H_p``.
- `Hc=2` : control horizon ``H_c``.
- `Mwt=fill(1.0,model.ny)` : main diagonal of ``\mathbf{M}`` weight matrix (vector)
- `Nwt=fill(0.1,model.nu)` : main diagonal of ``\mathbf{N}`` weight matrix (vector)
- `Lwt=fill(0.0,model.nu)` : main diagonal of ``\mathbf{L}`` weight matrix (vector)
- `Cwt=1e5` : slack variable weight ``C`` (scalar), use `Cwt=Inf` for hard constraints only
- `Ewt=1.0` : economic costs weight ``E`` (scalar). 
- `JE=(_,_,_)->0.0` : economic function ``J_E(\mathbf{U}_E, \mathbf{D̂}_E, \mathbf{Ŷ}_E)``.
- `ru=model.uop` : manipulated input setpoints ``\mathbf{r_u}`` (vector)
- `optim=JuMP.Model(Ipopt.Optimizer)` : nonlinear optimizer used in the predictive 
   controller, provided as a [`JuMP.Model`](https://jump.dev/JuMP.jl/stable/reference/models/#JuMP.Model)
   (default to [`Ipopt.jl`](https://github.com/jump-dev/Ipopt.jl) optimizer)

# Examples
```jldoctest
julia> model = NonLinModel((x,u,_)->0.5x+u, (x,_)->2x, 10, 1, 1, 1);

julia> mpc = NonLinMPC(model, Hp=20, Hc=1, Cwt=1e6)
NonLinMPC controller with a sample time Ts = 10.0 s, UnscentedKalmanFilter estimator and:
 1 manipulated inputs u
 2 states x̂
 1 measured outputs ym
 0 unmeasured outputs yu
 0 measured disturbances d
```

# Extended Help
`NonLinMPC` controllers based on [`LinModel`](@ref) compute the predictions with matrix 
algebra instead of a `for` loop. This feature can accelerate the optimization and is not 
available in any other package, to my knowledge.
"""
NonLinMPC(model::SimModel; kwargs...) = NonLinMPC(UnscentedKalmanFilter(model); kwargs...)


"""
    NonLinMPC(estim::StateEstimator; <keyword arguments>)

Use custom state estimator `estim` to construct `NonLinMPC`.

# Examples
```jldoctest
julia> model = NonLinModel((x,u,_)->0.5x+u, (x,_)->2x, 10, 1, 1, 1);

julia> estim = UnscentedKalmanFilter(model, σQ_int=[0.05]);

julia> mpc = NonLinMPC(estim, Hp=20, Hc=1, Cwt=1e6)
NonLinMPC controller with a sample time Ts = 10.0 s, UnscentedKalmanFilter estimator and:
 1 manipulated inputs u
 2 states x̂
 1 measured outputs ym
 0 unmeasured outputs yu
 0 measured disturbances d
```
"""
function NonLinMPC(
    estim::S;
    Hp::Int = 10,
    Hc::Int = 2,
    Mwt = fill(1.0, estim.model.ny),
    Nwt = fill(0.1, estim.model.nu),
    Lwt = fill(0.0, estim.model.nu),
    Cwt = 1e5,
    Ewt = 1.0,
    JE::JEFunc = (_,_,_) -> 0.0,
    ru  = estim.model.uop,
    optim::JuMP.Model = JuMP.Model(optimizer_with_attributes(Ipopt.Optimizer,"sb"=>"yes"))
) where {S<:StateEstimator, JEFunc<:Function}
    return NonLinMPC{S, JEFunc}(estim, Hp, Hc, Mwt, Nwt, Lwt, Cwt, Ewt, JE, ru, optim)
end

setnontlincon!(mpc::NonLinMPC, model::LinModel) = nothing

function setnonlincon!(mpc::NonLinMPC, model::NonLinModel)
    optim = mpc.optim
    ΔŨ = mpc.optim[:ΔŨ]
    con = mpc.con
    map(con -> delete(optim, con), all_nonlinear_constraints(optim))
    for i in findall(con.i_Ŷmin)
        f_sym = Symbol("C_Ŷmin_$(i)")
        add_nonlinear_constraint(optim, :($(f_sym)($(ΔŨ...)) <= 0))
    end
    for i in findall(con.i_Ŷmax)
        f_sym = Symbol("C_Ŷmax_$(i)")
        add_nonlinear_constraint(optim, :($(f_sym)($(ΔŨ...)) <= 0))
    end
    return nothing
end

init_objective!(mpc::NonLinMPC, _ ) = nothing

function obj_nonlinprog(mpc::NonLinMPC, model::LinModel, ΔŨ::NTuple{N, T}) where {N, T}
    ΔŨ = collect(ΔŨ) # convert NTuple to Vector
    Jqp = obj_quadprog(ΔŨ, mpc.P̃, mpc.q̃)
    U = mpc.S̃_Hp*ΔŨ + mpc.T_Hp*(mpc.estim.lastu0 + model.uop)
    UE = [U; U[(end - model.nu + 1):end]]
    ŶE = [mpc.ŷ; mpc.Ẽ*ΔŨ + mpc.F]
    D̂E = [mpc.d0 + model.dop; mpc.D̂0 + mpc.Dop]
    return Jqp + mpc.E*mpc.JE(UE, ŶE, D̂E)
end

function obj_nonlinprog(mpc::NonLinMPC, model::SimModel, ΔŨ::NTuple{N, T}) where {N, T}
    ΔŨ = collect(ΔŨ) # convert NTuple to Vector
    U0 = mpc.S̃_Hp*ΔŨ + mpc.T_Hp*(mpc.estim.lastu0)
    # --- output setpoint tracking term ---
    Ŷ = evalŶ(mpc, model, mpc.x̂d, mpc.d0, mpc.D̂0, U0)
    êy = mpc.R̂y - Ŷ
    JR̂y = êy'*mpc.M_Hp*êy  
    # --- move suppression term ---
    JΔŨ = ΔŨ'*mpc.Ñ_Hc*ΔŨ 
    # --- input setpoint tracking term ---
    U = U0 + mpc.Uop
    if !isempty(mpc.R̂u)
        êu = mpc.R̂u - U 
        JR̂u = êu'*mpc.L_Hp*ê
    else
        JR̂u = 0.0
    end
    # --- slack variable term ---
    Jϵ = !isinf(mpc.C) ? mpc.C*ΔŨ[end] : 0.0
    # --- economic term ---
    UE = [U; U[(end - model.nu + 1):end]]
    ŶE = [mpc.ŷ; Ŷ]
    D̂E = [mpc.d0 + model.dop; mpc.D̂0 + mpc.Dop]
    return JR̂y + JΔŨ + JR̂u + Jϵ + mpc.E*mpc.JE(UE, ŶE, D̂E)
end

function con_nonlinprog(mpc::NonLinMPC, model::SimModel, ΔŨ::NTuple{N, T}) where {N, T}
    ΔŨ = collect(ΔŨ) # convert NTuple to Vector
    U0 = mpc.S̃_Hp*ΔŨ + mpc.T_Hp*(mpc.estim.lastu0)
    Ŷ = evalŶ(mpc, model, mpc.x̂d, mpc.d0, mpc.D̂0, U0)
    C_Ŷmin = (mpc.con.Ŷmin - Ŷ)
    C_Ŷmax = (Ŷ - mpc.con.Ŷmax)
    if !isinf(mpc.C) # constraint softening activated :
        ϵ = ΔŨ[end]
        C_Ŷmin = C_Ŷmin - ϵ*mpc.con.c_Ŷmin
        C_Ŷmax = C_Ŷmax - ϵ*mpc.con.c_Ŷmin
    end
    C = [C_Ŷmin; C_Ŷmax]
    return C
end

function evalŶ(mpc, model, x̂d, d0, D̂0, U0::Vector{T}) where {T}
    Ŷd0 = Vector{T}(undef, model.ny*mpc.Hp)
    x̂d::Vector{T} = x̂d
    for j=1:mpc.Hp
        u0    = U0[(1 + model.nu*(j-1)):(model.nu*j)]
        x̂d[:] = model.f(x̂d, u0, d0)
        d0    = D̂0[(1 + model.nd*(j-1)):(model.nd*j)]
        Ŷd0[(1 + model.ny*(j-1)):(model.ny*j)] = model.h(x̂d, d0)
    end
    return Ŷd0 + mpc.F
end

"""
    memoize(myfunc::Function, n_outputs::Int)

Take a function `myfunc` and return a vector of length `n_outputs`, where element
`i` is a function that returns the equivalent of `myfunc(x...)[i]`.

To avoid duplication of work, cache the most-recent evaluations of `myfunc`.
Because `myfunc_i` is auto-differentiated with ForwardDiff, our cache needs to
work when `x` is a `Float64` and a `ForwardDiff.Dual`.
"""
function memoize(f::Function, n_outputs::Int)
    last_ΔŨ , last_f = nothing, nothing
    function f_i(i, ΔŨ::Float64...)
        if ΔŨ !== last_ΔŨ
            last_f = f(ΔŨ...)
            last_ΔŨ = ΔŨ
        end
        return last_f[i]
    end
    last_dΔŨ, last_dfdΔŨ = nothing, nothing
    function f_i(i, dΔŨ::T...) where {T<:Real}
        if dΔŨ !== last_dΔŨ
            last_dfdΔŨ = f(dΔŨ...)
            last_dΔŨ = dΔŨ
        end
        return last_dfdΔŨ[i]
    end
    return [(x...) -> f_i(i, x...) for i in 1:n_outputs]
end