@doc raw"""
    setconstraint!(mpc::PredictiveController; <keyword arguments>) -> mpc

Set the constraint parameters of the [`PredictiveController`](@ref) `mpc`.

The predictive controllers support both soft and hard constraints, defined by:
```math 
\begin{alignat*}{3}
    \mathbf{u_{min}  - c_{u_{min}}}  ϵ ≤&&\       \mathbf{u}(k+j) &≤ \mathbf{u_{max}  + c_{u_{max}}}  ϵ &&\qquad  j = 0, 1 ,..., H_p - 1 \\
    \mathbf{Δu_{min} - c_{Δu_{min}}} ϵ ≤&&\      \mathbf{Δu}(k+j) &≤ \mathbf{Δu_{max} + c_{Δu_{max}}} ϵ &&\qquad  j = 0, 1 ,..., H_c - 1 \\
    \mathbf{y_{min}  - c_{y_{min}}}  ϵ ≤&&\       \mathbf{ŷ}(k+j) &≤ \mathbf{y_{max}  + c_{y_{max}}}  ϵ &&\qquad  j = 1, 2 ,..., H_p     \\
    \mathbf{x̂_{min}  - c_{x̂_{min}}}  ϵ ≤&&\ \mathbf{x̂}_{k-1}(k+j) &≤ \mathbf{x̂_{max}  + c_{x̂_{max}}}  ϵ &&\qquad  j = H_p
\end{alignat*}
```
and also ``ϵ ≥ 0``. The last line is the terminal constraints applied on the states at the
end of the horizon (see Extended Help). See [`MovingHorizonEstimator`](@ref) constraints
for details on bounds and softness parameters ``\mathbf{c}``. The output and terminal 
constraints are all soft by default. See Extended Help for time-varying constraints.

# Arguments
- `mpc::PredictiveController` : predictive controller to set constraints.
- `umin  = fill(-Inf,nu)` : manipulated input lower bounds ``\mathbf{u_{min}}``.
- `umax  = fill(+Inf,nu)` : manipulated input upper bounds ``\mathbf{u_{max}}``.
- `Δumin = fill(-Inf,nu)` : manipulated input increment lower bounds ``\mathbf{Δu_{min}}``.
- `Δumax = fill(+Inf,nu)` : manipulated input increment upper bounds ``\mathbf{Δu_{max}}``.
- `ymin  = fill(-Inf,ny)` : predicted output lower bounds ``\mathbf{y_{min}}``.
- `ymax  = fill(+Inf,ny)` : predicted output upper bounds ``\mathbf{y_{max}}``.
- `x̂min  = fill(-Inf,nx̂)` : terminal constraint lower bounds ``\mathbf{x̂_{min}}``.
- `x̂max  = fill(+Inf,nx̂)` : terminal constraint upper bounds ``\mathbf{x̂_{max}}``.
- `c_umin  = fill(0.0,nu)` : `umin` softness weights ``\mathbf{c_{u_{min}}}``.
- `c_umax  = fill(0.0,nu)` : `umax` softness weights ``\mathbf{c_{u_{max}}}``.
- `c_Δumin = fill(0.0,nu)` : `Δumin` softness weights ``\mathbf{c_{Δu_{min}}}``.
- `c_Δumax = fill(0.0,nu)` : `Δumax` softness weights ``\mathbf{c_{Δu_{max}}}``.
- `c_ymin  = fill(1.0,ny)` : `ymin` softness weights ``\mathbf{c_{y_{min}}}``.
- `c_ymax  = fill(1.0,ny)` : `ymax` softness weights ``\mathbf{c_{y_{max}}}``.
- `c_x̂min  = fill(1.0,nx̂)` : `x̂min` softness weights ``\mathbf{c_{x̂_{min}}}``.
- `c_x̂max  = fill(1.0,nx̂)` : `x̂max` softness weights ``\mathbf{c_{x̂_{max}}}``.
- all the keyword arguments above but with a capital letter, except for the terminal
  constraints, e.g. `Ymax` or `C_Δumin` : for time-varying constraints (see Extended Help).

# Examples
```jldoctest
julia> mpc = LinMPC(setop!(LinModel(tf(3, [30, 1]), 4), uop=[50], yop=[25]));

julia> mpc = setconstraint!(mpc, umin=[0], umax=[100], Δumin=[-10], Δumax=[+10])
LinMPC controller with a sample time Ts = 4.0 s, OSQP optimizer, SteadyKalmanFilter estimator and:
 10 prediction steps Hp
  2 control steps Hc
  1 manipulated inputs u (0 integrating states)
  2 states x̂
  1 measured outputs ym (1 integrating states)
  0 unmeasured outputs yu
  0 measured disturbances d
```

# Extended Help
!!! details "Extended Help"
    Terminal constraints provide closed-loop stability guarantees on the nominal plant model.
    They can render an unfeasible problem however. In practice, a sufficiently large
    prediction horizon ``H_p`` without terminal constraints is typically enough for 
    stability. Note that terminal constraints are applied on the augmented state vector 
    ``\mathbf{x̂}`` (see [`SteadyKalmanFilter`](@ref) for details on augmentation).

    For variable constraints, the bounds can be modified after calling [`moveinput!`](@ref),
    that is, at runtime, but not the softness parameters ``\mathbf{c}``. It is not possible
    to modify `±Inf` bounds at runtime.

    !!! tip
        To keep a variable unconstrained while maintaining the ability to add a constraint
        later at runtime, set the bound to an absolute value sufficiently large when you
        create the controller (but different than `±Inf`).

    It is also possible to specify time-varying constraints over ``H_p`` and ``H_c`` 
    horizons. In such a case, they are defined by:
    ```math 
    \begin{alignat*}{3}
        \mathbf{U_{min}  - C_{u_{min}}}  ϵ ≤&&\ \mathbf{U}  &≤ \mathbf{U_{max}  + C_{u_{max}}}  ϵ \\
        \mathbf{ΔU_{min} - C_{Δu_{min}}} ϵ ≤&&\ \mathbf{ΔU} &≤ \mathbf{ΔU_{max} + C_{Δu_{max}}} ϵ \\
        \mathbf{Y_{min}  - C_{y_{min}}}  ϵ ≤&&\ \mathbf{Ŷ}  &≤ \mathbf{Y_{max}  + C_{y_{max}}}  ϵ
    \end{alignat*}
    ```
    For this, use the same keyword arguments as above but with a capital letter:
    - `Umin`  / `Umax`  / `C_umin`  / `C_umax`  : ``\mathbf{U}`` constraints `(nu*Hp,)`.
    - `ΔUmin` / `ΔUmax` / `C_Δumin` / `C_Δumax` : ``\mathbf{ΔU}`` constraints `(nu*Hc,)`.
    - `Ymin`  / `Ymax`  / `C_ymin`  / `C_ymax`  : ``\mathbf{Ŷ}`` constraints `(ny*Hp,)`.
"""
function setconstraint!(
    mpc::PredictiveController; 
    umin    = nothing, umax    = nothing,
    Δumin   = nothing, Δumax   = nothing,
    ymin    = nothing, ymax    = nothing,
    x̂min    = nothing, x̂max    = nothing,
    c_umin  = nothing, c_umax  = nothing,
    c_Δumin = nothing, c_Δumax = nothing,
    c_ymin  = nothing, c_ymax  = nothing,
    c_x̂min  = nothing, c_x̂max  = nothing,
    Umin    = nothing, Umax    = nothing,
    ΔUmin   = nothing, ΔUmax   = nothing,
    Ymin    = nothing, Ymax    = nothing,
    C_umax  = nothing, C_umin  = nothing,
    C_Δumax = nothing, C_Δumin = nothing,
    C_ymax  = nothing, C_ymin  = nothing,
    # TODO:
    # ------------ will be deleted in the future ---------------
    ŷmin    = nothing, ŷmax    = nothing,
    c_ŷmin  = nothing, c_ŷmax  = nothing,
    # ----------------------------------------------------------
)
    # TODO:
    # ----- these 4 `if`s will be deleted in the future --------
    if !isnothing(ŷmin)
        Base.depwarn("keyword arg ŷmin is deprecated, use ymin instead", :setconstraint!)
        ymin = ŷmin
    end
    if !isnothing(ŷmax)
        Base.depwarn("keyword arg ŷmax is deprecated, use ymax instead", :setconstraint!)
        ymax = ŷmax
    end
    if !isnothing(c_ŷmin)
        Base.depwarn("keyword arg ŷmin is deprecated, use ymin instead", :setconstraint!)
        c_ymin = c_ŷmin
    end
    if !isnothing(c_ŷmax)
        Base.depwarn("keyword arg ŷmax is deprecated, use ymax instead", :setconstraint!)
        c_ymax = c_ŷmax
    end
    # ----------------------------------------------------------
    model, con, optim = mpc.estim.model, mpc.con, mpc.optim
    nu, ny, nx̂, Hp, Hc = model.nu, model.ny, mpc.estim.nx̂, mpc.Hp, mpc.Hc
    notSolvedYet = (termination_status(optim) == OPTIMIZE_NOT_CALLED)
    C, E, ex̂ = mpc.C, mpc.Ẽ[:, 1:nu*Hc], mpc.con.ẽx̂[:, 1:nu*Hc]
    isnothing(Umin)     && !isnothing(umin)     && (Umin    = repeat(umin,    Hp))
    isnothing(Umax)     && !isnothing(umax)     && (Umax    = repeat(umax,    Hp))
    isnothing(ΔUmin)    && !isnothing(Δumin)    && (ΔUmin   = repeat(Δumin,   Hc))
    isnothing(ΔUmax)    && !isnothing(Δumax)    && (ΔUmax   = repeat(Δumax,   Hc))
    isnothing(Ymin)     && !isnothing(ymin)     && (Ymin    = repeat(ymin,    Hp))
    isnothing(Ymax)     && !isnothing(ymax)     && (Ymax    = repeat(ymax,    Hp))
    isnothing(C_umin)   && !isnothing(c_umin)   && (C_umin  = repeat(c_umin,  Hp))
    isnothing(C_umax)   && !isnothing(c_umax)   && (C_umax  = repeat(c_umax,  Hp))
    isnothing(C_Δumin)  && !isnothing(c_Δumin)  && (C_Δumin = repeat(c_Δumin, Hc))
    isnothing(C_Δumax)  && !isnothing(c_Δumax)  && (C_Δumax = repeat(c_Δumax, Hc))
    isnothing(C_ymin)   && !isnothing(c_ymin)   && (C_ymin  = repeat(c_ymin,  Hp))
    isnothing(C_ymax)   && !isnothing(c_ymax)   && (C_ymax  = repeat(c_ymax,  Hp))
    if !all(isnothing.([C_umin, C_umax, C_Δumin, C_Δumax, C_ymin, C_ymax, c_x̂min, c_x̂max]))
        !isinf(C) || throw(ArgumentError("Slack variable weight Cwt must be finite to set softness parameters"))
        notSolvedYet || error("Cannot set softness parameters after calling moveinput!")
    end
    if !isnothing(Umin)
        size(Umin)   == (nu*Hp,) || throw(ArgumentError("Umin size must be $((nu*Hp,))"))
        con.Umin[:] = Umin
    end
    if !isnothing(Umax)
        size(Umax)   == (nu*Hp,) || throw(ArgumentError("Umax size must be $((nu*Hp,))"))
        con.Umax[:] = Umax
    end
    if !isnothing(ΔUmin)
        size(ΔUmin)  == (nu*Hc,) || throw(ArgumentError("ΔUmin size must be $((nu*Hc,))"))
        con.ΔŨmin[1:nu*Hc] = ΔUmin
    end
    if !isnothing(ΔUmax)
        size(ΔUmax)  == (nu*Hc,) || throw(ArgumentError("ΔUmax size must be $((nu*Hc,))"))
        con.ΔŨmax[1:nu*Hc] = ΔUmax
    end
    if !isnothing(Ymin)
        size(Ymin)   == (ny*Hp,) || throw(ArgumentError("Ymin size must be $((ny*Hp,))"))
        con.Ymin[:] = Ymin
    end
    if !isnothing(Ymax)
        size(Ymax)   == (ny*Hp,) || throw(ArgumentError("Ymax size must be $((ny*Hp,))"))
        con.Ymax[:] = Ymax
    end
    if !isnothing(x̂min)
        size(x̂min)   == (nx̂,) || throw(ArgumentError("x̂min size must be $((nx̂,))"))
        con.x̂min[:] = x̂min
    end
    if !isnothing(x̂max)
        size(x̂max)   == (nx̂,) || throw(ArgumentError("x̂max size must be $((nx̂,))"))
        con.x̂max[:] = x̂max
    end
    if !isnothing(C_umin)
        size(C_umin) == (nu*Hp,) || throw(ArgumentError("C_umin size must be $((nu*Hp,))"))
        any(C_umin .< 0) && error("C_umin weights should be non-negative")
        con.A_Umin[:, end] = -C_umin
    end
    if !isnothing(C_umax)
        size(C_umax) == (nu*Hp,) || throw(ArgumentError("C_umax size must be $((nu*Hp,))"))
        any(C_umax .< 0) && error("C_umax weights should be non-negative")
        con.A_Umax[:, end] = -C_umax
    end
    if !isnothing(C_Δumin)
        size(C_Δumin) == (nu*Hc,) || throw(ArgumentError("C_Δumin size must be $((nu*Hc,))"))
        any(C_Δumin .< 0) && error("C_Δumin weights should be non-negative")
        con.A_ΔŨmin[1:end-1, end] = -C_Δumin 
    end
    if !isnothing(C_Δumax)
        size(C_Δumax) == (nu*Hc,) || throw(ArgumentError("C_Δumax size must be $((nu*Hc,))"))
        any(C_Δumax .< 0) && error("C_Δumax weights should be non-negative")
        con.A_ΔŨmax[1:end-1, end] = -C_Δumax
    end
    if !isnothing(C_ymin)
        size(C_ymin) == (ny*Hp,) || throw(ArgumentError("C_ymin size must be $((ny*Hp,))"))
        any(C_ymin .< 0) && error("C_ymin weights should be non-negative")
        con.C_ymin[:] = C_ymin
        A_Ymin ,_ = relaxŶ(model, C, con.C_ymin, con.C_ymax, E)
        con.A_Ymin[:] = A_Ymin
    end
    if !isnothing(C_ymax)
        size(C_ymax) == (ny*Hp,) || throw(ArgumentError("C_ymax size must be $((ny*Hp,))"))
        any(C_ymax .< 0) && error("C_ymax weights should be non-negative")
        con.C_ymax[:] = C_ymax
        _, A_Ymax = relaxŶ(model, C, con.C_ymin, con.C_ymax, E)
        con.A_Ymax[:] = A_Ymax
    end
    if !isnothing(c_x̂min)
        size(c_x̂min) == (nx̂,) || throw(ArgumentError("c_x̂min size must be $((nx̂,))"))
        any(c_x̂min .< 0) && error("c_x̂min weights should be non-negative")
        con.c_x̂min[:] = c_x̂min
        A_x̂min ,_ = relaxterminal(model, C, con.c_x̂min, con.c_x̂max, ex̂)
        con.A_x̂min[:] = A_x̂min
    end
    if !isnothing(c_x̂max)
        size(c_x̂max) == (nx̂,) || throw(ArgumentError("c_x̂max size must be $((nx̂,))"))
        any(c_x̂max .< 0) && error("c_x̂max weights should be non-negative")
        con.c_x̂max[:] = c_x̂max
        _, A_x̂max = relaxterminal(model, C, con.c_x̂min, con.c_x̂max, ex̂)
        con.A_x̂max[:] = A_x̂max
    end
    i_Umin,  i_Umax  = .!isinf.(con.Umin),  .!isinf.(con.Umax)
    i_ΔŨmin, i_ΔŨmax = .!isinf.(con.ΔŨmin), .!isinf.(con.ΔŨmin)
    i_Ymin,  i_Ymax  = .!isinf.(con.Ymin),  .!isinf.(con.Ymax)
    i_x̂min,  i_x̂max  = .!isinf.(con.x̂min),  .!isinf.(con.x̂max)
    if notSolvedYet
        con.i_b[:], con.i_g[:], con.A[:] = init_matconstraint_mpc(model,
            i_Umin, i_Umax, i_ΔŨmin, i_ΔŨmax, 
            i_Ymin, i_Ymax, i_x̂min, i_x̂max,
            con.A_Umin, con.A_Umax, con.A_ΔŨmin, con.A_ΔŨmax, 
            con.A_Ymin, con.A_Ymax, con.A_x̂min, con.A_x̂max
        )
        A = con.A[con.i_b, :]
        b = con.b[con.i_b]
        ΔŨvar = optim[:ΔŨvar]
        delete(optim, optim[:linconstraint])
        unregister(optim, :linconstraint)
        @constraint(optim, linconstraint, A*ΔŨvar .≤ b)
        setnonlincon!(mpc, model)
    else
        i_b, i_g = init_matconstraint_mpc(model, 
            i_Umin, i_Umax, i_ΔŨmin, i_ΔŨmax, 
            i_Ymin, i_Ymax, i_x̂min, i_x̂max
        )
        if i_b ≠ con.i_b || i_g ≠ con.i_g
            error("Cannot modify ±Inf constraints after calling moveinput!")
        end
    end
    return mpc
