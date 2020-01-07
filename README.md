<img src="docs/logos.png" width="600" />

# EMSx.jl
`EMSx.jl` is a Julia package for simulating the control of an electric microgrid with an Energy Management System. It originated from a project between [CERMICS](https://cermics-lab.enpc.fr/), [Efficacity](https://www.efficacity.com/) and [Schneider Electric](https://www.se.com/fr/fr/).

## Installation
If not installed, download [Julia 1.3.0](https://julialang.org/downloads/) or higher versions. 
Then, add the `EMSx.jl` package using Julia's [package manager](https://julialang.github.io/Pkg.jl/v1/managing-packages/). Note that `EMSx.jl` is not a registered package.

## Data
The microgrid control simulation relies on [data](https://shop.exchange.se.com/apps/52535/microgrid-energy-management-benchmark#!overview) provided by Schneider Electric. 

## Using EMSx.jl
`EMSx.jl` is a package for simulating the control of an electric microgrid on testing periods of one week. We have a pool of 70 microgrids with data. Each microgrid is composed of 

* a photovoltaic (PV) generating unit ,
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