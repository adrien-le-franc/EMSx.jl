# developed with Julia 1.0.3
#
# struct for EMS simulation


struct Paths
	train_data::String
	test_data::String
	save::String
end


struct Result
	cost::Array{Float64,1}
	soc::Array{Float64,1}
end

Base.:(==)(r1::Result, r2::Result) = (r1.cost == r2.cost && r1.soc == r2.soc)


struct Id
	site_id::String
	perdio_id::String
	battery_id::String
	model::AbstractModel
end


struct Simulation
	result::Result
	id::Id
end

Simulation() = Simulation(Result(zeros(1), zeros(1)), Id("", "", "", SDP()))
Base.:(==)(s1::Simulation, s2::Simulation) = (s1.result == s2.result && s1.id == s2.id)


struct Battery
	id::String
	capacity::Float64
	power::Float64
	charge_efficiency::Float64
	discharge_efficiency::Float64
end


struct Site
	id::String
	batteries::Union{Battery, Array{Battery}}
end

function Site(data::DataFrame, row::Int64)

	id = string(data[row, :SiteId])

	batteries = Battery[]
	number_of_batteries = Int((size(data, 2)-1) / 4)
	battery_fields = ["Capacity", "Power", "Charge_Efficiency", "Discharge_Efficiency"]

	for battery_id in 1:number_of_batteries
		args =  Float64[]
		for field in battery_fields
			arg = data[row, Symbol("Battery_$(battery_id)_$(field)")]
			push!(args, float(arg))
		end
		push!(batteries, Battery(string(battery_id), args...))
	end

	return Site(id, batteries)
	
end


mutable struct Period 
	id::String
	data::DataFrame
	site::Site
	simulations::Array{Simulation}
end


struct Scenario # restructurer avec ID... ??
	site_id::String
	period_id::String
	battery::Battery
	data::DataFrame
	model::AbstractModel
	paths::Paths
end
