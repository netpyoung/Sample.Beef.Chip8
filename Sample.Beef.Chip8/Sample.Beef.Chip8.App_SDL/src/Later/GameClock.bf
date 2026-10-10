using SDL3;
using System;

namespace Sample.Beef.Chip8.App_SDL.Later;

// todo accmulate tick / delta tick

class GameClock
{
    uint64 _performanceFrequency;
    uint64 _performanceCounter_curr;
    uint64 _performanceCounter_prev;

    float _accumulatorForFixedDeltaTime;
    float _accumulatorForFps;
    uint _frameCount;

    public float CurrentFps { get; private set; }
    public uint TargetFps { get; private set; }
    public float DeltaTimeSec { get; private set; }
    public float FixedDeltaTimeSec { get; private set; }
    public bool IsFpsUpdated { get; private set; }
    public float Alpha;

    [Inline]
    public void Init(uint targetFps)
    {
        TargetFps = targetFps;
        FixedDeltaTimeSec = 1.0f / targetFps;

        _performanceFrequency = SDL_GetPerformanceFrequency();
        _performanceCounter_curr = SDL_GetPerformanceCounter();
        _performanceCounter_prev = _performanceCounter_curr;
    }

    [Inline]
    public void UpdatePerFrameLoop()
    {
        _performanceCounter_curr = SDL_GetPerformanceCounter();
        let diff = _performanceCounter_curr - _performanceCounter_prev;
        _performanceCounter_prev = _performanceCounter_curr;

        DeltaTimeSec = (float)diff / (float)_performanceFrequency;

        //// to prevent Spiral of Death
        //const float MIN_DELTA_TIME_SEC = 0.25f;
        //DeltaTimeSec = Math.Min(DeltaTimeSec, MIN_DELTA_TIME_SEC);

        _accumulatorForFixedDeltaTime += DeltaTimeSec;
        _accumulatorForFps += DeltaTimeSec;

        _frameCount++;

        IsFpsUpdated = _accumulatorForFps >= 1.0f;

        if (IsFpsUpdated)
        {
            CurrentFps = (float)_frameCount  / _accumulatorForFps;
            _frameCount = 0;
            _accumulatorForFps -= 1.0f;
        }
    }

    [Inline]
    public bool TryConsumeFixedDeltaTimeSec()
    {
        if (_accumulatorForFixedDeltaTime >= FixedDeltaTimeSec)
        {
            _accumulatorForFixedDeltaTime -= FixedDeltaTimeSec;
            return true;
        }

        Alpha = _accumulatorForFixedDeltaTime / FixedDeltaTimeSec;
        return false;
    }
}