end

"By default, there is no nonlinear constraint, thus do nothing."
setnonlincon!(::PredictiveController, ::SimModel) = nothing

"""
    default_Hp(model::LinModel, Hp)

Estimate the default prediction horizon `Hp` with a security margin for [`LinModel`](@ref).
"""
function default_Hp(model::LinModel, Hp)
    # TODO: also check for settling time (poles)
    # TODO: also check for non minimum phase systems (zeros)
    # TODO: replace sum with max delay between all the I/O
    # TODO: use this nk value for default N value in sim!
    poles = eigvals(model.A)
    # atol=1e-3 to overestimate the number of delays : for closed-loop stability, it is
    # better to overestimate the default value of Hp, as a security margin.
    nk = sum(isapprox.(abs.(poles), 0.0, atol=1e-3)) # number of delays
    if isnothing(Hp)
        Hp = DEFAULT_HP0 + nk
    end
    if Hp ≤ nk
        @warn("prediction horizon Hp ($Hp) ≤ estimated number of delays in model "*
              "($nk), the closed-loop system may be unstable or zero-gain (unresponsive)")
    end
    return Hp
end

"""
    default_Hp(model::SimModel, Hp)

Throw an error if `isnothing(Hp)` when model is not a [`LinModel`](@ref).
"""
function default_Hp(::SimModel, Hp)
    if isnothing(Hp)
        # TODO:
        # ------------ will be deleted in the future ------------------------------------
        Base.depwarn("Hp=nothing is deprecated for NonLinModel, explicitly specify an "*
                     "integer value", :NonLinMPC)
        Hp = DEFAULT_HP0
        # ------------- and replaced by this -------------------------------------------
        # throw(ArgumentError("Prediction horizon Hp must be explicitly specified if "*
        #                     "model is not a LinModel."))
        # Hp = 0
        # -----------------------------------------------------------------------------
    end
    return Hp
