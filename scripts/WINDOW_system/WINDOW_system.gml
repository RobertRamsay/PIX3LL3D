/// WINDOW_system
/// Fullscreen / windowed switching.
///
/// The editor starts fullscreen. F10 (or View > Fullscreen) drops it to a
/// bordered, resizable window and F10 again puts it back. The windowed size
/// is remembered across toggles.
///
/// IMPORTANT: every fullscreen change makes DirectX tear down and rebuild the
/// swap chain, and that takes several frames to settle. Asking for a second
/// window change while the first is still in flight makes the runtime fight
/// itself - the log shows "was: 1, want: 0" immediately followed by
/// "was: 0, want: 1" - and it can fail outright with
/// "CreateSwapChain (legacy fallback) - Access is denied".
///
/// So this does exactly ONE window operation per frame, spread over a short
/// countdown, and refuses a new toggle until the last one has settled.
///
/// The application surface is deliberately NOT touched here. GameMaker
/// resizes it with the window on its own, and a manual surface_resize landing
/// in the middle of a swap chain rebuild is what broke this the first time.

#macro WINDOW_DEFAULT_W 1600
#macro WINDOW_DEFAULT_H 900

#macro WINDOW_SETTLE_FRAMES  8   // countdown after leaving fullscreen
#macro WINDOW_COOLDOWN_FRAMES 20 // toggles ignored until this runs out

/// @desc Swap between fullscreen and a resizable window.
/// Only sets the fullscreen flag; sizing happens later, in window_update().
function window_toggle_fullscreen()
{
    if (win_cooldown > 0)
    {
        return; // still settling from the last one
    }
    win_cooldown = WINDOW_COOLDOWN_FRAMES;

    if (window_get_fullscreen())
    {
        // Size and centre are applied by the countdown, not now
        win_settle = WINDOW_SETTLE_FRAMES;
        window_set_fullscreen(false);
        return;
    }

    // Remember this window so coming back out lands the same way
    win_last_w = window_get_width();
    win_last_h = window_get_height();
    win_settle = 0;
    window_set_fullscreen(true);
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

    // Bailed back to fullscreen in the meantime: drop the pending resize
    if (window_get_fullscreen())
    {
        win_settle = 0;
        return;
    }

    // One operation per frame, well clear of the swap chain rebuild
    if (win_settle == 4)
    {
        var _w = clamp(win_last_w, 640, max(display_get_width() - 80, 640));
        var _h = clamp(win_last_h, 480, max(display_get_height() - 120, 480));
        window_set_size(_w, _h);
        return;
    }

    if (win_settle == 0)
    {
        window_center();
    }
}
