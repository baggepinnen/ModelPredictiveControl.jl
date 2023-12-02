const DEFAULT_MHE_OPTIMIZER = optimizer_with_attributes(Ipopt.Optimizer,"sb"=>"yes")

struct MovingHorizonEstimator{
    NT<:Real, 
    SM<:SimModel, 
    JM<:JuMP.GenericModel
} <: StateEstimator{NT}
    model::SM
    # note: `NT` and the number type `JNT` in `JuMP.GenericModel{JNT}` can be
    # different since solvers that support non-Float64 are scarce.
    optim::JM
    W̃::Vector{NT}
    lastu0::Vector{NT}
    x̂::Vector{NT}
    P̂::Hermitian{NT, Matrix{NT}}
    He::Int
    i_ym::Vector{Int}
    nx̂ ::Int
    nym::Int
    nyu::Int
    nxs::Int
    As  ::Matrix{NT}
    Cs_u::Matrix{NT}
    Cs_y::Matrix{NT}
    nint_u ::Vector{Int}
    nint_ym::Vector{Int}
    Â ::Matrix{NT}
    B̂u::Matrix{NT}
    Ĉ ::Matrix{NT}
    B̂d::Matrix{NT}
    D̂d::Matrix{NT}
    P̂0  ::Hermitian{NT, Matrix{NT}}
    Q̂::Hermitian{NT, Matrix{NT}}
    R̂::Hermitian{NT, Matrix{NT}}
    invP̄::Hermitian{NT, Matrix{NT}}
    invQ̂_He::Hermitian{NT, Matrix{NT}}
    invR̂_He::Hermitian{NT, Matrix{NT}}
    X̂min::Vector{NT}
    X̂max::Vector{NT}
    X̂ ::Union{Vector{NT}, Missing} 
    Ym::Union{Vector{NT}, Missing}
    U ::Union{Vector{NT}, Missing}
    D ::Union{Vector{NT}, Missing}
    Ŵ ::Union{Vector{NT}, Missing}
    x̂0_past::Vector{NT}
    Nk::Vector{Int}
    function MovingHorizonEstimator{NT, SM, JM}(
        model::SM, He, i_ym, nint_u, nint_ym, P̂0, Q̂, R̂, optim::JM
    ) where {NT<:Real, SM<:SimModel{NT}, JM<:JuMP.GenericModel}
        nu, nd, nx, ny = model.nu, model.nd, model.nx, model.ny
        He < 1  && throw(ArgumentError("Estimation horizon He should be ≥ 1"))
        nym, nyu = validate_ym(model, i_ym)
        As, Cs_u, Cs_y, nint_u, nint_ym = init_estimstoch(model, i_ym, nint_u, nint_ym)
        nxs = size(As, 1)
        nx̂  = model.nx + nxs
        Â, B̂u, Ĉ, B̂d, D̂d = augment_model(model, As, Cs_u, Cs_y)
        validate_kfcov(nym, nx̂, Q̂, R̂, P̂0)
        lastu0 = zeros(NT, model.nu)
        x̂ = [zeros(NT, model.nx); zeros(NT, nxs)]
        P̂0 = Hermitian(P̂0, :L)
        Q̂, R̂ = Hermitian(Q̂, :L),  Hermitian(R̂, :L)
        invP̄ = Hermitian(inv(P̂0), :L)
        invQ̂_He = Hermitian(repeatdiag(inv(Q̂), He), :L)
        invR̂_He = Hermitian(repeatdiag(inv(R̂), He), :L)
        P̂ = copy(P̂0)
        X̂min, X̂max = fill(-Inf, nx̂*(He+1)), fill(+Inf, nx̂*(He+1))
        nvar = nx̂*(He + 1) 
        W̃ = zeros(nvar)
        X̂, Ym, U, D, Ŵ = zeros(nx̂*He), zeros(nym*He), zeros(nu*He), zeros(nd*He), zeros(nx̂*He)
        x̂0_past = zeros(nx̂)
        Nk = [1]
        estim = new{NT, SM, JM}(
            model, optim, W̃,
            lastu0, x̂, P̂, He,
            i_ym, nx̂, nym, nyu, nxs, 
            As, Cs_u, Cs_y, nint_u, nint_ym,
            Â, B̂u, Ĉ, B̂d, D̂d,
            P̂0, Q̂, R̂, invP̄, invQ̂_He, invR̂_He,
            X̂min, X̂max, 
            X̂, Ym, U, D, Ŵ, 
            x̂0_past, Nk
        )
        init_optimization!(estim, optim)
        return estim
    end
