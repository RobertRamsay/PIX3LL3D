/// POSTFX_system
/// Post-processing for the 3D view: the CRT monitor filter (sh_crt), with a
/// slider panel under the POST FX menu.
///
/// The editor renders to the application surface with automatic drawing
/// switched off (see the Create event). postfx_draw_scene() is called at the
/// top of Draw GUI and puts the 3D view on screen through the filter.
/// Everything the editor draws afterwards - menu bar, HUD, palette, About
/// panel, the whole pixel editor - lands on top untouched, so the UI stays
/// sharp and mouse picking is never thrown off by the curvature.
///
/// All state is initialised in obj_editor's Create event. fx holds the
/// parameters, fx_sliders describes them for the panel, fx_u caches the
/// shader uniform handles.

#macro FX_PANEL_W 340

// The projection the Draw event builds. Named here so anything that needs to
// reason about scene depth reads the same numbers the camera uses.
#macro FX_FOV   60
#macro FX_ZNEAR 1
#macro FX_ZFAR  32000

// ============================================================
//  DEFAULTS
// ============================================================

/// @desc A fresh parameter set. Used at Create and by "Reset to defaults".
function postfx_defaults()
{
    return {
        crt_curve: 0.50,
        crt_scan: 0.35,
        crt_lines: 540,
        crt_mask: 0.30,
        crt_glow: 0.00,         // 8 extra texture fetches per pixel when above zero
        crt_chroma: 0.60,
        crt_vignette: 0.45,
        crt_bright: 1.12,
        crt_contrast: 1.06,
        crt_sat: 1.08,
        crt_flicker: 0.25
    };
}

/// @desc Panel rows. step 0 is continuous, otherwise the value snaps to it.
function postfx_slider_defs()
{
    return [
        { key: "crt_curve",    label: "Curvature",     lo: 0.00, hi: 2.00, step: 0,  group: "CRT MONITOR" },
        { key: "crt_scan",     label: "Scanlines",     lo: 0.00, hi: 1.00, step: 0,  group: "CRT MONITOR" },
        { key: "crt_lines",    label: "Line count",    lo: 120,  hi: 1080, step: 10, group: "CRT MONITOR" },
        { key: "crt_mask",     label: "Aperture mask", lo: 0.00, hi: 1.00, step: 0,  group: "CRT MONITOR" },
        { key: "crt_glow",     label: "Phosphor glow", lo: 0.00, hi: 2.00, step: 0,  group: "CRT MONITOR" },
        { key: "crt_chroma",   label: "Chromatic ab.", lo: 0.00, hi: 3.00, step: 0,  group: "CRT MONITOR" },
        { key: "crt_vignette", label: "Vignette",      lo: 0.00, hi: 1.50, step: 0,  group: "CRT MONITOR" },
        { key: "crt_bright",   label: "Brightness",    lo: 0.50, hi: 2.00, step: 0,  group: "CRT MONITOR" },
        { key: "crt_contrast", label: "Contrast",      lo: 0.50, hi: 2.00, step: 0,  group: "CRT MONITOR" },
        { key: "crt_sat",      label: "Saturation",    lo: 0.00, hi: 2.00, step: 0,  group: "CRT MONITOR" },
        { key: "crt_flicker",  label: "Flicker",       lo: 0.00, hi: 1.00, step: 0,  group: "CRT MONITOR" }
    ];
}

/// @desc Cache every shader uniform handle once, at Create.
function postfx_uniforms()
{
    return {
        crt: {
            res:      shader_get_uniform(sh_crt, "u_res"),
            texel:    shader_get_uniform(sh_crt, "u_texel"),
            time:     shader_get_uniform(sh_crt, "u_time"),
            curve:    shader_get_uniform(sh_crt, "u_curve"),
            scan:     shader_get_uniform(sh_crt, "u_scan"),
            lines:    shader_get_uniform(sh_crt, "u_scan_lines"),
            mask:     shader_get_uniform(sh_crt, "u_mask"),
            glow:     shader_get_uniform(sh_crt, "u_glow"),
            chroma:   shader_get_uniform(sh_crt, "u_chroma"),
            vignette: shader_get_uniform(sh_crt, "u_vignette"),
            bright:   shader_get_uniform(sh_crt, "u_bright"),
            contrast: shader_get_uniform(sh_crt, "u_contrast"),
            sat:      shader_get_uniform(sh_crt, "u_sat"),
            flicker:  shader_get_uniform(sh_crt, "u_flicker")
        }
    };
}

