using System.Collections;
using System;
namespace Sample.Beef.Chip8;


public enum E_CHIP8_LAYOUTED_KEY
{
    K_1, K_2, K_3, K_C,
    K_4, K_5, K_6, K_D,
    K_7, K_8, K_9, K_E,
    K_A, K_0, K_B, K_F,
}

typealias KeyFn = delegate void(E_CHIP8_LAYOUTED_KEY e_chip8_key);

public class BaseChip8Keypad
{
    protected bool[CHIP8_TOTAL_KEYS] keyboard;
    Dictionary<u8, E_CHIP8_LAYOUTED_KEY> _dic = new Dictionary<uint8, E_CHIP8_LAYOUTED_KEY>(CHIP8_TOTAL_KEYS);

    public this()
    {
        _dic[0x00] = .K_0;
        _dic[0x01] = .K_1;
        _dic[0x02] = .K_2;
        _dic[0x03] = .K_3;
        _dic[0x04] = .K_4;
        _dic[0x05] = .K_5;
        _dic[0x06] = .K_6;
        _dic[0x07] = .K_7;
        _dic[0x08] = .K_8;
        _dic[0x09] = .K_9;
        _dic[0x0A] = .K_A;
        _dic[0x0B] = .K_B;
        _dic[0x0C] = .K_C;
        _dic[0x0D] = .K_D;
        _dic[0x0E] = .K_E;
        _dic[0x0F] = .K_F;
    }

    public ~this()
    {
        delete _dic;
    }

    public void Down(E_CHIP8_LAYOUTED_KEY key)
    {
        keyboard[(int)key] = true;
        if (_fn != null)
        {
            _fn((.)key);
            _fn = null;
        }
    }

    public void Up(E_CHIP8_LAYOUTED_KEY key)
    {
        keyboard[(int)key] = false;
    }

    public bool IsDown(u8 vx)
    {
        E_CHIP8_LAYOUTED_KEY key = _dic[vx];
        return keyboard[(uint)key];
    }

    KeyFn _fn = null;

    public void Hello(KeyFn fn)
    {
        _fn = fn;
    }

}

public class BaseChip8Keypad<T> : BaseChip8Keypad
{
    Span<T> _keyMap;

    public void SetMap(Span<T> map)
    {
        _keyMap = map;
    }

    public i8 Map(T key)
    {
        for (i8 i = 0; i < keyboard.Count; ++i)
        {
            if (_keyMap[i] == key)
            {
                return i;
            }
        }
        return -1;
    }
}