end

function MovingHorizonEstimator(
    model::SM;
    He::Int=nothing,
    i_ym::IntRangeOrVector = 1:model.ny,
    σP0::Vector = fill(1/model.nx, model.nx),
    σQ::Vector  = fill(1/model.nx, model.nx),
    σR::Vector  = fill(1, length(i_ym)),
    nint_u   ::IntVectorOrInt = 0,
    σQint_u  ::Vector = fill(1, max(sum(nint_u), 0)),
    σP0int_u ::Vector = fill(1, max(sum(nint_u), 0)),
    nint_ym  ::IntVectorOrInt = default_nint(model, i_ym, nint_u),
    σQint_ym ::Vector = fill(1, max(sum(nint_ym), 0)),
    σP0int_ym::Vector = fill(1, max(sum(nint_ym), 0)),
    optim::JM = JuMP.Model(DEFAULT_MHE_OPTIMIZER, add_bridges=false),
) where {NT<:Real, SM<:SimModel{NT}, JM<:JuMP.GenericModel}
    # estimated covariances matrices (variance = σ²) :
    P̂0 = Diagonal{NT}([σP0; σP0int_u; σP0int_ym].^2)
    Q̂  = Diagonal{NT}([σQ;  σQint_u;  σQint_ym].^2)
    R̂  = Diagonal{NT}(σR.^2)
    return MovingHorizonEstimator{NT, SM, JM}(
        model, He, i_ym, nint_u, nint_ym, P̂0, Q̂, R̂, optim
    )
end


"""
    init_optimization!(estim::MovingHorizonEstimator, optim::JuMP.GenericModel)

Init the nonlinear optimization of [`MovingHorizonEstimator`](@ref).
"""
function init_optimization!(
    estim::MovingHorizonEstimator, optim::JuMP.GenericModel{JNT}
) where JNT<:Real
    # --- variables and linear constraints ---
    nvar = length(estim.W̃)
    set_silent(optim)
    #limit_solve_time(estim) #TODO: add this feature
    @variable(optim, W̃var[1:nvar])
    # --- nonlinear optimization init ---
    nym, nx̂, He = estim.nym, estim.nx̂, estim.He #, length(i_g)
    # inspired from https://jump.dev/JuMP.jl/stable/tutorials/nonlinear/tips_and_tricks/#User-defined-operators-with-vector-outputs
    Jfunc = let estim=estim, model=estim.model, nvar=nvar , nŶm=He*nym, nX̂=(He+1)*nx̂
        last_W̃tup_float, last_W̃tup_dual = nothing, nothing
        Ŷm_cache::DiffCache{Vector{JNT}, Vector{JNT}} = DiffCache(zeros(nŶm), nvar + 3)
        X̂_cache ::DiffCache{Vector{JNT}, Vector{JNT}} = DiffCache(zeros(nX̂) , nvar + 3)
        function Jfunc(W̃tup::JNT...)
            Ŷm, X̂ = get_tmp(Ŷm_cache, W̃tup[1]), get_tmp(X̂_cache, W̃tup[1])
            W̃ = collect(W̃tup)
            if W̃tup != last_W̃tup_float
                Ŷm, _ = predict!(Ŷm, X̂, estim, model, W̃)
                last_W̃tup_float = W̃tup
            end
            return obj_nonlinprog(estim, model, Ŷm, W̃)
        end
        function Jfunc(W̃tup::ForwardDiff.Dual...)
            Ŷm, X̂ = get_tmp(Ŷm_cache, W̃tup[1]), get_tmp(X̂_cache, W̃tup[1])
            W̃ = collect(W̃tup)
            if W̃tup != last_W̃tup_dual
                Ŷm, _ = predict!(Ŷm, X̂, estim, model, W̃)
                last_W̃tup_dual = W̃tup
            end
            return obj_nonlinprog(estim, model, Ŷm, W̃)
        end
        Jfunc
    end
    register(optim, :Jfunc, nvar, Jfunc, autodiff=true)
    @NLobjective(optim, Min, Jfunc(W̃var...))
    return nothing
