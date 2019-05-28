# developed with Julia 1.1.1
#
# functions to simulate EMS


function simulate_site(site::Site, model::AbstractModel, paths::Paths)

	test_data = load_data(site.id, paths.test_data)
	train_data = load_data(site.id, paths.train_data)


	#load_train_data!(site, model, paths)

	periods = unique(test_data[:period_id])
	simulations = Simulation[]

	@showprogress for period_id in periods

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

		update_model!(model, battery, period.data)
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
		return nothing
	else
		return compute_value_functions(model, cost, dynamics)
	end

end

function online_step(scenario::Scenario, value_functions::Union{ValueFunctions,Nothing}) 


	state = initiate_state(scenario.model)
	horizon = size(scenario.data, 1)
	id = Id(scenario)
	simulation = Simulation(Result(zeros(horizon), zeros(horizon)), id)

	for t in 1:horizon

		control = compute_control(scenario.model, cost, dynamics, t, state, value_functions)

		# gestion de MPC -> forecasts vs value functions

		load = scenario.data[:actual_consumption][t]
		pv = scenario.data[:actual_pv][t]
		noise = [load-pv]

		stage_cost = cost(scenario.model, t, state, control, noise)
		state = dynamics(scenario.model, t, state, control, noise)

		simulation.result.cost[t] = stage_cost
		simulation.result.soc[t] = state_of_charge(scenario.model, state)

	end

	return simulation

end