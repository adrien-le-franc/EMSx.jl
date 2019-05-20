# developed with Julia 1.0.3
#
# functions to simulate EMS


function simulate_site(site::Site, model::AbstractModel, paths::Paths)

	test_data = load_data(site.id, paths.test_data)
	periods = unique(test_data[:period_id])
	simulations = Simulation[]

	for period_id in periods

		test_data_period = test_data[test_data.period_id .== period_id, :]
		period = Period(string(period_id), test_data_period, site, Simulation[])
		simulate_period!(period, model, paths)
		append!(simulations, period.simulations)

	end

	save(paths.save, site.id, simulations)

	return nothing 

end

function simulate_period!(period::Period, model::AbstractModel, paths::Paths)

	for battery in period.site.batteries

		scenario = Scenario(period.site.id, period.id, battery, period.data, model, paths)
		simulation = simulate_scenario(scenario)
		push!(period.simulations, simulation)

	end

	return nothing

end

function simulate_scenario(scenario::Scenario)

	value_functions = offline_step(scenario)

	simulation = online_step(scenario, value_functions)

	return simulation

end







function offline_step(scenario::Scenario)

	model = scenario.model

	if ! (typeof(model) <: DynamicProgrammingModel)
		return ValueFunctions()
	else
		return compute_value_function(model) ## dans StoOpt.jl 
	end

end

function online_step(scenario::Scenario, value_functions::ValueFunctions) 


	simulation = Simulation()

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

	return simulation

end