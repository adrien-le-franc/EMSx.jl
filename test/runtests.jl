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
	price = EMSx.load_prices(current_directory*"/data/edf_prices.csv")["edf_prices"]
	site = EMSx.load_sites(current_directory*"/data/metadata.csv", current_directory*"/data", 
		current_directory*"/tmp/test.jld")[1]
	period = EMSx.Period("1", CSV.read(site.path_to_data_csv), site, EMSx.Simulation[])
	
	net_demand = period.data[98, :actual_consumption] - period.data[98, :actual_pv]
	@test EMSx.apply_control(1, 672, price, period, 0., 0.) == (net_demand*price[1, :buy], 0.)
	simulation =  EMSx.simulate_scenario(controller, period, "edf_prices", price)
	@test simulation.result.soc == zeros(672)
	@test EMSx.simulate_period!(controller, period, Dict("edf_prices"=>price)) == nothing
	@test EMSx.simulate_site(controller, site, Dict("edf_prices"=>price)) == nothing
	@test EMSx.simulate_sites(controller, current_directory*"/tmp/test.jld", 
		current_directory*"/data/edf_prices.csv",
		current_directory*"/data/metadata.csv",
		current_directory*"/data") == nothing

end

rm(current_directory*"/tmp", recursive=true)