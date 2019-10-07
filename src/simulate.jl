# developed with Julia 1.1.1
#
# functions to simulate EMS 


function simulate_sites(controller::AbstractController, 
	path_to_save_jld_file::String,
	path_to_price_folder::String, 
	path_to_metadata_csv_file::String, 
	path_to_test_data_folder::String)

	sites = load_sites(path_to_metadata_csv_file, path_to_test_data_folder, path_to_save_jld_file)
	prices = load_prices(path_to_price_folder)
	elapsed = 0.0

	for site in sites
		
		elapsed += @elapsed simulate_site(controller, site, prices) 

	end

	save_time(path_to_save_jld_file, elapsed)

	return nothing

end

function simulate_site(controller::AbstractController, site::Site, 
	prices::Array{Price})

	test_data = CSV.read(site.path_to_data_csv)
	periods = unique(test_data[:period_id])
	simulations = Simulation[]

	@showprogress for period_id in periods

		test_data_period = test_data[test_data.period_id .== period_id, :]
		period = Period(string(period_id), test_data_period, site, Simulation[])
		simulate_period!(controller, period, prices)
		append!(simulations, period.simulations)

	end

	save_simulations(site, simulations)

	return nothing 

end

function simulate_period!(controller::AbstractController, period::Period, prices::Array{Price})

	battery = period.site.battery

	for price in prices

		simulation = simulate_scenario(controller, period, price)
		push!(period.simulations, simulation)

	end

	return nothing

end

function simulate_scenario(controller::AbstractController, period::Period, price::Price) 

	horizon = size(period.data, 1) - 96 # test data: 24h of history lag + period 
	id = Id(period.site.id, period.id, price.name, string(typeof(controller)))
	state_of_charge = 0.
	result = Result(horizon)
	timer = zeros(horizon)

	for t in 1:horizon 

		information = Information(t, price, period, state_of_charge)
		timing = @elapsed control = compute_control(controller, information)

		stage_cost, state_of_charge = apply_control(t, horizon, price, period, state_of_charge, control)
		result.cost[t] = stage_cost
		result.soc[t] = state_of_charge
		timer[t] = timing

	end

	return Simulation(result, timer, id)

end

function apply_control(t::Int64, horizon::Int64, price::Price, period::Period, soc::Float64, 
	control::Float64)
	"""
	note on the load and pv values:
	at the end of the period values at t+1 cannot be accessed, replaced by values at t=horizon
	with a minor impact since the optimal control is to empty the battery anyway
	"""
	
	load = period.data[:actual_consumption][min(t+96+1, horizon+96)]
	pv = period.data[:actual_pv][min(t+96+1, horizon+96)] 
	net_energy_demand = load-pv

	stage_cost = compute_stage_cost(period.site.battery, price, t, control, net_energy_demand)
	new_state_of_charge = compute_stage_dynamics(period.site.battery, soc, control)

	return stage_cost, new_state_of_charge

end