end

"""
    validate_args(mpc::PredictiveController, ry, d, D̂, R̂y, R̂u)

Check the dimensions of the arguments of [`moveinput!`](@ref).
"""
function validate_args(mpc::PredictiveController, ry, d, D̂, R̂y, R̂u)
    ny, nd, nu, Hp = mpc.estim.model.ny, mpc.estim.model.nd, mpc.estim.model.nu, mpc.Hp
    size(ry) ≠ (ny,)    && throw(DimensionMismatch("ry size $(size(ry)) ≠ output size ($ny,)"))
    size(d)  ≠ (nd,)    && throw(DimensionMismatch("d size $(size(d)) ≠ measured dist. size ($nd,)"))
    size(D̂)  ≠ (nd*Hp,) && throw(DimensionMismatch("D̂ size $(size(D̂)) ≠ measured dist. size × Hp ($(nd*Hp),)"))
    size(R̂y) ≠ (ny*Hp,) && throw(DimensionMismatch("R̂y size $(size(R̂y)) ≠ output size × Hp ($(ny*Hp),)"))
    if ~mpc.noR̂u
        size(R̂u) ≠ (nu*Hp,) && throw(DimensionMismatch("R̂u size $(size(R̂u)) ≠ manip. input size × Hp ($(nu*Hp),)"))
    end
