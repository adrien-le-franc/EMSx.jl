# developed with Julia 1.0.3
#
# functions to simulate micro grid control


function simulate_site(site::Site, args::Dict{String,Any})

	test_data = load_data(site.id, args["test"])
	periods = unique(test_data[:period_id])

	for period_id in periods

		test_data_period = test_data[test_data.period_id .== period_id, :]
		period = Period(string(period_id), test_data_period)
		simulate_period(period, site, args)

	end

	return nothing

end

function simulate_period(period::Period, site::Site, args::Dict{String,Any})

	for battery in site.batteries

		scenario = Scenario(site.id, period.id, battery, args["method"])
		simulate_scenario(scenario, period)

	end

	return nothing

end

function simulate_scenario(scenario::Scenario, period::Period)



end
