# developed with Julia 1.1.1
#
# tests for EMSx package

using EMSx
using CSV
using Distributed
using Test

const test_directory = @__DIR__

const test_data_directory = joinpath(test_directory, "data")
const test_metadata_directory = joinpath(test_directory, "metadata")

isdir(test_data_directory) && rm(test_data_directory, recursive=true)
EMSx.make_directory(test_data_directory)

const test_data_test_directory = joinpath(test_data_directory,"test")
const test_data_train_directory = joinpath(test_data_directory,"train")
const test_data_save_directory = joinpath(test_data_directory,"save")

EMSx.make_directory(test_data_save_directory)

const test_prices_path = joinpath(test_metadata_directory, "edf_prices.csv")
const test_metadata_path = joinpath(test_metadata_directory, "metadata.csv")
const test_periods_path = joinpath(test_metadata_directory, "test_periods.csv")

@testset "EMSx.jl test set" begin

  @testset "Preparing data" begin

    @test isnothing(EMSx.download_sites_data(test_data_directory, 
                                             69:69; 
                                             periods = [1,2], 
                                             progress = false))
    @test isfile(joinpath(test_data_directory, "69.csv.gz"))

    @test isnothing(EMSx.initialize_data(test_data_directory, 
                                         test_periods_path))
    @test isfile(joinpath(test_data_test_directory, "69.csv.gz"))
    @test isfile(joinpath(test_data_train_directory, "69.csv.gz"))

  end

  @testset "EMS simulator's body" begin
    
    controller = EMSx.DummyController()
    price = EMSx.load_prices(test_prices_path)[1]
    
    site = EMSx.load_sites(test_metadata_path, 
                           test_data_test_directory, 
                           nothing, 
                           test_data_save_directory)[1]
    
    period = EMSx.Period("1", 
                         EMSx.read_site_file(site.path_to_test_data_csv), 
                         site, 
                         EMSx.Simulation[])

    @testset "Simulation" begin

        net_demand = period.data[98, :actual_consumption] - period.data[98, :actual_pv]
        @test EMSx.apply_control(1, 672, price, period, 0., 0.) == (net_demand*price.buy[1], 0.)
        simulation =  EMSx.simulate_scenario(controller, period, price)
        @test simulation.result.soc == zeros(672)
        @test EMSx.simulate_period!(controller, period, [price]) == nothing

        @test EMSx.simulate_site(controller, site, [price]) == nothing 
        @test EMSx.simulate_sites(controller,
                                  test_data_save_directory, 
                                  test_prices_path, 
                                  test_metadata_path, 
                                  test_data_test_directory, 
                                  nothing) == nothing 
    end

    @testset "Parallel computing" begin

        @test EMSx.init_parallel(2) == workers()
        @test nworkers() == 2
        @test isnothing(@everywhere EMSx.DIR)

        sites = 1:3
        @test isnothing(EMSx.download_sites_data_parallel(test_data_directory,
                                                          sites;
                                                          periods = [1,2],
                                                          progress = false,
                                                          max_threads = 2))
        @test all(isfile, joinpath.([test_data_directory], string.(sites) .* ".csv.gz"))

        @test isnothing(EMSx.initialize_data_parallel(test_data_directory, 
                                                      test_periods_path;
                                                      progress = false))
        @test all(isfile, joinpath.([test_data_test_directory test_data_train_directory], 
                                    string.(sites) .* ".csv.gz"))

        @test EMSx.simulate_sites_parallel(controller,
                                           test_data_save_directory, 
                                           test_prices_path, 
                                           test_metadata_path, 
                                           test_data_test_directory, 
                                           nothing) == nothing

        @test EMSx.init_parallel(1) == workers() == [1]

    end

  end
    
end

rm(test_data_directory, recursive=true)