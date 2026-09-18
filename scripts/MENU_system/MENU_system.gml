/// MENU_system
/// Top menu bar with drop-down menus. Menus and items are defined in the
/// Create event (menu_defs). A clicked item sets menu_action for ONE frame;
/// the Step event (and the pixel editor) test menu_action alongside the
/// matching keyboard shortcut, so menus and keys always run the same code.
///
/// Item fields: label, key (shortcut text shown on the right), act (action id,
/// "" = info-only line), mode ("all", "3d" or "pe" - which editor shows it).
/// A label of "-" draws a separator.

/// @desc Is this menu / item shown in the current editor mode?
function menu_mode_visible(_mode)
{
    if (_mode == "all")
    {
        return true;
    }
    return (_mode == menu_mode);
}

/// @desc Per-frame menu input. Call first thing in the Step event.
function menu_update()
{
    menu_action = "";
    menu_esc_consumed = false;
    menu_click_consumed = false;

    menu_mode = "3d";
    if (pe_open)
    {
        menu_mode = "pe";
    }

    draw_set_font(-1);

    // --- Lay out the visible titles along the bar ---
    menu_vis = [];
    menu_title_x = [];
    menu_title_w = [];
    var _x = 6;
    for (var _i = 0; _i < array_length(menu_defs); _i++)
    {
        var _def = menu_defs[_i];
        if (menu_mode_visible(_def.mode))
        {
            var _w = string_width(_def.title) + menu_title_pad * 2;
            array_push(menu_vis, _i);
            array_push(menu_title_x, _x);
            array_push(menu_title_w, _w);
            _x += _w;
        }
    }

    // A mode switch can leave the open index pointing past the visible list
    if (menu_open >= array_length(menu_vis))
    {
        menu_open = -1;
    }

    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);

    // --- Title under the mouse ---
    menu_title_hover = -1;
    if (_my >= 0 && _my < menu_bar_h)
    {
        for (var _t = 0; _t < array_length(menu_vis); _t++)
        {
            if (_mx >= menu_title_x[_t] && _mx < menu_title_x[_t] + menu_title_w[_t])
            {
                menu_title_hover = _t;
            }
        }
    }

    // Escape closes an open menu (and does NOT fall through to quit)
    if (menu_open >= 0 && keyboard_check_pressed(vk_escape))
    {
        menu_open = -1;
        menu_esc_consumed = true;
    }

    // While a menu is open, sliding across the bar switches menus
    if (menu_open >= 0 && menu_title_hover >= 0)
    {
        menu_open = menu_title_hover;
    }

    menu_build_dropdown();

    // --- Item under the mouse ---
    menu_item_hover = menu_find_hover_item(_mx, _my);

    // --- Clicks ---
    if (mouse_check_button_pressed(mb_left))
    {
        if (menu_title_hover >= 0)
        {
            if (menu_open == menu_title_hover)
            {
                menu_open = -1;
            }
            else
            {
                menu_open = menu_title_hover;
            }
            menu_build_dropdown();
            menu_item_hover = menu_find_hover_item(_mx, _my);
            menu_click_consumed = true;
        }
        else if (menu_open >= 0)
        {
            if (menu_item_hover >= 0)
            {
                menu_action = menu_drop_items[menu_item_hover].act;
            }
            // Clicking anywhere (item or outside) closes the menu and eats the click
            menu_open = -1;
            menu_click_consumed = true;
        }
    }

    if (mouse_check_button_pressed(mb_right) && menu_open >= 0)
    {
        menu_open = -1;
        menu_click_consumed = true;
    }

    // Anything the menu owns this frame must not reach the editors
    menu_blocks_mouse = false;
    if (menu_click_consumed)
    {
        menu_blocks_mouse = true;
    }
    if (menu_open >= 0)
    {
        menu_blocks_mouse = true;
    }
    if (_my >= 0 && _my < menu_bar_h)
    {
        menu_blocks_mouse = true;
    }
}

