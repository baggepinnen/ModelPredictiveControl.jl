Ts = 4.0
sys = [ tf(1.90,[18.0,1])   tf(1.90,[18.0,1])   tf(1.90,[18.0,1]);
        tf(-0.74,[8.0,1])   tf(0.74,[8.0,1])    tf(-0.74,[8.0,1])   ] 

@testset "SteadyKalmanFilter construction" begin
    linmodel1 = LinModel(sys,Ts,i_u=[1,2])
    skalmanfilter1 = SteadyKalmanFilter(linmodel1)
    @test skalmanfilter1.nym == 2
    @test skalmanfilter1.nyu == 0
    @test skalmanfilter1.nxs == 2
    @test skalmanfilter1.nx̂ == 4
    @test skalmanfilter1.nint_ym == [1, 1]

    linmodel2 = LinModel(sys,Ts,i_d=[3])
    skalmanfilter2 = SteadyKalmanFilter(linmodel2, i_ym=[2])
    @test skalmanfilter2.nym == 1
    @test skalmanfilter2.nyu == 1
    @test skalmanfilter2.nxs == 1
    @test skalmanfilter2.nx̂ == 5
    @test skalmanfilter2.nint_ym == [1]

    skalmanfilter3 = SteadyKalmanFilter(linmodel1, nint_ym=0)
    @test skalmanfilter3.nxs == 0
    @test skalmanfilter3.nx̂ == 2
    @test skalmanfilter3.nint_ym == [0, 0]

    skalmanfilter4 = SteadyKalmanFilter(linmodel1, nint_ym=[2,2])
    @test skalmanfilter4.nxs == 4
    @test skalmanfilter4.nx̂ == 6

    skalmanfilter5 = SteadyKalmanFilter(linmodel2, σQ=[1,2,3,4], σQint_ym=[5, 6],  σR=[7, 8])
    @test skalmanfilter5.Q̂ ≈ Hermitian(diagm(Float64[1, 4, 9 ,16, 25, 36]))
    @test skalmanfilter5.R̂ ≈ Hermitian(diagm(Float64[49, 64]))

    linmodel3 = LinModel(append(tf(1,[1, 0]),tf(1,[10, 1]),tf(1,[-1, 1])), 0.1)
    skalmanfilter6 = SteadyKalmanFilter(linmodel3)
    @test skalmanfilter6.nxs == 2
    @test skalmanfilter6.nx̂ == 5
    @test skalmanfilter6.nint_ym == [0, 1, 1]

    skalmanfilter7 = SteadyKalmanFilter(linmodel1, nint_u=[1,1])
    @test skalmanfilter7.nxs == 2
    @test skalmanfilter7.nx̂  == 4
    @test skalmanfilter7.nint_u  == [1, 1]
    @test skalmanfilter7.nint_ym == [0, 0]

    linmodel2 = LinModel{Float32}(0.5*ones(1,1), ones(1,1), ones(1,1), zeros(1,0), zeros(1,0), 1.0)
    skalmanfilter8 = SteadyKalmanFilter(linmodel2)
    @test isa(skalmanfilter8, SteadyKalmanFilter{Float32})

    skalmanfilter9 = SteadyKalmanFilter(linmodel1, 1:2, 0, [1, 1], I(4), I(2))
    @test skalmanfilter9.Q̂ ≈ I(4)
    @test skalmanfilter9.R̂ ≈ I(2)

    @test_throws ErrorException SteadyKalmanFilter(linmodel1, nint_ym=[1,1,1])
    @test_throws ErrorException SteadyKalmanFilter(linmodel1, nint_ym=[-1,0])
    @test_throws ErrorException SteadyKalmanFilter(linmodel1, nint_ym=0, σQ=[1])
    @test_throws ErrorException SteadyKalmanFilter(linmodel1, nint_ym=0, σR=[1,1,1])
    @test_throws ErrorException SteadyKalmanFilter(linmodel3, nint_ym=[1, 0, 0])
    model_unobs = LinModel([1 0;0 1.5], [1;0][:,:], [1 0], zeros(2,0), zeros(1,0), 1.0)
    @test_throws ErrorException SteadyKalmanFilter(model_unobs, nint_ym=[1])
    @test_throws ErrorException SteadyKalmanFilter(LinModel(tf(1, [1,0]), 1), nint_ym=[1])
    @test_throws ErrorException SteadyKalmanFilter(linmodel1, nint_u=[1,1], nint_ym=[1,1])
