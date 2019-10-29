# developed with Julia 1.1.1
#
# tests for EMSx package

using EMSx, CSV, Test

current_directory = @__DIR__

try mkdir(current_directory*"/tmp")
catch error
	rm(current_directory*"/tmp", recursive=true)
	mkdir(current_directory*"/tmp")
end

@testset "EMS simulator's body" begin
	
	controller = EMSx.DummyController()
	price = EMSx.load_prices(current_directory*"/data/edf_prices.csv")[1]
	site = EMSx.load_sites(current_directory*"/data/metadata.csv", current_directory*"/data", 
		nothing, current_directory*"/tmp/test")[1]
	period = EMSx.Period("1", CSV.read(site.path_to_test_data_csv), site, EMSx.Simulation[])
	
	net_demand = period.data[98, :actual_consumption] - period.data[98, :actual_pv]
	@test EMSx.apply_control(1, 672, price, period, 0., 0.) == (net_demand*price.buy[1], 0.)
	simulation =  EMSx.simulate_scenario(controller, period, price)
	@test simulation.result.soc == zeros(672)
	@test EMSx.simulate_period!(controller, period, [price]) == nothing
	mkdir(current_directory*"/tmp/test")
	@test EMSx.simulate_site(controller, site, [price]) == nothing
	@test EMSx.simulate_sites(controller, 
		current_directory*"/tmp/test", 
		current_directory*"/data/edf_prices.csv",
		current_directory*"/data/metadata.csv",
		current_directory*"/data") == nothing

end

rm(current_directory*"/tmp", recursive=true)