# developed with Julia 1.1.1
#
# functions to simulate an EMS 


function simulate_sites(controller::AbstractController, 
                        path_to_save_folder::String,
                        path_to_price_csv_file::String, 
                        path_to_metadata_csv_file::String, 
                        path_to_test_data_folder::String,
                        path_to_train_data_folder::Union{String, Nothing}=nothing)
    
    make_directory(path_to_save_folder)
    prices = load_prices(path_to_price_csv_file)
    sites = load_sites(path_to_metadata_csv_file, path_to_test_data_folder, 
        path_to_train_data_folder, path_to_save_folder)

    elapsed = 0.0

    for site in sites
        
        elapsed += @elapsed simulate_site(controller, site, prices)

    end

    group_all_simulations(sites)
    println("Terminating model simulation in $(elapsed) seconds")

    return nothing

end

function simulate_sites_parallel(controller::EMSx.AbstractController,
                                 path_to_save_folder::String, 
                                 path_to_price_folder::String, 
                                 path_to_metadata_csv_file::String, 
                                 path_to_test_data_folder::String,
                                 path_to_train_data_folder::Union{String, Nothing}=nothing)

    make_directory(path_to_save_folder)
    prices = load_prices(path_to_price_folder)
    sites = load_sites(path_to_metadata_csv_file, path_to_test_data_folder, 
        path_to_train_data_folder, path_to_save_folder)

    to_do = length(sites)

    @sync begin 
        for p in workers()
            @async begin
                while true
                    idx = to_do
                    to_do -= 1
                    if idx <= 0
                        break
                    end
                    println("processing a new job - jobs left in queue : $(idx-1) / $(length(sites))")
                    _ = remotecall_fetch(simulate_site, p, controller, sites[idx], prices)
                end
            end
        end
    end

    group_all_simulations(sites)

end

function simulate_site(controller::AbstractController, 
                       site::Site, 
                       prices::Prices)
    
    test_data, site = load_site_data(site)
    controller = initialize_site_controller(controller, site, prices)
    periods = unique(test_data[!, :period_id])
    simulations = Simulation[]

    @showprogress for period_id in periods

        test_data_period = test_data[test_data.period_id .== period_id, :]
        period = Period(string(period_id), test_data_period, site)
        simulation = simulate_period(controller, period, prices)
        push!(simulations, simulation)

    end

    save_simulations(site, simulations)

    return nothing 

end

function simulate_period(controller::AbstractController, 
                           period::Period, 
                           prices::Prices) 

    horizon = size(period.data, 1) - 96 # test data: 24h of history lag + period data
    id = Id(period.site.id, period.id, prices.name, string(typeof(controller)))
    state_of_charge = 0.
    result = Result(horizon)
    timer = zeros(horizon)

    for t in 1:horizon 

        information = Information(t, prices, period, state_of_charge)
        timing = @elapsed control = compute_control(controller, information)

        stage_cost, state_of_charge = apply_control(t, horizon, prices, period, 
            state_of_charge, control)

        result.cost[t] = stage_cost
        result.soc[t] = state_of_charge
        timer[t] = timing

    end

    return Simulation(result, timer, id)

end

function apply_control(t::Int64, horizon::Int64, 
                       prices::Prices, period::Period, 
                       soc::Float64, control::Float64)
    """
    note on the load and pv values:
    at the end of the period values at t+1 cannot be accessed, replaced by values at t=horizon
    with a minor impact since the optimal control is to empty the battery anyway
    """
    
    load = period.data[! ,:actual_consumption][min(t+96+1, horizon+96)]
    pv = period.data[!, :actual_pv][min(t+96+1, horizon+96)] 
    net_energy_demand = load-pv

    stage_cost = compute_stage_cost(period.site.battery, prices, t, control, net_energy_demand)
    new_state_of_charge = compute_stage_dynamics(period.site.battery, soc, control)

    return stage_cost, new_state_of_charge

end