end

@testset "SteadyKalmanFilter estimator methods" begin
    linmodel1 = setop!(LinModel(sys,Ts,i_u=[1,2]), uop=[10,50], yop=[50,30])
    skalmanfilter1 = SteadyKalmanFilter(linmodel1, nint_ym=[1, 1])
    @test updatestate!(skalmanfilter1, [10, 50], [50, 30]) ≈ zeros(4)
    @test updatestate!(skalmanfilter1, [10, 50], [50, 30], Float64[]) ≈ zeros(4)
    @test skalmanfilter1.x̂ ≈ zeros(4)
    @test evaloutput(skalmanfilter1) ≈ skalmanfilter1() ≈ [50, 30]
    @test evaloutput(skalmanfilter1, Float64[]) ≈ skalmanfilter1(Float64[]) ≈ [50, 30]
    @test initstate!(skalmanfilter1, [10, 50], [50, 30+1]) ≈ [zeros(3); [1]]
    linmodel2 = LinModel(append(tf(1, [1, 0]), tf(2, [10, 1])), 1.0)
    skalmanfilter2 = SteadyKalmanFilter(linmodel2, nint_u=[1, 1])
    x = initstate!(skalmanfilter2, [10, 3], [0.5, 6+0.1])
    @test evaloutput(skalmanfilter2) ≈ [0.5, 6+0.1]
    @test updatestate!(skalmanfilter2, [0, 3], [0.5, 6+0.1]) ≈ x
    setstate!(skalmanfilter1, [1,2,3,4])
    @test skalmanfilter1.x̂ ≈ [1,2,3,4]
    for i in 1:100
        updatestate!(skalmanfilter1, [11, 52], [50, 30])
    end
    @test skalmanfilter1() ≈ [50, 30] atol=1e-3
    for i in 1:100
        updatestate!(skalmanfilter1, [10, 50], [51, 32])
    end
    @test skalmanfilter1() ≈ [51, 32] atol=1e-3
    skalmanfilter2 = SteadyKalmanFilter(linmodel1, nint_u=[1, 1])
    for i in 1:100
        updatestate!(skalmanfilter2, [11, 52], [50, 30])
    end
    @test skalmanfilter2() ≈ [50, 30] atol=1e-3
    for i in 1:100
        updatestate!(skalmanfilter2, [10, 50], [51, 32])
    end
    @test skalmanfilter2() ≈ [51, 32] atol=1e-3
    @test_throws ArgumentError updatestate!(skalmanfilter1, [10, 50])
end   
    
