# developed with Julia 1.1.1
#
# functions to calibrate EMS control models


using EMSx

using JLD2
using ProgressMeter


function calibrate_sites(controller::EMSx.AbstractController,
    path_to_save_folder::String, 
    path_to_price_csv_file::String, 
    path_to_metadata_csv_file::String, 
    path_to_train_data_folder::String)
    
    EMSx.make_directory(joinpath(path_to_save_folder, "value_functions"))
    prices = EMSx.load_prices(path_to_price_csv_file)
    sites = EMSx.load_sites(path_to_metadata_csv_file, nothing,
        path_to_train_data_folder, path_to_save_folder)

    elapsed = 0.0

    @showprogress for site in sites
        
        elapsed += @elapsed site_value_functions = calibrate_site(controller, 
            site, prices)
        
    end

    println("Terminating model calibration in $(elapsed) seconds")

    return nothing

end

function calibrate_site(controller::EMSx.AbstractController, site::EMSx.Site, 
    prices::EMSx.Prices)

    controller = EMSx.initialize_site_controller(controller, site, prices)

    timer = @elapsed value_function = compute_value_functions(controller)
    
    JLD2.save(joinpath(site.path_to_save_folder, "value_functions", site.id*".jld2"), 
        Dict("value_function"=>value_function, "time"=>timer))

    return nothing
    
end 