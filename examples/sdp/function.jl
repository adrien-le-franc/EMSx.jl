# developed with Julia 1.1.1
#
# functions for calibrating models for microgrid control
# models are  computed with a package available at 
# https://github.com/adrien-le-franc/StoOpt.jl


using EMSx
using StoOpt

using CSV, DataFrames, Dates
using Clustering


## Generic data parsing functions


is_week_end(date::Union{Dates.Date, Dates.DateTime}) = Dates.dayofweek(date) in [6, 7]
date_time_to_quarter(timer::Dates.Time) = Int64(Dates.hour(timer)*4 + Dates.minute(timer)/15 + 1)
noise_data_df() = DataFrame(timestamp=Dates.Time(0, 0, 0):Dates.Minute(15):Dates.Time(23, 45, 0), 
        data=[Float64[] for i in 1:96])

function net_demand_offline_law(path_to_data_csv::String; k::Int64=10)

    """
    parse offline data to return a Dict of DataFrame objects with columns
    :timestamp -> Dates.Time ; one day discretized at 15 min steps
    :value -> Array{Float64,1} ; scalar values of a stochastic process
    :probability -> Arra{Float64,1} ; probabilities of each scalar value
    """

    data = EMSx.read_site_file(path_to_data_csv)
    sorted_data = parse_data_frame(data)
    offline_law_data_frames = data_to_offline_law(sorted_data, k=k)

    return offline_law_data_frames
    
end

function parse_data_frame(data::DataFrame)

    train_data = Dict("week_day"=>noise_data_df(), "week_end"=>noise_data_df())

    for df in eachrow(data)

        timestamp = df[:timestamp]
        date = timestamp - Dates.Minute(15)
        day = Dates.Date(date)
        timing = Dates.Time(date)

        net_energy_demand = df[:actual_consumption] - df[:actual_pv]

        if is_week_end(day)
            push!(train_data["week_end"][date_time_to_quarter(timing), :data], 
                net_energy_demand)
        else
            push!(train_data["week_day"][date_time_to_quarter(timing), :data], 
                net_energy_demand)
        end

    end

    return train_data

end

function data_to_offline_law(data::Dict{String, DataFrame};
    k::Int64=10)

    offline_law_data_frames = Dict("week_day"=>DataFrame(), "week_end"=>DataFrame())

    for (key, df) in data

        law_df = DataFrame(timestamp=Dates.Time[], value=Array{Float64,1}[],
            probability=Array{Float64,1}[])

        for timestamp in Dates.Time(0, 0, 0):Dates.Minute(15):Dates.Time(23, 45, 0)

            noise_data = reshape(df[df.timestamp .== timestamp, :data][1], (1, :))
            n_data = length(noise_data)
            k_means = kmeans(noise_data, k)
            value = reshape(k_means.centers, :)
            probability = reshape(k_means.counts, :) / n_data
            push!(law_df, [timestamp, value, probability])

        end

        offline_law_data_frames[key] = law_df

    end

   return offline_law_data_frames

end


## StoOpt specific data parsing function
## enables connecting the generic offline data pipeline
## with the StoOpt package


function data_frames_to_noises(offline_law::Dict{String,DataFrame})

    w_week_day = hcat(offline_law["week_day"][!, :value]...)'
    pw_week_day = hcat(offline_law["week_day"][!, :probability]...)'
    w_week_end = hcat(offline_law["week_end"][!, :value]...)'
    pw_week_end = hcat(offline_law["week_end"][!, :probability]...)'

    # one-week-long stochastic process
    w = vcat([w_week_day for i in 1:5]..., [w_week_end for i in 1:2]...)
    pw = vcat([pw_week_day for i in 1:5]..., [pw_week_end for i in 1:2]...)

    return StoOpt.Noises(w, pw)

end


### hackable function


function compute_value_functions(controller::EMSx.AbstractController)
    """hackable function to compute value functions"""
    return nothing
end