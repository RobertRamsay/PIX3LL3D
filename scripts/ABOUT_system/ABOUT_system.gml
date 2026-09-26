/// ABOUT_system
/// Credits / version panel, plus the update check.
///
/// The app's version lives in the included file "version.txt" (one line, e.g.
/// 1.0.0). The SAME file sits in the repo, so the running build fetches the
/// GitHub copy over HTTP and compares it with its own: bump version.txt, build,
/// commit, and everyone already running an older build is told there is a new
/// one on itch.io.
///
/// All state lives on obj_editor and is initialised in its Create event.
/// The panel is modal: while it is open the Step event returns early, so
/// neither the 3D editor nor the pixel editor sees any input.

#macro ABOUT_APP_NAME    "PIX3LL3D"
#macro ABOUT_TAGLINE     "3D tile-based voxel level editor"
#macro ABOUT_VERSION_FILE "version.txt"
#macro ABOUT_VERSION_URL "https://raw.githubusercontent.com/RobertRamsay/PIX3LL3D/master/datafiles/version.txt"
#macro ABOUT_ITCH_URL    "https://polytricity.itch.io/pixell3d"
#macro ABOUT_CHECK_ON_START true   // fetch the remote version once at launch

// major.minor.patch.build. Missing parts count as 0, so "1.0.1" and "1.0.1.0"
// compare equal and older three-part saves still work.
#macro VERSION_PARTS 4

// Update banner shown over the viewport when a newer version is out
#macro ABOUT_BANNER_W 620
#macro ABOUT_BANNER_H 52

// ============================================================
//  VERSION FILE
// ============================================================

/// @desc First non-blank, non-comment line of a version file's text.
/// @param {String} _text raw file contents
/// @returns {String} version string, or "" when nothing usable was found
function version_parse_text(_text)
{
    var _clean = string_replace_all(string(_text), "\r", "");
    var _lines = string_split(_clean, "\n", false);
    for (var _i = 0; _i < array_length(_lines); _i++)
    {
        var _line = string_trim(_lines[_i]);
        if (_line == "")
        {
            continue;
        }
        if (string_char_at(_line, 1) == "#")
        {
            continue;
        }
        return _line;
    }
    return "";
}

/// @desc Read version.txt from the included files. Sets global.app_version.
/// Falls back through the usual locations so it works with the sandbox on or off.
function version_local_load()
{
    global.app_version = "";

    var _paths = [
        ABOUT_VERSION_FILE,
        working_directory + ABOUT_VERSION_FILE,
        program_directory + ABOUT_VERSION_FILE
    ];

    for (var _i = 0; _i < array_length(_paths); _i++)
    {
        var _path = _paths[_i];
        if (!file_exists(_path))
        {
            continue;
        }

        var _text = "";
        var _f = file_text_open_read(_path);
        if (_f == -1)
        {
            continue;
        }
        while (!file_text_eof(_f))
        {
            _text += file_text_read_string(_f) + "\n";
            file_text_readln(_f);
        }
        file_text_close(_f);

        var _ver = version_parse_text(_text);
        if (_ver != "")
        {
            global.app_version = _ver;
            return;
        }
    }

    // No file shipped with the build - say so rather than pretending
    global.app_version = "unknown";
}

/// @desc Split a version string into an array of 3 numbers (missing parts = 0).
/// Any trailing text on a part is dropped, so "1.2.0-beta" reads as 1.2.0.
function version_to_numbers(_v)
{
    var _out = [0, 0, 0, 0];
    var _parts = string_split(string(_v), ".", false);
    for (var _i = 0; _i < VERSION_PARTS; _i++)
    {
        if (_i < array_length(_parts))
        {
            var _digits = string_digits(_parts[_i]);
            if (_digits == "")
            {
                _out[_i] = 0;
            }
            else
            {
                _out[_i] = real(_digits);
            }
        }
    }
    return _out;
}

/// @desc Compare two version strings. Returns -1 (_a older), 0 (same), 1 (_a newer).
function version_compare(_a, _b)
{
    var _na = version_to_numbers(_a);
    var _nb = version_to_numbers(_b);
    for (var _i = 0; _i < VERSION_PARTS; _i++)
    {
        if (_na[_i] < _nb[_i])
        {
            return -1;
        }
        if (_na[_i] > _nb[_i])
        {
            return 1;
        }
    }
    return 0;
}

// ============================================================
//  UPDATE CHECK (async HTTP; result arrives in the Async HTTP event)
// ============================================================

/// @desc Start fetching the remote version file. Safe to call repeatedly.
function about_check_update()
{
    if (about_state == "checking")
    {
        return;
    }
    about_state = "checking";
    about_message = "Checking for updates...";
    about_ver_remote = "";
    about_http_id = http_get(ABOUT_VERSION_URL);
}

/// @desc Handle one async HTTP reply. Called from the Async HTTP event with async_load.
function about_http_result(_async)
{
    var _id = _async[? "id"];
    if (_id != about_http_id)
    {
        return;
    }

    var _status = _async[? "status"];
    if (_status > 0)
    {
        return; // still downloading
    }

    if (_status < 0)
    {
        about_state = "failed";
        about_message = "Could not reach the update server.";
        return;
    }

    var _http = _async[? "http_status"];
    if (_http != 200)
    {
        about_state = "failed";
        about_message = "Update check failed (HTTP " + string(_http) + ").";
        return;
    }

    var _remote = version_parse_text(string(_async[? "result"]));
    if (_remote == "")
    {
        about_state = "failed";
        about_message = "Update check failed (empty version file).";
        return;
    }

    about_ver_remote = _remote;

    if (version_compare(global.app_version, _remote) < 0)
    {
        about_state = "update";
        about_message = "Version " + _remote + " is available.";
    }
    else
    {
        about_state = "current";
        about_message = "You are up to date.";
    }
}

// ============================================================
//  UPDATE BANNER
//  Sits over the viewport under the menu bar once the launch check has
//  found a newer version. Click it to open itch.io, X to dismiss for
//  this session. Shows in the 3D editor and the pixel editor alike.
// ============================================================

