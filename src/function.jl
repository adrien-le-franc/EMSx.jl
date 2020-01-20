# developed with Julia 1.1.1
#
# functions for simulating micro grid control

function compute_stage_cost(battery::Battery, price::Price, t::Int64, 
    control::Float64, net_energy_demand::Float64)

    control = control*battery.power*0.25
    imported_energy = (control + net_energy_demand)
    return (price.buy[t]*max(0.,imported_energy) 
        - price.sell[t]*max(0.,-imported_energy))

end

function compute_stage_dynamics(battery::Battery, state::Float64, control::Float64)

    scale_factor = battery.power*0.25/battery.capacity
    soc = state + (battery.charge_efficiency*max(0.,control) 
        - max(0.,-control)/battery.discharge_efficiency)*scale_factor
    soc = max(0., min(1., soc)) 
    return soc

end

function save_simulations(site::Site, simulations::Array{Simulation})
    path_to_score = joinpath(site.path_to_save_folder, "score.jld")
    if isfile(path_to_score)
        file = load(path_to_score)
    else
        file = Dict()
    end
    file[site.id] = simulations
    save(path_to_score, file)
end

### hackable functions

function initialize_site_controller(controller::AbstractController, site::Site)
    """
    hackable function to update site dependent data and parameters
    and initialize the controller
    """
    return DummyController()
end

function update_price!(controller::AbstractController, price::Price)
    """
    hackable function to update price dependent data and parameters
    """
    return nothing
end

function compute_control(controller::AbstractController, information::Information)
    return 0. 
end
