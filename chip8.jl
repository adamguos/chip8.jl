using OffsetArrays
using Parameters

@with_kw mutable struct Chip8
    # V:     CPU registers V0-VF
    # I:     index register
    # pc:    program counter
    # gfx:   graphical display
    # stack: stores program state before jumping or calling subroutine
    # sp:    stack pointer
    # key:   keypad

    opcode::UInt16             = 0
    memory::OffsetArray{UInt8} = fill!(OffsetArray{UInt8}(undef, 0:4095), 0)

    V::OffsetArray{UInt8}      = fill!(OffsetArray{UInt8}(undef, 0:15), 0)
    I::UInt16                  = 0
    pc::UInt16                 = 0x200
    gfx::OffsetArray{UInt8}    = fill!(OffsetArray{UInt8}(undef, 0:63, 0:31), 0)
    delay_timer::UInt16        = 0
    sound_timer::UInt16        = 0
    stack::OffsetArray{UInt16} = fill!(OffsetArray{UInt16}(undef, 0:15), 0)
    sp::UInt16                 = 0
    key::OffsetArray{UInt8}    = fill!(OffsetArray{UInt8}(undef, 0:15), 0)
    draw_flag::Bool            = false
end

function initialise(program)
    chip = Chip8()

    chip8_fontset = UInt8.([
        0xF0, 0x90, 0x90, 0x90, 0xF0, # 0
        0x20, 0x60, 0x20, 0x20, 0x70, # 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, # 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, # 3
        0x90, 0x90, 0xF0, 0x10, 0x10, # 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, # 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, # 6
        0xF0, 0x10, 0x20, 0x40, 0x40, # 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, # 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, # 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, # A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, # B
        0xF0, 0x80, 0x80, 0x80, 0xF0, # C
        0xE0, 0x90, 0x90, 0x90, 0xE0, # D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, # E
        0xF0, 0x80, 0xF0, 0x80, 0x80  # F
    ])

    # Load fontset
    for i in 0:79
        chip.memory[i+80] = chip8_fontset[i+1];
    end

    # Load program
    for i in 0:(size(program, 1) - 1)
        chip.memory[i + 0x200] = program[i + 1]
    end

    return chip
end