/// @desc Put every parameter back to its default.
function postfx_reset()
{
    fx = postfx_defaults();
}

// ============================================================
//  THE PIPELINE
// ============================================================

/// @desc Put the 3D view on screen, through the CRT filter when it is on.
/// Call FIRST in Draw GUI, while the 3D view is still the only thing rendered.
function postfx_draw_scene()
{
    if (!surface_exists(application_surface))
    {
        return;
    }

    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();
    var _sw = surface_get_width(application_surface);
    var _sh = surface_get_height(application_surface);

    var _old_ztest = gpu_get_ztestenable();
    var _old_filter = gpu_get_tex_filter();

    gpu_set_ztestenable(false);
    draw_set_colour(c_white);
    draw_set_alpha(1);

    if (fx_crt_on)
    {
        // Linear filtering, so the curvature resamples smoothly
        gpu_set_tex_filter(true);
        shader_set(sh_crt);
        shader_set_uniform_f(fx_u.crt.res, _sw, _sh);
        shader_set_uniform_f(fx_u.crt.texel, 1 / max(_sw, 1), 1 / max(_sh, 1));
        shader_set_uniform_f(fx_u.crt.time, current_time / 1000);
        shader_set_uniform_f(fx_u.crt.curve, fx.crt_curve);
        shader_set_uniform_f(fx_u.crt.scan, fx.crt_scan);
        shader_set_uniform_f(fx_u.crt.lines, fx.crt_lines);
        shader_set_uniform_f(fx_u.crt.mask, fx.crt_mask);
        shader_set_uniform_f(fx_u.crt.glow, fx.crt_glow);
        shader_set_uniform_f(fx_u.crt.chroma, fx.crt_chroma);
        shader_set_uniform_f(fx_u.crt.vignette, fx.crt_vignette);
        shader_set_uniform_f(fx_u.crt.bright, fx.crt_bright);
        shader_set_uniform_f(fx_u.crt.contrast, fx.crt_contrast);
        shader_set_uniform_f(fx_u.crt.sat, fx.crt_sat);
        shader_set_uniform_f(fx_u.crt.flicker, fx.crt_flicker);
        draw_surface_stretched(application_surface, 0, 0, _gw, _gh);
        shader_reset();
    }
    else
    {
        // Filter off: this is exactly the blit GameMaker would have done itself
        gpu_set_tex_filter(false);
        draw_surface_stretched(application_surface, 0, 0, _gw, _gh);
    }

    gpu_set_tex_filter(_old_filter);
    gpu_set_ztestenable(_old_ztest);
}

// ============================================================
//  CONTROL PANEL
// ============================================================

/// @desc Panel rect and the y of every slider row (GUI pixels).
function postfx_panel_layout()
{
    var _gw = display_get_gui_width();

    fx_panel_w = FX_PANEL_W;
    fx_panel_x = _gw - fx_panel_w - 20;
    fx_panel_y = menu_bar_h + 20;

    fx_row_y = [];
    var _y = fx_panel_y + 40;
    var _group = "";

    for (var _i = 0; _i < array_length(fx_sliders); _i++)
    {
        if (fx_sliders[_i].group != _group)
        {
            _group = fx_sliders[_i].group;
            _y += 22;
        }
        array_push(fx_row_y, _y);
        _y += 24;
    }

    var _by = _y + 14;
    fx_btn_reset = [fx_panel_x + 14, _by, fx_panel_x + 14 + 140, _by + 26];
    fx_btn_close = [fx_panel_x + fx_panel_w - 14 - 90, _by, fx_panel_x + fx_panel_w - 14, _by + 26];
    fx_panel_h = (_by + 26 + 14) - fx_panel_y;
}

/// @desc Left and right edge of a slider track.
function postfx_track_x0()
{
    return fx_panel_x + 150;
}

function postfx_track_x1()
{
    return fx_panel_x + fx_panel_w - 62;
}

/// @desc Slider _i's value as 0..1 across its range.
function postfx_norm(_i)
{
    var _s = fx_sliders[_i];
    return clamp((fx[$ _s.key] - _s.lo) / (_s.hi - _s.lo), 0, 1);
}

