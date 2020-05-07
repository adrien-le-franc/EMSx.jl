
# EMSx.jl
| **Build Status** |
|:----------------:|
| [![Build Status][build-img]][build-url] | 
| [![Codecov branch][codecov-img]][codecov-url] |

[build-img]: https://travis-ci.org/adrien-le-franc/EMSx.jl.svg?branch=master
[build-url]: https://travis-ci.org/adrien-le-franc/EMSx.jl
[codecov-img]: https://codecov.io/gh/adrien-le-franc/EMSx.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/adrien-le-franc/EMSx.jl

`EMSx.jl` is a Julia package for simulating the control of an electric microgrid with an Energy Management System. It originated from a joint project between [CERMICS](https://cermics-lab.enpc.fr/), [Efficacity](https://www.efficacity.com/) and [Schneider Electric](https://www.se.com/fr/fr/). This package is designed for benchmarking EMS techniques, as documented in [this paper](https://hal.archives-ouvertes.fr/hal-02425913/document).

## Installation
If not installed, download [Julia 1.3.0](https://julialang.org/downloads/) or higher versions. 
Then, add the `EMSx.jl` package using Julia's [package manager](https://julialang.github.io/Pkg.jl/v1/managing-packages/). Note that `EMSx.jl` is not a registered package.

## Data
The microgrid control simulation relies on [data](https://shop.exchange.se.com/apps/52535/microgrid-energy-management-benchmark#!overview) provided by Schneider Electric. 

`EMSx.jl` provides functions for downloading the dataset:

1. make an account and login to Schneider's [platform](https://data.exchange.se.com)
2. generate an API key from your [account](https://data.exchange.se.com/account/api-keys/)
3. set an environment variable with your API key: `SCHNEIDER_API_KEY = XXX` 
4. just call `EMSx.download_sites_data(path_to_data_folder, 1:70)` to download all 70 sites

Note that the data is compressed to .gz file and that downloading the total amount of data requires about 5GB of disk space.

5. finally, perform the train/test data partitioning by running `EMSx.initialize_data(path_to_data_folder)`. By default, pre-partitioning data files are deleted to save disk space. You can choose to keep them with the keyword `delete_files=false`.

Due to the large volume of data, steps 4. and 5. can be time consuming. We provide [parallelization options](#parallelization) for these steps.


## Using EMSx.jl
`EMSx.jl` is a package for simulating the control of an electric microgrid on testing periods of one week. We have a pool of 70 microgrids with data. Each microgrid is composed with 

* a photovoltaic (PV) generating unit,
* a battery,
* a delivery point to exchange power with the grid,
* electric devices, resulting in a aggregated local load.

Energy exchanges with the grid induce costs. The aim of a controller is to manage the microgrid at least operating cost. During simulation, a controller has access to online data, gathered in instances of the `Information` type:

```julia
struct Information
	t::Int64 # time step in [1, 672]
	soc::Float64 # battery's state of charge in [0, 1]
	pv::Array{Float64,1} # 24h history of PV data, 15 min samples 
	forecast_pv::Array{Float64,1} # 24h forecasts of PV data, 15 min samples
	load::Array{Float64,1} # 24h history of load data, 15 min samples
	forecast_load::Array{Float64,1} # 24h forecasts of lad data, 15 min samples
	price::Price
	battery::Battery
	site_id::String
end
```
 We provide an example of usage for a `DummyController` which does not use the battery.
```julia
using EMSx

mutable struct DummyController <: EMSx.AbstractController end

EMSx.compute_control(controller::DummyController, 
	information::EMSx.Information) = 0.

const controller = DummyController()

EMSx.simulate_sites(controller,
	"home/xxx/path_to_save_folder",
	"home/xxx/path_to_price",
	"home/xxx/path_to_metadata",
	"home/xxx/path_to_simulation_data")
```
The behavior of `DummyController` is specified by the corresponding method of the `compute_control` function. For more complex controllers, you might also want to implement a specific method for the
`initialize_site_controller` function. We refer to [examples](https://github.com/adrien-le-franc/EMSx.jl/tree/master/examples) for more complex usages.

## Parallelization
`EMSx.jl` provides functions for distributed processing. Before calling a parallelized operation, initialize workers with `EMSx.init_parallel(n_workers)`. The following functions make use of parallelization:

* [`EMSx.download_sites_data_parallel`](src/database_interface/download_data.jl)
* [`EMSx.initialize_data_parallel`](src/database_interface/split_data.jl)
* [`EMSx.simulate_sites_parallel`](src/simulate.jl)

<img src="docs/logos.png" width="500" />