/// @desc Should the banner be on screen right now?
function about_banner_active()
{
    if (about_state != "update")
    {
        return false;
    }
    if (about_banner_hide)
    {
        return false;
    }
    if (about_visible)
    {
        return false; // the About panel is already telling them
    }
    return true;
}

/// @desc Banner rect and its two hit areas (GUI pixels).
function about_banner_layout()
{
    var _gw = display_get_gui_width();

    about_banner_x = floor((_gw - ABOUT_BANNER_W) * 0.5);
    about_banner_y = menu_bar_h + 14;

    var _x2 = about_banner_x + ABOUT_BANNER_W;
    var _y2 = about_banner_y + ABOUT_BANNER_H;

    // Dismiss box on the right, the rest of the bar opens itch.io
    about_banner_close = [_x2 - 38, about_banner_y + 10, _x2 - 12, about_banner_y + 36];
    about_banner_get = [_x2 - 210, about_banner_y + 11, _x2 - 40, about_banner_y + 41];
}

/// @desc Banner clicks. Call in Step, before the pixel editor takes over.
function about_banner_update()
{
    if (!about_banner_active())
    {
        return;
    }

    about_banner_layout();

    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    var _inside = (_mx >= about_banner_x && _mx < about_banner_x + ABOUT_BANNER_W && _my >= about_banner_y && _my < about_banner_y + ABOUT_BANNER_H);

    about_banner_hover = "";
    if (about_over(about_banner_close, _mx, _my))
    {
        about_banner_hover = "close";
    }
    else if (_inside)
    {
        about_banner_hover = "get";
    }

    if (!_inside)
    {
        return;
    }

    // The banner owns the mouse while the pointer is over it
    menu_blocks_mouse = true;

    if (mouse_check_button_pressed(mb_left) && !menu_click_consumed)
    {
        if (about_banner_hover == "close")
        {
            about_banner_hide = true;
        }
        else
        {
            url_open(ABOUT_ITCH_URL);
        }
    }
}

/// @desc Draw the banner. Call in Draw GUI, just before menu_draw().
function about_banner_draw()
{
    if (!about_banner_active())
    {
        return;
    }

    about_banner_layout();

    var _x1 = about_banner_x;
    var _y1 = about_banner_y;
    var _x2 = _x1 + ABOUT_BANNER_W;
    var _y2 = _y1 + ABOUT_BANNER_H;

    gpu_set_cullmode(cull_noculling);
    gpu_set_tex_filter(true);
    draw_set_font(font_pixeldown);
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);

    // Slow pulse so it catches the eye without strobing
    var _pulse = 0.5 + 0.5 * sin(current_time / 400);

    // Shadow and body
    draw_set_alpha(0.35);
    draw_set_colour(c_black);
    draw_rectangle(_x1 + 5, _y1 + 5, _x2 + 5, _y2 + 5, false);
    draw_set_alpha(1);
    draw_set_colour(make_color_rgb(150, 95, 10));
    draw_rectangle(_x1, _y1, _x2, _y2, false);

    // Pulsing amber outline
    draw_set_colour(merge_colour(make_color_rgb(200, 140, 30), make_color_rgb(255, 205, 90), _pulse));
    draw_rectangle(_x1, _y1, _x2, _y2, true);
    draw_rectangle(_x1 + 1, _y1 + 1, _x2 - 1, _y2 - 1, true);

    // Message
    draw_set_colour(c_white);
    draw_text(_x1 + 18, _y1 + 18, "Update available:  " + ABOUT_APP_NAME + " " + about_ver_remote);
    draw_set_colour(make_color_rgb(255, 225, 170));
    draw_text(_x1 + 18, _y1 + 36, "You are running " + global.app_version);

    // "Get it on itch.io"
    var _g = about_banner_get;
    if (about_banner_hover == "get")
    {
        draw_set_colour(make_color_rgb(255, 210, 110));
    }
    else
    {
        draw_set_colour(make_color_rgb(215, 160, 55));
    }
    draw_rectangle(_g[0], _g[1], _g[2], _g[3], false);
    draw_set_colour(make_color_rgb(90, 55, 5));
    draw_rectangle(_g[0], _g[1], _g[2], _g[3], true);
    draw_set_colour(make_color_rgb(40, 25, 0));
    draw_set_halign(fa_center);
    draw_text((_g[0] + _g[2]) * 0.5, (_g[1] + _g[3]) * 0.5, "Get it on itch.io");
    draw_set_halign(fa_left);

    // Dismiss
    var _c = about_banner_close;
    if (about_banner_hover == "close")
    {
        draw_set_colour(c_white);
    }
    else
    {
        draw_set_colour(make_color_rgb(255, 215, 150));
    }
    draw_set_halign(fa_center);
    draw_text((_c[0] + _c[2]) * 0.5, (_c[1] + _c[3]) * 0.5, "X");
    draw_set_halign(fa_left);

    // Restore shared draw state
    draw_set_valign(fa_top);
    draw_set_colour(c_white);
    draw_set_alpha(1);
    gpu_set_tex_filter(tex_filter_on);
}

// ============================================================
//  PANEL LAYOUT
// ============================================================

/// @desc Centre the panel on the GUI layer and lay out its buttons.
function about_layout()
{
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();

    about_w = 560;
    about_h = 330;
    about_x = floor((_gw - about_w) * 0.5);
    about_y = floor((_gh - about_h) * 0.5);

    var _bw = 190;
    var _bh = 28;
    var _by = about_y + about_h - _bh - 18;

    about_btn_check = [about_x + 20, _by, about_x + 20 + _bw, _by + _bh];
    about_btn_itch = [about_x + 30 + _bw, _by, about_x + 30 + _bw * 2, _by + _bh];
    about_btn_close = [about_x + about_w - 20 - 90, _by, about_x + about_w - 20, _by + _bh];
}

