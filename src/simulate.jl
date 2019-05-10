# developed with Julia 1.0.3
#
# functions to simulate EMS


function simulate_site(site::Site, model::AbstractModel, paths::Paths)

	test_data = load_data(site.id, paths.test_data)
	periods = unique(test_data[:period_id])

	for period_id in periods

		test_data_period = test_data[test_data.period_id .== period_id, :]
		period = Period(string(period_id), test_data_period, site)
		simulate_period(period, model, paths)

	end

	return nothing

end

function simulate_period(period::Period, model::AbstractModel, paths::Paths)

	for battery in period.site.batteries

		scenario = Scenario(period.site.id, period.id, battery, period.data, model, paths)
		simulate_scenario(scenario) 

	end

	return nothing

end

function simulate_scenario(scenario::Scenario)

	value_functions = offline_step(scenario)

	simulation = online_step(scenario, value_functions)

	return nothing

end

function offline_step(scenario::Scenario)

	return 0

end

function online_step(scenario::Scenario, value_functions)

	"""
	x = init_state()
	horizon = size(period.data, 1)

	simulation = 0 # save stuff ??

	for t in 1:horizon

		u = control()
		stage_cost = cost(t, x, u, w)
		x = dynamics(t, x, u, w)

	end

	return simulation
	"""

	return 0

end