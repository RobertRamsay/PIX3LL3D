/// WINDOW_system
/// Fullscreen / windowed switching and keeping the render target in step
/// with the window.
///
/// The editor starts fullscreen. F10 (or View > Fullscreen) drops it to a
/// bordered window that can be dragged and resized like any other app, and
/// F10 again puts it back. The windowed size is remembered across toggles.
///
/// Whenever the window changes size, the application surface has to follow:
/// postfx_draw_scene() reads it and the CRT filter runs once per pixel of it,
/// so a surface left at the old size is both wrong and needlessly expensive.

#macro WINDOW_DEFAULT_W 1600
#macro WINDOW_DEFAULT_H 900

/// @desc Keep the application surface the same size as the window.
/// Called from ui_update_gui_size, which already runs on every size change.
function window_sync_app_surface(_ww, _wh)
{
    if (!surface_exists(application_surface))
    {
        return;
    }
    if (surface_get_width(application_surface) == _ww && surface_get_height(application_surface) == _wh)
    {
        return;
    }
    surface_resize(application_surface, _ww, _wh);
}

/// @desc Swap between fullscreen and a resizable window.
function window_toggle_fullscreen()
{
    if (window_get_fullscreen())
    {
        window_set_fullscreen(false);

        // Restore the last windowed size, kept inside the display
        var _w = win_last_w;
        var _h = win_last_h;
        _w = clamp(_w, 640, max(display_get_width() - 80, 640));
        _h = clamp(_h, 480, max(display_get_height() - 120, 480));

        window_set_size(_w, _h);
        window_center();
    }
    else
    {
        // Remember where we were so coming back out lands the same way
        win_last_w = window_get_width();
        win_last_h = window_get_height();
        window_set_fullscreen(true);
    }

    // Force ui_update_gui_size to recompute rather than trust its cache
    ui_last_w = 0;
    ui_last_h = 0;
}
