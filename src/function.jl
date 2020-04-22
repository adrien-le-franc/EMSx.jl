# developed with Julia 1.1.1
#
# functions for simulating micro grid control

function compute_stage_cost(battery::Battery, prices::Prices, t::Int64, 
    control::Float64, net_energy_demand::Float64)

    control = control*battery.power*0.25
    imported_energy = (control + net_energy_demand)
    return (prices.buy[t]*max(0.,imported_energy) 
        - prices.sell[t]*max(0.,-imported_energy))

end

function compute_stage_dynamics(battery::Battery, state::Float64, control::Float64)

    scale_factor = battery.power*0.25/battery.capacity
    soc = state + (battery.charge_efficiency*max(0.,control) 
        - max(0.,-control)/battery.discharge_efficiency)*scale_factor
    soc = max(0., min(1., soc)) 
    return soc

end

function save_simulations(site::Site, simulations::Array{Simulation})
    path_to_score = joinpath(site.path_to_save_folder, site.id*".jld")
    save(path_to_score, "simulations", simulations)
end

function group_all_simulations(sites::Array{Site})

    scores = Dict()

    for site in sites

        path_to_score = joinpath(site.path_to_save_folder, site.id*".jld")
        simulation = load(path_to_score, "simulations")
        scores[site.id] = simulation

    end

    save(joinpath(sites[1].path_to_save_folder, "score.jld"), scores)

    if isfile(joinpath(sites[1].path_to_save_folder, "score.jld"))
        for site in sites
            rm(joinpath(site.path_to_save_folder, site.id*".jld"))
        end
    end

end

### hackable functions

function initialize_site_controller(controller::AbstractController, site::Site, prices::Prices)
    """
    hackable function to update site dependent data and parameters
    and initialize the controller
    """
    return DummyController()
end

function compute_control(controller::AbstractController, information::Information)
    """
    hackable function to implement the control technique of the controller
    """
    return 0. 
end
