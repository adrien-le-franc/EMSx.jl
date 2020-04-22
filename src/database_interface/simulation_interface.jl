# developed with Julia 1.3.0
#
# functions for loading data during simulation


function load_sites(path_to_metadata_csv::String, 
                    path_to_test_data_folder::Union{String, Nothing},
                    path_to_train_data_folder::Union{String, Nothing}, 
                    path_to_save_folder::String)

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

function load_sites(path_to_data_folder::String)
    path_to_metadata_csv = joinpath(DIR, "metadata")
    path_to_test_data_folder = joinpath(path_to_data_folder, "test")
    path_to_train_data_folder = joinpath(path_to_data_folder, "train")
    path_to_save_folder = joinpath(path_to_data_folder, "save")
    return load_sites(path_to_metadata_csv, path_to_test_data_folder,
                      path_to_train_data_folder, path_to_save_folder)
end

function load_prices(path_to_csv::String)

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

    name = splitext(basename(path_to_csv))[1]
    prices = Prices(name, prices[!, :buy], prices[!, :sell])

    return prices

end

function load_site_test_data(site::Site)
    test_data = read_site_file(site.path_to_test_data_csv, copycols = true)
    site_hidden_test_data = Site(site.id, 
                                 site.battery, 
                                 nothing, # hide path to test data to the controller
                                 site.path_to_train_data_csv, 
                                 site.path_to_save_folder)
    return test_data, site_hidden_test_data
end

load_site_data(site::Site) = load_site_test_data(site) # to avoid code breaks
