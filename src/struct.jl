# developed with Julia 1.1.1
#
# struct for EMS simulation


abstract type AbstractController end

mutable struct DummyController <: AbstractController
end


mutable struct Result
    cost::Array{Float64,1}
    soc::Array{Float64,1}
end

Result(h::Int64) = Result(zeros(h), zeros(h))


struct Id
    site_id::String
    period_id::String
    price_id::String
    model_type::String
end


struct Simulation
    result::Result
    timer::Array{Float64,1}
    id::Id
end


struct Battery
    capacity::Float64
    power::Float64
    charge_efficiency::Float64
    discharge_efficiency::Float64
end


struct Site
    id::String
    battery::Battery
    path_to_test_data_csv::Union{String, Nothing}
    path_to_train_data_csv::Union{String, Nothing}
    path_to_save_folder::String
end

function Site(data::DataFrame, row::Int64, path_to_test_data_folder::Union{String, Nothing}, 
    path_to_train_data_folder::Union{String, Nothing}, path_to_save_jld_file::String)

    id = string(data[row, :site_id])
    battery = Battery([float(x) for x in data[row, 3:end]]...)
    if path_to_test_data_folder != nothing
        path_to_test_data_csv = joinpath(path_to_test_data_folder, id*".csv.gz")
    else
        path_to_test_data_csv = nothing
    end
    if path_to_train_data_folder != nothing
        path_to_train_data_csv = joinpath(path_to_train_data_folder, id*".csv.gz")
    else
        path_to_train_data_csv = nothing
    end

    return Site(id, battery, path_to_test_data_csv, path_to_train_data_csv, 
        path_to_save_jld_file)
    
end


mutable struct Period 
    id::String
    data::DataFrame
    site::Site
end


struct Price
    name::String
    buy::Array{Float64,1}
    sell::Array{Float64,1}
end


struct Information
    t::Int64
    soc::Float64 
    pv::Array{Float64,1}
    forecast_pv::Array{Float64,1}
    load::Array{Float64,1}
    forecast_load::Array{Float64,1}
    price::Price
    battery::Battery
    site_id::String
end

function Information(t::Int64, price::Price, period::Period, soc::Float64)

    data = sort!(period.data[t+1:t+96, :], rev=true)
    pv = data[!, :actual_pv]
    forecast_pv = data[end, 102:197]
    load = data[!, :actual_consumption]
    forecast_load = data[end, 6:101]

    return Information(t, soc, pv, forecast_pv, load, forecast_load, price, period.site.battery, 
        period.site.id)

end