/// @desc Is the GUI mouse inside a [x1, y1, x2, y2] button rect?
function about_over(_rect, _mx, _my)
{
    return (_mx >= _rect[0] && _mx < _rect[2] && _my >= _rect[1] && _my < _rect[3]);
}

// ============================================================
//  PER-FRAME INPUT
// ============================================================

/// @desc Open the panel (and remember it was asked for by name).
function about_show()
{
    about_visible = true;
}

/// @desc Per-frame menu actions, keys and clicks for the About panel.
/// Call in the Step event straight after menu_update(), before anything else.
function about_update()
{
    // --- Menu actions (consumed so the editors never see them) ---
    if (menu_action == "about_show")
    {
        about_show();
        menu_action = "";
    }
    else if (menu_action == "about_check")
    {
        about_show();
        about_check_update();
        menu_action = "";
    }
    else if (menu_action == "about_itch")
    {
        url_open(ABOUT_ITCH_URL);
        menu_action = "";
    }

    // --- F12 toggles the panel ---
    if (keyboard_check_pressed(vk_f12))
    {
        if (about_visible)
        {
            about_visible = false;
        }
        else
        {
            about_show();
        }
    }

    if (!about_visible)
    {
        return;
    }

    // Any other menu choice made while the panel is up dismisses it and runs as normal
    if (menu_action != "")
    {
        about_visible = false;
        return;
    }

    // The panel owns the mouse while it is up
    menu_blocks_mouse = true;

    about_layout();

    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);

    about_hover = "";
    if (about_over(about_btn_check, _mx, _my))
    {
        about_hover = "check";
    }
    else if (about_over(about_btn_itch, _mx, _my))
    {
        about_hover = "itch";
    }
    else if (about_over(about_btn_close, _mx, _my))
    {
        about_hover = "close";
    }

    // --- Esc closes the panel (and must not fall through to quitting) ---
    if (keyboard_check_pressed(vk_escape) && !menu_esc_consumed)
    {
        about_visible = false;
        menu_esc_consumed = true;
        return;
    }

    // --- Clicks (a click the menu bar already took is left alone) ---
    if (mouse_check_button_pressed(mb_left) && !menu_click_consumed)
    {
        if (about_hover == "check")
        {
            about_check_update();
        }
        else if (about_hover == "itch")
        {
            url_open(ABOUT_ITCH_URL);
        }
        else if (about_hover == "close")
        {
            about_visible = false;
        }
        else
        {
            var _inside = (_mx >= about_x && _mx < about_x + about_w && _my >= about_y && _my < about_y + about_h);
            if (!_inside)
            {
                about_visible = false;
            }
        }
    }
}

// ============================================================
//  DRAW
// ============================================================