@testset "KalmanFilter construction" begin
    linmodel1 = setop!(LinModel(sys,Ts,i_u=[1,2]), uop=[10,50], yop=[50,30])
    kalmanfilter1 = KalmanFilter(linmodel1)
    @test kalmanfilter1.nym == 2
    @test kalmanfilter1.nyu == 0
    @test kalmanfilter1.nxs == 2
    @test kalmanfilter1.nx̂ == 4
    @test kalmanfilter1.nint_ym == [1, 1]

    linmodel2 = LinModel(sys,Ts,i_d=[3])
    kalmanfilter2 = KalmanFilter(linmodel2, i_ym=[2])
    @test kalmanfilter2.nym == 1
    @test kalmanfilter2.nyu == 1
    @test kalmanfilter2.nxs == 1
    @test kalmanfilter2.nx̂ == 5

    kalmanfilter3 = KalmanFilter(linmodel1, nint_ym=0)
    @test kalmanfilter3.nxs == 0
    @test kalmanfilter3.nx̂ == 2

    kalmanfilter4 = KalmanFilter(linmodel1, nint_ym=[2,2])
    @test kalmanfilter4.nxs == 4
    @test kalmanfilter4.nx̂ == 6

    kalmanfilter5 = KalmanFilter(linmodel2, σQ=[1,2,3,4], σQint_ym=[5, 6],  σR=[7, 8])
    @test kalmanfilter5.Q̂ ≈ Hermitian(diagm(Float64[1, 4, 9 ,16, 25, 36]))
    @test kalmanfilter5.R̂ ≈ Hermitian(diagm(Float64[49, 64]))

    kalmanfilter6 = KalmanFilter(linmodel2, σP0=[1,2,3,4], σP0int_ym=[5,6])
    @test kalmanfilter6.P̂0 ≈ Hermitian(diagm(Float64[1, 4, 9 ,16, 25, 36]))
    @test kalmanfilter6.P̂  ≈ Hermitian(diagm(Float64[1, 4, 9 ,16, 25, 36]))
    @test kalmanfilter6.P̂0 !== kalmanfilter6.P̂

    kalmanfilter7 = KalmanFilter(linmodel1, nint_u=[1,1])
    @test kalmanfilter7.nxs == 2
    @test kalmanfilter7.nx̂  == 4
    @test kalmanfilter7.nint_u  == [1, 1]
    @test kalmanfilter7.nint_ym == [0, 0]

    kalmanfilter8 = KalmanFilter(linmodel1, 1:2, 0, [1, 1], I(4), I(4), I(2))
    @test kalmanfilter8.P̂0 ≈ I(4)
    @test kalmanfilter8.Q̂ ≈ I(4)
    @test kalmanfilter8.R̂ ≈ I(2)

    linmodel2 = LinModel{Float32}(0.5*ones(1,1), ones(1,1), ones(1,1), zeros(1,0), zeros(1,0), 1.0)
    kalmanfilter8 = KalmanFilter(linmodel2)
    @test isa(kalmanfilter8, KalmanFilter{Float32})

    @test_throws ErrorException KalmanFilter(linmodel1, nint_ym=0, σP0=[1])
end

@testset "KalmanFilter estimator methods" begin
    linmodel1 = setop!(LinModel(sys,Ts,i_u=[1,2]), uop=[10,50], yop=[50,30])
    lo1 = KalmanFilter(linmodel1)
    @test updatestate!(lo1, [10, 50], [50, 30]) ≈ zeros(4)
    @test updatestate!(lo1, [10, 50], [50, 30], Float64[]) ≈ zeros(4)
    @test lo1.x̂ ≈ zeros(4)
    @test evaloutput(lo1) ≈ lo1() ≈ [50, 30]
    @test evaloutput(lo1, Float64[]) ≈ lo1(Float64[]) ≈ [50, 30]
    @test initstate!(lo1, [10, 50], [50, 30+1]) ≈ [zeros(3); [1]]
    setstate!(lo1, [1,2,3,4])
    @test lo1.x̂ ≈ [1,2,3,4]
    for i in 1:1000
        updatestate!(lo1, [11, 52], [50, 30])
    end
    @test lo1() ≈ [50, 30] atol=1e-3
    for i in 1:100
        updatestate!(lo1, [10, 50], [51, 32])
    end
    @test lo1() ≈ [51, 32] atol=1e-3
    kalmanfilter2 = KalmanFilter(linmodel1, nint_u=[1, 1])
    for i in 1:100
        updatestate!(kalmanfilter2, [11, 52], [50, 30])
    end
    @test kalmanfilter2() ≈ [50, 30] atol=1e-3
    for i in 1:100
        updatestate!(kalmanfilter2, [10, 50], [51, 32])
    end
    @test kalmanfilter2() ≈ [51, 32] atol=1e-3
    @test_throws ArgumentError updatestate!(lo1, [10, 50])
end   

