# developed with Julia 1.1.1
#
# tests for EMSx package

using EMSx, CSV, Test
using StoOpt

current_directory = @__DIR__

try mkdir(current_directory*"/tmp")
catch error
	rm(current_directory*"/tmp", recursive=true)
	mkdir(current_directory*"/tmp")
end

@testset "EMS simulator's body" begin
    
	site = load_sites(current_directory*"/data/metadata.csv")[1]
	model = DummyModel()
	paths = Paths("", current_directory*"/data", current_directory*"/tmp/test.jld")
	period = Period("1", CSV.read(current_directory*"/data/1.csv"), site, Simulation[])
	scenario = Scenario(site.id, period.id, site.batteries[1], period.data, model, paths)

	StoOpt.compute_control(m::DummyModel, cost::Function, dynamics::Function, 
		t::Int64, state::Array{Float64,1}, value_functions::Nothing) = [0.0]
	EMSx.cost(m::DummyModel, time::Int64, state::Array{Float64,1}, control::Array{Float64,1},
	noise::Array{Float64,1}) = 0.0
	EMSx.dynamics(m::AbstractModel, time::Int64, state::Array{Float64,1}, 
		control::Array{Float64,1}, noise::Array{Float64,1}) = [0.0]

	@test EMSx.simulate_scenario(scenario) == Simulation(EMSx.Result(zeros(10), zeros(10)), 
		EMSx.Id(scenario))
	@test EMSx.simulate_period!(period, model, paths) == nothing
	@test simulate_site(site, model, paths) == nothing

end

rm(current_directory*"/tmp", recursive=true)