/// POSTFX_system
/// Post-processing for the 3D view: SSAO (sh_ssao + sh_ssao_blur) and a CRT
/// monitor filter (sh_crt), with a slider panel under the POST FX menu.
///
/// The editor now renders to the application surface with automatic drawing
/// switched off (see the Create event). postfx_draw_scene() is called at the
/// top of Draw GUI and puts the 3D view on screen through whichever effects
/// are enabled. Everything the editor draws afterwards - menu bar, HUD,
/// palette, About panel, the whole pixel editor - lands on top untouched, so
/// the UI stays sharp and mouse picking is never thrown off by the curvature.
///
/// All state is initialised in obj_editor's Create event. fx holds the
/// parameters, fx_sliders describes them for the panel, fx_u caches the
/// shader uniform handles.

#macro FX_PANEL_W 340

// The SSAO shader has to linearise the depth buffer, so it needs the exact
// projection the Draw event builds. Both read these, so they cannot drift.
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
        // Ambient occlusion
        ssao_radius: 0.45,      // world units
        ssao_bias: 0.02,        // world units; stops a surface occluding itself
        ssao_intensity: 1.00,
        ssao_power: 1.60,
        ssao_samples: 8,        // each one is a depth fetch: the main AO cost
        ssao_res: 0.50,         // AO buffer scale; 0.5 = a quarter of the pixels
        ssao_blur: 1.00,        // tap spacing in pixels; 0 skips the blur loop
        ssao_tint: 0.25,        // 0 neutral black, 1 cool blue

        // CRT
        crt_curve: 0.50,
        crt_scan: 0.35,
        crt_lines: 540,
        crt_mask: 0.30,
        crt_glow: 0.00,         // 8 extra fetches per pixel when above zero
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
        { key: "ssao_radius",    label: "Radius",        lo: 0.05, hi: 2.00, step: 0,   group: "AMBIENT OCCLUSION" },
        { key: "ssao_bias",      label: "Bias",          lo: 0.00, hi: 0.20, step: 0,   group: "AMBIENT OCCLUSION" },
        { key: "ssao_intensity", label: "Intensity",     lo: 0.00, hi: 2.00, step: 0,   group: "AMBIENT OCCLUSION" },
        { key: "ssao_power",     label: "Falloff power", lo: 0.50, hi: 4.00, step: 0,   group: "AMBIENT OCCLUSION" },
        { key: "ssao_samples",   label: "Samples",       lo: 4,    hi: 32,   step: 1,   group: "AMBIENT OCCLUSION" },
        { key: "ssao_res",       label: "Buffer scale",  lo: 0.25, hi: 1.00, step: 0.05, group: "AMBIENT OCCLUSION" },
        { key: "ssao_blur",      label: "Blur",          lo: 0.00, hi: 4.00, step: 0,   group: "AMBIENT OCCLUSION" },
        { key: "ssao_tint",      label: "Cool tint",     lo: 0.00, hi: 1.00, step: 0,   group: "AMBIENT OCCLUSION" },

        { key: "crt_curve",      label: "Curvature",     lo: 0.00, hi: 2.00, step: 0,   group: "CRT MONITOR" },
        { key: "crt_scan",       label: "Scanlines",     lo: 0.00, hi: 1.00, step: 0,   group: "CRT MONITOR" },
        { key: "crt_lines",      label: "Line count",    lo: 120,  hi: 1080, step: 10,  group: "CRT MONITOR" },
        { key: "crt_mask",       label: "Aperture mask", lo: 0.00, hi: 1.00, step: 0,   group: "CRT MONITOR" },
        { key: "crt_glow",       label: "Phosphor glow", lo: 0.00, hi: 2.00, step: 0,   group: "CRT MONITOR" },
        { key: "crt_chroma",     label: "Chromatic ab.", lo: 0.00, hi: 3.00, step: 0,   group: "CRT MONITOR" },
        { key: "crt_vignette",   label: "Vignette",      lo: 0.00, hi: 1.50, step: 0,   group: "CRT MONITOR" },
        { key: "crt_bright",     label: "Brightness",    lo: 0.50, hi: 2.00, step: 0,   group: "CRT MONITOR" },
        { key: "crt_contrast",   label: "Contrast",      lo: 0.50, hi: 2.00, step: 0,   group: "CRT MONITOR" },
        { key: "crt_sat",        label: "Saturation",    lo: 0.00, hi: 2.00, step: 0,   group: "CRT MONITOR" },
        { key: "crt_flicker",    label: "Flicker",       lo: 0.00, hi: 1.00, step: 0,   group: "CRT MONITOR" }
    ];
}