/// @desc One button of the panel.
function about_draw_button(_rect, _label, _hot, _enabled)
{
    var _col = menu_col_hover;
    if (!_enabled)
    {
        _col = menu_col_panel;
    }
    else if (_hot)
    {
        _col = menu_col_accent;
    }

    draw_set_colour(_col);
    draw_rectangle(_rect[0], _rect[1], _rect[2], _rect[3], false);
    draw_set_colour(menu_col_line);
    draw_rectangle(_rect[0], _rect[1], _rect[2], _rect[3], true);

    if (_enabled)
    {
        draw_set_colour(c_white);
    }
    else
    {
        draw_set_colour(c_gray);
    }
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text((_rect[0] + _rect[2]) * 0.5, (_rect[1] + _rect[3]) * 0.5, _label);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

/// @desc Draw the About panel. Call in Draw GUI, just before menu_draw().
function about_draw()
{
    if (!about_visible)
    {
        return;
    }

    about_layout();

    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();

    gpu_set_cullmode(cull_noculling);
    gpu_set_tex_filter(true);
    draw_set_font(font_pixeldown);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // Dim everything behind the panel
    draw_set_alpha(0.55);
    draw_set_colour(c_black);
    draw_rectangle(0, 0, _gw, _gh, false);
    draw_set_alpha(1);

    var _x1 = about_x;
    var _y1 = about_y;
    var _x2 = about_x + about_w;
    var _y2 = about_y + about_h;

    // Shadow, body, outline
    draw_set_alpha(0.35);
    draw_set_colour(c_black);
    draw_rectangle(_x1 + 6, _y1 + 6, _x2 + 6, _y2 + 6, false);
    draw_set_alpha(1);
    draw_set_colour(menu_col_panel);
    draw_rectangle(_x1, _y1, _x2, _y2, false);
    draw_set_colour(menu_col_line);
    draw_rectangle(_x1, _y1, _x2, _y2, true);

    // Title strip
    draw_set_colour(menu_col_bar);
    draw_rectangle(_x1 + 1, _y1 + 1, _x2 - 1, _y1 + 44, false);
    draw_set_colour(menu_col_line);
    draw_line(_x1 + 1, _y1 + 44, _x2 - 1, _y1 + 44);

    draw_set_colour(c_white);
    draw_text(_x1 + 20, _y1 + 8, ABOUT_APP_NAME);
    draw_set_colour(c_ltgray);
    draw_text(_x1 + 20, _y1 + 25, ABOUT_TAGLINE);

    var _lx = _x1 + 20;
    var _vx = _x1 + 190;
    var _ty = _y1 + 62;
    var _line = 19;

    // --- Version ---
    draw_set_colour(c_ltgray);
    draw_text(_lx, _ty, "Version");
    draw_set_colour(c_white);
    draw_text(_vx, _ty, global.app_version);
    _ty += _line;

    draw_set_colour(c_ltgray);
    draw_text(_lx, _ty, "Latest release");
    if (about_state == "update")
    {
        draw_set_colour(c_yellow);
        draw_text(_vx, _ty, about_ver_remote + "  -  update available");
    }
    else if (about_state == "current")
    {
        draw_set_colour(c_lime);
        draw_text(_vx, _ty, about_ver_remote + "  -  up to date");
    }
    else if (about_state == "checking")
    {
        draw_set_colour(c_white);
        draw_text(_vx, _ty, "checking...");
    }
    else if (about_state == "failed")
    {
        draw_set_colour(c_orange);
        draw_text(_vx, _ty, about_message);
    }
    else
    {
        draw_set_colour(c_gray);
        draw_text(_vx, _ty, "not checked yet");
    }
    _ty += _line + 12;

    // --- Credits ---
    draw_set_colour(menu_col_line);
    draw_line(_lx, _ty, _x2 - 20, _ty);
    _ty += 10;

    draw_set_colour(c_white);
    draw_text(_lx, _ty, "Credits");
    _ty += _line + 4;

    draw_set_colour(c_ltgray);
    draw_text(_lx, _ty, "Code and design");
    draw_set_colour(c_white);
    draw_text(_vx, _ty, "Robert Ramsay");
    _ty += _line;

    draw_set_colour(c_ltgray);
    draw_text(_lx, _ty, "Built-in graphics");
    draw_set_colour(c_white);
    draw_text(_vx, _ty, "Robert Ramsay");
    _ty += _line;

    draw_set_colour(c_ltgray);
    draw_text(_lx, _ty, "Published by");
    draw_set_colour(c_white);
    draw_text(_vx, _ty, "Polytricity Ltd");
    _ty += _line + 8;

    draw_set_colour(c_gray);
    draw_text(_lx, _ty, ABOUT_ITCH_URL);

    // --- Buttons ---
    var _can_check = (about_state != "checking");
    about_draw_button(about_btn_check, "Check for updates", (about_hover == "check"), _can_check);
    about_draw_button(about_btn_itch, "Get it on itch.io", (about_hover == "itch"), true);
    about_draw_button(about_btn_close, "Close", (about_hover == "close"), true);

    // Restore shared draw state
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_colour(c_white);
    draw_set_alpha(1);
    gpu_set_tex_filter(tex_filter_on);
}

// ============================================================
//  GUIDED TOUR (Help > Guided tour; offered on first launch)
// ============================================================
// A step-by-step checklist that ticks itself off as the user actually does
// each thing. Code around the editor reports what happened with
// tut_event("name"); the current step completes once its event has arrived
// enough times. The steps themselves live in the Create event (tut_chapters).
//
// The tour runs in a scratch scene: the user's scene (tiles, tileset, clips)
// is saved to a backup file first and loaded back when the tour ends.

#macro TUT_CARD_W 480
#macro TUT_PAD 16

/// @desc Where tour progress is kept (next to the recent-files list).
function tut_store_path()
{
    var _dir = environment_get_variable("APPDATA");
    if (_dir == "")
    {
        _dir = environment_get_variable("HOME");
    }
    if (_dir == "")
    {
        return "pix3ll3d_tour.txt";
    }
    return _dir + "/pix3ll3d_tour.txt";
}

/// @desc Where the user's scene waits while the tour runs.
function tut_backup_file()
{
    var _dir = environment_get_variable("APPDATA");
    if (_dir == "")
    {
        _dir = environment_get_variable("HOME");
    }
    if (_dir == "")
    {
        return "pix3ll3d_tour_backup.scene";
    }
    return _dir + "/pix3ll3d_tour_backup.scene";
}

/// @desc Read progress: line 1 "dontask=0/1", then one finished step id per line.
function tut_load()
{
    var _file = tut_store_path();
    if (!file_exists(_file))
    {
        return;
    }

    var _f = file_text_open_read(_file);
    if (_f < 0)
    {
        return;
    }

    var _first = true;
    while (!file_text_eof(_f))
    {
        var _line = string_trim(file_text_read_string(_f));
        file_text_readln(_f);

        if (_first)
        {
            _first = false;
            if (_line == "dontask=1")
            {
                tut_dont_ask = true;
            }
            continue;
        }

        for (var _c = 0; _c < array_length(tut_chapters); _c++)
        {
            var _steps = tut_chapters[_c].steps;
            for (var _s = 0; _s < array_length(_steps); _s++)
            {
                if (_steps[_s].id == _line)
                {
                    _steps[_s].done = true;
                }
            }
        }
    }
    file_text_close(_f);
}

/// @desc Write progress back out.
function tut_save()
{
    var _f = file_text_open_write(tut_store_path());
    if (_f < 0)
    {
        return;
    }

    if (tut_dont_ask)
    {
        file_text_write_string(_f, "dontask=1");
    }
    else
    {
        file_text_write_string(_f, "dontask=0");
    }
    file_text_writeln(_f);

    for (var _c = 0; _c < array_length(tut_chapters); _c++)
    {
        var _steps = tut_chapters[_c].steps;
        for (var _s = 0; _s < array_length(_steps); _s++)
        {
            if (_steps[_s].done)
            {
                file_text_write_string(_f, _steps[_s].id);
                file_text_writeln(_f);
            }
        }
    }
    file_text_close(_f);
}

/// @desc Counts for the progress bar, rank and finish card.
function tut_totals()
{
    var _out = { steps: 0, done: 0, chapters_done: 0 };
    for (var _c = 0; _c < array_length(tut_chapters); _c++)
    {
        var _steps = tut_chapters[_c].steps;
        var _all = true;
        for (var _s = 0; _s < array_length(_steps); _s++)
        {
            _out.steps += 1;
            if (_steps[_s].done)
            {
                _out.done += 1;
            }
            else
            {
                _all = false;
            }
        }
        if (_all)
        {
            _out.chapters_done += 1;
        }
    }
    return _out;
}

/// @desc Title that grows with finished chapters.
function tut_rank()
{
    var _names = ["Trainee", "Builder", "Architect", "Master builder", "Pixel Wizard"];
    var _chapters = max(1, array_length(tut_chapters));
    var _i = floor(tut_totals().chapters_done * (array_length(_names) - 1) / _chapters);
    _i = clamp(_i, 0, array_length(_names) - 1);
    return _names[_i];
}

/// @desc True when every step of a chapter is done.
function tut_chapter_done(_c)
{
    var _steps = tut_chapters[_c].steps;
    for (var _s = 0; _s < array_length(_steps); _s++)
    {
        if (!_steps[_s].done)
        {
            return false;
        }
    }
    return true;
}

/// @desc Move to the first unfinished step at or after chapter _c. Sets
/// tut_finished when there is nothing left.
function tut_seek_from(_c)
{
    for (var _cc = _c; _cc < array_length(tut_chapters); _cc++)
    {
        var _steps = tut_chapters[_cc].steps;
        for (var _s = 0; _s < array_length(_steps); _s++)
        {
            if (!_steps[_s].done)
            {
                tut_ch = _cc;
                tut_st = _s;
                tut_finished = false;
                return;
            }
        }
    }
    // Nothing after _c: look from the start (a skipped step may remain)
    for (var _cb = 0; _cb < _c; _cb++)
    {
        var _steps_b = tut_chapters[_cb].steps;
        for (var _sb = 0; _sb < array_length(_steps_b); _sb++)
        {
            if (!_steps_b[_sb].done)
            {
                tut_ch = _cb;
                tut_st = _sb;
                tut_finished = false;
                return;
            }
        }
    }
    tut_finished = true;
}

/// @desc The step on screen now.
function tut_current()
{
    return tut_chapters[tut_ch].steps[tut_st];
}

/// @desc Start the tour: park the user's scene, then begin from the first
/// unfinished step.
function tut_start()
{
    tut_saved_path = scene_path;
    scene_save(tut_backup_file());

    global.world_tiles = {};
    global.undo_stack = [];
    global.redo_stack = [];
    scene_path = "";

    tut_active = true;
    tut_checklist = false;
    tut_time = 0;
    tut_sparks = [];
    tut_seek_from(0);

    tile_msg = "Tour started - your scene is kept safe and comes back when you finish";
    tile_msg_timer = room_speed * 4;
}

/// @desc End the tour and bring the user's scene back exactly as it was.
function tut_stop()
{
    tut_active = false;
    tut_checklist = false;
    tut_finished = false;
    tut_save();

    var _backup = tut_backup_file();
    if (file_exists(_backup))
    {
        scene_load(_backup);
        file_delete(_backup);
    }
    scene_path = tut_saved_path;
    global.undo_stack = [];
    global.redo_stack = [];

    tile_msg = "Tour closed - your scene is back. Help > Guided tour picks up where you left off";
    tile_msg_timer = room_speed * 4;
}

/// @desc Report that something happened. Cheap when no tour is running.
function tut_event(_ev)
{
    if (!tut_active || tut_finished || tut_checklist)
    {
        return;
    }

    var _st = tut_current();
    if (_st.done || _st.ev != _ev)
    {
        return;
    }

    _st.count += 1;
    if (_st.count >= _st.need)
    {
        tut_complete_step();
    }
}

/// @desc Tick the current step, celebrate, and move on.
function tut_complete_step()
{
    var _st = tut_current();
    _st.done = true;
    tut_flash = room_speed * 0.6;
    tut_burst(24);

    var _ch = tut_ch;
    if (tut_chapter_done(_ch))
    {
        tut_toast = "Chapter complete!  Medal: " + tut_chapters[_ch].medal + "   Rank: " + tut_rank();
        tut_toast_timer = room_speed * 4;
        tut_burst(60);
    }

    tut_save();
    tut_seek_from(_ch);
}

/// @desc A shower of sparkles from the tick box on the card.
function tut_burst(_n)
{
    var _L = tut_card_layout();
    var _cols = [c_yellow, make_colour_rgb(120, 220, 255), make_colour_rgb(255, 120, 220), c_white, make_colour_rgb(140, 255, 140)];
    for (var _i = 0; _i < _n; _i++)
    {
        var _a = random(360);
        var _sp = random_range(2, 7);
        array_push(tut_sparks, {
            x: _L.x + 30,
            y: _L.step_y + 10,
            vx: lengthdir_x(_sp, _a),
            vy: lengthdir_y(_sp, _a) - 2,
            life: irandom_range(25, 50),
            col: _cols[irandom(array_length(_cols) - 1)]
        });
    }
}

/// @desc Positions of everything on the card (GUI pixels). Shared by the
/// Step (clicks) and Draw GUI (drawing) so they always agree.
/// Top-right in the 3D view; bottom-left of the canvas in the pixel editor,
/// clear of its tool and colour panels.
function tut_card_layout()
{
    draw_set_font(font_pixeldown);
    var _w = TUT_CARD_W;
    var _x = display_get_gui_width() - _w - 16;
    if (pe_open)
    {
        _x = pe_vx0 + 12;
    }
    var _y = 0;   // laid out from 0, moved into place at the end
    var _line = string_height("Ag") + 4;
    var _inner = _w - TUT_PAD * 2;

    var _out = {
        x: _x,
        y: _y,
        w: _w,
        h: 0,
        line: _line,
        step_y: 0,
        btns: [],
        rows: []
    };

    var _cy = _y + TUT_PAD;
    _cy += _line;          // "GUIDED TOUR" + rank
    _cy += _line;          // chapter line
    _cy += 14;             // progress bar
    _cy += 10;

    if (tut_finished)
    {
        _out.step_y = _cy;
        _cy += _line * 5 + 10;
        var _bw = string_width("Finish") + 30;
        array_push(_out.btns, { label: "Finish", act: "finish", x: _x + _w - TUT_PAD - _bw, y: _cy, w: _bw, h: _line + 10 });
        _cy += _line + 10;
    }
    else if (tut_checklist)
    {
        _out.step_y = _cy;
        for (var _c = 0; _c < array_length(tut_chapters); _c++)
        {
            array_push(_out.rows, { ch: _c, x: _x + TUT_PAD, y: _cy, w: _inner, h: _line });
            _cy += _line;
            _cy += _line * array_length(tut_chapters[_c].steps);
            _cy += 6;
        }
        _cy += 6;
        var _bw = string_width("Close list") + 30;
        array_push(_out.btns, { label: "Close list", act: "list", x: _x + _w - TUT_PAD - _bw, y: _cy, w: _bw, h: _line + 10 });
        _cy += _line + 10;
    }
    else
    {
        var _st = tut_current();
        _out.step_y = _cy;
        _cy += _line + 4;  // step title
        _cy += string_height_ext(_st.how, _line, _inner - 10) + 10;
        _cy += _line + 14; // key badge
        _cy += 8;

        var _labels = ["Back", "Skip", "Checklist", "Quit tour"];
        var _acts = ["back", "skip", "list", "quit"];
        var _bx = _x + TUT_PAD;
        for (var _b = 0; _b < 4; _b++)
        {
            var _bw = string_width(_labels[_b]) + 24;
            array_push(_out.btns, { label: _labels[_b], act: _acts[_b], x: _bx, y: _cy, w: _bw, h: _line + 10 });
            _bx += _bw + 8;
        }
        _cy += _line + 10;
    }

    _out.h = _cy + TUT_PAD - _y;

    // Move everything down to where the card really sits
    var _top = menu_bar_h + 12;
    if (pe_open)
    {
        _top = pe_vy1 - 12 - _out.h;
    }
    _out.y += _top;
    _out.step_y += _top;
    for (var _b = 0; _b < array_length(_out.btns); _b++)
    {
        _out.btns[_b].y += _top;
    }
    for (var _r = 0; _r < array_length(_out.rows); _r++)
    {
        _out.rows[_r].y += _top;
    }
    return _out;
}

/// @desc Card input, timers and sparkles. Call in the Step event: in the 3D
/// view after clip_strip_update(), in the pixel editor before pe_step().
/// Claims the mouse over the card (clip_blocks_mouse, and tut_mouse_over for
/// the pixel editor, which listens to menu_blocks_mouse instead).
function tut_update()
{
    tut_mouse_over = false;
    // Sparkles and the toast keep running for a moment after a finish
    for (var _i = array_length(tut_sparks) - 1; _i >= 0; _i--)
    {
        var _p = tut_sparks[_i];
        _p.x += _p.vx;
        _p.y += _p.vy;
        _p.vy += 0.25;
        _p.life -= 1;
        if (_p.life <= 0)
        {
            array_delete(tut_sparks, _i, 1);
        }
    }
    if (tut_toast_timer > 0)
    {
        tut_toast_timer -= 1;
    }
    if (tut_flash > 0)
    {
        tut_flash -= 1;
    }

    if (!tut_active)
    {
        return;
    }

    if (!tut_finished)
    {
        tut_time += delta_time / 1000000;
    }

    var _L = tut_card_layout();
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);

    tut_hover = "";
    if (_mx < _L.x || _mx > _L.x + _L.w || _my < _L.y || _my > _L.y + _L.h)
    {
        return;
    }

    clip_blocks_mouse = true; // the card owns the mouse, same as the clip strip
    tut_mouse_over = true;

    for (var _b = 0; _b < array_length(_L.btns); _b++)
    {
        var _btn = _L.btns[_b];
        if (_mx >= _btn.x && _mx <= _btn.x + _btn.w && _my >= _btn.y && _my <= _btn.y + _btn.h)
        {
            tut_hover = _btn.act;
        }
    }

    var _row_hover = -1;
    for (var _r = 0; _r < array_length(_L.rows); _r++)
    {
        var _row = _L.rows[_r];
        if (_mx >= _row.x && _mx <= _row.x + _row.w && _my >= _row.y && _my <= _row.y + _row.h)
        {
            _row_hover = _row.ch;
        }
    }
    tut_row_hover = _row_hover;

    if (!mouse_check_button_pressed(mb_left))
    {
        return;
    }

    if (_row_hover >= 0)
    {
        // Jump to a chapter: its first unfinished step, or its first step
        tut_checklist = false;
        tut_ch = _row_hover;
        tut_st = 0;
        var _steps = tut_chapters[_row_hover].steps;
        for (var _s = array_length(_steps) - 1; _s >= 0; _s--)
        {
            if (!_steps[_s].done)
            {
                tut_st = _s;
            }
        }
        tut_finished = false;
        return;
    }

    switch (tut_hover)
    {
        case "back":
            // Go back one step and let it be done again
            if (tut_st > 0)
            {
                tut_st -= 1;
            }
            else if (tut_ch > 0)
            {
                tut_ch -= 1;
                tut_st = array_length(tut_chapters[tut_ch].steps) - 1;
            }
            var _bk = tut_current();
            _bk.done = false;
            _bk.count = 0;
            break;

        case "skip":
            // Move on without ticking it; it stays open on the checklist
            var _here = tut_chapters[tut_ch].steps;
            if (tut_st < array_length(_here) - 1)
            {
                tut_st += 1;
            }
            else if (tut_ch < array_length(tut_chapters) - 1)
            {
                tut_ch += 1;
                tut_st = 0;
            }
            else
            {
                tut_finished = true;
            }
            break;

        case "list":
            tut_checklist = !tut_checklist;
            break;

        case "quit":
            tut_stop();
            break;

        case "finish":
            tut_stop();
            break;
    }
}

