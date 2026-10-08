using System.Diagnostics;
using System;
using System.Collections;
using SDL2;

namespace Sample.Beef.Chip8.App_SDL.Later;

// onKeyDown -> onKeyPress -> onKeyUp
// -> onMouseDown -> onMousePress -> onMouseUp
class GameInput
{
    bool* currentState = null;
    bool[] previousState = null ~ delete _;
    int32 numKeys = 0;

    uint currentMouseButtons;
    uint previousMouseButtons;

    int32 _mousex;
    int32 _mousey;
    int32 _mouseWheelY;

    public SDL.Point MousePos => .(_mousex, _mousey);

    public void Init()
    {
        Debug.Assert(previousState == null);

        currentState = SDL.GetKeyboardState(&numKeys);
        previousState = new bool[numKeys];
        Internal.MemCpy(previousState.Ptr, currentState, numKeys);

        previousMouseButtons = currentMouseButtons;
        currentMouseButtons = SDL.GetMouseState(out _mousex, out _mousey);
    }

    // NOTE(pyoung): must call before SDL.PollEvent.
    public void UpdatePerFrameLoop()
    {
        Internal.MemCpy(previousState.Ptr, currentState, numKeys);

        previousMouseButtons = currentMouseButtons;
        currentMouseButtons = SDL.GetMouseState(out _mousex, out _mousey);
    }

    public bool GetKey(SDL.Scancode scancode)
    {
        return currentState[(uint32)scancode];
    }

    public bool GetKeyDown(SDL.Scancode scancode)
    {
        return currentState[(uint32)scancode] && !previousState[(uint32)scancode];
    }

    public bool GetKeyUp(SDL.Scancode scancode)
    {
        return !currentState[(uint32)scancode] && previousState[(uint32)scancode];
    }

    public bool GetMouseButtonUp(uint32 button)
    {
        Debug.Assert(button != 0, "button != 0 - https://wiki.libsdl.org/SDL2/SDL_BUTTON");

        uint32 mask = SDL.BUTTON(button);
        bool isCurrentPressed = (currentMouseButtons & mask) != 0;
        bool isPreviousPressed = (previousMouseButtons & mask) != 0;
        return !isCurrentPressed && isPreviousPressed;
    }

    public bool GetMouseButton(uint32 button)
    {
        Debug.Assert(button != 0, "button != 0 - https://wiki.libsdl.org/SDL2/SDL_BUTTON");

        uint32 mask = SDL.BUTTON(button);
        bool isCurrentPressed = (currentMouseButtons & mask) != 0;
        return isCurrentPressed;
    }

    public bool GetMouseButtonDown(uint32 button)
    {
        Debug.Assert(button != 0, "button != 0 - https://wiki.libsdl.org/SDL2/SDL_BUTTON");

        uint32 mask = SDL.BUTTON(button);
        bool isCurrentPressed = (currentMouseButtons & mask) != 0;
        bool isPreviousPressed = (previousMouseButtons & mask) != 0;

        return isCurrentPressed && !isPreviousPressed;
    }

    public void UpdatePerPollEvent(SDL.Event evt)
    {
        _mouseWheelY = 0;
        switch (evt.type) {
        case .MouseWheel:
            if (evt.wheel.direction == (.)SDL.MouseWheelDirection.Flipped)
            {
                _mouseWheelY -= evt.wheel.y;
            }
            else
            {
                _mouseWheelY += evt.wheel.y;
            }
        default:
        }
    }
}