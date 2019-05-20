# developed with Julia 1.0.3
#
# models and functions for simulation with EMSx


const cost_parameters = Dict("buy_price"=>zeros(args["horizon"]), 
            "sell_price"=>zeros(args["horizon"]))

function init_model(model_name::String, args::Dict{String,Any})

    if model_name == "SDP"

        function cost(sdp::SDP, time::Int64, state::Float64, control::Float64, noise::Float64)
            energy_demand = control + noise
            return (sdp.cost_parameters["buy_price"]*max(0,energy_demand) 
                - sdp.cost_parameters["sell_price"]*max(0, -energy_demand))
        end

        function dynamics(sdp::SDP, time::Int64, state::Float64, control::Float64, noise::Float64)
            return state + (sdp.dynamics_parameters["charge_efficiency"]*max(0, control) 
                - max(0, -control)/sdp.dynamics_parameters["discharge_efficiency"])
        end

        dynamics_parameters = Dict("charge_efficiency"=>1., "discharge_efficiency"=>1.)

        model = SDP(Grid(0:args["dx"]:1), Grid(-1:args["du"]:1), Noise(), cost_parameters, 
            dynamics_parameters, args["horizon"])        

    else

        error("Model $(model_name) is not implemented")

    end

    return model

end