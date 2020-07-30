# Examples

This directory provides two examples of implementation of controllers for running a simulation with `EMSx.jl`:

* a controller based on Model Predictive Control [(MPC)](mpc.jl)
* a controller based on Stochastic Dynamic Programming [(SDP)](sdp/sdp.jl)

note that for SDP, a specific calibration (offline) phase is implemented. You can run these examples from a terminal by parsing your key arguments reported in [arguments.jl](arguments.jl) as in the following example:

```julia
julia mpc.jl --save /home/xxx/path_to_save_folder
```

