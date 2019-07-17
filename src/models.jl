# developed with Julia 1.1.1
#
# models and functions for simulation with EMSx


function initiate_model(model_name::String, args::Dict{String,Any})

    args["cost_parameters"] = Dict("buy_price"=>zeros(args["horizon"]), 
            "sell_price"=>zeros(args["horizon"]), "pmax"=>0.)

    args["dynamics_parameters"] = Dict("charge_efficiency"=>0., "discharge_efficiency"=>0.,
            "pmax"=>0., "cmax"=>0.)

    if model_name == "sdp" 

        if args["%COMMAND%"] == "ar"

             if args["online"] == "offline"
                model = initiate_SDPAR(args)
            elseif args["online"] == "forecast"
                model = initiate_SDPAROF(args)
            elseif args["online"] == "observed"
                model = initiate_SDPAROO(args)
            else
                error("SdpAR online law $(args["online"]) is not implemented")
            end 

        else

            if args["online"] == "offline"
                model = initiate_SDP(args)
            elseif args["online"] == "forecast"
                model = initiate_SDPOF(args)
            elseif args["online"] == "observed"
                model = initiate_SDPOO(args)
            else
                error("SDP online law $(args["online"]) is not implemented")
            end            

        end

    elseif model_name == "mpc"

        model = initiate_MPC(args)

    elseif model_name == "dummy"

        model = initiate_DummyModel()

    else

        error("Model $(model_name) is not implemented")

    end

    println("Model $(model_name) successfuly built, starting simulation")
    return model

end


# DynamicProgrammingModel
# Generic functions for all models

function update_period!(model::DynamicProgrammingModel, period::Period, 
    train_noises::Dict{String, DataFrame})

    model.cost_parameters["buy_price"] =  Array(period.data[:price_buy_00])
    model.cost_parameters["sell_price"] = Array(period.data[:price_sell_00])
    model.noises = train_noises_of_period!(model, period, train_noises)

end

function update_battery!(model::AbstractModel, battery::Battery)

    model.cost_parameters["pmax"] = battery.power
    model.dynamics_parameters["charge_efficiency"] = battery.charge_efficiency
    model.dynamics_parameters["discharge_efficiency"] = battery.discharge_efficiency
    model.dynamics_parameters["pmax"] = battery.power
    model.dynamics_parameters["cmax"] = battery.capacity

end

# SDP model
# Online law = offline law

initiate_SDP(args::Dict{String,Any}) = SDP(Grid(0:args["dx"]:1, enumerate=true), 
    Grid(-1:args["du"]:1), nothing, args["cost_parameters"], args["dynamics_parameters"], 
    args["horizon"])

online_information!(sdp::SDP, df::DataFrame, t::Int64) = RandomVariable(sdp.noises, t)

# SDPOF 
# Online law based on online Forecast

mutable struct SDPOF <: SdpModel

    states::Grid
    controls::Grid
    noises::Union{Noises, Nothing}
    cost_parameters::Dict{String,Any}
    dynamics_parameters::Dict{String,Any}
    horizon::Int64
    noise_points::Int64

end

initiate_SDPOF(args::Dict{String,Any}) = SDPOF(Grid(0:args["dx"]:1, enumerate=true), 
    Grid(-1:args["du"]:1), nothing, args["cost_parameters"], args["dynamics_parameters"],
    args["horizon"])

function online_information!(sdpof::SDPOF, data::DataFrame, t::Int64)
    forecast = [data[:load_00][t] - data[:pv_00][t]] / 1000
    return RandomVariable(reshape(forecast, 1, 1), [1.])
end

# SDPOO
# Online law based on Observed noise realizations

mutable struct SDPOO <: SdpModel

    states::Grid
    controls::Grid
    noises::Union{Noises, Nothing}
    cost_parameters::Dict{String,Any}
    dynamics_parameters::Dict{String,Any}
    horizon::Int64
    noise_points::Int64

end

initiate_SDPOO(args::Dict{String,Any}) = SDPOO(Grid(0:args["dx"]:1, enumerate=true), 
    Grid(-1:args["du"]:1), nothing, args["cost_parameters"], args["dynamics_parameters"], 
    args["horizon"])

function online_information!(sdpoo::SDPOO, data::DataFrame, t::Int64)
    if t == 1
        observed = [data[:actual_consumption][1] - data[:actual_pv][1]] / 1000
    else
        observed = [data[:actual_consumption][t-1] - data[:actual_pv][t-1]] / 1000
    end
    return RandomVariable(reshape(observed, 1, 1), [1.])
end

# SdpAR
# State dynamics includes an AR(p) modeling of the noise process

abstract type SdpAR <: StoOpt.SdpModel end

function cost(model::SdpAR, t::Int64, state::Array{Float64,1}, control::Array{Float64,1},
    noise::Array{Float64,1})
    control = control*model.cost_parameters["pmax"]*0.25

    w = dynamics(model, t, state, control, noise)[2:end]
    w = (w*(model.dynamics_parameters["noise_upper_bound"]
        -model.dynamics_parameters["noise_lower_bound"]) .+ 
    model.dynamics_parameters["noise_lower_bound"])

    energy_demand = (control + w + noise)[1]

    return (model.cost_parameters["buy_price"][t]*max(0.,energy_demand) 
        - model.cost_parameters["sell_price"][t]*max(0.,-energy_demand))
end

