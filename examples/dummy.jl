# developed with Julia 1.1.1
#
# EMS simulation with a dummy controller


using EMSx

include("arguments.jl")


args = parse_commandline()

const controller = EMSx.DummyController()

EMSx.simulate_sites(controller,
    joinpath(args["save"], "dummy"),
    args["price"],
    args["metadata"],
    args["test"])