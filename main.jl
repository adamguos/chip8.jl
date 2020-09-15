using ArgParse
include("emu_cycle.jl")

function main()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "rom"
            help = "path to Chip8 ROM binary"
            required = true
    end

    parsed_args = parse_args(s)
    path = parsed_args["rom"]

    if isfile(path)
        emu_cycle(path)
    else
        throw(ErrorException("Path to ROM does not exist"))
    end
end

main()
