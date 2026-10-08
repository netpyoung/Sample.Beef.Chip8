using System;

using Sample.Beef.Chip8;
using internal Sample.Beef.Chip8;

namespace Sample.Beef.Chip8.App_SDL.Tests;

class Test_Opcode
{
    [Test]
    public static void Test1()
    {
        Chip8Emulator chip8 = scope Chip8Emulator();
        chip8.vm.registers.PC = 0x00;
        chip8.vm.registers.V[0x00] = 0x22;
        chip8.vm.Execution(0x3022);

        Test.Assert(chip8.vm.registers.PC == 2);
    }

    [Test]
    public static void Test2()
    {
        Chip8Emulator chip8 = scope Chip8Emulator();

        chip8.vm.registers.PC = 0x00;
        chip8.vm.registers.V[2] = 0x10;
        chip8.vm.registers.V[3] = 0x20;
        chip8.vm.Execution(0x5230);
        Test.Assert(chip8.vm.registers.PC == 0);

        chip8.vm.registers.PC = 0x00;
        chip8.vm.registers.V[2] = 0x10;
        chip8.vm.registers.V[3] = 0x10;
        chip8.vm.Execution(0x5230);
        Test.Assert(chip8.vm.registers.PC == 2);
    }
}