end


"Print the overall dimensions of the state estimator `estim` with left padding `n`."
function print_estim_dim(io::IO, estim::MovingHorizonEstimator, n)
    nu, nd = estim.model.nu, estim.model.nd
    nx̂, nym, nyu = estim.nx̂, estim.nym, estim.nyu
    He = estim.He
    println(io, "$(lpad(He, n)) estimation steps He")
    println(io, "$(lpad(nu, n)) manipulated inputs u ($(sum(estim.nint_u)) integrating states)")
    println(io, "$(lpad(nx̂, n)) states x̂")
    println(io, "$(lpad(nym, n)) measured outputs ym ($(sum(estim.nint_ym)) integrating states)")
    println(io, "$(lpad(nyu, n)) unmeasured outputs yu")
    print(io,   "$(lpad(nd, n)) measured disturbances d")
end


"""
    obj_nonlinprog(estim::MovingHorizonEstimator, model::SimModel, ΔŨ::Vector{Real})

Objective function for [`MovingHorizonEstimator`](@ref).

The function `dot(x, A, x)` is a performant way of calculating `x'*A*x`.
"""
function obj_nonlinprog(
    estim::MovingHorizonEstimator, ::SimModel, Ŷm, W̃::Vector{T}
) where {T<:Real}
    Nk = estim.Nk[]
    nYm, nŴ, nx̂, invP̄ = Nk*estim.nym, Nk*estim.nx̂, estim.nx̂, estim.invP̄
    invQ̂_Nk, invR̂_Nk = @views estim.invQ̂_He[1:nŴ, 1:nŴ], estim.invR̂_He[1:nYm, 1:nYm]
    x̄0 = @views W̃[1:nx̂] - estim.x̂0_past  # W̃ = [x̂(k-Nk|k); Ŵ]
    V̂  = @views estim.Ym[1:nYm] - Ŷm[1:nYm]
    Ŵ  = @views W̃[nx̂+1:nx̂+nŴ]
    return dot(x̄0, invP̄, x̄0) + dot(Ŵ, invQ̂_Nk, Ŵ) + dot(V̂, invR̂_Nk, V̂)
end

function predict!(
    Ŷm, X̂, estim::MovingHorizonEstimator, model::SimModel, W̃::Vector{T}
) where {T<:Real}
    nu, nd, nx̂, nym, Nk = model.nu, model.nd, estim.nx̂, estim.nym, estim.Nk[]
    X̂[1:nx̂] = W̃[1:nx̂] # W̃ = [x̂(k-Nk|k); Ŵ]
    for j=1:Nk
        u = @views estim.U[(1 + nu*(j-1)):(nu*j)]
        d = @views estim.D[(1 + nd*(j-1)):(nd*j)]
        ŵ = @views W̃[(1 + nx̂*j):(nx̂*(j+1))]
        x̂ = @views X̂[(1 + nx̂*(j-1)):(nx̂*j)]
        Ŷm[(1 + nym*(j-1)):(nym*j)] = ĥ(estim, model, x̂, d)[estim.i_ym]
        X̂[(1 + nx̂*j):(nx̂*(j+1))]    = f̂(estim, model, x̂, u, d) + ŵ
    end
    return Ŷm, X̂
end

"Reset `estim.P̂`, `estim.invP̄` and the time windows for the moving horizon estimator."
function init_estimate_cov!(estim::MovingHorizonEstimator, _ , _ , _ ) 
    estim.P̂.data[:]    = estim.P̂0 # .data is necessary for Hermitians
    estim.invP̄.data[:] = Hermitian(inv(estim.P̂0), :L)
    estim.x̂0_past     .= 0
    estim.W̃           .= 0
    estim.X̂           .= 0
    estim.Ym          .= 0
    estim.U           .= 0
    estim.D           .= 0
    estim.Ŵ           .= 0
    estim.Nk          .= 1
    return nothing
end