/// @desc Cache every shader uniform / sampler handle once, at Create.
function postfx_uniforms()
{
    return {
        ssao: {
            depth:     shader_get_sampler_index(sh_ssao, "u_depth"),
            texel:     shader_get_uniform(sh_ssao, "u_texel"),
            res:       shader_get_uniform(sh_ssao, "u_res"),
            znear:     shader_get_uniform(sh_ssao, "u_znear"),
            zfar:      shader_get_uniform(sh_ssao, "u_zfar"),
            fov:       shader_get_uniform(sh_ssao, "u_fov_scale"),
            radius:    shader_get_uniform(sh_ssao, "u_radius"),
            bias:      shader_get_uniform(sh_ssao, "u_bias"),
            intensity: shader_get_uniform(sh_ssao, "u_intensity"),
            power:     shader_get_uniform(sh_ssao, "u_power"),
            samples:   shader_get_uniform(sh_ssao, "u_samples")
        },
        blur: {
            ao:    shader_get_sampler_index(sh_ssao_blur, "u_ao"),
            depth: shader_get_sampler_index(sh_ssao_blur, "u_depth"),
            texel: shader_get_uniform(sh_ssao_blur, "u_texel"),
            znear: shader_get_uniform(sh_ssao_blur, "u_znear"),
            zfar:  shader_get_uniform(sh_ssao_blur, "u_zfar"),
            blur:  shader_get_uniform(sh_ssao_blur, "u_blur"),
            tint:  shader_get_uniform(sh_ssao_blur, "u_tint"),
            debug: shader_get_uniform(sh_ssao_blur, "u_debug")
        },
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

/// @desc Set only the parameters that cost frame time, leaving the look alone.
/// "low", "medium" or "high".
function postfx_preset(_name)
{
    if (_name == "low")
    {
        fx.ssao_samples = 6;
        fx.ssao_res = 0.25;
        fx.ssao_blur = 1.00;
        fx.crt_glow = 0.00;
        return;
    }

    if (_name == "medium")
    {
        fx.ssao_samples = 10;
        fx.ssao_res = 0.50;
        fx.ssao_blur = 1.25;
        fx.crt_glow = 0.35;
        return;
    }

    fx.ssao_samples = 24;
    fx.ssao_res = 1.00;
    fx.ssao_blur = 2.00;
    fx.crt_glow = 0.60;
}

// ============================================================
//  SURFACES
// ============================================================

/// @desc Make sure the working surfaces exist. The AO buffer can be smaller
/// than the scene buffer - it is upsampled bilinearly in the composite pass.
function postfx_surfaces_ensure(_ao_w, _ao_h, _w, _h)
{
    if (!surface_exists(fx_surf_ao))
    {
        fx_surf_ao = surface_create(_ao_w, _ao_h);
    }
    else if (surface_get_width(fx_surf_ao) != _ao_w || surface_get_height(fx_surf_ao) != _ao_h)
    {
        surface_resize(fx_surf_ao, _ao_w, _ao_h);
    }

    if (!surface_exists(fx_surf_scene))
    {
        fx_surf_scene = surface_create(_w, _h);
    }
    else if (surface_get_width(fx_surf_scene) != _w || surface_get_height(fx_surf_scene) != _h)
    {
        surface_resize(fx_surf_scene, _w, _h);
    }
}

/// @desc Drop the working surfaces (Clean Up, or when all effects go off).
function postfx_surfaces_free()
{
    if (surface_exists(fx_surf_ao))
    {
        surface_free(fx_surf_ao);
    }
    fx_surf_ao = -1;

    if (surface_exists(fx_surf_scene))
    {
        surface_free(fx_surf_scene);
    }
    fx_surf_scene = -1;
}

// ============================================================
//  THE PIPELINE
// ============================================================

/// @desc Put the 3D view on screen through the enabled effects.
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

    // Fast path: nothing enabled, so this is just the blit GameMaker would
    // have done for us.
    if (!fx_ssao_on && !fx_crt_on)
    {
        var _plain_filter = gpu_get_tex_filter();
        var _plain_ztest = gpu_get_ztestenable();
        gpu_set_ztestenable(false);
        gpu_set_tex_filter(false);
        draw_set_colour(c_white);
        draw_set_alpha(1);
        draw_surface_stretched(application_surface, 0, 0, _gw, _gh);
        gpu_set_tex_filter(_plain_filter);
        gpu_set_ztestenable(_plain_ztest);
        return;
    }

    // Save the state the rest of the frame expects back
    var _old_ztest = gpu_get_ztestenable();
    var _old_zwrite = gpu_get_zwriteenable();
    var _old_cull = gpu_get_cullmode();
    var _old_filter = gpu_get_tex_filter();

    gpu_set_ztestenable(false);
    gpu_set_zwriteenable(false);
    gpu_set_cullmode(cull_noculling);
    draw_set_colour(c_white);
    draw_set_alpha(1);

    var _src = application_surface;

    if (fx_ssao_on)
    {
        // The AO buffer runs at a fraction of the scene resolution. At 0.5 that
        // is a quarter of the pixels, so a quarter of the depth fetches.
        var _scale = clamp(fx.ssao_res, 0.25, 1);
        var _aow = max(round(_sw * _scale), 1);
        var _aoh = max(round(_sh * _scale), 1);

        postfx_surfaces_ensure(_aow, _aoh, _sw, _sh);

        var _depth = surface_get_texture_depth(application_surface);
        var _texel_x = 1 / max(_sw, 1);
        var _texel_y = 1 / max(_sh, 1);
        var _fov_scale = tan(degtorad(FX_FOV) * 0.5);

        // --- Pass 1: occlusion factor into fx_surf_ao ---
        gpu_set_tex_filter(false);
        surface_set_target(fx_surf_ao);
        draw_clear(c_white);
        shader_set(sh_ssao);
        shader_set_uniform_f(fx_u.ssao.texel, 1 / _aow, 1 / _aoh);
        shader_set_uniform_f(fx_u.ssao.res, _aow, _aoh);
        shader_set_uniform_f(fx_u.ssao.znear, FX_ZNEAR);
        shader_set_uniform_f(fx_u.ssao.zfar, FX_ZFAR);
        shader_set_uniform_f(fx_u.ssao.fov, _fov_scale);
        shader_set_uniform_f(fx_u.ssao.radius, fx.ssao_radius);
        shader_set_uniform_f(fx_u.ssao.bias, fx.ssao_bias);
        shader_set_uniform_f(fx_u.ssao.intensity, fx.ssao_intensity);
        shader_set_uniform_f(fx_u.ssao.power, fx.ssao_power);
        shader_set_uniform_f(fx_u.ssao.samples, fx.ssao_samples);
        texture_set_stage(fx_u.ssao.depth, _depth);
        gpu_set_tex_filter_ext(fx_u.ssao.depth, false);
        draw_surface_stretched(application_surface, 0, 0, _aow, _aoh);
        shader_reset();
        surface_reset_target();

        // --- Pass 2: bilateral blur, composited over the scene colour ---
        surface_set_target(fx_surf_scene);
        draw_clear_alpha(c_black, 0);
        shader_set(sh_ssao_blur);
        shader_set_uniform_f(fx_u.blur.texel, _texel_x, _texel_y);
        shader_set_uniform_f(fx_u.blur.znear, FX_ZNEAR);
        shader_set_uniform_f(fx_u.blur.zfar, FX_ZFAR);
        shader_set_uniform_f(fx_u.blur.blur, fx.ssao_blur);
        shader_set_uniform_f(fx_u.blur.tint, fx.ssao_tint);
        if (fx_ao_debug)
        {
            shader_set_uniform_f(fx_u.blur.debug, 1);
        }
        else
        {
            shader_set_uniform_f(fx_u.blur.debug, 0);
        }
        texture_set_stage(fx_u.blur.ao, surface_get_texture(fx_surf_ao));
        texture_set_stage(fx_u.blur.depth, _depth);
        // Smooth upsample of the small AO buffer, point sampling on depth
        gpu_set_tex_filter_ext(fx_u.blur.ao, true);
        gpu_set_tex_filter_ext(fx_u.blur.depth, false);
        draw_surface(application_surface, 0, 0);
        shader_reset();
        surface_reset_target();

        _src = fx_surf_scene;
    }

    // --- Final blit to the back buffer ---
    gpu_set_tex_filter(true);

    if (fx_crt_on)
    {
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
        draw_surface_stretched(_src, 0, 0, _gw, _gh);
        shader_reset();
    }
    else
    {
        draw_surface_stretched(_src, 0, 0, _gw, _gh);
    }

    // Hand the state back exactly as it was
    gpu_set_tex_filter(_old_filter);
    gpu_set_cullmode(_old_cull);
    gpu_set_zwriteenable(_old_zwrite);
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

    // Quality presets on their own row, then reset / close
    var _bw = floor((fx_panel_w - 28 - 16) / 3);
    var _py = _y + 20;
    fx_btn_low = [fx_panel_x + 14, _py, fx_panel_x + 14 + _bw, _py + 24];
    fx_btn_med = [fx_panel_x + 22 + _bw, _py, fx_panel_x + 22 + _bw * 2, _py + 24];
    fx_btn_high = [fx_panel_x + 30 + _bw * 2, _py, fx_panel_x + 30 + _bw * 3, _py + 24];

    var _by = _py + 24 + 10;
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
    // --- Toggles ---
    if (keyboard_check_pressed(vk_f5) || menu_action == "fx_ssao")
    {
        if (fx_ssao_on)
        {
            fx_ssao_on = false;
        }
        else
        {
            fx_ssao_on = true;
        }
    }

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

    if (menu_action == "fx_ao_debug")
    {
        if (fx_ao_debug)
        {
            fx_ao_debug = false;
        }
        else
        {
            fx_ao_debug = true;
            fx_ssao_on = true;
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

    // Only SSAO needs the working surfaces, so give the VRAM back when it is off
    if (!fx_ssao_on)
    {
        postfx_surfaces_free();
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
        else if (_mx >= fx_btn_low[0] && _mx < fx_btn_low[2] && _my >= fx_btn_low[1] && _my < fx_btn_low[3])
        {
            postfx_preset("low");
        }
        else if (_mx >= fx_btn_med[0] && _mx < fx_btn_med[2] && _my >= fx_btn_med[1] && _my < fx_btn_med[3])
        {
            postfx_preset("medium");
        }
        else if (_mx >= fx_btn_high[0] && _mx < fx_btn_high[2] && _my >= fx_btn_high[1] && _my < fx_btn_high[3])
        {
            postfx_preset("high");
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
    draw_set_font(-1);
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

    var _state = "";
    if (fx_ssao_on)
    {
        _state += "AO ";
    }
    if (fx_crt_on)
    {
        _state += "CRT";
    }
    if (_state == "")
    {
        _state = "all off";
        draw_set_colour(c_gray);
    }
    else
    {
        draw_set_colour(c_lime);
    }
    draw_text(_x1 + 92, _y1 + 15, _state);

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

        // Dim a group whose effect is switched off
        var _live = fx_crt_on;
        if (_s.group == "AMBIENT OCCLUSION")
        {
            _live = fx_ssao_on;
        }

        if (_live)
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
        if (_live)
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

    // Quality presets: these move only the parameters that cost frame time
    draw_set_colour(menu_col_accent);
    draw_text(_x1 + 14, fx_btn_low[1] - 13, "QUALITY (COST ONLY)");
    postfx_draw_button(fx_btn_low, "Low");
    postfx_draw_button(fx_btn_med, "Medium");
    postfx_draw_button(fx_btn_high, "High");

    // Buttons
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
