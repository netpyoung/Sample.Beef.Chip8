using System;
using SDL3;
using System.Collections;
using System.IO;
using Sample.Beef.Chip8;
using Sample.Beef.Chip8.App_SDL.Later;

namespace Sample.Beef.Chip8.App_SDL;

static
{
    public static readonly GameClock GAME_CLOCK = new GameClock() ~ delete _;
}

class Keypad : BaseChip8Keypad<SDL_Scancode> { }

class Program
{
    const int CHIP8_WINDOW_MULTIPLIER = 20;
    const int SCREEN_WIDTH = Chip8Display.WIDTH * CHIP8_WINDOW_MULTIPLIER;
    const int SCREEN_HEIGHT = Chip8Display.HEIGHT * CHIP8_WINDOW_MULTIPLIER;
    static readonly String S_TITLE = "Sample.Beef.Chip8.App_SDL";

    static SDL_Scancode[CHIP8_TOTAL_KEYS] S_KEYPAD_MAP =
        .( //
        //.Key1, .Key2, .Key3, .C,
        //.Key4, .Key5, .Key6,  .D,
        //.Key7, .Key8, .Key9, .E,
        //.A, .Key0, .B, .F
        .SDL_SCANCODE_1, .SDL_SCANCODE_2, .SDL_SCANCODE_3, .SDL_SCANCODE_4,
        .SDL_SCANCODE_Q, .SDL_SCANCODE_W, .SDL_SCANCODE_E, .SDL_SCANCODE_R,
        .SDL_SCANCODE_A, .SDL_SCANCODE_S, .SDL_SCANCODE_D, .SDL_SCANCODE_F,
        .SDL_SCANCODE_Z, .SDL_SCANCODE_X, .SDL_SCANCODE_C, .SDL_SCANCODE_V
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

        if (!SDL_Init(.SDL_INIT_AUDIO | .SDL_INIT_VIDEO | .SDL_INIT_EVENTS))
        {
            Console.Error.WriteLine($"err: {scope String(SDL_GetError())}");
            Environment.Exit(1);
        }
        defer SDL_Quit();


        SDL_Window* window = SDL_CreateWindow(S_TITLE, SCREEN_WIDTH, SCREEN_HEIGHT, 0);
        if (window == null)
        {
            Console.Error.WriteLine($"err: {scope String(SDL_GetError())}");
            Environment.Exit(1);
        }
        defer SDL_DestroyWindow(window);


        SDL_Renderer* renderer = SDL_CreateRenderer(window, null);
        if (renderer == null)
        {
            Console.Error.WriteLine($"err: {scope String(SDL_GetError())}");
            Environment.Exit(1);
        }
        defer SDL_DestroyRenderer(renderer);

        SDL_Texture* texture = SDL_CreateTexture(
            renderer,
            .SDL_PIXELFORMAT_ABGR8888,
            .SDL_TEXTUREACCESS_STREAMING,
            Chip8Display.WIDTH,
            Chip8Display.HEIGHT
            );
        if (texture == null)
        {
            Console.Error.WriteLine($"err: {scope String(SDL_GetError())}");
            Environment.Exit(1);
        }
        defer SDL_DestroyTexture(texture);

        SDL_SetTextureScaleMode(texture, .SDL_SCALEMODE_NEAREST);

        uint TimerHz = 60;
        uint targetCpuHz = 500;
        double cpuCycleAccumulator = 0.0;
        double fixedDelta = (double)targetCpuHz / TimerHz;

        GAME_CLOCK.Init(targetFps: TimerHz);

        Beefer beefer = .();
        beefer.Init();
        defer beefer.Dispose();

        SDL_Event evt = ?;
        FRAME_LOOP:while (true)
        {
            GAME_CLOCK.UpdatePerFrameLoop();

            while (SDL_PollEvent(&evt))
            {
                switch ((SDL_EventType)evt.type) {
                case .SDL_EVENT_QUIT:
                    break FRAME_LOOP;
                case .SDL_EVENT_KEY_DOWN:
                    let k = evt.key.scancode;
                    if (k == .SDL_SCANCODE_ESCAPE)
                    {
                        break FRAME_LOOP;
                    }

                    let vkey = keyboard.Map(k);
                    if (vkey != -1)
                    {
                        keyboard.Down((E_CHIP8_LAYOUTED_KEY)vkey);
                    }
                case .SDL_EVENT_KEY_UP:
                    let k = evt.key.scancode;
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

            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
            SDL_RenderClear(renderer);

            // chip8 Render
            {
                SDL_UpdateTexture(texture, null, chip8.GetDisplaySpan().Ptr, pitch: Chip8Display.WIDTH * sizeof(uint32));
            }

            SDL_RenderTexture(renderer, texture, null, null);
            SDL_RenderPresent(renderer);
        }
    }

    struct Beefer : IDisposable
    {
        SDL_AudioSpec _spec;
        SDL_AudioStream* _audioStream;
        List<int16> _buffer;

        public void Init() mut
        {
            SDL_AudioSpec spec = .();
            spec.freq  = 44100;
            spec.format = .SDL_AUDIO_S16;
            spec.channels = 1;

            SDL_AudioStream* stream = SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, null, null);
            if (stream == null)
            {
                return;
            }

            _spec = spec;
            _audioStream = stream;
            _buffer =  new List<int16>(10000);
            SDL_ResumeAudioStreamDevice(_audioStream);
        }

        public void Dispose()
        {
            delete _buffer;
            SDL_DestroyAudioStream(_audioStream);
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

            int queuedBytes = SDL_GetAudioStreamQueued(_audioStream);
            if (queuedBytes <= 8192 * 4)
            {
                SDL_PutAudioStreamData(_audioStream, _buffer.Ptr, .(_buffer.Count * sizeof(int16)));
            }
        }
    }
}