end


@doc raw"""
    init_ΔUtoU(model, Hp, Hc) -> S, T

Init manipulated input increments to inputs conversion matrices.

The conversion from the input increments ``\mathbf{ΔU}`` to manipulated inputs over ``H_p`` 
are calculated by:
```math
\mathbf{U} = \mathbf{S} \mathbf{ΔU} + \mathbf{T} \mathbf{u}(k-1) \\
```
"""
function init_ΔUtoU(model::SimModel{NT}, Hp, Hc) where {NT<:Real}
    # S and T are `Matrix{NT}` since conversion is faster than `Matrix{Bool}` or `BitMatrix`
    I_nu = Matrix{NT}(I, model.nu, model.nu)
    S_Hc = LowerTriangular(repeat(I_nu, Hc, Hc))
    S = [S_Hc; repeat(I_nu, Hp - Hc, Hc)]
    T = repeat(I_nu, Hp)
    return S, T
end


@doc raw"""
    init_predmat(estim, ::LinModel, Hp, Hc) -> E, G, J, K, V, ex̂, fx̂, gx̂, jx̂, kx̂, vx̂

Construct the prediction matrices for [`LinModel`](@ref) `model`.

The linear model predictions are evaluated by :
```math
\begin{aligned}
    \mathbf{Ŷ} &= \mathbf{E ΔU} + \mathbf{G d}(k) + \mathbf{J D̂} 
                                + \mathbf{K x̂}_{k-1}(k) + \mathbf{V u}(k-1) \\
               &= \mathbf{E ΔU} + \mathbf{F}
\end{aligned}
```
where the predicted outputs ``\mathbf{Ŷ}`` and measured disturbances ``\mathbf{D̂}`` are from 
``k + 1`` to ``k + H_p``. Input increments ``\mathbf{ΔU}`` are from ``k`` to
``k + H_c - 1``. The vector ``\mathbf{x̂}_{k-1}(k)`` is the state estimated at the last 
control period. The method also computes similar matrices but for the predicted terminal 
states at ``k+H_p``:
```math
\begin{aligned}
    \mathbf{x̂}_{k-1}(k+H_p) 
            &= \mathbf{e_x̂ ΔU} + \mathbf{g_x̂ d}(k) + \mathbf{j_x̂ D̂} 
                               + \mathbf{k_x̂ x̂}_{k-1}(k) + \mathbf{v_x̂ u}(k-1) \\
            &= \mathbf{e_x̂ ΔU} + \mathbf{f_x̂}
\end{aligned}
```
Operating points on ``\mathbf{u}``, ``\mathbf{d}`` and ``\mathbf{y}`` are omitted in above
equations.

# Extended Help
!!! details "Extended Help"
    Using the augmented matrices ``\mathbf{Â, B̂_u, Ĉ, B̂_d, D̂_d}`` in `estim` and the
    function ``\mathbf{W}(j) = \mathbf{Ĉ} ( ∑_{i=0}^j \mathbf{Â}^i ) \mathbf{B̂_u}``, the
    prediction matrices are computed by :
    ```math
    \begin{aligned}
    \mathbf{E} &= \begin{bmatrix}
        \mathbf{W}(0)      & \mathbf{0}        & \cdots & \mathbf{0}              \\
        \mathbf{W}(1)      & \mathbf{W}(0)     & \cdots & \mathbf{0}              \\
        \vdots             & \vdots            & \ddots & \vdots                  \\
        \mathbf{W}(H_p-1)  & \mathbf{W}(H_p-2) & \cdots & \mathbf{W}(H_p-H_c+1)   \end{bmatrix} \\
    \mathbf{G} &= \begin{bmatrix}
        \mathbf{Ĉ}\mathbf{Â}^{0} \mathbf{B̂_d}     \\ 
        \mathbf{Ĉ}\mathbf{Â}^{1} \mathbf{B̂_d}     \\ 
        \vdots                                    \\
        \mathbf{Ĉ}\mathbf{Â}^{H_p-1} \mathbf{B̂_d} \end{bmatrix} \\
    \mathbf{J} &= \begin{bmatrix}
        \mathbf{D̂_d}                              & \mathbf{0}                                & \cdots & \mathbf{0}   \\ 
        \mathbf{Ĉ}\mathbf{Â}^{0} \mathbf{B̂_d}     & \mathbf{D̂_d}                              & \cdots & \mathbf{0}   \\ 
        \vdots                                    & \vdots                                    & \ddots & \vdots       \\
        \mathbf{Ĉ}\mathbf{Â}^{H_p-2} \mathbf{B̂_d} & \mathbf{Ĉ}\mathbf{Â}^{H_p-3} \mathbf{B̂_d} & \cdots & \mathbf{D̂_d} \end{bmatrix} \\
    \mathbf{K} &= \begin{bmatrix}
        \mathbf{Ĉ}\mathbf{Â}^{1}      \\
        \mathbf{Ĉ}\mathbf{Â}^{2}      \\
        \vdots                        \\
        \mathbf{Ĉ}\mathbf{Â}^{H_p}    \end{bmatrix} \\
    \mathbf{V} &= \begin{bmatrix}
        \mathbf{W}(0)        \\
        \mathbf{W}(1)        \\
        \vdots               \\
        \mathbf{W}(H_p-1)    \end{bmatrix}
    \end{aligned}
    ```
    For the terminal constraints, the matrices are computed with the function
    ``\mathbf{w_x̂}(j) = ( ∑_{i=0}^j \mathbf{Â}^i ) \mathbf{B̂_u}`` and:
    ```math
    \begin{aligned}
    \mathbf{e_x̂} &= \begin{bmatrix} \mathbf{w_x̂}(H_p-1) & \mathbf{w_x̂}(H_p-2) & \cdots & \mathbf{w_x̂}(H_p-H_c+1) \end{bmatrix} \\
    \mathbf{g_x̂} &= \mathbf{Â}^{H_p-1} \mathbf{B̂_d} \\
    \mathbf{j_x̂} &= \begin{bmatrix} \mathbf{Â}^{H_p-2} \mathbf{B̂_d} & \mathbf{Â}^{H_p-3} \mathbf{B̂_d} & \cdots & \mathbf{0} \end{bmatrix} \\
    \mathbf{k_x̂} &= \mathbf{Â}^{H_p} \\
    \mathbf{v_x̂} &= \mathbf{w_x̂}(H_p-1)
    \end{aligned}
    ```
"""
function init_predmat(estim::StateEstimator{NT}, model::LinModel, Hp, Hc) where {NT<:Real}
    Â, B̂u, Ĉ, B̂d, D̂d = estim.Â, estim.B̂u, estim.Ĉ, estim.B̂d, estim.D̂d
    nu, nx̂, ny, nd = model.nu, estim.nx̂, model.ny, model.nd
    # --- pre-compute matrix powers ---
    # Apow 3D array : Apow[:,:,1] = A^0, Apow[:,:,2] = A^1, ... , Apow[:,:,Hp+1] = A^Hp
    Âpow = Array{NT}(undef, nx̂, nx̂, Hp+1)
    Âpow[:,:,1] = I(nx̂)
    for j=2:Hp+1
        Âpow[:,:,j] = Âpow[:,:,j-1]*Â
    end
    # Apow_csum 3D array : Apow_csum[:,:,1] = A^0, Apow_csum[:,:,2] = A^1 + A^0, ...
    Âpow_csum  = cumsum(Âpow, dims=3)
    # helper function to improve code clarity and be similar to eqs. in docstring:
    getpower(array3D, power) = array3D[:,:, power+1]
    # --- state estimates x̂ ---
    kx̂ = getpower(Âpow, Hp)
    K  = Matrix{NT}(undef, Hp*ny, nx̂)
    for j=1:Hp
        iRow = (1:ny) .+ ny*(j-1)
        K[iRow,:] = Ĉ*getpower(Âpow, j)
    end    
    # --- manipulated inputs u ---
    vx̂ = getpower(Âpow_csum, Hp-1)*B̂u
    V  = Matrix{NT}(undef, Hp*ny, nu)
    for j=1:Hp
        iRow = (1:ny) .+ ny*(j-1)
        V[iRow,:] = Ĉ*getpower(Âpow_csum, j-1)*B̂u
    end
    ex̂ = Matrix{NT}(undef, nx̂, Hc*nu)
    E  = zeros(NT, Hp*ny, Hc*nu) 
    for j=1:Hc # truncated with control horizon
        iRow = (ny*(j-1)+1):(ny*Hp)
        iCol = (1:nu) .+ nu*(j-1)
        E[iRow, iCol] = V[iRow .- ny*(j-1),:]
        ex̂[:  , iCol] = getpower(Âpow_csum, Hp-j)*B̂u
    end
    # --- measured disturbances d ---
    gx̂ = getpower(Âpow, Hp-1)*B̂d
    G  = Matrix{NT}(undef, Hp*ny, nd)
    jx̂ = Matrix{NT}(undef, nx̂, Hp*nd)
    J  = repeatdiag(D̂d, Hp)
    if nd ≠ 0
        for j=1:Hp
            iRow = (1:ny) .+ ny*(j-1)
            G[iRow,:] = Ĉ*getpower(Âpow, j-1)*B̂d
        end
        for j=1:Hp
            iRow = (ny*j+1):(ny*Hp)
            iCol = (1:nd) .+ nd*(j-1)
            J[iRow, iCol] = G[iRow .- ny*j,:]
            jx̂[:  , iCol] = j < Hp ? getpower(Âpow, Hp-j-1)*B̂d : zeros(NT, nx̂, nd)
        end
    end
    # dummy values (updated just before optimization):
    F, fx̂  = zeros(NT, ny*Hp), zeros(NT, nx̂)
    return E, F, G, J, K, V, ex̂, fx̂, gx̂, jx̂, kx̂, vx̂
