using System;

namespace Sample.Beef.Chip8;

public struct Chip8Registers
{
    public u8[16] V; // register: V0 ... VF
    public u16 PC; // Program Counter
    public u8 SP; // Stack Pointer
    public u16 I; // Index Register
    public u8 DelayTimer;
    public u8 SoundTimer;

    [Inline] public ref u8 V0 mut => ref V[0x00];
    [Inline] public ref u8 VF mut => ref V[0x0F];
}