/// @desc Set slider _i from a 0..1 position, snapping to its step.
function postfx_set_norm(_i, _t)
{
    var _s = fx_sliders[_i];
    var _v = _s.lo + clamp(_t, 0, 1) * (_s.hi - _s.lo);
    if (_s.step > 0)
    {
        _v = round(_v / _s.step) * _s.step;
    }
    fx[$ _s.key] = clamp(_v, _s.lo, _s.hi);
}

/// @desc Slider _i's value as display text.
function postfx_value_text(_i)
{
    var _s = fx_sliders[_i];
    var _v = fx[$ _s.key];
    if (_s.step >= 1)
    {
        return string(round(_v));
    }
    return string_format(_v, 1, 2);
}

/// @desc Menu actions, shortcut keys and panel input. Call in Step after
/// bg_ui_update(), in the 3D branch only.
function postfx_update()
{
    if (keyboard_check_pressed(vk_f6) || menu_action == "fx_crt")
    {
        if (fx_crt_on)
        {
            fx_crt_on = false;
        }
        else
        {
            fx_crt_on = true;
        }
    }

    if (keyboard_check_pressed(vk_f7) || menu_action == "fx_panel")
    {
        if (fx_panel_open)
        {
            fx_panel_open = false;
        }
        else
        {
            fx_panel_open = true;
        }
    }

    if (menu_action == "fx_reset")
    {
        postfx_reset();
    }

    if (!fx_panel_open)
    {
        fx_drag = -1;
        return;
    }

    postfx_panel_layout();

    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    var _over_panel = (_mx >= fx_panel_x && _mx < fx_panel_x + fx_panel_w && _my >= fx_panel_y && _my < fx_panel_y + fx_panel_h);

    // Esc closes the panel before it can reach the quit handler
    if (keyboard_check_pressed(vk_escape) && !menu_esc_consumed)
    {
        fx_panel_open = false;
        fx_drag = -1;
        menu_esc_consumed = true;
        return;
    }

    fx_hover = -1;
    var _x0 = postfx_track_x0();
    var _x1 = postfx_track_x1();

    for (var _i = 0; _i < array_length(fx_sliders); _i++)
    {
        var _ry = fx_row_y[_i];
        if (_my >= _ry - 8 && _my < _ry + fx_slider_h + 8 && _mx >= _x0 - 8 && _mx < _x1 + 8)
        {
            fx_hover = _i;
        }
    }

    if (mouse_check_button_pressed(mb_left) && !menu_click_consumed)
    {
        if (fx_hover >= 0)
        {
            fx_drag = fx_hover;
            postfx_set_norm(fx_drag, (_mx - _x0) / max(_x1 - _x0, 1));
        }
        else if (_mx >= fx_btn_reset[0] && _mx < fx_btn_reset[2] && _my >= fx_btn_reset[1] && _my < fx_btn_reset[3])
        {
            postfx_reset();
        }
        else if (_mx >= fx_btn_close[0] && _mx < fx_btn_close[2] && _my >= fx_btn_close[1] && _my < fx_btn_close[3])
        {
            fx_panel_open = false;
        }
    }

    if (fx_drag >= 0)
    {
        if (mouse_check_button(mb_left))
        {
            postfx_set_norm(fx_drag, (_mx - _x0) / max(_x1 - _x0, 1));
        }
        else
        {
            fx_drag = -1;
        }
    }

    // The panel owns the mouse so clicks never fall through into the scene
    if (_over_panel || fx_drag >= 0)
    {
        menu_blocks_mouse = true;
    }
}

