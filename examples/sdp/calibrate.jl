# developed with Julia 1.1.1
#
# functions to calibrate EMS control models


using EMSx

using JLD
using ProgressMeter


function calibrate_sites(controller::EMSx.AbstractController,
    path_to_save_folder::String, 
    path_to_price_folder::String, 
    path_to_metadata_csv_file::String, 
    path_to_train_data_folder::String)
    
    EMSx.make_directory(joinpath(path_to_save_folder, "value_functions"))
    prices = EMSx.load_prices(path_to_price_folder)
    sites = EMSx.load_sites(path_to_metadata_csv_file, nothing,
        path_to_train_data_folder, path_to_save_folder)

    elapsed = 0.0

    @showprogress for site in sites
        
        elapsed += @elapsed site_value_functions = calibrate_site(controller, site, prices)
        
    end

    println("Terminating model calibration in $(elapsed) seconds")

    return nothing

end

function calibrate_site(controller::EMSx.AbstractController, site::EMSx.Site, 
    prices::Array{EMSx.Price})

    controller = EMSx.initialize_site_controller(controller, site)
    
    value_functions = Dict{String, Any}()
    timer = Float64[]

    for price in prices

        EMSx.update_price!(controller, price)
        timing = @elapsed value_functions[price.name] = compute_value_functions(controller)
        push!(timer, timing)

    end

    save(joinpath(site.path_to_save_folder, "value_functions", site.id*".jld"), 
        Dict("value_functions"=>value_functions, "time"=>timer))

    return nothing

end 