end

"Return empty matrices if `model` is not a [`LinModel`](@ref)"
function init_predmat(estim::StateEstimator{NT}, model::SimModel, Hp, Hc) where {NT<:Real}
    nu, nx̂, nd = model.nu, estim.nx̂, model.nd
    E  = zeros(NT, 0, nu*Hc)
    G  = zeros(NT, 0, nd)
    J  = zeros(NT, 0, nd*Hp)
    K  = zeros(NT, 0, nx̂)
    V  = zeros(NT, 0, nu)
    F  = zeros(NT, 0)
    ex̂, gx̂, jx̂, kx̂, vx̂, fx̂ = E, G, J, K, V, F
    return E, F, G, J, K, V, ex̂, fx̂, gx̂, jx̂, kx̂, vx̂
end

@doc raw"""
    init_quadprog(model::LinModel, Ẽ, S, M_Hp, N_Hc, L_Hp) -> H̃, q̃, p

Init the quadratic programming optimization matrix `H̃` and `q̃` for MPC.

The matrices appear in the quadratic general form :
```math
    J = \min_{\mathbf{ΔŨ}} \frac{1}{2}\mathbf{(ΔŨ)'H̃(ΔŨ)} + \mathbf{q̃'(ΔŨ)} + p 
```
``\mathbf{H̃}`` is constant if the model and weights are linear and time invariant (LTI). The 
vector ``\mathbf{q̃}`` and scalar ``p`` need recalculation each control period ``k`` (see
`initpred!`). ``p`` does not impact the minima position. It is thus 
useless at optimization but required to evaluate the minimal ``J`` value.
"""
function init_quadprog(::LinModel{NT}, Ẽ, S̃, M_Hp, Ñ_Hc, L_Hp) where {NT<:Real}
    H̃ = Hermitian(convert(Matrix{NT}, 2*(Ẽ'*M_Hp*Ẽ + Ñ_Hc + S̃'*L_Hp*S̃)), :L)
    q̃ = zeros(NT, size(H̃, 1))   # dummy value (updated just before optimization)
    p = zeros(NT, 1)            # dummy value (updated just before optimization)
    return H̃, q̃, p
end
"Return empty matrices if `model` is not a [`LinModel`](@ref)."
function init_quadprog(::SimModel{NT}, Ẽ, S̃, M_Hp, Ñ_Hc, L_Hp) where {NT<:Real}
    H̃ = Hermitian(zeros(NT, 0, 0))
    q̃ = zeros(NT, 0)
    p = zeros(NT, 1)            # dummy value (updated just before optimization)
    return H̃, q̃, p
end

