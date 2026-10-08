using System;

namespace Sample.Beef.Chip8;

struct Chip8VM : IDisposable
{
    Random _rand;
    u16[16] stack = .();
    internal Chip8Registers registers = .(); // TODO(pyoung): public to internal
    public BaseChip8Keypad _keyboard;
    Chip8Memory* _memory;
    Chip8Display* _display;

    KeyFn _fnFx0A;

    public void Init(Random rand, Chip8Memory* memory, Chip8Display* display) mut
    {
        _rand = rand;
        _memory = memory;
        _display = display;
        _fnFx0A = new => Fx0A;
    }

    public void Dispose() mut
    {
        delete _fnFx0A;
        _fnFx0A = null;
    }

    u8 _waitingX;
    bool _isWaiting = false;

    void Fx0A(E_CHIP8_LAYOUTED_KEY e_chip8_key) mut
    {
        let x = _waitingX;
        registers.V[x] = (u8)e_chip8_key;
        _isWaiting = false;
    }

    [Inline]
    public void Step() mut
    {
        u16 opcode = FetchOpcode();
        Execution(opcode);
    }

    [Inline]
    void StackPush(u16 val) mut
    {
        stack[registers.SP] = val;
        registers.SP += 1;
    }

    [Inline]
    u16 StackPop() mut
    {
        registers.SP -= 1;
        u16 val = stack[registers.SP];
        return val;
    }

    [Inline]
    u8 FetchU8() mut
    {
        u8 data8 = _memory.PeekU8(registers.PC);
        registers.PC += 1;
        return data8;
    }

    [Inline]
    u16 FetchOpcode() mut
    {
        u8 hi = FetchU8();
        u8 lo = FetchU8();

        u16 opcode = (u16)hi << 8 | (u16)lo;
        return opcode;
    }

    internal void Execution(u16 opcode) mut
    {
        switch (opcode)
        {
        // 00E0 - CLS
        case 0x00'E0:
            _display.ClearPixels();
        // 00EE - RET
        case 0x00'EE:
            u16 addr = StackPop();
            registers.PC = addr;
        default:
            _Execution_Extended(opcode);
        }
    }

