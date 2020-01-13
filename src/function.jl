# developed with Julia 1.1.1
#
# functions for simulating micro grid control


make_directory(path::String) = if !isdir(path) mkpath(path) end


function download_sites_data(apikey::String, 
							 path_to_data_folder::String, 
							 files_range::UnitRange{Int} = 1:24)
	files_number = length(files_range)
	base_url = "https://data.exchange.se.com/api/datasets/1.0/
				microgrid-energy-management-benchmark-time-series/
				alternative_exports/memb_ts_part_"
    payload = ""
    headers = Dict("Authorization" => "Apikey "*apikey, 
    			   "cache-control"=> "no-cache")
	files_sizes = [223_307_074, 160_151_765, 178_683_342, 239_746_014, 
				   194_319_624, 229_800_343, 225_999_196, 205_952_190, 
				   227_255_093, 188_492_377, 175_456_044, 223_456_964, 
				   212_553_744, 194_117_872, 183_992_889, 230_422_835, 
				   243_373_871, 180_393_452, 163_495_560, 176_314_186, 
				   167_929_157, 183_420_654, 178_688_199, 90_261_417]

	for (fileindex, filenumber) in enumerate(files_range)
		filepath = joinpath(path_to_data_folder, string(filenumber)*".zip")
		download_stream = open(filepath, "w")
	    download_task = @async HTTP.get(base_url*string(filenumber)*"_zip/", 
	    								data=payload, 
	    								headers=headers, 
	    								response_stream = download_stream)
	    progress_meter = Progress(files_sizes[filenumber], 
	    						  "Downloading file $fileindex / $files_number")
	    while download_task.state != :done
	    	update!(progress_meter, filesize(filepath))
	    end
	    close(download_stream)
	    @assert filesize(filepath) == files_sizes[n] "File $n could be corrupted, 
	    											  consider downloading this 
	    											  file again" 
	end

	return
end

function train_test_split(path_to_data_folder::String, path_to_test_periods_csv::String)
	"""
	is to become download_dataset() when data is available on exchange platform
	"""

	make_directory(joinpath(path_to_data_folder, "test"))
	make_directory(joinpath(path_to_data_folder, "train"))
	test_periods = CSV.read(path_to_test_periods_csv)

	@showprogress for site in test_periods[!, :site_id]

		data = CSV.read(joinpath(path_to_data_folder, "$(site).csv"), copycols=true)
		periods = test_periods[test_periods.site_id .== site, :test_periods][1]
		periods = [parse(Int64, id) for id in split(periods[2:end-1], ",")]
		test_data = DataFrame()

		for period in periods
			df = data[data.period_id .== period, :]
			timestamp = df[1, :timestamp]
			history_span = timestamp-Dates.Day(1):Dates.Minute(15):timestamp-Dates.Minute(15)
			history = data[in(history_span).(data.timestamp), :]
			history[!, :period_id] = period*ones(Int64, 96)
			new_period = vcat(history, df)
			test_data = vcat(test_data, new_period)
		end

		CSV.write(joinpath(path_to_data_folder, "test", "$(site).csv"), test_data)
		train_data = data[(!).(in(periods).(data.period_id)), :]
		CSV.write(joinpath(path_to_data_folder, "train", "$(site).csv"), train_data)

	end

	return nothing

end

function load_sites(path_to_metadata_csv::String, path_to_test_data_folder::Union{String, Nothing},
	path_to_train_data_folder::Union{String, Nothing}, path_to_save_folder::String)

    sites = Site[]
    metadata = CSV.read(path_to_metadata_csv)
    number_of_sites = size(metadata, 1)

    for row in 1:number_of_sites
        site = Site(metadata, row, path_to_test_data_folder, 
        	path_to_train_data_folder, path_to_save_folder)
        push!(sites, site)
    end

    return sites

end

function load_prices_csv(path_to_csv::String)

	prices = CSV.read(path_to_csv)

	if !(names(prices) == [:timestamp, :buy, :sell] && size(prices, 1) == 672)
		error("price DataFrame at $(path_to_csv) is not in expected shape")
	end

	if !(all(isa.(prices[!, :timestamp], Dates.Time)))
		try prices[!, :timestamp] = Dates.Time.(prices[!, :timestamp])
		catch error
			println("could not convert timestamp to Dates.Time")
		end
	end

	return prices

end

function load_prices(path_to_prices::String)

	prices = Price[]

	if !isdir(path_to_prices)
		name = split(split(path_to_prices, "/")[end], ".")[1]
		data_frame = load_prices_csv(path_to_prices)
		push!(prices, Price(name, data_frame[!, :buy], data_frame[!, :sell]))
	else
		for file in readdir(path_to_prices)
			name = split(split(path_to_prices, "/")[end], ".")[1]
			data_frame = load_prices_csv(joinpath(path_to_prices, file))
			push!(prices, Price(name, data_frame[!, :buy], data_frame[!, :sell]))	
		end
	end

	return prices

end

function load_site_data(site::Site)
	test_data = CSV.read(site.path_to_test_data_csv)
	site_hidden_test_data = Site(site.id, site.battery, nothing, 
		site.path_to_train_data_csv, site.path_to_save_folder)
	return test_data, site_hidden_test_data
end

function compute_stage_cost(battery::Battery, price::Price, t::Int64, 
	control::Float64, net_energy_demand::Float64)

	control = control*battery.power*0.25
	imported_energy = (control + net_energy_demand)
	return (price.buy[t]*max(0.,imported_energy) 
		- price.sell[t]*max(0.,-imported_energy))

end

function compute_stage_dynamics(battery::Battery, state::Float64, control::Float64)

	scale_factor = battery.power*0.25/battery.capacity
	soc = state + (battery.charge_efficiency*max(0.,control) 
		- max(0.,-control)/battery.discharge_efficiency)*scale_factor
	soc = max(0., min(1., soc)) 
	return soc

end

function save_simulations(site::Site, simulations::Array{Simulation})
	path_to_score = joinpath(site.path_to_save_folder, "score.jld")
	if isfile(path_to_score)
		file = load(path_to_score)
	else
		file = Dict()
	end
	file[site.id] = simulations
	save(path_to_score, file)
end

### hackable functions

function initialize_site_controller(controller::AbstractController, site::Site)
	"""
	hackable function to update site dependent data and parameters
	and initialize the controller
	"""
	return DummyController()
end

function update_price!(controller::AbstractController, price::Price)
	"""
	hackable function to update price dependent data and parameters
	"""
	return nothing
end

function compute_control(controller::AbstractController, information::Information)
	return 0. 
end