"""
    init_defaultcon_mpc(estim, C, S, N_Hc, E, ex̂, fx̂, gx̂, jx̂, kx̂, vx̂) -> con, S̃, Ñ_Hc, Ẽ

Init `ControllerConstraint` struct with default parameters based on estimator `estim`.

Also return `S̃`, `Ñ_Hc` and `Ẽ` matrices for the the augmented decision vector `ΔŨ`.
"""
function init_defaultcon_mpc(
    estim::StateEstimator{NT}, 
    Hp, Hc, C, S, N_Hc, E, ex̂, fx̂, gx̂, jx̂, kx̂, vx̂
) where {NT<:Real}
    model = estim.model
    nu, ny, nx̂ = model.nu, model.ny, estim.nx̂
    umin,       umax    = fill(convert(NT,-Inf), nu), fill(convert(NT,+Inf), nu)
    Δumin,      Δumax   = fill(convert(NT,-Inf), nu), fill(convert(NT,+Inf), nu)
    ymin,       ymax    = fill(convert(NT,-Inf), ny), fill(convert(NT,+Inf), ny)
    x̂min,       x̂max    = fill(convert(NT,-Inf), nx̂), fill(convert(NT,+Inf), nx̂)
    c_umin,     c_umax  = fill(zero(NT), nu), fill(zero(NT), nu)
    c_Δumin,    c_Δumax = fill(zero(NT), nu), fill(zero(NT), nu)
    c_ymin,     c_ymax  = fill(one(NT),  ny), fill(one(NT),  ny)
    c_x̂min,     c_x̂max  = fill(zero(NT), nx̂), fill(zero(NT), nx̂)
    Umin, Umax, ΔUmin, ΔUmax, Ymin, Ymax = 
        repeat_constraints(Hp, Hc, umin, umax, Δumin, Δumax, ymin, ymax)
    C_umin, C_umax, C_Δumin, C_Δumax, C_ymin, C_ymax = 
        repeat_constraints(Hp, Hc, c_umin, c_umax, c_Δumin, c_Δumax, c_ymin, c_ymax)
    A_Umin, A_Umax, S̃ = relaxU(model, C, C_umin, C_umax, S)
    A_ΔŨmin, A_ΔŨmax, ΔŨmin, ΔŨmax, Ñ_Hc = relaxΔU(model, C, C_Δumin, C_Δumax, ΔUmin, ΔUmax, N_Hc)
    A_Ymin, A_Ymax, Ẽ = relaxŶ(model, C, C_ymin, C_ymax, E)
    A_x̂min, A_x̂max, ẽx̂ = relaxterminal(model, C, c_x̂min, c_x̂max, ex̂)
    i_Umin,  i_Umax  = .!isinf.(Umin),  .!isinf.(Umax)
    i_ΔŨmin, i_ΔŨmax = .!isinf.(ΔŨmin), .!isinf.(ΔŨmax)
    i_Ymin,  i_Ymax  = .!isinf.(Ymin),  .!isinf.(Ymax)
    i_x̂min,  i_x̂max  = .!isinf.(x̂min),  .!isinf.(x̂max)
    i_b, i_g, A = init_matconstraint_mpc(
        model, 
        i_Umin, i_Umax, i_ΔŨmin, i_ΔŨmax, i_Ymin, i_Ymax, i_x̂min, i_x̂max,
        A_Umin, A_Umax, A_ΔŨmin, A_ΔŨmax, A_Ymin, A_Ymax, A_x̂max, A_x̂min
    )
    b = zeros(NT, size(A, 1)) # dummy b vector (updated just before optimization)
    con = ControllerConstraint{NT}(
        ẽx̂      , fx̂    , gx̂     , jx̂       , kx̂     , vx̂     ,  
        Umin    , Umax  , ΔŨmin  , ΔŨmax    , Ymin   , Ymax   , x̂min   , x̂max,
        A_Umin  , A_Umax, A_ΔŨmin, A_ΔŨmax  , A_Ymin , A_Ymax , A_x̂min , A_x̂max,
        A       , b     , i_b    , C_ymin   , C_ymax , c_x̂min , c_x̂max , i_g
    )
    return con, S̃, Ñ_Hc, Ẽ
end

"Repeat predictive controller constraints over prediction `Hp` and control `Hc` horizons."
function repeat_constraints(Hp, Hc, umin, umax, Δumin, Δumax, ymin, ymax)
    Umin  = repeat(umin, Hp)
    Umax  = repeat(umax, Hp)
    ΔUmin = repeat(Δumin, Hc)
    ΔUmax = repeat(Δumax, Hc)
    Ymin  = repeat(ymin, Hp)
    Ymax  = repeat(ymax, Hp)
    return Umin, Umax, ΔUmin, ΔUmax, Ymin, Ymax
end



@doc raw"""
    relaxU(model, C, C_umin, C_umax, S) -> A_Umin, A_Umax, S̃

Augment manipulated inputs constraints with slack variable ϵ for softening.

Denoting the input increments augmented with the slack variable
``\mathbf{ΔŨ} = [\begin{smallmatrix} \mathbf{ΔU} \\ ϵ \end{smallmatrix}]``, it returns the
augmented conversion matrix ``\mathbf{S̃}``, similar to the one described at
[`init_ΔUtoU`](@ref). It also returns the ``\mathbf{A}`` matrices for the inequality
constraints:
```math
\begin{bmatrix} 
    \mathbf{A_{U_{min}}} \\ 
    \mathbf{A_{U_{max}}} 
\end{bmatrix} \mathbf{ΔŨ} ≤
\begin{bmatrix}
    - \mathbf{U_{min}} + \mathbf{T} \mathbf{u}(k-1) \\
    + \mathbf{U_{max}} - \mathbf{T} \mathbf{u}(k-1)
\end{bmatrix}
```
"""
function relaxU(::SimModel{NT}, C, C_umin, C_umax, S) where {NT<:Real}
    if !isinf(C) # ΔŨ = [ΔU; ϵ]
        # ϵ impacts ΔU → U conversion for constraint calculations:
        A_Umin, A_Umax = -[S  C_umin], [S -C_umax] 
        # ϵ has no impact on ΔU → U conversion for prediction calculations:
        S̃ = [S zeros(NT, size(S, 1))]
    else # ΔŨ = ΔU (only hard constraints)
        A_Umin, A_Umax = -S,  S
        S̃ = S
    end
    return A_Umin, A_Umax, S̃
end

