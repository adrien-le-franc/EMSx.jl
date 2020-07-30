# Examples

This directory provides two examples of implementation of controllers for running a simulation with `EMSx.jl`:

* a controller designed with Model Predictive Control [(MPC)](mpc.jl)
* a controller designed with Stochastic Dynamic Programming [(SDP)](sdp/sdp.jl)

Note that for SDP, a specific calibration (offline) phase is implemented. You can run these examples from a terminal by parsing your key arguments reported in [arguments.jl](arguments.jl) as in the following example:

```
julia mpc.jl --save /home/xxx/path_to_save_folder
```

Details about controller design techniques are documented in [this paper](https://hal.archives-ouvertes.fr/hal-02425913/document). 