@testset "Luenberger construction" begin
    linmodel1 = LinModel(sys,Ts,i_u=[1,2])
    lo1 = Luenberger(linmodel1)
    @test lo1.nym == 2
    @test lo1.nyu == 0
    @test lo1.nxs == 2
    @test lo1.nx̂ == 4

    linmodel2 = LinModel(sys,Ts,i_d=[3])
    lo2 = Luenberger(linmodel2, i_ym=[2])
    @test lo2.nym == 1
    @test lo2.nyu == 1
    @test lo2.nxs == 1
    @test lo2.nx̂ == 5

    lo3 = Luenberger(linmodel1, nint_ym=0)
    @test lo3.nxs == 0
    @test lo3.nx̂ == 2

    lo4 = Luenberger(linmodel1, nint_ym=[2,2])
    @test lo4.nxs == 4
    @test lo4.nx̂ == 6

    lo5 = Luenberger(linmodel1, nint_u=[1,1])
    @test lo5.nxs == 2
    @test lo5.nx̂  == 4
    @test lo5.nint_u  == [1, 1]
    @test lo5.nint_ym == [0, 0]

    linmodel2 = LinModel{Float32}(0.5*ones(1,1), ones(1,1), ones(1,1), zeros(1,0), zeros(1,0), 1.0)
    lo6 = Luenberger(linmodel2)
    @test isa(lo6, Luenberger{Float32})

    @test_throws ErrorException Luenberger(linmodel1, nint_ym=[1,1,1])
    @test_throws ErrorException Luenberger(linmodel1, nint_ym=[-1,0])
    @test_throws ErrorException Luenberger(linmodel1, p̂=[0.5])
    @test_throws ErrorException Luenberger(linmodel1, p̂=fill(1.5, lo1.nx̂))
    @test_throws ErrorException Luenberger(LinModel(tf(1,[1, 0]),0.1), p̂=[0.5,0.6])
end
    
@testset "Luenberger estimator methods" begin
    linmodel1 = setop!(LinModel(sys,Ts,i_u=[1,2]), uop=[10,50], yop=[50,30])
    ukf1 = Luenberger(linmodel1, nint_ym=[1, 1])
    @test updatestate!(ukf1, [10, 50], [50, 30]) ≈ zeros(4)
    @test updatestate!(ukf1, [10, 50], [50, 30], Float64[]) ≈ zeros(4)
    @test ukf1.x̂ ≈ zeros(4)
    @test evaloutput(ukf1) ≈ ukf1() ≈ [50, 30]
    @test evaloutput(ukf1, Float64[]) ≈ ukf1(Float64[]) ≈ [50, 30]
    @test initstate!(ukf1, [10, 50], [50, 30+1]) ≈ [zeros(3); [1]]
    setstate!(ukf1, [1,2,3,4])
    @test ukf1.x̂ ≈ [1,2,3,4]
    for i in 1:100
        updatestate!(ukf1, [11, 52], [50, 30])
    end
    @test ukf1() ≈ [50, 30] atol=1e-3
    for i in 1:100
        updatestate!(ukf1, [10, 50], [51, 32])
    end
    @test ukf1() ≈ [51, 32] atol=1e-3
    lo2 = Luenberger(linmodel1, nint_u=[1, 1])
    for i in 1:100
        updatestate!(lo2, [11, 52], [50, 30])
    end
    @test lo2() ≈ [50, 30] atol=1e-3
    for i in 1:100
        updatestate!(lo2, [10, 50], [51, 32])
    end
    @test lo2() ≈ [51, 32] atol=1e-3
end

