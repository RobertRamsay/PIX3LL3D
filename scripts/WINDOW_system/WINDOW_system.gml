/// WINDOW_system
/// Fullscreen / windowed switching, without exclusive fullscreen.
///
/// WHY NOT window_set_fullscreen: it asks DirectX for a real display mode
/// change, which tears down and rebuilds the swap chain. Going INTO fullscreen
/// that way fails on this project with
///   "CreateSwapChain (legacy fallback) - HRESULT 0x80070005 Access is denied"
/// and sometimes takes the runtime down with an access violation. Giving the
/// window a border made that path more fragile still, and the room is
/// 3840x2160 while the display is 1080p, so the mode it wants may not exist.
/// Spacing the calls out did not help, because a single window_set_fullscreen
/// is enough to trigger it - there is nothing left to space out.
///
/// So "fullscreen" here is a borderless window filling the display, which is
/// what most desktop apps actually do. No mode change, no swap chain rebuild,
/// no flicker, and alt-tab behaves better. window_set_fullscreen is never
/// called, so window_get_fullscreen() stays false - win_is_full is the real
/// state and the menu tick reads that.
///
/// The window rectangle is still applied a few frames after the border change,
/// one call at a time, to keep window operations from stacking up in a frame.

#macro WINDOW_DEFAULT_W 1600
#macro WINDOW_DEFAULT_H 900
#macro WINDOW_COOLDOWN_FRAMES 15
#macro WINDOW_SETTLE_FRAMES 3

/// @desc Borderless, filling the display.
function window_go_fullscreen()
{
    win_is_full = true;
    window_set_showborder(false);
    win_settle = WINDOW_SETTLE_FRAMES;
}

/// @desc Bordered and resizable, back at the remembered size.
function window_go_windowed()
{
    win_is_full = false;
    window_set_showborder(true);
    win_settle = WINDOW_SETTLE_FRAMES;
}

/// @desc F10 / View > Fullscreen.
function window_toggle_fullscreen()
{
    if (win_cooldown > 0)
    {
        return; // still settling from the last one
    }
    win_cooldown = WINDOW_COOLDOWN_FRAMES;

    if (win_is_full)
    {
        window_go_windowed();
        return;
    }

    // Remember the window we are leaving so F10 brings it back
    win_last_w = window_get_width();
    win_last_h = window_get_height();
    window_go_fullscreen();
}

/// @desc Per-frame window housekeeping. Call once, first thing in Step.
function window_update()
{
    if (win_cooldown > 0)
    {
        win_cooldown -= 1;
    }

    if (win_settle <= 0)
    {
        return;
    }

    win_settle -= 1;
    if (win_settle > 0)
    {
        return;
    }

    // One call does position and size together
    if (win_is_full)
    {
        window_set_rectangle(0, 0, display_get_width(), display_get_height());
        return;
    }

    var _dw = display_get_width();
    var _dh = display_get_height();
    var _w = clamp(win_last_w, 640, max(_dw - 80, 640));
    var _h = clamp(win_last_h, 480, max(_dh - 120, 480));

    window_set_rectangle(round((_dw - _w) * 0.5), round((_dh - _h) * 0.5), _w, _h);
}
