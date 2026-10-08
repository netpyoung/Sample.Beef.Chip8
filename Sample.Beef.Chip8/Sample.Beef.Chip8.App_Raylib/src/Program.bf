using System;
using RaylibBeef;
using System.Threading;
using System.Collections;
using System.IO;

namespace Sample.Beef.Chip8.App_Raylib;

class Keypad : BaseChip8Keypad<KeyboardKey> { }

class Program
{
    const int CHIP8_WINDOW_MULTIPLIER = 20;
    const int SCREEN_WIDTH = Chip8Display.WIDTH * CHIP8_WINDOW_MULTIPLIER;
    const int SCREEN_HEIGHT = Chip8Display.HEIGHT * CHIP8_WINDOW_MULTIPLIER;
    static readonly String S_TITLE = "Sample.Beef.Chip8.App_Raylib";

    const KeyboardKey[CHIP8_TOTAL_KEYS] _keyMap =
        .( //
        //.KEY_ONE, .KEY_TWO, .KEY_THREE, .KEY_C,
        //.KEY_FOUR, .KEY_FIVE, .KEY_SIX, .KEY_D,
        //.KEY_SEVEN, .KEY_EIGHT, .KEY_NINE, .KEY_E,
        //.KEY_A, .KEY_ZERO, .KEY_B, .KEY_F

        .KEY_ONE, .KEY_TWO, .KEY_THREE, .KEY_FOUR,
        .KEY_Q, .KEY_W, .KEY_E, .KEY_R,
        .KEY_A, .KEY_S, .KEY_D, .KEY_F,
        .KEY_Z, .KEY_X, .KEY_C, .KEY_V
        );

    public static void Main(String[] args)
    {
        if (args.Count == 0)
        {
            Console.WriteLine($"need rom file path");
            Environment.Exit(1);
        }

        List<u8> romData = scope List<u8>();
        if (File.ReadAll(args[0], romData) case .Err(let err))
        {
            Console.WriteLine($"err: {err}");
            Environment.Exit(1);
        }

        Raylib.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, S_TITLE);
        defer Raylib.CloseWindow();

        Raylib.SetTargetFPS(60);

        Keypad keyboard = scope Keypad();
        Chip8Emulator chip8 = scope Chip8Emulator();
        chip8.LoadRomData(romData);
        chip8.InitKeyboard(keyboard);
        Keypad keypad = scope Keypad();
        keypad.SetMap(_keyMap);
        chip8.InitKeyboard(keypad);

        Image image = .(chip8.GetDisplaySpan().Ptr, Chip8Display.WIDTH, Chip8Display.HEIGHT, mipmaps: 1, rlPixelFormat.RL_PIXELFORMAT_UNCOMPRESSED_R8G8B8A8);

        Texture2D texture = Raylib.LoadTextureFromImage(image);
        defer Raylib.UnloadTexture(texture);

        Raylib.SetTextureFilter(texture, rlTextureFilter.RL_TEXTURE_FILTER_POINT);


        uint TimerHz = 60;
        uint targetCpuHz = 500;
        double cpuCycleAccumulator = 0.0;
        double fixedDelta = (double)targetCpuHz / TimerHz;
        Beefer beefer = .();
        beefer.Init();
        defer beefer.Dispose();

        // Raylib.SetExitKey(.KEY_ESCAPE); // default is .KEY_ESCAPE
        // Raylib.SetExitKey(.KEY_NULL);   // prevent from escape key
        while (!Raylib.WindowShouldClose())
        {
            for (let k in _keyMap)
            {
                let index = keypad.Map(k);
                if (index < 0)
                {
                    continue;
                }
                if (Raylib.IsKeyDown(k))
                {
                    keypad.Down((E_CHIP8_LAYOUTED_KEY)index);
                }
                if (Raylib.IsKeyUp(k))
                {
                    keypad.Up((E_CHIP8_LAYOUTED_KEY)index);
                }
            }

            if (chip8.DelayTimer > 0)
            {
                chip8.DelayTimer -= 1;
            }

            if (chip8.SoundTimer > 0)
            {
                float sec = chip8.SoundTimer / 60.0f;
                float millisec = sec * 1000;
                beefer.Beep(1500, (int)millisec);

                chip8.SoundTimer = 0;
            }

            cpuCycleAccumulator += fixedDelta;

            while (cpuCycleAccumulator >= 1.0)
            {
                chip8.Step();
                cpuCycleAccumulator -= 1.0;
            }

            Raylib.UpdateTexture(texture, chip8.GetDisplaySpan().Ptr);

            Raylib.BeginDrawing();
            Raylib.ClearBackground(Raylib.BLACK);

            Raylib.DrawTexturePro(
                texture,
                .(0, 0, Chip8Display.WIDTH, Chip8Display.HEIGHT),
                .(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT),
                .(0, 0), 0.0f, Raylib.WHITE
                );

            Raylib.DrawFPS(20, 20);

            Raylib.EndDrawing();
        }
    }

    struct Beefer : IDisposable
    {
        AudioStream _stream;
        List<int16> _buffer;

        public void Init() mut
        {
            Raylib.InitAudioDevice();
            Raylib.SetAudioStreamBufferSizeDefault(65536);
            _stream = Raylib.LoadAudioStream(44100, 16, 1);
            _buffer = new List<int16>(10000);

            Raylib.SetAudioStreamVolume(_stream, 1.0f);
            Raylib.PlayAudioStream(_stream);
        }

        public void Dispose()
        {
            delete _buffer;
            Raylib.UnloadAudioStream(_stream);
            Raylib.CloseAudioDevice();
        }

        public void Beep(int frequency, int durationMs)
        {
            int sampleRate = 44100;
            int numSamples = (sampleRate * durationMs) / 1000;

            _buffer.Clear();
            _buffer.Resize(numSamples);

            int16 amplitude = 18000;
            for (int i = 0; i < numSamples; ++i)
            {
                double time = (double)i / sampleRate;
                _buffer[i] = (int16)(amplitude * Math.Sin(2.0 * Math.PI_f * frequency * time));
            }
            Raylib.UpdateAudioStream(_stream, _buffer.Ptr, (int32)_buffer.Count);
        }
    }
}