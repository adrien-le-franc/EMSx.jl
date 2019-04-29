# developed with Julia 1.0.3
#
# struct for micro grid simulation


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

function Site(line::Array{SubString{String}}, header::Dict{SubString{String},Int64})

	id = line[header["SiteId"]]

	batteries = Battery[]
	number_of_batteries = Int((length(header)-1) / 4)
	battery_fields = ["Capacity", "Power", "Charge_Efficiency", "Discharge_Efficiency"]

	for battery_id in 1:number_of_batteries
		args = Float64[]
		for field in battery_fields
			field = line[header["Battery_$(battery_id)_$(field)"]]
			push!(args, parse(Float64, field))
		end
		push!(batteries, Battery(string(battery_id), args...))
	end

	return Site(id, batteries)

end


struct Period
	id::String
end