@doc raw"""
    update_estimate!(estim::UnscentedKalmanFilter, u, ym, d)
    
Update [`UnscentedKalmanFilter`](@ref) state `estim.x̂` and covariance estimate `estim.P̂`.

A ref[^4]:

```math
\begin{aligned}
    \mathbf{Ŷ^m}(k) &= \bigg[\begin{matrix} \mathbf{ĥ^m}\Big( \mathbf{X̂}_{k-1}^{1}(k) \Big) & \mathbf{ĥ^m}\Big( \mathbf{X̂}_{k-1}^{2}(k) \Big) & \cdots & \mathbf{ĥ^m}\Big( \mathbf{X̂}_{k-1}^{n_σ}(k) \Big) \end{matrix}\bigg] \\
    \mathbf{ŷ^m}(k) &= \mathbf{Ŷ^m}(k) \mathbf{m̂} 
\end{aligned} 
```

[^4]: TODO
"""
function update_estimate!(estim::MovingHorizonEstimator{NT}, u, ym, d) where NT<:Real
    model, optim, x̂, P̂ = estim.model, estim.optim, estim.x̂, estim.P̂
    nx̂, nym, nu, nd, nŵ = estim.nx̂, estim.nym, model.nu, model.nd, estim.nx̂
    Nk, He = estim.Nk[], estim.He
    nŴ, nYm, nX̂ = nx̂*Nk, nym*Nk, nx̂*(Nk+1)
    W̃var::Vector{VariableRef} = optim[:W̃var]
    ŵ = zeros(nŵ) # ŵ(k) = 0 for warm-starting
    if Nk < He
        estim.X̂[ (1 + nx̂*(Nk-1)):(nx̂*Nk)]   = x̂
        estim.Ym[(1 + nym*(Nk-1)):(nym*Nk)] = ym
        estim.U[ (1 + nu*(Nk-1)):(nu*Nk)]   = u
        estim.D[ (1 + nd*(Nk-1)):(nd*Nk)]   = d
        estim.Ŵ[ (1 + nŵ*(Nk-1)):(nŵ*Nk)]   = ŵ
    else
        estim.X̂[:]  = [estim.X̂[nx̂+1:end]  ; x̂]
        estim.Ym[:] = [estim.Ym[nym+1:end]; ym]
        estim.U[:]  = [estim.U[nu+1:end]  ; u]
        estim.D[:]  = [estim.D[nd+1:end]  ; d]
        estim.Ŵ[:]  = [estim.Ŵ[nŵ+1:end]  ; ŵ]
    end
    Ŷm = Vector{NT}(undef, nYm)
    X̂  = Vector{NT}(undef, nX̂)
    estim.x̂0_past[:] = estim.X̂[1:nx̂]
    W̃0 = [estim.x̂0_past; estim.Ŵ]
    Ŷm, X̂ = predict!(Ŷm, X̂, estim, model, W̃0)
    J0 = obj_nonlinprog(estim, model, Ŷm, W̃0)
    # initial W̃0 with Ŵ=0 if objective or constraint function not finite :
    isfinite(J0) || (W̃0 = [estim.x̂0_past; zeros(NT, nŴ)])
    set_start_value.(W̃var, W̃0)
    unfix.(W̃var[is_fixed.(W̃var)])
    fix.(W̃var[(nx̂*(Nk+1)+1):end], 0.0) 
    try
        optimize!(optim)
    catch err
        if isa(err, MOI.UnsupportedAttribute{MOI.VariablePrimalStart})
            # reset_optimizer to unset warm-start, set_start_value.(nothing) seems buggy
            MOIU.reset_optimizer(optim)
            optimize!(optim)
        else
            rethrow(err)
        end
    end
    status = termination_status(optim)
    W̃curr, W̃last = value.(W̃var), W̃0
    if !(status == OPTIMAL || status == LOCALLY_SOLVED)
        if isfatal(status)
            @error("MHE terminated without solution: estimation in open-loop", 
                   status)
        else
            @warn("MHE termination status not OPTIMAL or LOCALLY_SOLVED: keeping "*
                  "solution anyway", status)
        end
        @debug solution_summary(optim, verbose=true)
    end
    estim.W̃[:] = !isfatal(status) ? W̃curr : W̃last
    estim.Ŵ[1:nŴ] = estim.W̃[nx̂+1:nx̂+nŴ] # update Ŵ with optimum for next time step
    Ŷm, X̂ = predict!(Ŷm, X̂, estim, model, estim.W̃)
    x̂[:] = X̂[(1 + nx̂*Nk):(nx̂*(Nk+1))]
    estim.Nk[] = Nk < He ? Nk + 1 : He
    return nothing
end