/// @desc Draw a small button.
function tut_draw_button(_btn, _primary)
{
    var _fill = make_colour_rgb(58, 62, 78);
    if (_primary)
    {
        _fill = make_colour_rgb(60, 105, 200);
    }
    if (tut_hover == _btn.act)
    {
        _fill = make_colour_rgb(90, 140, 235);
    }
    draw_set_colour(_fill);
    draw_rectangle(_btn.x, _btn.y, _btn.x + _btn.w, _btn.y + _btn.h, false);
    draw_set_colour(make_colour_rgb(120, 125, 145));
    draw_rectangle(_btn.x, _btn.y, _btn.x + _btn.w, _btn.y + _btn.h, true);
    draw_set_colour(c_white);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(_btn.x + _btn.w * 0.5, _btn.y + _btn.h * 0.5, _btn.label);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

/// @desc Draw the card, sparkles and chapter toast. Call from Draw GUI (3D view).
function tut_draw()
{
    gpu_set_tex_filter(true);
    draw_set_font(font_pixeldown);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    if (tut_active)
    {
        var _L = tut_card_layout();
        var _x = _L.x;
        var _w = _L.w;
        var _line = _L.line;
        var _inner = _w - TUT_PAD * 2;

        draw_set_alpha(0.94);
        draw_set_colour(make_colour_rgb(26, 28, 38));
        draw_rectangle(_x, _L.y, _x + _w, _L.y + _L.h, false);
        draw_set_alpha(1);
        draw_set_colour(make_colour_rgb(60, 105, 200));
        draw_rectangle(_x, _L.y, _x + _w, _L.y + _L.h, true);

        var _cy = _L.y + TUT_PAD;
        var _tot = tut_totals();

        draw_set_colour(make_colour_rgb(255, 210, 90));
        draw_text(_x + TUT_PAD, _cy, "GUIDED TOUR");
        var _rank = "Rank: " + tut_rank();
        draw_set_colour(make_colour_rgb(150, 155, 175));
        draw_text(_x + _w - TUT_PAD - string_width(_rank), _cy, _rank);
        _cy += _line;

        draw_set_colour(make_colour_rgb(120, 170, 255));
        draw_text(_x + TUT_PAD, _cy, "Chapter " + string(tut_ch + 1) + " of " + string(array_length(tut_chapters)) + " - " + tut_chapters[tut_ch].title);
        _cy += _line;

        // Progress bar over every step of every chapter
        var _frac = 0;
        if (_tot.steps > 0)
        {
            _frac = _tot.done / _tot.steps;
        }
        draw_set_colour(make_colour_rgb(50, 54, 68));
        draw_rectangle(_x + TUT_PAD, _cy + 2, _x + TUT_PAD + _inner, _cy + 10, false);
        draw_set_colour(make_colour_rgb(110, 220, 120));
        draw_rectangle(_x + TUT_PAD, _cy + 2, _x + TUT_PAD + _inner * _frac, _cy + 10, false);
        _cy += 24;

        if (tut_finished)
        {
            var _mins = floor(tut_time / 60);
            var _secs = floor(tut_time) mod 60;
            var _secs_txt = string(_secs);
            if (_secs < 10)
            {
                _secs_txt = "0" + _secs_txt;
            }
            draw_set_colour(c_yellow);
            draw_text(_x + TUT_PAD, _cy, "TOUR COMPLETE!");
            draw_set_colour(c_white);
            draw_text(_x + TUT_PAD, _cy + _line, string(_tot.done) + " of " + string(_tot.steps) + " steps in " + string(_mins) + ":" + _secs_txt);
            draw_text(_x + TUT_PAD, _cy + _line * 2, "Rank: " + tut_rank());
            draw_set_colour(make_colour_rgb(185, 190, 205));
            draw_text(_x + TUT_PAD, _cy + _line * 3, "That's every part of the editor covered.");
            draw_text(_x + TUT_PAD, _cy + _line * 4, "F9 shows every shortcut, any time.");
            tut_draw_button(_L.btns[0], true);
        }
        else if (tut_checklist)
        {
            for (var _c = 0; _c < array_length(tut_chapters); _c++)
            {
                var _row = _L.rows[_c];
                var _chd = tut_chapter_done(_c);
                if (tut_row_hover == _c)
                {
                    draw_set_colour(make_colour_rgb(45, 50, 70));
                    draw_rectangle(_row.x - 4, _row.y, _row.x + _row.w, _row.y + _row.h, false);
                }
                draw_set_colour(make_colour_rgb(120, 170, 255));
                var _medal = "";
                if (_chd)
                {
                    _medal = "   [" + tut_chapters[_c].medal + "]";
                }
                draw_text(_row.x, _row.y, string(_c + 1) + ". " + tut_chapters[_c].title + _medal);

                var _sy = _row.y + _line;
                var _steps = tut_chapters[_c].steps;
                for (var _s = 0; _s < array_length(_steps); _s++)
                {
                    var _mark = "[ ]";
                    draw_set_colour(make_colour_rgb(185, 190, 205));
                    if (_steps[_s].done)
                    {
                        _mark = "[x]";
                        draw_set_colour(make_colour_rgb(110, 220, 120));
                    }
                    draw_text(_row.x + 14, _sy, _mark + " " + _steps[_s].text);
                    _sy += _line;
                }
            }
            tut_draw_button(_L.btns[0], false);
        }
        else
        {
            var _st = tut_current();

            // Tick box (flashes green when a step completes)
            var _box = make_colour_rgb(120, 125, 145);
            if (tut_flash > 0)
            {
                _box = make_colour_rgb(110, 220, 120);
            }
            draw_set_colour(_box);
            draw_rectangle(_x + TUT_PAD, _cy + 2, _x + TUT_PAD + 16, _cy + 18, true);

            draw_set_colour(c_white);
            var _title = "Step " + string(tut_st + 1) + " of " + string(array_length(tut_chapters[tut_ch].steps)) + ":  " + _st.text;
            draw_text(_x + TUT_PAD + 26, _cy, _title);
            _cy += _line + 4;

            draw_set_colour(make_colour_rgb(185, 190, 205));
            draw_text_ext(_x + TUT_PAD + 10, _cy, _st.how, _line, _inner - 10);
            _cy += string_height_ext(_st.how, _line, _inner - 10) + 10;

            // The key to press, with a slow pulse
            var _kw = string_width(_st.key) + 24;
            var _pulse = 0.5 + 0.5 * sin(current_time / 180);
            draw_set_colour(make_colour_rgb(36, 40, 56));
            draw_rectangle(_x + TUT_PAD + 10, _cy, _x + TUT_PAD + 10 + _kw, _cy + _line + 8, false);
            draw_set_colour(merge_colour(make_colour_rgb(60, 105, 200), c_yellow, _pulse));
            draw_rectangle(_x + TUT_PAD + 10, _cy, _x + TUT_PAD + 10 + _kw, _cy + _line + 8, true);
            draw_set_colour(c_yellow);
            draw_text(_x + TUT_PAD + 22, _cy + 4, _st.key);

            if (_st.need > 1)
            {
                draw_set_colour(make_colour_rgb(150, 155, 175));
                var _pct = floor(min(_st.count, _st.need) / _st.need * 100);
                draw_text(_x + TUT_PAD + 22 + _kw, _cy + 4, string(_pct) + "%");
            }

            for (var _b = 0; _b < array_length(_L.btns); _b++)
            {
                tut_draw_button(_L.btns[_b], false);
            }
        }
    }

    // Sparkles
    for (var _i = 0; _i < array_length(tut_sparks); _i++)
    {
        var _p = tut_sparks[_i];
        draw_set_alpha(min(1, _p.life / 20));
        draw_set_colour(_p.col);
        draw_rectangle(_p.x - 2, _p.y - 2, _p.x + 2, _p.y + 2, false);
    }
    draw_set_alpha(1);

    // Chapter toast, centre screen
    if (tut_toast_timer > 0)
    {
        var _gw = display_get_gui_width();
        var _ty = display_get_gui_height() * 0.3;
        var _tw = string_width(tut_toast) + 40;
        draw_set_alpha(min(1, tut_toast_timer / 20));
        draw_set_colour(make_colour_rgb(30, 60, 40));
        draw_rectangle((_gw - _tw) * 0.5, _ty - 6, (_gw + _tw) * 0.5, _ty + 30, false);
        draw_set_colour(make_colour_rgb(110, 220, 120));
        draw_rectangle((_gw - _tw) * 0.5, _ty - 6, (_gw + _tw) * 0.5, _ty + 30, true);
        draw_set_colour(c_white);
        draw_set_halign(fa_center);
        draw_text(_gw * 0.5, _ty, tut_toast);
        draw_set_halign(fa_left);
        draw_set_alpha(1);
    }

    draw_set_colour(c_white);
}

// ------------------------------------------------------------
//  First-launch question
// ------------------------------------------------------------

/// @desc Card geometry for the question.
function tut_prompt_layout()
{
    draw_set_font(font_pixeldown);
    var _w = 560;
    var _line = string_height("Ag") + 4;
    var _h = TUT_PAD * 2 + _line * 5 + 20 + _line + 10;
    var _x = floor((display_get_gui_width() - _w) * 0.5);
    var _y = floor((display_get_gui_height() - _h) * 0.5);
    var _by = _y + _h - TUT_PAD - (_line + 10);

    var _labels = ["Start tour", "Not now", "Don't ask again"];
    var _acts = ["start", "later", "never"];
    var _btns = [];
    var _total = 0;
    for (var _b = 0; _b < 3; _b++)
    {
        _total += string_width(_labels[_b]) + 30;
    }
    _total += 16;
    var _bx = _x + floor((_w - _total) * 0.5);
    for (var _b = 0; _b < 3; _b++)
    {
        var _bw = string_width(_labels[_b]) + 30;
        array_push(_btns, { label: _labels[_b], act: _acts[_b], x: _bx, y: _by, w: _bw, h: _line + 10 });
        _bx += _bw + 8;
    }

    return { x: _x, y: _y, w: _w, h: _h, line: _line, btns: _btns };
}

/// @desc Question input. The caller exits the Step while tut_prompt is true.
function tut_prompt_update()
{
    var _L = tut_prompt_layout();
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);

    tut_hover = "";
    for (var _b = 0; _b < array_length(_L.btns); _b++)
    {
        var _btn = _L.btns[_b];
        if (_mx >= _btn.x && _mx <= _btn.x + _btn.w && _my >= _btn.y && _my <= _btn.y + _btn.h)
        {
            tut_hover = _btn.act;
        }
    }

    if (!mouse_check_button_pressed(mb_left))
    {
        return;
    }

    switch (tut_hover)
    {
        case "start":
            tut_prompt = false;
            tut_start();
            break;

        case "later":
            tut_prompt = false;
            break;

        case "never":
            tut_prompt = false;
            tut_dont_ask = true;
            tut_save();
            break;
    }
}

