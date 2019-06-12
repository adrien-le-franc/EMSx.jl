# developed with Julia 1.1.1
#
# models and functions for simulation with EMSx


function initiate_model(model_name::String, args::Dict{String,Any})

    args["cost_parameters"] = Dict("buy_price"=>zeros(args["horizon"]), 
            "sell_price"=>zeros(args["horizon"]), "pmax"=>0.)

    args["dynamics_parameters"] = Dict("charge_efficiency"=>0., "discharge_efficiency"=>0.,
            "pmax"=>0., "cmax"=>0.)

    if model_name == "sdp" 

        if args["online"] == "offline"
            model = initiate_SDP(args)
        elseif args["online"] == "forecast"
            model = initiate_SDPOF(args)
        elseif args["online"] == "observed"
            model = initiate_SDPOO(args)
        else
            error("SDP online law $(args["online"]) is not implemented")
        end 

    elseif model_name == "mpc"

        model = initiate_MPC(args)

    elseif model_name == "dummy"

        model = initiate_DummyModel()

    else

        error("Model $(model_name) is not implemented")

    end

    return model

end


# DynamicProgrammingModel
# Generic functions for all models

function update_period!(model::DynamicProgrammingModel, period::Period, 
    train_noises::Dict{String, DataFrame})

    model.cost_parameters["buy_price"] =  Array(period.data[:price_buy_00])
    model.cost_parameters["sell_price"] = Array(period.data[:price_sell_00])
    model.noises = train_noises_of_period(model, period, train_noises)

end

function update_battery!(model::AbstractModel, battery::Battery)

    model.cost_parameters["pmax"] = battery.power
    model.dynamics_parameters["charge_efficiency"] = battery.charge_efficiency
    model.dynamics_parameters["discharge_efficiency"] = battery.discharge_efficiency
    model.dynamics_parameters["pmax"] = battery.power
    model.dynamics_parameters["cmax"] = battery.capacity

end

# SDP

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

end

initiate_SDPOO(args::Dict{String,Any}) = SDPOO(Grid(0:args["dx"]:1, enumerate=true), 
    Grid(-1:args["du"]:1), nothing, args["cost_parameters"], args["dynamics_parameters"], 
    args["horizon"])

function online_information!(sdpoo::SDPOO, data::DataFrame, t::Int64)
    observed = [data[:actual_consumption][t] - data[:actual_pv][t]] / 1000
    return RandomVariable(reshape(observed, 1, 1), [1.])
end

# MPC 

struct MPC <: RollingHorizonModel

    model::Model
    cost_parameters::Dict{String,Any}
    dynamics_parameters::Dict{String,Any}
    horizon::Int64

end

function initiate_MPC(args::Dict{String,Any})

    model = Model(with_optimizer(Clp.Optimizer, LogLevel=0))

    h = args["horizon"]
    @variable(model, u_c[1:h])
    @variable(model, u_d[1:h])
    @variable(model, z[1:h])
    @variable(model, w[1:h])
    @variable(model, x[1:h+1])
    @variable(model, x_0)
    @expression(model, u, u_c-u_d)

    @constraint(model, 0. .<= u_c .<= 1.)
    @constraint(model, 0. .<= u_d .<= 1.)
    @constraint(model, 0. .<= x .<= 1.)
    @constraint(model, 0. .<= z)

    model[:dynamics] = @constraint(model, x .== 0.)
    model[:pmax] = @constraint(model, u+w .<= z)

    weights = vcat(zeros(1, h), Array(LowerTriangular(ones(h, h))))
    dynamics_parameters = Dict("dynamic_matrix"=>weights)

    return MPC(model, Dict(), dynamics_parameters, h)

end

function update_battery!(mpc::MPC, battery::Battery)

    mpc.cost_parameters["pmax"] = battery.power
    mpc.dynamics_parameters["charge_efficiency"] = battery.charge_efficiency
    mpc.dynamics_parameters["discharge_efficiency"] = battery.discharge_efficiency
    mpc.dynamics_parameters["pmax"] = battery.power
    mpc.dynamics_parameters["cmax"] = battery.capacity
    
    model = mpc.model

    if all(JuMP.is_valid.(model, model[:dynamics]))
        JuMP.delete.(model, model[:dynamics])
    end

    model[:dynamics] = @constraint(model, model[:x] .== (battery.power*0.25/battery.capacity.*
        mpc.dynamics_parameters["dynamic_matrix"])*(battery.charge_efficiency.*model[:u_c] - 
        model[:u_d]./battery.discharge_efficiency) + 
        model[:x_0].*ones(mpc.horizon+1))

    if all(JuMP.is_valid.(model, model[:pmax]))
        JuMP.delete.(model, model[:pmax])
    end

    model[:pmax] = @constraint(model, model[:u]*battery.power*0.25+model[:w] .<= model[:z])

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
    @objective(model, Min, sum(buy_prices.*model[:z] - sell_prices.*(model[:z]
        -(model[:u]*mpc.cost_parameters["pmax"]*0.25+model[:w]))))

    return nothing

end

function StoOpt.compute_control(mpc::MPC, cost::Function, dynamics::Function, 
    t::Int64, state::Array{Float64,1}, noise::Nothing, value_functions::Nothing)

    JuMP.fix(mpc.model[:x_0], state[1])
    JuMP.optimize!(mpc.model)
    return [JuMP.value(mpc.model[:u][1])]

end

# DummyModel

struct DummyModel <: AbstractModel
        cost_parameters::Dict{String,Any}
        dynamics_parameters::Dict{String,Any}
end

initiate_DummyModel() = DummyModel(Dict(), Dict())

StoOpt.compute_control(m::DummyModel, cost::Function, dynamics::Function, 
        t::Int64, state::Array{Float64,1}, noise::Nothing, value_functions::Nothing) = [0.0]