@doc raw"""
    relaxΔU(
        model, C, C_Δumin, C_Δumax, ΔUmin, ΔUmax, N_Hc
    ) -> A_ΔŨmin, A_ΔŨmax, ΔŨmin, ΔŨmax, Ñ_Hc

Augment input increments constraints with slack variable ϵ for softening.

Denoting the input increments augmented with the slack variable 
``\mathbf{ΔŨ} = [\begin{smallmatrix} \mathbf{ΔU} \\ ϵ \end{smallmatrix}]``, it returns the
augmented input increment weights ``\mathbf{Ñ}_{H_c}`` (that incorporate ``C``). It also  
returns the augmented constraints ``\mathbf{ΔŨ_{min}}`` and ``\mathbf{ΔŨ_{max}}`` and the 
``\mathbf{A}`` matrices for the inequality constraints:
```math
\begin{bmatrix} 
    \mathbf{A_{ΔŨ_{min}}} \\ 
    \mathbf{A_{ΔŨ_{max}}}
\end{bmatrix} \mathbf{ΔŨ} ≤
\begin{bmatrix}
    - \mathbf{ΔŨ_{min}} \\
    + \mathbf{ΔŨ_{max}}
\end{bmatrix}
```
"""
function relaxΔU(::SimModel{NT}, C, C_Δumin, C_Δumax, ΔUmin, ΔUmax, N_Hc) where {NT<:Real}
    diag_N_Hc = diag(N_Hc)
    if !isinf(C) # ΔŨ = [ΔU; ϵ]
        # 0 ≤ ϵ ≤ ∞  
        ΔŨmin, ΔŨmax = [ΔUmin; NT[0.0]], [ΔUmax; NT[Inf]]
        A_ϵ = [zeros(NT, 1, length(ΔUmin)) NT[1.0]]
        A_ΔŨmin, A_ΔŨmax = -[I  C_Δumin; A_ϵ], [I -C_Δumax; A_ϵ]
        Ñ_Hc = Diagonal{NT}([diag_N_Hc; C])
    else # ΔŨ = ΔU (only hard constraints)
        ΔŨmin, ΔŨmax = ΔUmin, ΔUmax
        I_Hc = Matrix{NT}(I, size(N_Hc))
        A_ΔŨmin, A_ΔŨmax = -I_Hc,  I_Hc
        Ñ_Hc = Diagonal{NT}(diag_N_Hc)
    end
    return A_ΔŨmin, A_ΔŨmax, ΔŨmin, ΔŨmax, Ñ_Hc
end

@doc raw"""
    relaxŶ(::LinModel, C, C_ymin, C_ymax, E) -> A_Ymin, A_Ymax, Ẽ

Augment linear output prediction constraints with slack variable ϵ for softening.

Denoting the input increments augmented with the slack variable 
``\mathbf{ΔŨ} = [\begin{smallmatrix} \mathbf{ΔU} \\ ϵ \end{smallmatrix}]``, it returns the 
``\mathbf{Ẽ}`` matrix that appears in the linear model prediction equation 
``\mathbf{Ŷ = Ẽ ΔŨ + F}``, and the ``\mathbf{A}`` matrices for the inequality constraints:
```math
\begin{bmatrix} 
    \mathbf{A_{Y_{min}}} \\ 
    \mathbf{A_{Y_{max}}}
\end{bmatrix} \mathbf{ΔŨ} ≤
\begin{bmatrix}
    - \mathbf{Y_{min}} + \mathbf{F} \\
    + \mathbf{Y_{max}} - \mathbf{F} 
\end{bmatrix}
```
"""
function relaxŶ(::LinModel{NT}, C, C_ymin, C_ymax, E) where {NT<:Real}
    if !isinf(C) # ΔŨ = [ΔU; ϵ]
        # ϵ impacts predicted output constraint calculations:
        A_Ymin, A_Ymax = -[E  C_ymin], [E -C_ymax] 
        # ϵ has no impact on output predictions
        Ẽ = [E zeros(NT, size(E, 1), 1)] 
    else # ΔŨ = ΔU (only hard constraints)
        Ẽ = E
        A_Ymin, A_Ymax = -E,  E
    end
    return A_Ymin, A_Ymax, Ẽ
end

"Return empty matrices if model is not a [`LinModel`](@ref)"
function relaxŶ(::SimModel{NT}, C, C_ymin, C_ymax, E) where {NT<:Real}
    Ẽ = !isinf(C) ? [E zeros(NT, 0, 1)] : E
    A_Ymin, A_Ymax = -Ẽ,  Ẽ 
    return A_Ymin, A_Ymax, Ẽ
end

@doc raw"""
    relaxterminal(::LinModel, C, c_x̂min, c_x̂max, ex̂) -> A_x̂min, A_x̂max, ẽx̂

Augment terminal state constraints with slack variable ϵ for softening.

Denoting the input increments augmented with the slack variable 
``\mathbf{ΔŨ} = [\begin{smallmatrix} \mathbf{ΔU} \\ ϵ \end{smallmatrix}]``, it returns the 
``\mathbf{ẽ_{x̂}}`` matrix that appears in the terminal state equation 
``\mathbf{x̂}_{k-1}(k + H_p) = \mathbf{ẽ_x̂ ΔŨ + f_x̂}``, and the ``\mathbf{A}`` matrices for 
the inequality constraints:
```math
\begin{bmatrix} 
    \mathbf{A_{x̂_{min}}} \\ 
    \mathbf{A_{x̂_{max}}}
\end{bmatrix} \mathbf{ΔŨ} ≤
\begin{bmatrix}
    - \mathbf{x̂_{min}} + \mathbf{f_x̂} \\
    + \mathbf{x̂_{max}} - \mathbf{f_x̂} 
\end{bmatrix}
```
"""
function relaxterminal(::LinModel{NT}, C, c_x̂min, c_x̂max, ex̂) where {NT<:Real}
    if !isinf(C) # ΔŨ = [ΔU; ϵ]
        # ϵ impacts terminal constraint calculations:
        A_x̂min, A_x̂max = -[ex̂ c_x̂min], [ex̂ -c_x̂max]
        # ϵ has no impact on terminal state predictions
        ẽx̂ = [ex̂ zeros(NT, size(ex̂, 1), 1)] 
    else # ΔŨ = ΔU (only hard constraints)
        ẽx̂ = ex̂
        A_x̂min, A_x̂max = -ex̂,  ex̂
    end
    return A_x̂min, A_x̂max, ẽx̂
end

"Return empty matrices if model is not a [`LinModel`](@ref)"
function relaxterminal(::SimModel{NT}, C, c_x̂min, c_x̂max, ex̂) where {NT<:Real}
    ẽx̂ = !isinf(C) ? [ex̂ zeros(NT, 0, 1)] : ex̂
    A_x̂min, A_x̂max = -ẽx̂,  ẽx̂
    return A_x̂min, A_x̂max, ẽx̂
end

