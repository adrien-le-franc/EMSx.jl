# developed with Julia 1.1.1
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
	period_id::String
	battery_id::String
	model_type::DataType
end


struct Simulation
	result::Result
	id::Id
end

Simulation(h::Int64) = Simulation(Result(zeros(h), zeros(h)), Id("", "", "", ""))
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

	id = string(data[row, :site_id])
	battery = Battery("1", [float(x) for x in data[row, 3:end]]...)

	return Site(id, battery)
	
end

mutable struct Period 
	id::String
	data::DataFrame
	site::Site
	simulations::Array{Simulation}
end


mutable struct Scenario
	site_id::String
	period_id::String
	battery::Battery
	data::DataFrame
	model::AbstractModel
	paths::Paths
end

Id(s::Scenario) = Id(s.site_id, s.period_id, s.battery.id, typeof(s.model))

struct Price
	price_buy::DataFrame
	price_sell::DataFrame
end

function Price(prices::DataFrame)

	price_buy = DataFrame(timing=collect(Dates.Time(0, 0, 0):Dates.Minute(15):Dates.Time(23, 45, 0)))
	price_buy[:weekday] = prices[:buy]
	if Symbol("buy_weekend") in names(prices)
		price_buy[:weekend] = prices[:buy_weekend]
	else
		price_buy[:weekend] = prices[:buy]
	end

	price_sell = DataFrame(timing=collect(Dates.Time(0, 0, 0):Dates.Minute(15):Dates.Time(23, 45, 0)))
	price_sell[:weekday] = prices[:sell]
	if Symbol("sell_weekend") in names(prices)
		price_sell[:weekend] = prices[:sell_weekend]
	else
		price_sell[:weekend] = prices[:sell]
	end

	return Price(price_buy, price_sell)

end