@testset "InternalModel construction" begin
    linmodel1 = LinModel(sys,Ts,i_u=[1,2])
    internalmodel1 = InternalModel(linmodel1)
    @test internalmodel1.nym == 2
    @test internalmodel1.nyu == 0
    @test internalmodel1.nxs == 2
    @test internalmodel1.nx̂ == 2

    linmodel2 = LinModel(sys,Ts,i_d=[3])
    internalmodel2 = InternalModel(linmodel2,i_ym=[2])
    @test internalmodel2.nym == 1
    @test internalmodel2.nyu == 1
    @test internalmodel2.nxs == 1
    @test internalmodel2.nx̂ == 4

    f(x,u,d) = linmodel2.A*x + linmodel2.Bu*u + linmodel2.Bd*d
    h(x,d)   = linmodel2.C*x + linmodel2.Dd*d
    nonlinmodel = NonLinModel(f, h, Ts, 2, 4, 2, 2)
    internalmodel3 = InternalModel(nonlinmodel)
    @test internalmodel3.nym == 2
    @test internalmodel3.nyu == 0
    @test internalmodel3.nxs == 2
    @test internalmodel3.nx̂  == 4

    stoch_ym_tf = tf([1, -0.3],[1, -0.5],Ts)*tf([1,0],[1,-1],Ts).*I(2)
    internalmodel4 = InternalModel(linmodel2,stoch_ym=stoch_ym_tf)
    @test internalmodel4.nym == 2
    @test internalmodel4.nyu == 0
    @test internalmodel4.nxs == 4
    @test internalmodel4.nx̂ == 4

    stoch_ym_ss=minreal(ss(stoch_ym_tf))
    internalmodel5 = InternalModel(linmodel2,stoch_ym=stoch_ym_ss)
    @test internalmodel5.nym == 2
    @test internalmodel5.nyu == 0
    @test internalmodel5.nxs == 4
    @test internalmodel5.nx̂ == 4
    @test internalmodel5.As ≈ stoch_ym_ss.A
    @test internalmodel5.Bs ≈ stoch_ym_ss.B
    @test internalmodel5.Cs ≈ stoch_ym_ss.C
    @test internalmodel5.Ds ≈ stoch_ym_ss.D

    stoch_ym_resample = c2d(d2c(ss(1,1,1,1,linmodel2.Ts), :tustin), 2linmodel2.Ts, :tustin)
    internalmodel6 = InternalModel(linmodel2, i_ym=[2], stoch_ym=stoch_ym_resample)
    @test internalmodel6.As ≈ internalmodel2.As
    @test internalmodel6.Bs ≈ internalmodel2.Bs
    @test internalmodel6.Cs ≈ internalmodel2.Cs
    @test internalmodel6.Ds ≈ internalmodel2.Ds

    stoch_ym_cont = ss(zeros(2,2), I(2), I(2), zeros(2,2))
    stoch_ym_disc = c2d(stoch_ym_cont, linmodel2.Ts, :tustin)
    internalmodel7 = InternalModel(linmodel2, stoch_ym=stoch_ym_cont)
    @test internalmodel7.As ≈ stoch_ym_disc.A
    @test internalmodel7.Bs ≈ stoch_ym_disc.B
    @test internalmodel7.Cs ≈ stoch_ym_disc.C
    @test internalmodel7.Ds ≈ stoch_ym_disc.D

    linmodel3 = LinModel{Float32}(0.5*ones(1,1), ones(1,1), ones(1,1), zeros(1,0), zeros(1,0), 1.0)
    internalmodel8 = InternalModel(linmodel3)
    @test isa(internalmodel8, InternalModel{Float32})

    unstablemodel = LinModel(ss(diagm([0.5, -0.5, 1.5]), ones(3,1), I, 0, 1))
    @test_throws ErrorException InternalModel(unstablemodel)
    @test_throws ErrorException InternalModel(linmodel1, i_ym=[1,4])
    @test_throws ErrorException InternalModel(linmodel1, i_ym=[2,2])
    @test_throws ErrorException InternalModel(linmodel1, stoch_ym=ss(1,1,1,1,Ts))
    @test_throws ErrorException InternalModel(linmodel1, stoch_ym=ss(1,1,1,0,Ts).*I(2))
end    
    
