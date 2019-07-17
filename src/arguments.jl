# developed with Julia 1.1.1
#
# argument parsing

using ArgParse

function parse_commandline()

	s = ArgParseSettings()

    @add_arg_table s begin

    	## REQUIRED ##
        
        "--save"
        	help = "path to .jld file to save results"
        	arg_type = String
        	required = true

        ## paths ##

        "--metadata"
        	help = "metadata.csv - site and battery parameters"     
        	arg_type = String
        	default = "/home/EMSx.jl/data/metadata.csv"

        "--train"
        	help = "train data folder"
        	arg_type = String
        	default = "/home/EMSx.jl/data/train"

        "--test"
        	help = "test data folder"
        	arg_type = String
        	default = "/home/EMSx.jl/data/test"

        ## COMMANDS ##

        "--sdp"
            help = "dynamic programming with SDP model"
            action = :command

        "--sddp"
            help = "dynamic programming with SDDP model"
            action = :command 

        "--mpc"
            help = "rolling horizon with MPC model"
            action = :command

        "--dummy"
            help = "dummy EMS policy not using the battery"
            action = :command

    end

    s["sdp"].commands_are_required = false

    @add_arg_table s["sdp"] begin

        "--horizon"
            help = "horizon of control"
            arg_type = Int64
            default = 960

        "--k"
            help = "cardinal of discrete noise space"
            arg_type = Int64
            default = 10
        
        "--dx"
            help = "step of the normalized state Grid"
            arg_type = Float64
            default = 0.1

        "--du"
            help = "step of the normalized control Grid"
            arg_type = Float64
            default = 0.1

        "--online"
            help = "online law for noise: offline/forecast/observed"
            arg_type = String
            default = "offline"

        "--ar"
            help = "modeling noises with an ar process"
            action = :command

    end

    @add_arg_table s["sdp"]["ar"] begin
        
        "--lags"
            help = "number p of lags for AR(p)"
            arg_type = Int64
            default = 1

        "--dw"
            help = "step of the normalized noise lags grid"
            arg_type = Float64
            default = 0.1
    end

    @add_arg_table s["mpc"] begin
        
        "--horizon"
            help = "horizon of control"
            arg_type = Int64
            default = 96

    end

    @add_arg_table s["dummy"] begin
        
        "--horizon"
            help = "horizon of control"
            arg_type = Int64
            default = 0

    end

    parsed_args = parse_args(s)
    for (key, val) in parsed_args
        println("  $key  =>  $(repr(val))")
    end

    return parse_args(s)
    
end

function check_arguments(args::Dict{String,Any})

    #save: is .jld ?
    #model: is implemented ?
    # command ? one ? single ?
	
end
