# developed with Julia 1.1.1
#
# models and functions for simulation with EMSx


const cost_parameters = Dict("buy_price"=>zeros(args["horizon"]), 
            "sell_price"=>zeros(args["horizon"]), "pmax"=>0.)

function init_model(model_name::String, args::Dict{String,Any})

    if model_name == "SDP"

        dynamics_parameters = Dict("charge_efficiency"=>0., "discharge_efficiency"=>0.,
            "pmax"=>0., "cmax"=>0.)


        function load_train_data!(site::Site, sdp::SDP, paths::Paths)

           data = load_data(site.id, paths.train_data)
           load = Array(data[:actual_load])
           pv = Array(data[:actual_pv])
           sdp.noise = Noise(reshape(load-pv, :, 2), 10)

        end

        function update_model!(sdp::SDP, battery::Battery, data::DataFrame)

            sdp.cost_parameters["buy_price"] =  Array(data[:price_buy_00])
            sdp.cost_parameters["sell_price"] = Array(data[:price_sell_00])
            sdp.cost_parameters["pmax"] = battery.power

            sdp.dynamics_parameters["charge_efficiency"] = battery.charge_efficiency
            sdp.dynamics_parameters["discharge_efficiency"] = battery.discharge_efficiency
            sdp.dynamics_parameters["pmax"] = battery.power
            sdp.dynamics_parameters["cmax"] = battery.capacity

        end

        model = SDP(Grid(0:args["dx"]:1), Grid(-1:args["du"]:1), nothing, cost_parameters, 
            dynamics_parameters, args["horizon"])        

    else

        error("Model $(model_name) is not implemented")

    end

    return model

end