/// @desc Draw the question. Call from Draw GUI.
function tut_prompt_draw()
{
    if (!tut_prompt)
    {
        return;
    }

    var _L = tut_prompt_layout();
    gpu_set_tex_filter(true);
    draw_set_font(font_pixeldown);

    draw_set_alpha(0.55);
    draw_set_colour(c_black);
    draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
    draw_set_alpha(1);

    draw_set_colour(make_colour_rgb(26, 28, 38));
    draw_rectangle(_L.x, _L.y, _L.x + _L.w, _L.y + _L.h, false);
    draw_set_colour(make_colour_rgb(60, 105, 200));
    draw_rectangle(_L.x, _L.y, _L.x + _L.w, _L.y + _L.h, true);

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    var _cx = _L.x + _L.w * 0.5;
    var _cy = _L.y + TUT_PAD;
    draw_set_colour(c_yellow);
    draw_text(_cx, _cy, "Welcome to " + ABOUT_APP_NAME + "!");
    draw_set_colour(c_white);
    draw_text(_cx, _cy + _L.line * 1.5, "Take the guided tour? It walks you through");
    draw_text(_cx, _cy + _L.line * 2.5, "the controls one small task at a time.");
    draw_set_colour(make_colour_rgb(150, 155, 175));
    draw_text(_cx, _cy + _L.line * 3.8, "Any scene you have open is kept safe and comes back after.");
    draw_set_halign(fa_left);

    for (var _b = 0; _b < array_length(_L.btns); _b++)
    {
        tut_draw_button(_L.btns[_b], _b == 0);
    }
}