function dynamics(model::SdpAR, t::Int64, state::Array{Float64,1}, 
    control::Array{Float64,1}, noise::Array{Float64,1}) 

    normalize = model.dynamics_parameters["pmax"]*0.25/model.dynamics_parameters["cmax"]

    soc = state[1] + (model.dynamics_parameters["charge_efficiency"]*max(0.,control[1]) 
        - max(0.,-control[1])/model.dynamics_parameters["discharge_efficiency"])*normalize

    weights = model.dynamics_parameters["ar_period_weights"][t, :]
    lags = push!(state[2:end],1.)
    prediction = lags'*weights
    prediction = min(max(prediction, 0.), 1.)

    return [soc, prediction, state[2:end-1]...]

end

function initiate_state(model::SdpAR)
    return append!([0.0], [0.5 for i in 1:model.lags])
end


# SdpAR 
# Online law = offline law


mutable struct SDPAR <: SdpAR

    states::Grid
    controls::Grid
    noises::Union{Noises, Nothing}
    cost_parameters::Dict{String,Any}
    dynamics_parameters::Dict{String,Any}
    horizon::Int64
    noise_points::Int64
    lags::Int64

end

function initiate_SDPAR(args::Dict{String,Any}) 

    states = [0:args["dx"]:1]
    for lag in args["ar"]["lags"]
        push!(states, 0:args["ar"]["dw"]:1)
    end

    SDPAR(Grid(states..., enumerate=true), 
    Grid(-1:args["du"]:1), nothing, args["cost_parameters"], args["dynamics_parameters"], 
    args["horizon"], args["k"], args["ar"]["lags"])
end

online_information!(sdp::SDPAR, df::DataFrame, t::Int64) = RandomVariable(sdp.noises, t)


# MPC 

mutable struct MPC <: RollingHorizonModel

    model::Model
    cost_parameters::Dict{String,Any}
    dynamics_parameters::Dict{String,Any}
    horizon::Int64

end

function initiate_MPC(args::Dict{String,Any})

    model = Model(with_optimizer(Clp.Optimizer, LogLevel=0))
    return MPC(model, Dict(), Dict(), args["horizon"])

end

function update_battery!(mpc::MPC, battery::Battery)

    h = mpc.horizon
    umax = battery.power*0.25
    xmax = battery.capacity
    rho_c = battery.charge_efficiency
    rho_d = battery.discharge_efficiency
    weights = vcat(zeros(1, h), Array(LowerTriangular(ones(h, h))))

    model = Model(with_optimizer(Clp.Optimizer, LogLevel=0))

    @variable(model, u_c[1:h])
    @variable(model, u_d[1:h])
    @variable(model, z[1:h])
    @variable(model, x[1:h+1])
    @variable(model, w[1:h])
    @variable(model, x0)

    @constraint(model, 0. .<= u_c)
    @constraint(model, u_c .<= umax)
    @constraint(model, 0. .<= u_d)
    @constraint(model, u_d .<= umax)
    @constraint(model, 0. .<= x)
    @constraint(model, x .<= xmax)
    @constraint(model, 0. .<= z )
    @expression(model, u,  u_c - u_d)

    @constraint(model, u.+w .<= z)
    @constraint(model, diff(x) .== rho_c.*u_c .- u_d./rho_d)
    @constraint(model, x[1] == x0)

    mpc.model = model

    mpc.cost_parameters["pmax"] = battery.power
    mpc.dynamics_parameters["charge_efficiency"] = rho_c
    mpc.dynamics_parameters["discharge_efficiency"] = rho_d
    mpc.dynamics_parameters["pmax"] = battery.power
    mpc.dynamics_parameters["cmax"] = xmax

    return nothing

end

function online_information!(mpc::MPC, data::DataFrame, t::Int64)

    df = data[t, :]
    model = mpc.model

    forecast = zeros(mpc.horizon)
    buy_prices = zeros(mpc.horizon)
    sell_prices = zeros(mpc.horizon)

    for k in 0:95

            quater_ahead = string(k)
            if k < 10
                quater_ahead = "0"*quater_ahead
            end
            forecast[k+1] = (df[Symbol("load_$(quater_ahead)")] 
                - df[Symbol("pv_$(quater_ahead)")]) / 1000

            if k > min(960-t, 95)
                continue
            end

            buy_prices[k+1] = df[Symbol("price_buy_$(quater_ahead)")]
            sell_prices[k+1] = df[Symbol("price_sell_$(quater_ahead)")]
            
    end

    JuMP.fix.(model[:w], forecast)
    @objective(model, Min, sum(buy_prices.*model[:z]-sell_prices.*(model[:z]-model[:u]-model[:w])))

    return nothing

end

function StoOpt.compute_control(mpc::MPC, cost::Function, dynamics::Function, 
    t::Int64, state::Array{Float64,1}, noise::Nothing, value_functions::Nothing)

    JuMP.fix(mpc.model[:x0], state[1]*mpc.dynamics_parameters["cmax"])
    JuMP.optimize!(mpc.model)
    return [JuMP.value(mpc.model[:u][1])] / (mpc.dynamics_parameters["pmax"]*0.25)

end

# DummyModel

struct DummyModel <: AbstractModel
        cost_parameters::Dict{String,Any}
        dynamics_parameters::Dict{String,Any}
end

initiate_DummyModel() = DummyModel(Dict(), Dict())

StoOpt.compute_control(m::DummyModel, cost::Function, dynamics::Function, 
        t::Int64, state::Array{Float64,1}, noise::Nothing, value_functions::Nothing) = [0.0]