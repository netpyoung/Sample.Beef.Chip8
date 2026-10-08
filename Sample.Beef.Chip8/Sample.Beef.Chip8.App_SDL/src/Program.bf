using System;
using SDL2;
using Sample.Beef.Chip8.App_SDL.Later;
using System.Collections;
using System.IO;
using Sample.Beef.Chip8;

namespace Sample.Beef.Chip8.App_SDL;

static
{
    public static readonly GameClock GAME_CLOCK = new GameClock() ~ delete _;
    public static readonly GameInput GAME_INPUT = new GameInput() ~ delete _;
}

class Keypad : BaseChip8Keypad<SDL.Scancode> { }

class Program
{
    const int CHIP8_WINDOW_MULTIPLIER = 20;
    const int SCREEN_WIDTH = Chip8Display.WIDTH * CHIP8_WINDOW_MULTIPLIER;
    const int SCREEN_HEIGHT = Chip8Display.HEIGHT * CHIP8_WINDOW_MULTIPLIER;
    static readonly String S_TITLE = "Sample.Beef.Chip8.App_SDL";

    static SDL.Scancode[CHIP8_TOTAL_KEYS] S_KEYPAD_MAP =
        .( //
        //.Key1, .Key2, .Key3, .C,
        //.Key4, .Key5, .Key6,  .D,
        //.Key7, .Key8, .Key9, .E,
        //.A, .Key0, .B, .F
        .Key1, .Key2, .Key3, .Key4,
        .Q, .W, .E, .R,
        .A, .S, .D, .F,
        .Z, .X, .C, .V
        );

    public static void Main(String[] args)
    {
        if (args.Count == 0)
        {
            Console.WriteLine($"need rom file path");
            Environment.Exit(1);
        }

        List<u8> romData = scope List<uint8>();
        if (File.ReadAll(args[0], romData) case .Err(let err))
        {
            Console.WriteLine($"err: {err}");
            Environment.Exit(1);
        }

        Keypad keyboard = scope Keypad();
        Chip8Emulator chip8 = scope Chip8Emulator();

        chip8.LoadRomData(romData);
        chip8.InitKeyboard(keyboard);

        keyboard.SetMap(S_KEYPAD_MAP);

        if (SDL.Init(.Everything) != 0)
        {
            Console.Error.WriteLine($"err: {scope String(SDL.GetError())}");
            Environment.Exit(1);
        }
        defer SDL.Quit();

        SDL.SetHint(SDL.SDL_HINT_RENDER_SCALE_QUALITY, "0");

        SDL.Window* window = SDL.CreateWindow(
            S_TITLE,
            .Undefined, .Undefined,
            SCREEN_WIDTH,
            SCREEN_HEIGHT,
            .Shown
            );
        if (window == null)
        {
            Console.Error.WriteLine($"err: {scope String(SDL.GetError())}");
            Environment.Exit(1);
        }
        defer SDL.DestroyWindow(window);


        SDL.Renderer* renderer = SDL.CreateRenderer(window, index: -1, flags: .Accelerated | .PresentVSync);
        if (renderer == null)
        {
            Console.Error.WriteLine($"err: {scope String(SDL.GetError())}");
            Environment.Exit(1);
        }
        defer SDL.DestroyRenderer(renderer);

        SDL.Texture* texture = SDL.CreateTexture(
            renderer,
            SDL.PIXELFORMAT_ABGR8888,
            (.)SDL.TextureAccess.Streaming,
            Chip8Display.WIDTH,
            Chip8Display.HEIGHT
            );
        if (texture == null)
        {
            Console.Error.WriteLine($"err: {scope String(SDL.GetError())}");
            Environment.Exit(1);
        }
        defer SDL.DestroyTexture(texture);

        uint TimerHz = 60;
        uint targetCpuHz = 500;
        double cpuCycleAccumulator = 0.0;
        double fixedDelta = (double)targetCpuHz / TimerHz;

        GAME_CLOCK.Init(targetFps: TimerHz);

        Beefer beefer = .();
        beefer.Init();
        defer beefer.Dispose();

        FRAME_LOOP:while (true)
        {
            GAME_CLOCK.UpdatePerFrameLoop();

            while (SDL.PollEvent(let event) != 0)
            {
                switch (event.type) {
                case .Quit:
                    break FRAME_LOOP;
                case .KeyDown:
                    let k = event.key.keysym.scancode;
                    if (k == .Escape)
                    {
                        break FRAME_LOOP;
                    }

                    let vkey = keyboard.Map(k);
                    if (vkey != -1)
                    {
                        keyboard.Down((E_CHIP8_LAYOUTED_KEY)vkey);
                    }
                case .KeyUp:
                    let k = event.key.keysym.scancode;
                    let vkey = keyboard.Map(k);
                    if (vkey != -1)
                    {
                        keyboard.Up((E_CHIP8_LAYOUTED_KEY)vkey);
                    }
                default:
                }
            }

            // chip8 update
            {
                while (GAME_CLOCK.TryConsumeFixedDeltaTimeSec())
                {
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
                }
            }

            SDL.SetRenderDrawColor(renderer, 0, 0, 0, 0);
            SDL.RenderClear(renderer);

            // chip8 Render
            {
                SDL.UpdateTexture(texture, null, chip8.GetDisplaySpan().Ptr, pitch: Chip8Display.WIDTH * sizeof(uint32));
            }

            SDL.RenderCopy(renderer, texture, null, null);
            SDL.RenderPresent(renderer);
        }
    }

    struct Beefer : IDisposable
    {
        SDL.SDL_AudioSpec _spec;
        SDL.AudioDeviceID _audioDevice;
        List<int16> _buffer;

        public void Init() mut
        {
            SDL.SDL_AudioSpec spec = .();
            spec.freq  = 44100;
            spec.format = SDL.AUDIO_S16SYS;
            spec.channels = 1;
            spec.samples = 2048;

            SDL.AudioDeviceID audioDevice = SDL.OpenAudioDevice(null, 0, ref spec, let obtained, 0);
            if (audioDevice == 0)
            {
                return;
            }
            _spec = spec;
            _audioDevice = audioDevice;
            _buffer =  new List<int16>(10000);
        }

        public void Dispose()
        {
            delete _buffer;
            SDL.CloseAudioDevice((uint32)_audioDevice);
        }

        public void Beep(int frequency, int durationMs)
        {
            int sampleRate = _spec.freq;
            int numSamples = (sampleRate * durationMs) / 1000;

            _buffer.Clear();
            _buffer.Resize(numSamples);

            int16 amplitude = 10000;
            for (int i = 0; i < numSamples; ++i)
            {
                double time = (double)i / sampleRate;
                _buffer[i] = (int16)(amplitude * Math.Sin(2.0 * Math.PI_f * frequency * time));
            }
            SDL.QueueAudio(_audioDevice, _buffer.Ptr, .(_buffer.Count * sizeof(int16)));
            SDL.PauseAudioDevice((uint32)_audioDevice, 0);
        }
    }
}