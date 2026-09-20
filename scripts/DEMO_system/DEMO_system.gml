/// DEMO_system
/// Demo / PRO gating, driven by ONE macro.
///
///   DEMO_MODE true   -> demo build: OBJ export and tileset PNG saving are
///                       locked, and reaching for either opens the PRO panel.
///   DEMO_MODE false  -> full build: everything unlocked, no panel, no (PRO)
///                       labels, and no other behaviour changes.
///
/// Scene save, save-as and load are NEVER gated. Somebody trying the demo can
/// still build and keep their levels; what they cannot do is take the result
/// out of the editor.
///
/// Everything routes through demo_lock(), which returns true when the caller
/// should stop. That keeps the gate in one place per feature rather than
/// scattered through the menus, the toolbar and the keyboard handlers.

#macro DEMO_MODE true

#macro DEMO_PANEL_W 560
#macro DEMO_PANEL_H 330

/// @desc Gate a feature. Returns true when the caller must NOT proceed, and
/// opens the PRO panel naming the feature. Always false in the full build.
function demo_lock(_feature)
{
    if (!DEMO_MODE)
    {
        return false;
    }

    demo_feature = _feature;
    demo_visible = true;
    return true;
}

/// @desc Menu label helper: marks an item (PRO) in the demo, plain otherwise.
function demo_label(_text)
{
    if (!DEMO_MODE)
    {
        return _text;
    }
    return _text + "   (PRO)";
}

/// @desc Panel rect and buttons (GUI pixels).
function demo_layout()
{
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();

    demo_x = floor((_gw - DEMO_PANEL_W) * 0.5);
    demo_y = floor((_gh - DEMO_PANEL_H) * 0.5);

    var _bh = 30;
    var _by = demo_y + DEMO_PANEL_H - _bh - 20;

    demo_btn_get = [demo_x + 20, _by, demo_x + 20 + 230, _by + _bh];
    demo_btn_close = [demo_x + DEMO_PANEL_W - 20 - 100, _by, demo_x + DEMO_PANEL_W - 20, _by + _bh];
}

/// @desc Per-frame input for the PRO panel. Call in Step before the pixel
/// editor branch, so it is modal in both editors.
function demo_update()
{
    if (!demo_visible)
    {
        return;
    }

    demo_layout();

    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);

    // The panel owns the mouse while it is up
    menu_blocks_mouse = true;

    demo_hover = "";
    if (about_over(demo_btn_get, _mx, _my))
    {
        demo_hover = "get";
    }
    else if (about_over(demo_btn_close, _mx, _my))
    {
        demo_hover = "close";
    }

    // Esc closes it rather than falling through to quitting the app
    if (keyboard_check_pressed(vk_escape) && !menu_esc_consumed)
    {
        demo_visible = false;
        menu_esc_consumed = true;
        return;
    }

    if (mouse_check_button_pressed(mb_left) && !menu_click_consumed)
    {
        if (demo_hover == "get")
        {
            url_open(ABOUT_ITCH_URL);
            demo_visible = false;
        }
        else if (demo_hover == "close")
        {
            demo_visible = false;
        }
        else
        {
            var _inside = (_mx >= demo_x && _mx < demo_x + DEMO_PANEL_W && _my >= demo_y && _my < demo_y + DEMO_PANEL_H);
            if (!_inside)
            {
                demo_visible = false;
            }
        }
    }
}

/// @desc Draw the PRO panel. Call in Draw GUI, just before menu_draw().
function demo_draw()
{
    if (!demo_visible)
    {
        return;
    }

    demo_layout();

    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();

    var _x1 = demo_x;
    var _y1 = demo_y;
    var _x2 = demo_x + DEMO_PANEL_W;
    var _y2 = demo_y + DEMO_PANEL_H;

    gpu_set_cullmode(cull_noculling);
    gpu_set_tex_filter(true);
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // Dim the editor behind it
    draw_set_alpha(0.55);
    draw_set_colour(c_black);
    draw_rectangle(0, 0, _gw, _gh, false);
    draw_set_alpha(1);

    // Shadow, body, outline
    draw_set_alpha(0.35);
    draw_set_colour(c_black);
    draw_rectangle(_x1 + 6, _y1 + 6, _x2 + 6, _y2 + 6, false);
    draw_set_alpha(1);
    draw_set_colour(menu_col_panel);
    draw_rectangle(_x1, _y1, _x2, _y2, false);
    draw_set_colour(make_color_rgb(215, 160, 55));
    draw_rectangle(_x1, _y1, _x2, _y2, true);

    // Title strip
    draw_set_colour(make_color_rgb(150, 95, 10));
    draw_rectangle(_x1 + 1, _y1 + 1, _x2 - 1, _y1 + 44, false);
    draw_set_colour(make_color_rgb(215, 160, 55));
    draw_line(_x1 + 1, _y1 + 44, _x2 - 1, _y1 + 44);

    draw_set_colour(c_white);
    draw_text(_x1 + 20, _y1 + 8, "PRO feature");
    draw_set_colour(make_color_rgb(255, 225, 170));
    draw_text(_x1 + 20, _y1 + 25, demo_feature + " is not available in the demo.");

    var _tx = _x1 + 20;
    var _ty = _y1 + 68;
    var _line = 19;

    draw_set_colour(c_white);
    draw_text(_tx, _ty, "The full version unlocks:");
    _ty += _line + 4;

    draw_set_colour(c_ltgray);
    draw_text(_tx + 14, _ty, "OBJ export  -  take your scene into any 3D tool");
    _ty += _line;
    draw_text(_tx + 14, _ty, "Tileset PNG saving  -  keep the art you edit here");
    _ty += _line + 12;

    draw_set_colour(menu_col_line);
    draw_line(_tx, _ty, _x2 - 20, _ty);
    _ty += 12;

    draw_set_colour(make_color_rgb(150, 220, 150));
    draw_text(_tx, _ty, "Your scenes still save and load normally in the demo.");
    _ty += _line + 10;

    draw_set_colour(c_white);
    draw_text(_tx, _ty, "Thank you for trying " + ABOUT_APP_NAME + ". Buying the full version");
    _ty += _line;
    draw_text(_tx, _ty, "directly supports this tool and the other projects behind it.");
    _ty += _line + 6;

    draw_set_colour(c_gray);
    draw_text(_tx, _ty, ABOUT_ITCH_URL);

    // Buttons
    demo_draw_button(demo_btn_get, "Get the full version", (demo_hover == "get"), true);
    demo_draw_button(demo_btn_close, "Not now", (demo_hover == "close"), false);

    // Restore shared draw state
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_colour(c_white);
    draw_set_alpha(1);
    gpu_set_tex_filter(tex_filter_on);
}

/// @desc One panel button. _primary gives it the warm accent.
function demo_draw_button(_rect, _label, _hot, _primary)
{
    var _col = menu_col_hover;
    if (_primary)
    {
        _col = make_color_rgb(215, 160, 55);
        if (_hot)
        {
            _col = make_color_rgb(255, 210, 110);
        }
    }
    else if (_hot)
    {
        _col = menu_col_accent;
    }

    draw_set_colour(_col);
    draw_rectangle(_rect[0], _rect[1], _rect[2], _rect[3], false);
    draw_set_colour(menu_col_line);
    draw_rectangle(_rect[0], _rect[1], _rect[2], _rect[3], true);

    if (_primary)
    {
        draw_set_colour(make_color_rgb(40, 25, 0));
    }
    else
    {
        draw_set_colour(c_white);
    }
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text((_rect[0] + _rect[2]) * 0.5, (_rect[1] + _rect[3]) * 0.5, _label);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}