@testset "InternalModel estimator methods" begin
    linmodel1 = setop!(LinModel(sys,Ts,i_u=[1,2]) , uop=[10,50], yop=[50,30])
    internalmodel1 = InternalModel(linmodel1)
    @test updatestate!(internalmodel1, [10, 50], [50, 30] .+ 1) ≈ zeros(2)
    @test updatestate!(internalmodel1, [10, 50], [50, 30] .+ 1, Float64[]) ≈ zeros(2)
    @test internalmodel1.x̂d ≈ internalmodel1.x̂ ≈ zeros(2)
    @test internalmodel1.x̂s ≈ ones(2)
    @test ModelPredictiveControl.evalŷ(internalmodel1, [51,31], Float64[]) ≈ [51,31]
    @test initstate!(internalmodel1, [10, 50], [50, 30]) ≈ zeros(2)
    linmodel2 = LinModel(append(tf(3, [5, 1]), tf(2, [10, 1])), 1.0)
    stoch_ym = append(tf([2.5, 1],[1.2, 1, 0]),tf([1.5, 1], [1.3, 1, 0]))
    estim = InternalModel(linmodel2; stoch_ym)
    initstate!(estim, [1, 2], [3+0.1, 4+0.5])
    @test estim.x̂d ≈ estim.Â*estim.x̂d + estim.B̂u*[1, 2]
    ŷs = [3+0.1, 4+0.5] - estim()
    @test estim.x̂s ≈ estim.Âs*estim.x̂s + estim.B̂s*ŷs
    @test internalmodel1.x̂s ≈ zeros(2)
    setstate!(internalmodel1, [1,2])
    @test internalmodel1.x̂ ≈ [1,2]
end
 
@testset "UnscentedKalmanFilter construction" begin
    linmodel1 = LinModel(sys,Ts,i_d=[3])
    f(x,u,d) = linmodel1.A*x + linmodel1.Bu*u + linmodel1.Bd*d
    h(x,d)   = linmodel1.C*x + linmodel1.Du*d
    nonlinmodel = NonLinModel(f, h, Ts, 2, 4, 2, 1)

    ukf1 = UnscentedKalmanFilter(linmodel1)
    @test ukf1.nym == 2
    @test ukf1.nyu == 0
    @test ukf1.nxs == 2
    @test ukf1.nx̂ == 6

    ukf2 = UnscentedKalmanFilter(nonlinmodel)
    @test ukf2.nym == 2
    @test ukf2.nyu == 0
    @test ukf2.nxs == 2
    @test ukf2.nx̂ == 6

    ukf3 = UnscentedKalmanFilter(nonlinmodel, i_ym=[2])
    @test ukf3.nym == 1
    @test ukf3.nyu == 1
    @test ukf3.nxs == 1
    @test ukf3.nx̂ == 5

    ukf4 = UnscentedKalmanFilter(nonlinmodel, σQ=[1,2,3,4], σQint_ym=[5, 6],  σR=[7, 8])
    @test ukf4.Q̂ ≈ Hermitian(diagm(Float64[1, 4, 9 ,16, 25, 36]))
    @test ukf4.R̂ ≈ Hermitian(diagm(Float64[49, 64]))
    
    ukf5 = UnscentedKalmanFilter(nonlinmodel, nint_ym=[2,2])
    @test ukf5.nxs == 4
    @test ukf5.nx̂ == 8

    ukf6 = UnscentedKalmanFilter(nonlinmodel, σP0=[1,2,3,4], σP0int_ym=[5,6])
    @test ukf6.P̂0 ≈ Hermitian(diagm(Float64[1, 4, 9 ,16, 25, 36]))
    @test ukf6.P̂  ≈ Hermitian(diagm(Float64[1, 4, 9 ,16, 25, 36]))
    @test ukf6.P̂0 !== ukf6.P̂

    ukf7 = UnscentedKalmanFilter(nonlinmodel, α=0.1, β=4, κ=0.2)
    @test ukf7.γ ≈ 0.1*√(ukf7.nx̂+0.2)
    @test ukf7.Ŝ[1, 1] ≈ 2 - 0.1^2 + 4 - ukf7.nx̂/(ukf7.γ^2)

    ukf8 = UnscentedKalmanFilter(nonlinmodel, nint_u=[1, 1], nint_ym=[0, 0])
    @test ukf8.nxs == 2
    @test ukf8.nx̂  == 6
    @test ukf8.nint_u  == [1, 1]
    @test ukf8.nint_ym == [0, 0]

    ukf9 = UnscentedKalmanFilter(nonlinmodel, 1:2, 0, [1, 1], I(6), I(6), I(2), 0.1, 2, 0)
    @test ukf9.P̂0 ≈ I(6)
    @test ukf9.Q̂ ≈ I(6)
    @test ukf9.R̂ ≈ I(2)

    linmodel2 = LinModel{Float32}(0.5*ones(1,1), ones(1,1), ones(1,1), zeros(1,0), zeros(1,0), 1.0)
    ukf9 = UnscentedKalmanFilter(linmodel2)
    @test isa(ukf9, UnscentedKalmanFilter{Float32})