/// @desc Build the filtered item list and geometry of the open drop-down.
function menu_build_dropdown()
{
    menu_drop_items = [];
    menu_drop_iy = [];
    menu_drop_ih = [];
    menu_drop_x = 0;
    menu_drop_y = menu_bar_h;
    menu_drop_w = 0;
    menu_drop_h = 0;

    if (menu_open < 0)
    {
        return;
    }

    var _def = menu_defs[menu_vis[menu_open]];
    var _y = menu_bar_h + 3;
    var _label_w = 0;
    var _key_w = 0;

    for (var _i = 0; _i < array_length(_def.items); _i++)
    {
        var _it = _def.items[_i];
        if (menu_mode_visible(_it.mode))
        {
            // Skip a separator that would be the first visible line
            var _is_sep = (_it.label == "-");
            if (_is_sep && array_length(menu_drop_items) == 0)
            {
                continue;
            }

            var _h = menu_item_h;
            if (_is_sep)
            {
                _h = menu_sep_h;
            }

            array_push(menu_drop_items, _it);
            array_push(menu_drop_iy, _y);
            array_push(menu_drop_ih, _h);
            _y += _h;

            if (!_is_sep)
            {
                _label_w = max(_label_w, string_width(_it.label));
                _key_w = max(_key_w, string_width(_it.key));
            }
        }
    }

    // Drop a trailing separator
    var _n = array_length(menu_drop_items);
    if (_n > 0)
    {
        if (menu_drop_items[_n - 1].label == "-")
        {
            _y -= menu_drop_ih[_n - 1];
            array_delete(menu_drop_items, _n - 1, 1);
            array_delete(menu_drop_iy, _n - 1, 1);
            array_delete(menu_drop_ih, _n - 1, 1);
        }
    }

    menu_drop_x = menu_title_x[menu_open];
    menu_drop_w = menu_item_pad + menu_check_w + _label_w + menu_key_gap + _key_w + menu_item_pad;
    menu_drop_h = (_y + 3) - menu_bar_h;

    // Keep the drop-down on screen
    var _gw = display_get_gui_width();
    if (menu_drop_x + menu_drop_w > _gw)
    {
        menu_drop_x = max(0, _gw - menu_drop_w);
    }
}

/// @desc Index of the clickable item under the mouse, or -1.
function menu_find_hover_item(_mx, _my)
{
    if (menu_open < 0)
    {
        return -1;
    }
    if (_mx < menu_drop_x || _mx >= menu_drop_x + menu_drop_w)
    {
        return -1;
    }
    for (var _i = 0; _i < array_length(menu_drop_items); _i++)
    {
        var _it = menu_drop_items[_i];
        if (_it.label != "-" && _it.act != "")
        {
            if (_my >= menu_drop_iy[_i] && _my < menu_drop_iy[_i] + menu_drop_ih[_i])
            {
                return _i;
            }
        }
    }
    return -1;
}

/// @desc Tick state for toggle-style items.
function menu_item_checked(_act)
{
    if (string_copy(_act, 1, 5) == "tool_")
    {
        return (("tool_" + pe_tool) == _act);
    }

    switch (_act)
    {
        case "grid":          return grid_visible;
        case "tex_filter":    return tex_filter_on;
        case "cull":          return cull_on;
        case "tiles_builtin": return !global.tile_is_custom;
        case "tiles_custom":  return global.tile_is_custom;
        case "pe_toggle":     return pe_open;
        case "pe_pixel_grid": return pe_show_pixel_grid;
        case "pe_tile_grid":  return pe_show_tile_grid;
        case "pe_tile_clip":  return pe_tile_clip;
    }
    return false;
}

