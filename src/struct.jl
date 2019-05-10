# developed with Julia 1.0.3
#
# struct for EMS simulation


struct Paths
	train_data::String
	test_data::String
	save::String
end


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


struct Period 
	id::String
	data::DataFrame
	site::Site
end


struct Scenario
	site_id::String
	period_id::String
	battery::Battery
	data::DataFrame
	model::AbstractModel
	paths::Paths
end