end

@testset "UnscentedKalmanFilter estimator methods" begin
    linmodel1 = LinModel(sys,Ts,i_u=[1,2])
    f(x,u,_) = linmodel1.A*x + linmodel1.Bu*u
    h(x,_)   = linmodel1.C*x
    nonlinmodel = setop!(NonLinModel(f, h, Ts, 2, 2, 2), uop=[10,50], yop=[50,30])
    ukf1 = UnscentedKalmanFilter(nonlinmodel)
    @test updatestate!(ukf1, [10, 50], [50, 30]) ≈ zeros(4) atol=1e-9
    @test updatestate!(ukf1, [10, 50], [50, 30], Float64[]) ≈ zeros(4) atol=1e-9
    @test ukf1.x̂ ≈ zeros(4) atol=1e-9
    @test evaloutput(ukf1) ≈ ukf1() ≈ [50, 30]
    @test evaloutput(ukf1, Float64[]) ≈ ukf1(Float64[]) ≈ [50, 30]
    @test initstate!(ukf1, [10, 50], [50, 30+1]) ≈ zeros(4) atol=1e-9
    setstate!(ukf1, [1,2,3,4])
    @test ukf1.x̂ ≈ [1,2,3,4]
    for i in 1:100
        updatestate!(ukf1, [11, 52], [50, 30])
    end
    @test ukf1() ≈ [50, 30] atol=1e-3
    for i in 1:100
        updatestate!(ukf1, [10, 50], [51, 32])
    end
    @test ukf1() ≈ [51, 32] atol=1e-3
    ukf2 = UnscentedKalmanFilter(linmodel1, nint_u=[1, 1], nint_ym=[0, 0])
    for i in 1:100
        updatestate!(ukf2, [11, 52], [50, 30])
    end
    @test ukf2() ≈ [50, 30] atol=1e-3
    for i in 1:100
        updatestate!(ukf2, [10, 50], [51, 32])
    end
    @test ukf2() ≈ [51, 32] atol=1e-3
end

