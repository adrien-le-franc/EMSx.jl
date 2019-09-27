# developed with Julia 1.1.1
#
# EMS simulation with a dummy controller


using EMSx

save_folder = joinpath(@__DIR__, "../results")

controller = EMSx.DummyController()
EMSx.simulate_sites(controller, joinpath(save_folder, "dummy.jld"))