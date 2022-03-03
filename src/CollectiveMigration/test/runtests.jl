using AnimalNavigation, Manifolds
using Test

@testset "AnimalNavigation.jl" begin
    # Testing resultant vector on unit circle
    same_angle = [π, π, π]
    opposite_angles = [π / 2, -π / 2]

    @test AnimalNavigation.circ_resultant(same_angle) == 1
    @test AnimalNavigation.circ_resultant(opposite_angles) < 1E-16
    # Testing circular mean
    circ = Manifolds.Circle(ℝ)
    angles = [π, -π / 2]
    weights = [1, 2]
    long_angles = [π, -π / 2, -π / 2]

    @test abs(mean(circ, same_angle) - same_angle[1]) < 1E-16
    @test abs(mean(circ, angles, weights) - mean(circ, long_angles)) < 1E-16


end
