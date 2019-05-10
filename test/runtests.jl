# developed with Julia 1.0.3
#
# tests for EMSx package

using EMSx, CSV, Test
using StoOpt

current_directory = @__DIR__
struct DummyModel <: DynamicProgrammingModel end

@testset "EMS simulator's body" begin
    
	site = load_sites(current_directory*"/data/metadata.csv")[1]
	model = DummyModel()
	paths = Paths("", current_directory*"/data", "")
	period = Period("1", CSV.read(current_directory*"/data/1.csv"), site)
	scenario = Scenario(site.id, period.id, site.batteries[1], period.data, model, paths)

	@test simulate_scenario(scenario) == nothing
	@test simulate_period(period, model, paths) == nothing
	@test simulate_site(site, model, paths) == nothing

end