/// @desc Draw the bar and any open drop-down. Call LAST in Draw GUI.
function menu_draw()
{
    var _gw = display_get_gui_width();

    draw_set_font(-1);
    gpu_set_tex_filter(true);
    draw_set_valign(fa_middle);
    draw_set_halign(fa_left);

    // --- Bar ---
    draw_set_alpha(0.95);
    draw_set_colour(menu_col_bar);
    draw_rectangle(0, 0, _gw, menu_bar_h - 1, false);
    draw_set_alpha(1);
    draw_set_colour(menu_col_line);
    draw_line(0, menu_bar_h - 1, _gw, menu_bar_h - 1);

    for (var _t = 0; _t < array_length(menu_vis); _t++)
    {
        var _tx = menu_title_x[_t];
        var _tw = menu_title_w[_t];
        if (_t == menu_open)
        {
            draw_set_colour(menu_col_accent);
            draw_rectangle(_tx, 0, _tx + _tw - 1, menu_bar_h - 2, false);
        }
        else if (_t == menu_title_hover)
        {
            draw_set_colour(menu_col_hover);
            draw_rectangle(_tx, 0, _tx + _tw - 1, menu_bar_h - 2, false);
        }
        draw_set_colour(c_white);
        draw_text(_tx + menu_title_pad, menu_bar_h * 0.5, menu_defs[menu_vis[_t]].title);
    }

    // Mode label on the right of the bar
    var _mode_text = "3D EDITOR  |  Plane: " + active_plane;
    if (pe_open)
    {
        _mode_text = "PIXEL EDITOR  |  " + pe_tool_label(pe_tool);
    }
    draw_set_halign(fa_right);
    draw_set_colour(c_ltgray);
    draw_text(_gw - 10, menu_bar_h * 0.5, _mode_text);
    draw_set_halign(fa_left);

    // --- Drop-down ---
    if (menu_open >= 0)
    {
        var _x1 = menu_drop_x;
        var _y1 = menu_drop_y;
        var _x2 = menu_drop_x + menu_drop_w;
        var _y2 = menu_drop_y + menu_drop_h;

        // Shadow, body, outline
        draw_set_alpha(0.35);
        draw_set_colour(c_black);
        draw_rectangle(_x1 + 4, _y1 + 4, _x2 + 4, _y2 + 4, false);
        draw_set_alpha(0.97);
        draw_set_colour(menu_col_panel);
        draw_rectangle(_x1, _y1, _x2, _y2, false);
        draw_set_alpha(1);
        draw_set_colour(menu_col_line);
        draw_rectangle(_x1, _y1, _x2, _y2, true);

        for (var _i = 0; _i < array_length(menu_drop_items); _i++)
        {
            var _it = menu_drop_items[_i];
            var _iy = menu_drop_iy[_i];
            var _ih = menu_drop_ih[_i];

            if (_it.label == "-")
            {
                draw_set_colour(menu_col_line);
                var _sy = _iy + floor(_ih * 0.5);
                draw_line(_x1 + 6, _sy, _x2 - 6, _sy);
                continue;
            }

            if (_i == menu_item_hover)
            {
                draw_set_colour(menu_col_accent);
                draw_rectangle(_x1 + 2, _iy, _x2 - 2, _iy + _ih - 1, false);
            }

            var _cy = _iy + _ih * 0.5;

            // Tick box for toggles
            if (_it.act != "")
            {
                if (menu_item_checked(_it.act))
                {
                    var _bx = _x1 + menu_item_pad;
                    draw_set_colour(c_white);
                    draw_rectangle(_bx + 2, _cy - 4, _bx + 9, _cy + 3, false);
                }
            }

            // Label: info-only lines are dimmed
            if (_it.act == "")
            {
                draw_set_colour(c_ltgray);
            }
            else
            {
                draw_set_colour(c_white);
            }
            draw_set_halign(fa_left);
            draw_text(_x1 + menu_item_pad + menu_check_w, _cy, _it.label);

            // Shortcut, right-aligned
            if (_it.key != "")
            {
                draw_set_halign(fa_right);
                if (_i == menu_item_hover)
                {
                    draw_set_colour(c_white);
                }
                else
                {
                    draw_set_colour(c_gray);
                }
                draw_text(_x2 - menu_item_pad, _cy, _it.key);
            }
        }
    }

    // Restore shared draw state
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_colour(c_white);
    draw_set_alpha(1);
    gpu_set_tex_filter(tex_filter_on);
}
