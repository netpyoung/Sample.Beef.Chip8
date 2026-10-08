using System.Diagnostics;
using System;

namespace Sample.Beef.Chip8;

[Packed, Union]
public struct Color
{
    struct
    {
        public u8 r;
        public u8 g;
        public u8 b;
        public u8 a;
    };

    public u32 abgr;

    public this(u8 r, u8 g, u8 b, u8 a)
    {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }
}

public struct Chip8Display
{
    // ( 0, 0) --- (63, 0)
    //    |           |
    // ( 0,31) --- (63,31)
    public const int WIDTH = 64;
    public const int HEIGHT = 32;

    //const u32 COLOR_ON = 0xFFFFFFFF; // ABGR
    //const u32 COLOR_OFF = 0xFF000000;

    const Color COLOR_ON =  .(255, 255, 255, 255);
    const Color COLOR_OFF = .(0, 0, 0, 255);

    u32[WIDTH * HEIGHT] _pixels; // 64 * 32 == 256 bytes

    public void SetPixel(int x, int y) mut
    {
        Debug.Assert(0 <= x && x < WIDTH);
        Debug.Assert(0 <= y && y < HEIGHT);

        _pixels[y * WIDTH + x] = COLOR_ON.abgr;
    }

    public bool IsSetPixel(int x, int y)
    {
        Debug.Assert(0 <= x && x < WIDTH);
        Debug.Assert(0 <= y && y < HEIGHT);

        return _pixels[y * WIDTH + x] == COLOR_ON.abgr;
    }

    public Span<u32> GetSpan()
    {
        return _pixels;
    }

    public bool DrawSpriteAt(int x, int y, Span<u8> sprite) mut
    {
        bool isPixelCollision = false;
        for (int ly = 0; ly < sprite.Length; ++ly)
        {
            u8 c = (u8)sprite[ly];
            for (int lx = 0; lx < 8; ++lx)
            {
                if (c & (0b10000000 >> lx) == 0)
                {
                    continue;
                }

                let px = (lx + x) % WIDTH;
                let py = (ly + y) % HEIGHT;
                let idx = py * WIDTH + px;
                if (_pixels[idx] == COLOR_ON.abgr)
                {
                    isPixelCollision = true;
                    _pixels[idx] = COLOR_OFF.abgr;
                }
                else
                {
                    _pixels[idx] = COLOR_ON.abgr;
                }
            }
        }
        return isPixelCollision;
    }

    public void ClearPixels() mut
    {
        _pixels.SetAll(COLOR_OFF.abgr);
    }
}