    void _Execution_Extended(u16 opcode) mut
    {
        // 0nnn
        // 0xyn
        // 00kk
        u16 nnn = opcode & 0x0F'FF;
        u8 x = (u8)((opcode >> 8) & 0x00'0F);
        u8 y = (u8)((opcode >> 4) & 0x00'0F);
        u8 n = (u8)(opcode & 0x00'0F);
        u8 kk = (u8)(opcode & 0x00'FF);

        switch (opcode >> 12)
        {
        // 1nnn - JP addr
        case 0x1:
            registers.PC = nnn;
        // 2nnn - CALL addr
        case 0x2:
            StackPush(registers.PC);
            registers.PC = nnn;
        // 3xkk - SE Vx, byte
        case 0x3:
            if (registers.V[x] == kk)
            {
                registers.PC += 2;
            }
        // 4xkk - SNE Vx, byte
        case 0x4:
            if (registers.V[x] != kk)
            {
                registers.PC += 2;
            }
        // 5xy0 - SE Vx, Vy
        case 0x5:
            if (registers.V[x] == registers.V[y])
            {
                registers.PC += 2;
            }
        // 6xkk - LD Vx, byte
        case 0x6:
            registers.V[x] = kk;
        // 7xkk - ADD Vx, byte
        case 0x7:
            registers.V[x] += kk;
        case 0x8:
            _Execution_8xy0(opcode);
        // 9xy0 - SNE Vx, Vy
        case 0x9:
            if (registers.V[x] != registers.V[y])
            {
                registers.PC += 2;
            }
        // Annn - LD I, addr
        case 0xA:
            registers.I = nnn;
        // Bnnn - JP V0, addr
        case 0xB:
            registers.PC = nnn + registers.V0;
        // Cxkk - RND Vx, byte
        case 0xC:
            u8 rnd = (u8)(_rand.NextU32() % 256);
            registers.V[x] = rnd & kk;
        // Dxyn - DRW Vx, Vy, nibble
        case 0xD:
            Span<u8> span = _memory.GetSpriteData(registers.I, n);

            bool isPixelCollision = _display.DrawSpriteAt(registers.V[x], registers.V[y], span);
            if (isPixelCollision)
            {
                registers.VF = 1;
            }
            else
            {
                registers.VF = 0;
            }
        // Ex9E - SKP Vx
        // ExA1 - SKNP Vx
        case 0xE:
            switch (opcode & 0x00'FF)
            {
            case 0x00'9E:
                u8 k = registers.V[x];
                if (_keyboard.IsDown(k))
                {
                    registers.PC += 2;
                }
            case 0x00'A1:
                u8 k = registers.V[x];
                if (!_keyboard.IsDown(k))
                {
                    registers.PC += 2;
                }
            default:
                Runtime.FatalError();
            }
        case 0xF:
            _Execution_Fx00(opcode);
        default:
            Runtime.FatalError();
        }
    }

    void _Execution_8xy0(u16 opcode) mut
    {
        u8 x = (u8)((opcode >> 8) & 0x00'0F);
        u8 y = (u8)((opcode >> 4) & 0x00'0F);

        switch (opcode & 0x00'0F)
        {
        // 8xy0 - LD Vx, Vy
        case 0x0:
            registers.V[x] = registers.V[y];
        // 8xy1 - OR Vx, Vy
        case 0x1:
            registers.V[x] |= registers.V[y];
        // 8xy2 - AND Vx, Vy
        case 0x2:
            registers.V[x] &= registers.V[y];
        // 8xy3 - XOR Vx, Vy
        case 0x3:
            registers.V[x] ^= registers.V[y];
        // 8xy4 - ADD Vx, Vy
        case 0x4:
            u16 sum = (u16)registers.V[x] + (u16)registers.V[y];
            registers.V[x] = (u8)sum;
            registers.VF = (sum > 0xFF) ? 1 : 0;
        // 8xy5 - SUB Vx, Vy
        case 0x5:
            u8 vx = registers.V[x];
            u8 vy = registers.V[y];
            u8 flag = (vx >= vy) ? 1 : 0;
            registers.V[x] = vx - vy;
            registers.VF = flag;
        // 8xy6 - SHR Vx {, Vy}
        case 0x6:
            u8 lsb = registers.V[x] & 0x01;
            registers.V[x] >>= 1;
            registers.VF = lsb;
        // 8xy7 - SUBN Vx, Vy
        case 0x7:
            u8 vx = registers.V[x];
            u8 vy = registers.V[y];
            u8 flag = (vy >= vx) ? 1 : 0;
            registers.V[x] = vy - vx;
            registers.VF = flag;
        // 8xyE - SHL Vx {, Vy}
        case 0xE:
            u8 msb = (registers.V[x] & 0x80) >> 7;
            registers.V[x] <<= 1;
            registers.VF = msb;
        default:
            Runtime.FatalError();
        }
    }

    void _Execution_Fx00(u16 opcode) mut
    {
        u8 x = (u8)((opcode >> 8) & 0x00'0F);
        switch (opcode & 0x00'FF)
        {
        // Fx07 - LD Vx, DT
        case 0x07:
            registers.V[x] = registers.DelayTimer;
        // Fx0A - LD Vx, K
        case 0x0A:
            _waitingX = x;
            _isWaiting = true;
            _waitingX = x;
            _keyboard.Hello(_fnFx0A);
           // Fx15 - LD DT, Vx
        case 0x15:
            registers.DelayTimer = registers.V[x];
        // Fx18 - LD ST, Vx
        case 0x18:
            registers.SoundTimer = registers.V[x];
        // Fx1E - ADD I, Vx
        case 0x1E:
            registers.I += registers.V[x];
        // Fx29 - LD F, Vx
        case 0x29:
            registers.I = registers.V[x] * 5; // CHIP8_DEFAULT_SPRITE_HEIGHT = 5;
        // Fx33 - LD B, Vx
        case 0x33:
            u8 hundreds = registers.V[x] / 100;
            u8 tens = (registers.V[x] / 10) % 10;
            u8 unit = registers.V[x] % 10;
            _memory.SetU8(registers.I, hundreds);
            _memory.SetU8(registers.I + 1, tens);
            _memory.SetU8(registers.I + 2, unit);
        // Fx55 - LD [I], Vx
        case 0x55:
            for (int i = 0; i <= x; i++)
            {
                _memory.SetU8(registers.I + i, registers.V[i]);
            }
        // Fx65 - LD Vx, [I]
        case 0x65:
            for (int i = 0; i <= x; i++)
            {
                registers.V[i] = _memory.PeekU8(registers.I + i);
            }
        default:
            Runtime.FatalError();
        }
    }
}
