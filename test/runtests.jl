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

	@test simulate_scenario(scenario) == Simulation()
	@test simulate_period!(period, model, paths) == nothing
	@test simulate_site(site, model, paths) == nothing

end

rm(current_directory*"/tmp", recursive=true)