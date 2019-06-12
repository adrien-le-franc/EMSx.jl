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
    
	
	
	model = EMSx.DummyModel(Dict(), Dict())
	site = load_sites(current_directory*"/data/metadata.csv")[1]
	paths = Paths("", current_directory*"/data", current_directory*"/tmp/test.jld")
	period = EMSx.Period("1", CSV.read(current_directory*"/data/1.csv"), site, EMSx.Simulation[])
	scenario = EMSx.Scenario(site.id, period.id, site.batteries[1], period.data, model, paths)

	EMSx.cost(m::AbstractModel, time::Int64, state::Array{Float64,1}, control::Array{Float64,1},
	noise::Array{Float64,1}) = 0.0
	EMSx.dynamics(m::AbstractModel, time::Int64, state::Array{Float64,1}, 
		control::Array{Float64,1}, noise::Array{Float64,1}) = [0.0]

	@test EMSx.simulate_scenario(scenario) == EMSx.Simulation(EMSx.Result(zeros(10), zeros(10)), 
		EMSx.Id(scenario))
	@test EMSx.simulate_period!(model, period, paths) == nothing
	@test simulate_site(model, site, paths) == nothing

end

rm(current_directory*"/tmp", recursive=true)