function emulateCycle(chip)
    # Fetch opcode
    chip.opcode = UInt16(chip.memory[chip.pc]) << 8 | chip.memory[chip.pc + 1]

    # println("0x$(string(chip.opcode, base=16)), 0x$(string(chip.pc, base=16))\n")

    # Decode and execute opcode
    if chip.opcode == 0x00E0                # 0x00E0: clears the screen
        chip.gfx = fill!(OffsetArray{UInt8}(undef, 0:63, 0:31), 0)
        chip.pc += 2
    elseif chip.opcode == 0x00EE            # 0x00EE: returns from a subroutine
        chip.sp -= 1
        # chip.pc = chip.stack[chip.sp]
        chip.pc = chip.stack[chip.sp] + 2
    elseif chip.opcode & 0xF000 == 0x1000   # 0x1nnn: jump to location nnn
        chip.pc = chip.opcode & 0x0FFF
    elseif chip.opcode & 0xF000 == 0x2000   # 0x2nnn: calls subroutine at address nnn
        chip.stack[chip.sp] = chip.pc
        chip.sp += 1
        chip.pc = chip.opcode & 0x0FFF
    elseif chip.opcode & 0xF000 == 0x3000   # 0x3xkk: skip next instruction if Vx = kk
        if chip.V[(chip.opcode & 0x0F00) >> 8] == chip.opcode & 0x00FF
            chip.pc += 4
        else
            chip.pc += 2
        end
    elseif chip.opcode & 0xF000 == 0x4000   # 0x4xkk: skip next instruction if Vx != kk
        if chip.V[(chip.opcode & 0x0F00) >> 8] != chip.opcode & 0x00FF
            chip.pc += 4
        else
            chip.pc += 2
        end
    elseif chip.opcode & 0xF00F == 0x5000   # 0x5xy0: skip next instruction if Vx = Vy
        if chip.V[(chip.opcode & 0x0F00) >> 8] == chip.V[(chip.opcode & 0x00F0) >> 4]
            chip.pc += 4
        else
            chip.pc += 2
        end
    elseif chip.opcode & 0xF000 == 0x6000   # 0x6xkk: set Vx = kk
        chip.V[(chip.opcode & 0x0F00) >> 8] = chip.opcode & 0x00FF
        chip.pc += 2
    elseif chip.opcode & 0xF000 == 0x7000   # 0x7xkk: set Vx = Vx + kk
        chip.V[(chip.opcode & 0x0F00) >> 8] += UInt8(chip.opcode & 0x00FF)
        chip.pc += 2
    elseif chip.opcode & 0xF00F == 0x8000   # 0x8xy0: set Vx = Vy
        chip.V[(chip.opcode & 0x0F00) >> 8] = chip.V[(chip.opcode & 0x00F0) >> 4]
        chip.pc += 2
    elseif chip.opcode & 0xF00F == 0x8001   # 0x8xy1: set Vx = Vx or Vy
        chip.V[(chip.opcode & 0x0F00) >> 8] = chip.V[(chip.opcode & 0x0F00) >> 8] |
                chip.V[(chip.opcode & 0x00F0) >> 4]
        chip.pc += 2
    elseif chip.opcode & 0xF00F == 0x8002   # 0x8xy2: set Vx = Vx and Vy
        chip.V[(chip.opcode & 0x0F00) >> 8] = chip.V[(chip.opcode & 0x0F00) >> 8] &
                chip.V[(chip.opcode & 0x00F0) >> 4]
        chip.pc += 2
    elseif chip.opcode & 0xF00F == 0x8003   # 0x8xy3: set Vx = Vx xor Vy
        chip.V[(chip.opcode & 0x0F00) >> 8] = chip.V[(chip.opcode & 0x0F00) >> 8] ⊻
                chip.V[(chip.opcode & 0x00F0) >> 4]
        chip.pc += 2
    elseif chip.opcode & 0xF00F == 0x8004   # 0x8xy4: set Vx = Vx + Vy, set VF = carry
        if chip.V[(chip.opcode & 0x00F0) >> 4] > 0xFF - chip.V[(chip.opcode & 0x0F00) >> 8]
            chip.V[0xF] = 1 # carry
        else
            chip.V[0xF] = 0
        end
        chip.V[(chip.opcode & 0x0F00) >> 8] += chip.V[(chip.opcode & 0x00F0) >> 4]
        chip.pc += 2
    elseif chip.opcode & 0xF00F == 0x8005   # 0x8xy5: set Vx = Vx - Vy, set VF = not borrow
        if chip.V[(chip.opcode & 0x00F0) >> 4] > chip.V[(chip.opcode & 0x0F00) >> 8]
            chip.V[0xF] = 0 # borrow
        else
            chip.V[0xF] = 1
        end
        chip.V[(chip.opcode & 0x0F00) >> 8] -= chip.V[(chip.opcode & 0x00F0) >> 4]
        chip.pc += 2
    elseif chip.opcode & 0xF00F == 0x8006   # 0x8xy6: set Vx = Vx >> 1, set VF = 1 if Vx is odd
        if chip.V[(chip.opcode & 0x0F00) >> 8] & 0x0001 == 0x0001
            chip.V[0xF] = 1 # Vx is odd
        else
            chip.V[0xF] = 0
        end
        chip.V[(chip.opcode & 0x0F00) >> 8] >>= 1
        chip.pc += 2
    elseif chip.opcode & 0xF00F == 0x8007   # 0x8xy7: set Vx = Vy - Vx, set VF = not borrow
        if chip.V[(chip.opcode & 0x0F00) >> 8] > chip.V[(chip.opcode & 0x00F0) >> 4]
            chip.V[0xF] = 0 # borrow
        else
            chip.V[0xF] = 1
        end
        chip.V[(chip.opcode & 0x0F00) >> 8] = chip.V[(chip.opcode & 0x00F0) >> 4] -
                chip.V[(chip.opcode & 0x0F00) >> 8]
        chip.pc += 2
    elseif chip.opcode & 0xF00F == 0x800E   # 0x8xyE: Vx = Vx << 1, set VF = 1 if overflow
        if chip.V[(chip.opcode & 0x0F00) >> 8] & 0x8000 == 0x8000
            chip.V[0xF] = 1
        else
            chip.V[0xF] = 0
        end
        chip.V[(chip.opcode & 0x0F00) >> 8] <<= 1
        chip.pc += 2
    elseif chip.opcode & 0xF00F == 0x9000   # 0x9xy0: skip next instruction if Vx != Vy
        if chip.V[(chip.opcode & 0x0F00) >> 8] != chip.V[(chip.opcode & 0x00F0) >> 4]
            chip.pc += 4
        else
            chip.pc += 2
        end
    elseif chip.opcode & 0xF000 == 0xA000   # 0xAnnn: set I = nnn
        chip.I = chip.opcode & 0x0FFF
        chip.pc += 2
    elseif chip.opcode & 0xF000 == 0xB000   # 0xBnnn: jump to location nnn + V0
        chip.pc = (chip.opcode & 0x0FFF) + chip.V[0x0]
    elseif chip.opcode & 0xF000 == 0xC000   # 0xCxkk: set Vx = random byte and kk
        chip.V[(chip.opcode & 0x0F00) >> 8] = rand(UInt8) + (chip.opcode & 0x00FF)
        chip.pc += 2
    elseif chip.opcode & 0xF000 == 0xD000   # 0xDxyn: display n-byte sprite starting at memory
                                            # location I at (Vx, Vy), set VF = collision
        x = chip.V[(chip.opcode & 0x0F00) >> 8]
        y = chip.V[(chip.opcode & 0x00F0) >> 4]
        height = chip.opcode & 0x000F
        pixel::UInt8 = 0

        chip.V[0xF] = 0
        for yline in 0:(height-1)
            pixel = chip.memory[chip.I + yline]
            for xline in 0:7
                if pixel & (0x80 >> xline) != 0
                    if chip.gfx[x + xline, y + yline] == 1
                        chip.V[0xF] = 1
                    end
                    chip.gfx[x + xline, y + yline] ⊻= 1
                end
            end
        end

        chip.draw_flag = true
        chip.pc += 2
    elseif chip.opcode & 0xF0FF == 0xE09E   # 0xEx9E: skip next instruction if key with the value of
                                            # Vx is pressed
        if chip.key[chip.V[(chip.opcode & 0x0F00) >> 8]] != 0
            chip.pc += 4
        else
            chip.pc += 2
        end
    elseif chip.opcode & 0xF0FF == 0xE0A1   # 0xExA1: skip next instruction if key with the value of
                                            # Vx is not pressed
        if chip.key[chip.V[(chip.opcode & 0x0F00) >> 8]] == 0
            chip.pc += 4
        else
            chip.pc += 2
        end
    elseif chip.opcode & 0xF0FF == 0xF007   # 0xFx07: set Vx = delay timer value
        chip.V[(chip.opcode & 0x0F00) >> 8] = chip.delay_timer
        chip.pc += 2
    elseif chip.opcode & 0xF0FF == 0xF00A   # 0xFx0A: wait for a key press, store the value of the
                                            # key in Vx
        waiting = true
        while waiting
            for i in 0:15
                if chip.key[i] != 0
                    chip.V[(chip.opcode & 0x0F00) >> 8] = i
                    waiting = false
                    break
                end
            end
        end
        chip.pc += 2
    elseif chip.opcode & 0xF0FF == 0xF015   # 0xFx15: set delay timer = Vx
        chip.delay_timer = chip.V[(chip.opcode & 0x0F00) >> 8]
        chip.pc += 2
    elseif chip.opcode & 0xF0FF == 0xF018   # 0xFx18: set sound timer = Vx
        chip.sound_timer = chip.V[(chip.opcode & 0x0F00) >> 8]
        chip.pc += 2
    elseif chip.opcode & 0xF0FF == 0xF01E   # 0xFx1E: set I = I + Vx
        chip.I += chip.V[(chip.opcode & 0x0F00) >> 8]
        chip.pc += 2
    elseif chip.opcode & 0xF0FF == 0xF029   # 0xFx29: set I = location of sprite for digit Vx
        chip.I = chip.V[(chip.opcode & 0x0F00) >> 8] * 5
        chip.pc += 2
    elseif chip.opcode & 0xF0FF == 0xF033   # 0xFx33: store BCD representation of Vx in memory
                                            # locations I, I+1, and I+2
        chip.memory[chip.I] = div(chip.V[(chip.opcode & 0x0F00) >> 8], 100)
        chip.memory[chip.I+1] = div(chip.V[(chip.opcode & 0x0F00) >> 8], 10) % 10
        chip.memory[chip.I+2] = (chip.V[(chip.opcode & 0x0F00) >> 8] % 100) % 10
        chip.pc += 2
    elseif chip.opcode & 0xF0FF == 0xF055   # 0xFx55: store registers V0 through Vx in memory
                                            # starting at location I
        for i in 0:((chip.opcode & 0x0F00) >> 8)
            chip.memory[chip.I + i] = chip.V[i]
        end
        chip.pc += 2
    elseif chip.opcode & 0xF0FF == 0xF065   # 0xFx65: read registers V0 through Vx from memory
                                            # starting at location I
        for i in 0:((chip.opcode & 0x0F00) >> 8)
            chip.V[i] = chip.memory[chip.I + i]
        end
        chip.pc += 2
    else
        print("Unknown opcode: 0x$(string(chip.opcode, base=16))\n")
    end

    # Update timers
    if chip.delay_timer > 0
        chip.delay_timer -= 1
    end

    if chip.sound_timer > 0
        if chip.sound_timer == 1
            print("beep!\n")
        end
        chip.sound_timer -= 1
    end

    return chip
end
