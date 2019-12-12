# developed with Julia 1.1.1
#
# tests for EMSx package

using EMSx
using CSV
using Distributed
using Test

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

	if length(Sys.cpu_info()) > 1

		addprocs(1)
		@everywhere using EMSx

		@test EMSx.simulate_sites_parallel(controller, 
			current_directory*"/tmp/test", 
			current_directory*"/data/edf_prices.csv",
			current_directory*"/data/metadata.csv",
			current_directory*"/data") == nothing

		for worker in workers()
			rmprocs(worker)
		end

	end

end

@testset "Data manipulation functions" begin

	@test EMSx.train_test_split(joinpath(current_directory, "data/raw"), 
		joinpath(current_directory, "data/raw/test_periods.csv")) == nothing

end

rm(current_directory*"/tmp", recursive=true)
rm(current_directory*"/data/raw/test", recursive=true)
rm(current_directory*"/data/raw/train", recursive=true)