using Test
using VDPTag2
using POMDPs
using POMDPTools
using ParticleFilters
using Random
using MCTS
using LinearAlgebra

# Seed RNG for reproducibility
Random.seed!(1)
rng = MersenneTwister(31)

@testset "ToNextML + MCTS" begin
    pomdp = VDPTagPOMDP()
    gen = NextMLFirst(mdp(pomdp), rng)
    s = TagState(Vec2(1.0, 1.0), Vec2(-1.0, -1.0))

    struct DummyNode end
    MCTS.n_children(::DummyNode) = rand(1:10)

    a1 = next_action(gen, pomdp, s, DummyNode())
    a2 = next_action(gen, pomdp, initialstate(pomdp), DummyNode())

    @test a1 isa Float64
    @test a2 isa TagAction
    @test a2.look == false
    @test 0.0 <= a2.angle <= 2π
end

@testset "Barrier Stop Sanity" begin
    barriers = CardinalBarriers(0.2, 1.8)
    for a in range(0.0, stop=2π, length=100)
        s = TagState(Vec2(0,0), Vec2(1,1))
        delta = 1.0 * 0.5 * Vec2(cos(a), sin(a))  # speed * step_size
        moved = barrier_stop(barriers, s.agent, delta)
        @test norm(moved - s.agent) ≤ norm(delta) + 1e-8
    end
end

@testset "Simulation - Continuous" begin
    pomdp = VDPTagPOMDP()
    policy = ToNextML(pomdp)
    updater = BootstrapFilter(pomdp, 100)
    hist = simulate(HistoryRecorder(max_steps=10), pomdp, policy, updater)
    @test length(state_hist(hist)) > 1
end

@testset "Simulation - Discrete" begin
    dpomdp = AODiscreteVDPTagPOMDP()
    policy = RandomPolicy(dpomdp)
    hist = simulate(HistoryRecorder(max_steps=10), dpomdp, policy)
    @test length(state_hist(hist)) > 1
end

@testset "Barriers Block Movement" begin
    pomdp = VDPTagPOMDP(mdp=VDPTagMDP(barriers=CardinalBarriers(0.0, 100.0)))
    policy = ToNextML(pomdp)
    updater = BootstrapFilter(pomdp, 100)

    for quadrant in [Vec2(1,1), Vec2(-1,1), Vec2(1,-1), Vec2(-1,-1)]
        for _ in 1:10
            s0 = rand(rng, initialstate(pomdp))
            s0 = TagState(quadrant, s0.target)
            hist = simulate(HistoryRecorder(max_steps=5), pomdp, policy, updater, s0)
            for s in state_hist(hist)
                @test all(s.agent .* quadrant .>= 0.0)
            end
        end
    end
end

@testset "No Barriers - Can Cross Quadrants" begin
    pomdp = VDPTagPOMDP()
    policy = ToNextML(pomdp)
    updater = BootstrapFilter(pomdp, 100)

    for quadrant in [Vec2(1,1), Vec2(-1,1), Vec2(1,-1), Vec2(-1,-1)]
        crossed = 0
        for _ in 1:25
            s0 = rand(rng, initialstate(pomdp))
            s0 = TagState(quadrant, s0.target)
            hist = simulate(HistoryRecorder(max_steps=10), pomdp, policy, updater, s0)
            if any(s.agent .* quadrant .< 0.0 for s in state_hist(hist))
                crossed += 1
            end
        end
        @test crossed > 0  # should cross at least once
    end
end