@testset "ExtendedKalmanFilter construction" begin
    linmodel1 = LinModel(sys,Ts,i_d=[3])
    f(x,u,d) = linmodel1.A*x + linmodel1.Bu*u + linmodel1.Bd*d
    h(x,d)   = linmodel1.C*x + linmodel1.Du*d
    nonlinmodel = NonLinModel(f, h, Ts, 2, 4, 2, 1)

    ekf1 = ExtendedKalmanFilter(linmodel1)
    @test ekf1.nym == 2
    @test ekf1.nyu == 0
    @test ekf1.nxs == 2
    @test ekf1.nx̂ == 6

    ekf2 = ExtendedKalmanFilter(nonlinmodel)
    @test ekf2.nym == 2
    @test ekf2.nyu == 0
    @test ekf2.nxs == 2
    @test ekf2.nx̂ == 6

    ekf3 = ExtendedKalmanFilter(nonlinmodel, i_ym=[2])
    @test ekf3.nym == 1
    @test ekf3.nyu == 1
    @test ekf3.nxs == 1
    @test ekf3.nx̂ == 5

    ekf4 = ExtendedKalmanFilter(nonlinmodel, σQ=[1,2,3,4], σQint_ym=[5, 6],  σR=[7, 8])
    @test ekf4.Q̂ ≈ Hermitian(diagm(Float64[1, 4, 9 ,16, 25, 36]))
    @test ekf4.R̂ ≈ Hermitian(diagm(Float64[49, 64]))
    
    ekf5 = ExtendedKalmanFilter(nonlinmodel, nint_ym=[2,2])
    @test ekf5.nxs == 4
    @test ekf5.nx̂ == 8

    ekf6 = ExtendedKalmanFilter(nonlinmodel, σP0=[1,2,3,4], σP0int_ym=[5,6])
    @test ekf6.P̂0 ≈ Hermitian(diagm(Float64[1, 4, 9 ,16, 25, 36]))
    @test ekf6.P̂  ≈ Hermitian(diagm(Float64[1, 4, 9 ,16, 25, 36]))
    @test ekf6.P̂0 !== ekf6.P̂

    ekf7 = ExtendedKalmanFilter(nonlinmodel, nint_u=[1,1], nint_ym=[0,0])
    @test ekf7.nxs == 2
    @test ekf7.nx̂  == 6
    @test ekf7.nint_u  == [1, 1]
    @test ekf7.nint_ym == [0, 0]

    ekf8 = ExtendedKalmanFilter(nonlinmodel, 1:2, 0, [1, 1], I(6), I(6), I(2))
    @test ekf8.P̂0 ≈ I(6)
    @test ekf8.Q̂ ≈ I(6)
    @test ekf8.R̂ ≈ I(2)

    linmodel2 = LinModel{Float32}(0.5*ones(1,1), ones(1,1), ones(1,1), zeros(1,0), zeros(1,0), 1.0)
    ekf8 = ExtendedKalmanFilter(linmodel2)
    @test isa(ekf8, ExtendedKalmanFilter{Float32})
end

@testset "ExtendedKalmanFilter estimator methods" begin
    linmodel1 = LinModel(sys,Ts,i_u=[1,2])
    f(x,u,_) = linmodel1.A*x + linmodel1.Bu*u
    h(x,_)   = linmodel1.C*x
    nonlinmodel = setop!(NonLinModel(f, h, Ts, 2, 2, 2), uop=[10,50], yop=[50,30])
    ekf1 = ExtendedKalmanFilter(nonlinmodel)
    @test updatestate!(ekf1, [10, 50], [50, 30]) ≈ zeros(4) atol=1e-9
    @test updatestate!(ekf1, [10, 50], [50, 30], Float64[]) ≈ zeros(4) atol=1e-9
    @test ekf1.x̂ ≈ zeros(4) atol=1e-9
    @test evaloutput(ekf1) ≈ ekf1() ≈ [50, 30]
    @test evaloutput(ekf1, Float64[]) ≈ ekf1(Float64[]) ≈ [50, 30]
    @test initstate!(ekf1, [10, 50], [50, 30+1]) ≈ zeros(4);
    setstate!(ekf1, [1,2,3,4])
    @test ekf1.x̂ ≈ [1,2,3,4]
    for i in 1:100
        updatestate!(ekf1, [11, 52], [50, 30])
    end
    @test ekf1() ≈ [50, 30] atol=1e-3
    for i in 1:100
        updatestate!(ekf1, [10, 50], [51, 32])
    end
    @test ekf1() ≈ [51, 32] atol=1e-3
    ekf2 = ExtendedKalmanFilter(linmodel1, nint_u=[1, 1], nint_ym=[0, 0])
    for i in 1:100
        updatestate!(ekf2, [11, 52], [50, 30])
    end
    @test ekf2() ≈ [50, 30] atol=1e-3
    for i in 1:100
        updatestate!(ekf2, [10, 50], [51, 32])
    end
    @test ekf2() ≈ [51, 32] atol=1e-3
end
