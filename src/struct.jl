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
	model_type::DataType
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
	path_to_data_csv::String
	path_to_save_jld_file::String
end

function Site(data::DataFrame, row::Int64, path_to_data_folder::String, 
	path_to_save_jld_file::String)

	id = string(data[row, :site_id])
	battery = Battery([float(x) for x in data[row, 3:end]]...)
	path_to_data_csv = path_to_data_folder*"/"*id*".csv"

	return Site(id, battery, path_to_data_csv, path_to_save_jld_file)
	
end


mutable struct Period 
	id::String
	data::DataFrame
	site::Site
	simulations::Array{Simulation}
end


struct Information
	t::Int64
	soc::Float64 
	pv::Array{Float64,1}
	forecast_pv::Array{Float64,1}
	load::Array{Float64,1}
	forecast_load::Array{Float64,1}
	price::DataFrame
	battery::Battery
end

function Information(t::Int64, price::DataFrame, period::Period, soc::Float64)

	data = period.data[t+1:t+96, :]
	pv = data[:actual_pv]
	forecast_pv = data[end, 102:197]
	load = data[:actual_consumption]
	forecast_load = data[end, 6:101]

	return Information(t, soc, pv, forecast_pv, load, forecast_load, price, period.site.battery)

end