/// @desc Draw the control panel. Call in Draw GUI before about_draw().
function postfx_panel_draw()
{
    if (!fx_panel_open)
    {
        return;
    }

    postfx_panel_layout();

    var _x1 = fx_panel_x;
    var _y1 = fx_panel_y;
    var _x2 = fx_panel_x + fx_panel_w;
    var _y2 = fx_panel_y + fx_panel_h;

    gpu_set_tex_filter(true);
    draw_set_font(font_pixeldown);
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);

    // Shadow, body, outline
    draw_set_alpha(0.35);
    draw_set_colour(c_black);
    draw_rectangle(_x1 + 5, _y1 + 5, _x2 + 5, _y2 + 5, false);
    draw_set_alpha(0.96);
    draw_set_colour(menu_col_panel);
    draw_rectangle(_x1, _y1, _x2, _y2, false);
    draw_set_alpha(1);
    draw_set_colour(menu_col_line);
    draw_rectangle(_x1, _y1, _x2, _y2, true);

    // Title strip
    draw_set_colour(menu_col_bar);
    draw_rectangle(_x1 + 1, _y1 + 1, _x2 - 1, _y1 + 30, false);
    draw_set_colour(menu_col_line);
    draw_line(_x1 + 1, _y1 + 30, _x2 - 1, _y1 + 30);
    draw_set_colour(c_white);
    draw_text(_x1 + 14, _y1 + 15, "POST FX");

    if (fx_crt_on)
    {
        draw_set_colour(c_lime);
        draw_text(_x1 + 92, _y1 + 15, "CRT");
    }
    else
    {
        draw_set_colour(c_gray);
        draw_text(_x1 + 92, _y1 + 15, "off");
    }

    // Frame rate, so the cost of a slider is visible while you drag it
    draw_set_halign(fa_right);
    draw_set_colour(c_ltgray);
    draw_text(_x2 - 14, _y1 + 15, string(fps) + " fps  (uncapped " + string(round(fps_real)) + ")");
    draw_set_halign(fa_left);

    // Rows
    var _tx0 = postfx_track_x0();
    var _tx1 = postfx_track_x1();
    var _group = "";

    for (var _i = 0; _i < array_length(fx_sliders); _i++)
    {
        var _s = fx_sliders[_i];
        var _ry = fx_row_y[_i];
        var _cy = _ry + fx_slider_h * 0.5;

        if (_s.group != _group)
        {
            _group = _s.group;
            draw_set_colour(menu_col_line);
            draw_line(_x1 + 12, _ry - 14, _x2 - 12, _ry - 14);
            draw_set_colour(menu_col_accent);
            draw_text(_x1 + 14, _ry - 24, _group);
        }

        // Dim the rows while the effect is switched off
        if (fx_crt_on)
        {
            draw_set_colour(c_ltgray);
        }
        else
        {
            draw_set_colour(c_gray);
        }
        draw_text(_x1 + 14, _cy, _s.label);

        // Track
        draw_set_colour(menu_col_bar);
        draw_rectangle(_tx0, _ry, _tx1, _ry + fx_slider_h, false);
        draw_set_colour(menu_col_line);
        draw_rectangle(_tx0, _ry, _tx1, _ry + fx_slider_h, true);

        // Filled portion
        var _t = postfx_norm(_i);
        var _kx = _tx0 + _t * (_tx1 - _tx0);
        if (fx_crt_on)
        {
            draw_set_colour(menu_col_accent);
        }
        else
        {
            draw_set_colour(menu_col_hover);
        }
        draw_rectangle(_tx0 + 1, _ry + 1, max(_tx0 + 1, _kx), _ry + fx_slider_h - 1, false);

        // Knob
        if (_i == fx_drag || _i == fx_hover)
        {
            draw_set_colour(c_white);
        }
        else
        {
            draw_set_colour(c_ltgray);
        }
        draw_rectangle(_kx - 2, _ry - 3, _kx + 2, _ry + fx_slider_h + 3, false);

        // Value
        draw_set_halign(fa_right);
        draw_set_colour(c_white);
        draw_text(_x2 - 14, _cy, postfx_value_text(_i));
        draw_set_halign(fa_left);
    }

    postfx_draw_button(fx_btn_reset, "Reset defaults");
    postfx_draw_button(fx_btn_close, "Close");

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_colour(c_white);
    draw_set_alpha(1);
    gpu_set_tex_filter(tex_filter_on);
}

/// @desc One panel button.
function postfx_draw_button(_rect, _label)
{
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    var _hot = (_mx >= _rect[0] && _mx < _rect[2] && _my >= _rect[1] && _my < _rect[3]);

    if (_hot)
    {
        draw_set_colour(menu_col_accent);
    }
    else
    {
        draw_set_colour(menu_col_hover);
    }
    draw_rectangle(_rect[0], _rect[1], _rect[2], _rect[3], false);
    draw_set_colour(menu_col_line);
    draw_rectangle(_rect[0], _rect[1], _rect[2], _rect[3], true);

    draw_set_colour(c_white);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text((_rect[0] + _rect[2]) * 0.5, (_rect[1] + _rect[3]) * 0.5, _label);
    draw_set_halign(fa_left);
}
