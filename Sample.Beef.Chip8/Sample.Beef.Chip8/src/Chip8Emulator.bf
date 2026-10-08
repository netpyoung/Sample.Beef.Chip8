using System;

namespace Sample.Beef.Chip8;

public class Chip8Emulator
{
    public Chip8VM vm;
    Chip8Memory memory;
    Chip8Display display;
    Random _rand;
    BaseChip8Keypad _keypad;

    public ref u8 DelayTimer => ref vm.[Friend]registers.DelayTimer;
    public ref u8 SoundTimer => ref vm.[Friend]registers.SoundTimer;

    public this(int seed = 100)
    {
        _rand = new Random(seed);
        memory.Init();
        vm.Init(_rand, &memory, &display);
    }

    public ~this()
    {
        vm.Dispose();
        delete _rand;
    }

    public void LoadRomData(Span<u8> romData)
    {
        memory.WriteFromRomData(romData);
        vm.[Friend]registers.PC = Chip8Memory.ADDRESS.ADDR_PROGRAM_LOAD;
    }

    public void InitKeyboard(BaseChip8Keypad ikeyboard)
    {
        _keypad = ikeyboard;
        vm._keyboard = ikeyboard;
    }

    public void Step()
    {
        if (vm.[Friend]_isWaiting)
        {
            return;
        }

        vm.Step();
    }

    public bool IsSetPixel(int x, int y)
    {
        return display.IsSetPixel(x, y);
    }

    public Span<u32> GetDisplaySpan()
    {
        return display.GetSpan();
    }
}