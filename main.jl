using Debugger, Graphics, Gtk
include("chip8.jl")

GFX_SCALE = 10

KEY_MAP = Dict(
    49  => 0x1, 50  => 0x2, 51  => 0x3, 52  => 0xC,
    113 => 0x4, 119 => 0x5, 101 => 0x6, 114 => 0xD,
    97  => 0x7, 115 => 0x8, 100 => 0x9, 102 => 0xE,
    122 => 0xA, 120 => 0x0, 99  => 0xB, 118 => 0xF
)

function draw_canvas(chip, c)
    # Clear canvas
    @guarded draw(c) do widget
        ctx = getgc(c)
        rectangle(ctx, 0, 0, width(c), height(c))
        set_source_rgb(ctx, 1, 1, 1)
        fill(ctx)
    end

    gfx_array = chip.gfx
    # for i in 0:63
    #     for j in 0:31
    #         if gfx_array[i, j] == 1
    #             @guarded draw(c) do widget
    #                 ctx = getgc(c)
    #                 x = i*GFX_SCALE
    #                 y = j*GFX_SCALE
    #             
    #                 # Draw pixel
    #                 rectangle(ctx, x, y, GFX_SCALE, GFX_SCALE)
    #                 set_source_rgb(ctx, 0, 0, 0)
    #                 fill(ctx)
    #             end
    #         end
    #     end
    # end

    @guarded draw(c) do widget
        ctx = getgc(c)
        for i in 0:63
            for j in 0:31
                x = i*GFX_SCALE
                y = j*GFX_SCALE

                if gfx_array[i, j] == 1
                    # Draw pixel
                    rectangle(ctx, x, y, GFX_SCALE, GFX_SCALE)
                    set_source_rgb(ctx, 0, 0, 0)
                    fill(ctx)
                end
            end
        end
    end
end

function main(rom)
    f = open(rom)
    program = []
    while !eof(f)
        push!(program, read(f, UInt8))
    end
    
    chip = initialise(program)

    c = @GtkCanvas()
    win = GtkWindow(c, "Canvas", 64*GFX_SCALE, 32*GFX_SCALE)
    show(c)

    signal_connect(win, "key-press-event") do widget, event
        println(KEY_MAP[event.keyval])
        chip.key[KEY_MAP[event.keyval]] = 1
    end

    signal_connect(win, "key-release-event") do widget, event
        chip.key[KEY_MAP[event.keyval]] = 0
    end

    while true
        chip = emulateCycle(chip)
        if chip.draw_flag
            draw_canvas(chip, c)
            chip.draw_flag = false
        end
        # println("0x$(string(chip.opcode, base=16)), 0x$(string(chip.pc, base=16))")
        sleep(0.002)
    end
end

# main("roms/test_opcode.ch8")
# main("roms/bitmap.ch8")
# main("roms/Keypad Test [Hap, 2006].ch8")
main("roms/Space Invaders [David Winter].ch8")