@doc raw"""
    init_stochpred(estim::InternalModel, Hp) -> Ks, Ps

Init the stochastic prediction matrices for [`InternalModel`](@ref).

`Ks` and `Ps` matrices are defined as:
```math
    \mathbf{Ŷ_s} = \mathbf{K_s x̂_s}(k) + \mathbf{P_s ŷ_s}(k)
```
Current stochastic outputs ``\mathbf{ŷ_s}(k)`` comprises the measured outputs 
``\mathbf{ŷ_s^m}(k) = \mathbf{y^m}(k) - \mathbf{ŷ_d^m}(k)`` and unmeasured 
``\mathbf{ŷ_s^u}(k) = \mathbf{0}``. See [^2].

[^2]: Desbiens, A., D. Hodouin & É. Plamondon. 2000, "Global predictive control : a unified
    control structure for decoupling setpoint tracking, feedforward compensation and 
    disturbance rejection dynamics", *IEE Proceedings - Control Theory and Applications*, 
    vol. 147, no 4, https://doi.org/10.1049/ip-cta:20000443, p. 465–475, ISSN 1350-2379.
"""
function init_stochpred(estim::InternalModel{NT}, Hp) where NT<:Real
    As, B̂s, Cs = estim.As, estim.B̂s, estim.Cs
    ny  = estim.model.ny
    nxs = estim.nxs
    Ks = Matrix{NT}(undef, ny*Hp, nxs)
    Ps = Matrix{NT}(undef, ny*Hp, ny)
    for i = 1:Hp
        iRow = (1:ny) .+ ny*(i-1)
        Ms = Cs*As^(i-1)*B̂s
        Ks[iRow,:] = Cs*As^i - Ms*Cs
        Ps[iRow,:] = Ms
    end
    return Ks, Ps 
end

"Return empty matrices if `estim` is not a [`InternalModel`](@ref)."
function init_stochpred(estim::StateEstimator{NT}, _ ) where NT<:Real
    return zeros(NT, 0, estim.nxs), zeros(NT, 0, estim.model.ny)
end


@doc raw"""
    init_matconstraint_mpc(model::LinModel,
        i_Umin, i_Umax, i_ΔŨmin, i_ΔŨmax, i_Ymin, i_Ymax, i_x̂min, i_x̂max, args...
    ) -> i_b, i_g, A

Init `i_b`, `i_g` and `A` matrices for the linear and nonlinear inequality constraints.

The linear and nonlinear inequality constraints are respectively defined as:
```math
\begin{aligned} 
    \mathbf{A ΔŨ } &≤ \mathbf{b} \\ 
    \mathbf{g(ΔŨ)} &≤ \mathbf{0}
\end{aligned}
```
`i_b` is a `BitVector` including the indices of ``\mathbf{b}`` that are finite numbers. 
`i_g` is a similar vector but for the indices of ``\mathbf{g}`` (empty if `model` is a 
[`LinModel`](@ref)). The method also returns the ``\mathbf{A}`` matrix if `args` is
provided. In such a case, `args`  needs to contain all the inequality constraint matrices: 
`A_Umin, A_Umax, A_ΔŨmin, A_ΔŨmax, A_Ymin, A_Ymax, A_x̂min, A_x̂max`.
"""
function init_matconstraint_mpc(::LinModel{NT}, 
    i_Umin, i_Umax, i_ΔŨmin, i_ΔŨmax, i_Ymin, i_Ymax, i_x̂min, i_x̂max, args...
) where {NT<:Real}
    i_b = [i_Umin; i_Umax; i_ΔŨmin; i_ΔŨmax; i_Ymin; i_Ymax; i_x̂min; i_x̂max]
    i_g = BitVector()
    if isempty(args)
        A = zeros(NT, length(i_b), 0)
    else
        A_Umin, A_Umax, A_ΔŨmin, A_ΔŨmax, A_Ymin, A_Ymax, A_x̂min, A_x̂max = args
        A = [A_Umin; A_Umax; A_ΔŨmin; A_ΔŨmax; A_Ymin; A_Ymax; A_x̂min; A_x̂max]
    end
    return i_b, i_g, A
end

"Init `i_b, A` without outputs and terminal constraints if `model` is not a [`LinModel`](@ref)."
function init_matconstraint_mpc(::SimModel{NT},
    i_Umin, i_Umax, i_ΔŨmin, i_ΔŨmax, i_Ymin, i_Ymax, i_x̂min, i_x̂max, args...
) where {NT<:Real}
    i_b = [i_Umin; i_Umax; i_ΔŨmin; i_ΔŨmax]
    i_g = [i_Ymin; i_Ymax; i_x̂min; i_x̂max]
    if isempty(args)
        A = zeros(NT, length(i_b), 0)
    else
        A_Umin, A_Umax, A_ΔŨmin, A_ΔŨmax, _ , _ , _ , _ = args
        A = [A_Umin; A_Umax; A_ΔŨmin; A_ΔŨmax]
    end
    return i_b, i_g, A
end

"Validate predictive controller weight and horizon specified values."
function validate_weights(model, Hp, Hc, M_Hp, N_Hc, L_Hp, C, E=nothing)
    nu, ny = model.nu, model.ny
    nM, nN, nL = ny*Hp, nu*Hc, nu*Hp
    Hp < 1  && throw(ArgumentError("Prediction horizon Hp should be ≥ 1"))
    Hc < 1  && throw(ArgumentError("Control horizon Hc should be ≥ 1"))
    Hc > Hp && throw(ArgumentError("Control horizon Hc should be ≤ prediction horizon Hp"))
    size(M_Hp) ≠ (nM,nM) && throw(ArgumentError("M_Hp size $(size(M_Hp)) ≠ (ny*Hp, ny*Hp) ($nM,$nM)"))
    size(N_Hc) ≠ (nN,nN) && throw(ArgumentError("N_Hc size $(size(N_Hc)) ≠ (nu*Hc, nu*Hc) ($nN,$nN)"))
    size(L_Hp) ≠ (nL,nL) && throw(ArgumentError("L_Hp size $(size(L_Hp)) ≠ (nu*Hp, nu*Hp) ($nL,$nL)"))
    (!isdiag(M_Hp) || any(diag(M_Hp).<0)) && throw(ArgumentError("M_Hp should be a positive semidefinite diagonal matrix"))
    (!isdiag(N_Hc) || any(diag(N_Hc).<0)) && throw(ArgumentError("N_Hc should be a positive semidefinite diagonal matrix"))
    (!isdiag(L_Hp) || any(diag(L_Hp).<0)) && throw(ArgumentError("L_Hp should be a positive semidefinite diagonal matrix"))
    size(C) ≠ ()    && throw(ArgumentError("Cwt should be a real scalar"))
    C < 0     && throw(ArgumentError("Cwt weight should be ≥ 0"))
    !isnothing(E) && size(E) ≠ () && throw(ArgumentError("Ewt should be a real scalar"))
end