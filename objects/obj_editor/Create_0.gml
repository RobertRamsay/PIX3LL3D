/// @desc CREATE EVENT of obj_editor

// --- 3D RENDER SETTINGS ---
gpu_set_ztestenable(true);
gpu_set_zwriteenable(true);
gpu_set_alphatestenable(true);
tex_filter_on = false;
gpu_set_tex_filter(tex_filter_on);
cull_on = false;
gpu_set_cullmode(cull_noculling);
grid_visible = true;

// --- BACKGROUND GRADIENT (sky top / bottom tones, editable from the swatch by the axis box) ---
bg_col_top = make_color_rgb(135, 206, 235);
bg_col_bot = make_color_rgb(40, 60, 170);
bg_edit = "";          // "" closed, "top" or "bot" while the RGB popup is open
bg_drag = -1;          // slider being dragged (0 R, 1 G, 2 B), -1 = none
bg_ui_x = 0;           // swatch rect (set by bg_ui_layout)
bg_ui_y = 0;
bg_ui_w = 0;
bg_ui_h = 0;
bg_pop_x = 0;          // popup rect
bg_pop_y = 0;
bg_pop_w = 0;
bg_pop_h = 0;
bg_slider_h = 12;
bg_slider_step = 26;

// --- UI SCALE (GUI is a fixed 1080-high logical layer; see ui_update_gui_size) ---
ui_ref_h = 1080;
ui_last_w = 0;
ui_last_h = 0;

// --- WINDOW (F10 toggles fullscreen; see WINDOW_system) ---
// Size to come back to when dropping out of fullscreen. Updated every time
// you leave a window, so the toggle remembers what you last had. The room is
// 3840x2160, so without an explicit size a windowed run would open at 4K.
win_last_w = WINDOW_DEFAULT_W;
win_last_h = WINDOW_DEFAULT_H;
win_settle = 0;          // frames left before the pending window rect is applied
win_cooldown = 0;        // frames before another toggle is accepted

// We start "fullscreen" as a borderless window filling the display. The
// project option already opens it borderless, so this is just the size.
// window_set_fullscreen is never used - see WINDOW_system for why.
win_is_full = true;
window_set_rectangle(0, 0, display_get_width(), display_get_height());

// --- APPLICATION SURFACE (post FX read it; see POSTFX_system) ---
// The 3D view renders here, and postfx_draw_scene() puts it on screen at the
// top of Draw GUI, so the UI drawn afterwards never goes through the shader.
application_surface_enable(true);
application_surface_draw_enable(false);

// --- DISPLAY (vsync on, no MSAA) ---
// MSAA is gone. It was cheap while the editor drew straight to the back
// buffer, but once the 3D view moved onto the application surface for the
// post FX it became a full multisampled render target every frame, for
// almost no visible gain on this geometry.
display_reset(0, true);
// --- CAMERA VARIABLES ---
cam_dist = 12;
cam_pitch = 20.7;
cam_yaw = 0;
cam_look_x = 0.73;
cam_look_y = 0;
cam_look_z = -0.3;
// Defaults for Home-key reset
cam_dist_default = cam_dist;
cam_pitch_default = cam_pitch;
cam_yaw_default = cam_yaw;
cam_look_x_default = cam_look_x;
cam_look_y_default = cam_look_y;
cam_look_z_default = cam_look_z;
cam_dragging = false;
cam_panning = false;
cam_pan_anchor_x = 0;
cam_pan_anchor_y = 0;
cam_pan_anchor_z = 0;

// --- TILE DATA ---
global.world_tiles = {};

// --- UNDO / REDO (snapshot stacks, capped) ---
global.undo_stack = [];   // each entry is a deep clone of world_tiles
global.redo_stack = [];
global.undo_max = 100;
scene_path = "";          // last saved/loaded file path ("" = none yet)
global.recent_scenes = [];   // recently saved/loaded scenes, newest first
menu_file_base = [];         // File menu as written below, before recents
active_plane = "XY";

// --- VERTEX FORMAT (colour only: grid + ghost) ---
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
global.v_format = vertex_format_end();
// --- VERTEX BUFFER ---
global.v_buffer = vertex_create_buffer();
// --- VERTEX FORMAT (textured: committed tiles) ---
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_texcoord();
vertex_format_add_color();
global.v_format_tex = vertex_format_end();
// --- VERTEX BUFFER (textured) ---
global.v_buffer_tex = vertex_create_buffer();

// --- 3D GRID (thick screen-space lines; see GRID_system + sh_grid_line) ---
grid_line_px = 3;                                // line width in screen pixels
grid_half = 20;                                  // grid runs -grid_half..+grid_half
grid_col_ref = make_color_rgb(80, 120, 220);     // zero-offset reference grid
vertex_format_begin();
vertex_format_add_position_3d();                 // this endpoint
vertex_format_add_normal();                      // the other endpoint
vertex_format_add_color();
vertex_format_add_texcoord();                    // x = side (-1 / +1)
grid_vfmt = vertex_format_end();
grid_vb = vertex_create_buffer();
grid_vb_key = "";                                // placement the buffer was built for
grid_u_screen = shader_get_uniform(sh_grid_line, "u_screen");
grid_u_width = shader_get_uniform(sh_grid_line, "u_width");
// --- GHOST TILE ---
ghost_x = 0;
ghost_y = 0;
ghost_z = 0;
ghost_off_x = 0;
ghost_off_y = 0;
ghost_off_z = 0;
cam_dragging = false;
// --- TILE PALETTE ---
active_sub = 0;          // currently selected sub-image for placing
ghost_rot = 0;           // preview rotation in 90-degree steps (0..3)
#macro FLIP_X_DEFAULT true
#macro FLIP_Y_DEFAULT false
ghost_flip_x = FLIP_X_DEFAULT;  // mirror texture horizontally (default on to match desired orientation)
ghost_flip_y = FLIP_Y_DEFAULT;  // mirror texture vertically
palette_phase = 0;       // drives the panel gradient animation
grid_offset = 0;         // decal offset in cm steps along active plane normal (-5..+5)
grid_offset_max = 20;     // max cm steps either direction
cm_world = 0.05;         // world units per 1 cm step (tunable)
palette_open = false;    // true while space is held
palette_hover = -1;      // sub-image under the mouse in the palette (-1 = none)

// --- TILESET SWAP ---
global.tile_sprite = spr_tile;     // active tileset (built-in by default)
global.tile_custom = -1;           // runtime-imported sprite (-1 = none loaded)
global.tile_custom_path = "";      // source PNG of the imported set ("" = none)
// Cell size of the ACTIVE sheet. tileset_import sets this to whatever it
// sliced at, and switching sheets restores the right one.
global.tile_cell = sprite_get_width(spr_tile);
// What the next import / re-slice should use: 0 = detect, or 8/16/24/32
global.tile_cell_pref = 0;
// Short-lived confirmation line, so a re-slice is never silent
tile_msg = "";
sheet_new_pending = "";     // size action awaiting a second pick (unsaved edits)

// --- WIREFRAME OVERLAY (F; see BRUSH_system) ---
wire_on = false;
wire_empty = [];          // per frame of the active tileset: true = fully transparent
wire_empty_spr = -1;      // tileset sprite wire_empty was worked out for
wire_empty_count = -1;    // its frame count at the time
wire_invisible = 0;       // placed tiles using an empty frame (legend)
wire_backfacing = 0;      // placed tiles showing their back (legend)
invisible_count = 0;      // placed tiles with a fully transparent graphic
invisible_recount = 0;    // steps until that count is refreshed
invisible_btn_hover = false; // mouse over the warning's Clean up button

// --- CLUSTER SELECT / CLIP HISTORY (Ctrl+Shift drag, Ctrl+C; see BRUSH_system) ---
global.clip_items = [];   // clips, newest first: tiles + thumbnail
sel_keys = [];            // keys of the tiles currently selected
sel_dragging = false;     // Ctrl+Shift rubber band in progress
sel_x0 = 0;               // drag start / end, in window pixels
sel_y0 = 0;
sel_x1 = 0;
sel_y1 = 0;
clip_held = -1;           // index of the clip in hand (-1 = none)
clip_hover = -1;          // index under the mouse in the strip (-1 = none)
clip_blocks_mouse = false; // the strip owns the mouse this frame
clip_capture_pending = false; // a thumbnail grab is waiting for a clean frame
clip_capture_wait = 0;        // frames left to wait before grabbing
clip_capture_keys = [];       // tiles the pending grab will take
clip_capture_rect = [0, 0, 0, 0]; // drag rectangle the thumbnail comes from
clip_capture_grid = false;    // was the grid on before the capture

// --- PAINT / ERASE STROKES (hold the mouse button and move) ---
paint_active = false;    // left button held after a valid press
paint_last_key = "";     // last cell stamped in this stroke
erase_active = false;    // right button held after a valid press
erase_last_key = "";     // last cell erased in this stroke
tile_msg_timer = 0;
global.tile_is_custom = false;     // true when the active set is the custom one


// --- BRUSH (rectangular multi-tile selection from the palette) ---
brush_cols = 1;          // width of the brush in tiles
brush_rows = 1;          // height of the brush in tiles
brush_subs = [active_sub]; // flat array of sub-images, row-major (cols within rows)
brush_rot = 0;
palette_drag_start = -1; // palette cell where the drag began (-1 = not dragging)
brush_rot = 0;           // brush quarter-turns (0..3), for flip-axis correction
palette_cols = 31;       // tiles per row (current; changes with tileset)
palette_cols_builtin = 31; // default columns for the built-in set
global.tile_custom_cols = 0; // columns in the imported sheet (0 = none)
palette_cell = 32;       // pixel size of each palette cell
palette_cell_max = 32;   // full cell size; shrinks toward the min to fit big sheets
palette_cell_min = 12;   // smallest a cell is allowed to get
palette_pad = 2         // gap between cells
palette_x = 0;           // top-left of palette, set to mouse on open
palette_y = 0;

// --- BRUSH NUDGE (arrow keys shift the held brush a texel at a time) ---
// Steps along each world axis, in texture pixels of a tile. Only the active
// plane's two in-plane axes are applied; see BRUSH_system.
nudge_x = 0;
nudge_y = 0;
nudge_z = 0;
nudge_max = 64;          // limit either way, in texels (4 tiles at a 16px cell)

// --- SHIFT TAP (match depth to the tile under the cursor) ---
shift_tap_armed = false; // true while Shift is held with nothing else pressed
tab_tap_armed = false;   // true while Tab is held with nothing else pressed (acts like Shift)

// --- PLANE OFFSETS ---
plane_offset_XY = { left_right: 0, up_down: 0, depth: 0 };
plane_offset_XZ = { left_right: 0, up_down: 0, depth: 0 };
plane_offset_YZ = { left_right: 0, up_down: 0, depth: 0 };
// --- ABOUT / VERSION (see ABOUT_system) ---
// global.app_version comes from the included file version.txt
version_local_load();
about_visible = false;        // true while the modal About panel is up
about_state = "idle";         // "idle", "checking", "current", "update", "failed"
about_message = "";           // status line shown when a check fails
about_ver_remote = "";        // version reported by the remote version.txt
about_http_id = -1;           // id of the in-flight http_get (-1 = none)
about_x = 0;                  // panel rect (set by about_layout)
about_y = 0;
about_w = 0;
about_h = 0;
about_btn_check = [0, 0, 0, 0];   // button rects: [x1, y1, x2, y2]
about_btn_itch = [0, 0, 0, 0];
about_btn_close = [0, 0, 0, 0];
about_hover = "";             // "", "check", "itch" or "close"

// Update banner over the viewport (see ABOUT_system)
about_banner_hide = false;    // dismissed with X for this session
about_banner_hover = "";      // "", "get" or "close"
about_banner_x = 0;           // banner rect (set by about_banner_layout)
about_banner_y = 0;
about_banner_get = [0, 0, 0, 0];
about_banner_close = [0, 0, 0, 0];

// --- DEMO / PRO GATE (see DEMO_system; one macro, DEMO_MODE) ---
demo_visible = false;         // true while the PRO panel is up
demo_feature = "";            // which locked feature opened it
demo_hover = "";              // "", "get" or "close"
demo_x = 0;                   // panel rect (set by demo_layout)
demo_y = 0;
demo_btn_get = [0, 0, 0, 0];
demo_btn_close = [0, 0, 0, 0];

// Quiet check at launch; the result only shows up if there is something newer
if (ABOUT_CHECK_ON_START)
{
    about_check_update();
}

// --- POST FX (CRT monitor filter; see POSTFX_system) ---
fx = postfx_defaults();          // every tunable parameter
fx_sliders = postfx_slider_defs();
fx_u = postfx_uniforms();        // cached shader uniform handles
fx_crt_on = false;
fx_panel_open = false;
fx_panel_x = 0;                  // panel rect (set by postfx_panel_layout)
fx_panel_y = 0;
fx_panel_w = 0;
fx_panel_h = 0;
fx_row_y = [];                   // y of each slider row
fx_btn_reset = [0, 0, 0, 0];
fx_btn_close = [0, 0, 0, 0];
fx_slider_h = 12;
fx_drag = -1;                    // slider being dragged (-1 = none)
fx_hover = -1;                   // slider under the mouse (-1 = none)

// --- MENU BAR (replaces the old shortcuts panel; see MENU_system) ---
menu_bar_h = 22;            // height of the top bar in GUI pixels
menu_title_pad = 10;        // horizontal padding around each title
menu_item_h = 20;           // height of a drop-down line
menu_sep_h = 9;             // height of a separator line
menu_item_pad = 10;         // inner padding of the drop-down
menu_key_gap = 36;          // minimum gap between label and shortcut
menu_check_w = 18;          // space reserved for the tick box
menu_mode = "3d";           // "3d" or "pe" (which editor the bar is showing)
menu_open = -1;             // index into menu_vis of the open menu (-1 = closed)
menu_title_hover = -1;
menu_item_hover = -1;
menu_vis = [];              // indices of menu_defs visible in this mode
menu_title_x = [];
menu_title_w = [];
menu_drop_items = [];       // visible items of the open menu
menu_drop_iy = [];
menu_drop_ih = [];
menu_drop_x = 0;
menu_drop_y = 0;
menu_drop_w = 0;
menu_drop_h = 0;
menu_action = "";           // action id chosen this frame ("" = none)
menu_esc_consumed = false;  // Esc closed a menu this frame (don't quit)
menu_click_consumed = false;
menu_blocks_mouse = false;  // true when the menu owns the mouse this frame
menu_col_bar = make_color_rgb(30, 32, 40);
menu_col_panel = make_color_rgb(38, 40, 50);
menu_col_line = make_color_rgb(80, 84, 100);
menu_col_hover = make_color_rgb(58, 62, 78);
menu_col_accent = make_color_rgb(60, 105, 200);

menu_defs = [
    {
        title: "File", mode: "all",
        items: [
            { label: "Save scene",       key: "Ctrl+S",       act: "scene_save",    mode: "3d" },
            { label: "Save scene as...", key: "Ctrl+Shift+S", act: "scene_save_as", mode: "3d" },
            { label: "Load scene...",    key: "Ctrl+L",       act: "scene_load",    mode: "3d" },
            { label: "-",                key: "",             act: "",              mode: "3d" },
            { label: demo_label("Export OBJ..."), key: "Alt+Shift+S", act: "export_obj", mode: "3d" },
            { label: "-",                key: "",             act: "",              mode: "3d" },
            { label: "Restart",          key: "Enter",        act: "restart",       mode: "3d" },
            { label: "Quit",             key: "Esc",          act: "quit",          mode: "3d" },
            { label: demo_label("Save texture PNG"), key: "Ctrl+S",  act: "pe_save_png",    mode: "pe" },
            { label: demo_label("Save texture PNG as..."), key: "Ctrl+Shift+S", act: "pe_save_png_as", mode: "pe" },
            { label: "-",                     key: "",             act: "",               mode: "pe" },
            { label: "Apply to tiles",        key: "Enter",        act: "pe_apply",       mode: "pe" },
            { label: "Close pixel editor",    key: "P / Esc",      act: "pe_close",       mode: "pe" }
        ]
    },
    {
        title: "Edit", mode: "all",
        items: [
            { label: "Undo",                key: "Ctrl+Z", act: "undo",   mode: "all" },
            { label: "Redo",                key: "Ctrl+Y", act: "redo",   mode: "all" },
            { label: "-",                   key: "",       act: "",       mode: "3d" },
            { label: "Rotate brush",        key: "R",      act: "rotate", mode: "3d" },
            { label: "Flip brush H",        key: "X",      act: "flip_x", mode: "3d" },
            { label: "Flip brush V",        key: "Y",      act: "flip_y", mode: "3d" },
            { label: "-",                   key: "",       act: "",       mode: "3d" },
            { label: "Remove duplicate / back-to-back faces", key: "", act: "clean_faces", mode: "3d" },
            { label: "Remove invisible tiles", key: "", act: "clean_invisible", mode: "3d" }
        ]
    },
    {
        title: "View", mode: "all",
        items: [
            { label: "Fullscreen",       key: "F10",  act: "fullscreen", mode: "all" },
            { label: "-",                key: "",     act: "",           mode: "all" },
            { label: "Reset view",       key: "Home", act: "reset_view", mode: "3d" },
            { label: "-",                key: "",     act: "",           mode: "3d" },
            { label: "Grid",             key: "G",    act: "grid",       mode: "3d" },
            { label: "Tile texture filter", key: "T", act: "tex_filter", mode: "3d" },
            { label: "Backface culling", key: "B",    act: "cull",       mode: "3d" },
            { label: "Wireframe",        key: "F",    act: "wireframe",  mode: "3d" },
            { label: "Fit sheet",        key: "Home",   act: "pe_fit",        mode: "pe" },
            { label: "Zoom in",          key: "=",      act: "pe_zoom_in",    mode: "pe" },
            { label: "Zoom out",         key: "-",      act: "pe_zoom_out",   mode: "pe" },
            { label: "-",                key: "",       act: "",              mode: "pe" },
            { label: "Pixel grid",       key: "Ctrl+G", act: "pe_pixel_grid", mode: "pe" },
            { label: "Tile grid",        key: "Ctrl+T", act: "pe_tile_grid",  mode: "pe" }
        ]
    },
    {
        title: "Place", mode: "3d",
        items: [
            { label: "Depth in",       key: "Q",     act: "depth_in",    mode: "3d" },
            { label: "Depth out",      key: "E",     act: "depth_out",   mode: "3d" },
            { label: "Reset depth",    key: "W",     act: "depth_reset", mode: "3d" },
            { label: "-",              key: "",      act: "",            mode: "3d" },
            { label: "Decal forward",  key: ".",     act: "decal_fwd",   mode: "3d" },
            { label: "Decal back",     key: ",",     act: "decal_back",  mode: "3d" },
            { label: "Reset decal",    key: "0",     act: "decal_reset", mode: "3d" },
            { label: "-",              key: "",      act: "",            mode: "3d" },
            { label: "Nudge left",     key: "Left",  act: "nudge_left",  mode: "3d" },
            { label: "Nudge right",    key: "Right", act: "nudge_right", mode: "3d" },
            { label: "Nudge up",       key: "Up",    act: "nudge_up",    mode: "3d" },
            { label: "Nudge down",     key: "Down",  act: "nudge_down",  mode: "3d" },
            { label: "Reset nudge",    key: "N",     act: "nudge_reset", mode: "3d" }
        ]
    },
    {
        title: "Tileset", mode: "all",
        items: [
            { label: "Import PNG...",     key: "Ctrl+I", act: "tiles_import",  mode: "3d" },
            { label: "-",                 key: "",       act: "",              mode: "3d" },
            { label: "New sheet 64 x 64",     key: "", act: "sheet_new_64",       mode: "all" },
            { label: "New sheet 128 x 128",   key: "", act: "sheet_new_128",      mode: "all" },
            { label: "New sheet 256 x 256",   key: "", act: "sheet_new_256",      mode: "all" },
            { label: "New sheet 512 x 512",   key: "", act: "sheet_new_512",      mode: "all" },
            { label: "New sheet 1024 x 512",  key: "", act: "sheet_new_1024x512", mode: "all" },
            { label: "-",                 key: "",       act: "",              mode: "all" },
            { label: "Built-in tileset",  key: "F1",     act: "tiles_builtin", mode: "3d" },
            { label: "Custom tileset",    key: "F2",     act: "tiles_custom",  mode: "3d" },
            { label: "-",                 key: "",       act: "",              mode: "3d" },
            { label: "Cell size: auto",   key: "",       act: "cell_auto",     mode: "all" },
            { label: "Cell size: 8",      key: "",       act: "cell_8",        mode: "all" },
            { label: "Cell size: 16",     key: "",       act: "cell_16",       mode: "all" },
            { label: "Cell size: 24",     key: "",       act: "cell_24",       mode: "all" },
            { label: "Cell size: 32",     key: "",       act: "cell_32",       mode: "all" },
            { label: "Re-slice at this size", key: "",   act: "cell_reimport", mode: "all" },
            { label: "-",                 key: "",       act: "",              mode: "3d" },
            { label: "Pixel editor",      key: "P",      act: "pe_toggle",     mode: "3d" }
        ]
    },
    {
        title: "Post FX", mode: "3d",
        items: [
            { label: "CRT monitor",        key: "F6", act: "fx_crt",   mode: "3d" },
            { label: "-",                  key: "",   act: "",         mode: "3d" },
            { label: "Controls...",        key: "F7", act: "fx_panel", mode: "3d" },
            { label: "Reset to defaults",  key: "",   act: "fx_reset", mode: "3d" }
        ]
    },
    {
        title: "Tools", mode: "pe",
        items: [
            { label: "Pencil",         key: "B",       act: "tool_pencil",       mode: "pe" },
            { label: "Eraser",         key: "E",       act: "tool_eraser",       mode: "pe" },
            { label: "Fill",           key: "G",       act: "tool_fill",         mode: "pe" },
            { label: "Replace colour", key: "Shift+G", act: "tool_replace",      mode: "pe" },
            { label: "Line",           key: "L",       act: "tool_line",         mode: "pe" },
            { label: "Rectangle",      key: "U",       act: "tool_rect",         mode: "pe" },
            { label: "Filled rect",    key: "Shift+U", act: "tool_rect_fill",    mode: "pe" },
            { label: "Ellipse",        key: "O",       act: "tool_ellipse",      mode: "pe" },
            { label: "Filled ellipse", key: "Shift+O", act: "tool_ellipse_fill", mode: "pe" },
            { label: "Eyedropper",     key: "I / Alt", act: "tool_picker",       mode: "pe" },
            { label: "Select",         key: "M",       act: "tool_select",       mode: "pe" },
            { label: "-",              key: "",        act: "",                  mode: "pe" },
            { label: "Swap colours",   key: "X",       act: "pe_swap_colours",   mode: "pe" },
            { label: "Brush smaller",  key: "[",       act: "pe_brush_down",     mode: "pe" },
            { label: "Brush larger",   key: "]",       act: "pe_brush_up",       mode: "pe" },
            { label: "Clip to tile",   key: "K",       act: "pe_tile_clip",      mode: "pe" }
        ]
    },
    {
        title: "Select", mode: "pe",
        items: [
            { label: "Select all", key: "Ctrl+A", act: "pe_select_all", mode: "pe" },
            { label: "Deselect",   key: "Ctrl+D", act: "pe_deselect",   mode: "pe" },
            { label: "-",          key: "",       act: "",              mode: "pe" },
            { label: "Copy",       key: "Ctrl+C", act: "pe_copy",       mode: "pe" },
            { label: "Cut",        key: "Ctrl+X", act: "pe_cut",        mode: "pe" },
            { label: "Paste",      key: "Ctrl+V", act: "pe_paste",      mode: "pe" },
            { label: "Delete",     key: "Del",    act: "pe_delete",     mode: "pe" },
            { label: "-",          key: "",       act: "",              mode: "pe" },
            { label: "Flip H (selection or tile)", key: "H", act: "pe_flip_h", mode: "pe" },
            { label: "Flip V (selection or tile)", key: "V", act: "pe_flip_v", mode: "pe" }
        ]
    },
    {
        title: "Help", mode: "all",
        items: [
            { label: "Shortcut keys...", key: "F9",           act: "shortcuts", mode: "all" },
            { label: "Guided tour",      key: "",             act: "tour_start", mode: "3d" },
            { label: "-",               key: "",             act: "",       mode: "all" },
            { label: "Place / replace", key: "LMB",          act: "", mode: "3d" },
            { label: "Remove",          key: "RMB / Del",    act: "", mode: "3d" },
            { label: "Tile palette",    key: "Space (hold)", act: "", mode: "3d" },
            { label: "Pick brush",      key: "Space+drag",   act: "", mode: "3d" },
            { label: "Pan",             key: "MMB drag",     act: "", mode: "3d" },
            { label: "Orbit",           key: "Alt+MMB drag", act: "", mode: "3d" },
            { label: "Zoom",            key: "Wheel",        act: "", mode: "3d" },
            { label: "Nudge brush 1px",  key: "Arrow keys",      act: "", mode: "3d" },
            { label: "Nudge brush 4px",  key: "Shift+arrows",    act: "", mode: "3d" },
            { label: "Paint primary",   key: "LMB",              act: "", mode: "pe" },
            { label: "Paint secondary / erase", key: "RMB",              act: "", mode: "pe" },
            { label: "Eyedropper",      key: "Alt (hold)",       act: "", mode: "pe" },
            { label: "Pan",             key: "MMB / Space+drag", act: "", mode: "pe" },
            { label: "Zoom",            key: "Wheel",            act: "", mode: "pe" },
            { label: "Move selection",  key: "Select tool drag", act: "", mode: "pe" },
            { label: "Store colour",    key: "Shift+click swatch", act: "", mode: "pe" },
            { label: "Commit / clear",  key: "Esc",              act: "", mode: "pe" }
        ]
    },
    {
        title: "About", mode: "all",
        items: [
            { label: "Credits...",                 key: "F12", act: "about_show",  mode: "all" },
            { label: "Version / check updates...", key: "",    act: "about_check", mode: "all" },
            { label: "-",                          key: "",    act: "",            mode: "all" },
            { label: "Version " + global.app_version, key: "", act: "",            mode: "all" },
            { label: "-",                          key: "",    act: "",            mode: "all" },
            { label: ABOUT_APP_NAME + " on itch.io", key: "",  act: "about_itch",  mode: "all" }
        ]
    }
];

// --- SHORTCUT KEYS PANEL (F9 / Help > Shortcut keys; see MENU_system) ---
// Every key and mouse combination, in one place. Keep this in step with the
// code when a shortcut changes - it is what users read.
shortcuts_open = false;
shortcut_sections = [
    {
        title: "3D VIEW",
        groups: [
            { title: "Placing", rows: [
                ["LMB",              "Place / replace tile (hold and drag to paint)"],
                ["RMB",              "Remove brush footprint (hold and drag to erase)"],
                ["Del / Backspace",  "Remove the tile under the cursor"],
                ["Space (hold)",     "Tile palette - click or drag to pick tiles"],
                ["Alt+LMB",          "Pick up the tile under the cursor"],
                ["R",                "Rotate brush"],
                ["Ctrl+R",           "Rotate the placed tile under the cursor"],
                ["X",                "Flip H - tile under cursor, else brush"],
                ["Y",                "Flip V - tile under cursor, else brush"]
            ]},
            { title: "Depth and position", rows: [
                ["Q / E",            "Depth in / out"],
                ["W",                "Reset depth"],
                ["Shift or Tab (tap)", "Match depth to the tile under the cursor"],
                [". / ,",            "Decal forward / back"],
                ["0",                "Reset decal"],
                ["Arrow keys",       "Nudge brush 1 pixel"],
                ["Shift+arrows",     "Nudge brush 4 pixels"],
                ["N",                "Reset nudge"]
            ]},
            { title: "Clusters", rows: [
                ["Ctrl+Shift+drag",  "Select tiles"],
                ["Ctrl+C",           "Copy the selection as a cluster"],
                ["LMB",              "Place the held cluster"],
                ["R / X",            "Turn / mirror the held cluster"],
                ["Esc",              "Put the cluster down / clear selection"],
                ["Strip LMB / RMB",  "Hold / remove a stored cluster"]
            ]},
            { title: "View", rows: [
                ["MMB drag",         "Pan"],
                ["Alt+MMB drag",     "Orbit"],
                ["Wheel",            "Zoom"],
                ["Home",             "Reset view"],
                ["G",                "Grid"],
                ["T",                "Tile texture filter"],
                ["B",                "Backface culling"],
                ["F",                "Wireframe"],
                ["F6 / F7",          "CRT effect / Post FX controls"],
                ["F10",              "Fullscreen / windowed"]
            ]},
            { title: "File and tiles", rows: [
                ["Ctrl+S",           "Save scene"],
                ["Ctrl+Shift+S",     "Save scene as"],
                ["Ctrl+L",           "Load scene"],
                ["Alt+Shift+S",      "Export OBJ"],
                ["Ctrl+Z / Ctrl+Y",  "Undo / redo"],
                ["Ctrl+I",           "Import tileset PNG"],
                ["F1 / F2",          "Built-in / custom tileset"],
                ["P",                "Pixel editor"],
                ["F9 / F12",         "Shortcut keys / credits"],
                ["Enter / Esc",      "Restart / quit"]
            ]}
        ]
    },
    {
        title: "PIXEL EDITOR",
        groups: [
            { title: "Tools", rows: [
                ["B",                "Pencil"],
                ["E",                "Eraser"],
                ["G / Shift+G",      "Fill / replace colour"],
                ["L",                "Line"],
                ["U / Shift+U",      "Rectangle / filled"],
                ["O / Shift+O",      "Ellipse / filled"],
                ["I or Alt (hold)",  "Eyedropper"],
                ["M",                "Select"]
            ]},
            { title: "Painting", rows: [
                ["LMB",              "Paint primary colour"],
                ["RMB",              "Paint secondary (transparent = erase)"],
                ["X",                "Swap colours"],
                ["[ / ]",            "Brush smaller / larger"],
                ["K",                "Clip painting to one tile"]
            ]},
            { title: "Selection", rows: [
                ["Ctrl+A / Ctrl+D",  "Select all / deselect"],
                ["Ctrl+C / X / V",   "Copy / cut / paste"],
                ["Del",              "Delete selection"],
                ["H / V",            "Flip selection or tile H / V"],
                ["Esc",              "Commit / clear selection, then close"]
            ]},
            { title: "View", rows: [
                ["Wheel or = / -",   "Zoom"],
                ["MMB or Space+drag", "Pan"],
                ["Home",             "Fit sheet"],
                ["Ctrl+G / Ctrl+T",  "Pixel grid / tile grid"]
            ]},
            { title: "File", rows: [
                ["Ctrl+S",           "Save texture PNG"],
                ["Ctrl+Shift+S",     "Save texture PNG as"],
                ["Enter",            "Apply to tiles"],
                ["Ctrl+Z / Ctrl+Y",  "Undo / redo"],
                ["P",                "Close pixel editor"]
            ]}
        ]
    }
];

// --- GUIDED TOUR (Help > Guided tour; offered on first launch; see ABOUT_system) ---
tut_active = false;       // the tour card is up
tut_prompt = false;       // the first-launch question is up
tut_dont_ask = false;     // "Don't ask again" was chosen
tut_finished = false;     // every step done: showing the finish card
tut_checklist = false;    // the card is showing the checklist
tut_ch = 0;               // current chapter
tut_st = 0;               // current step within it
tut_time = 0;             // seconds spent in the tour
tut_hover = "";           // card button under the mouse
tut_row_hover = -1;       // checklist chapter row under the mouse
tut_flash = 0;            // tick-box flash timer
tut_toast = "";           // chapter-complete message
tut_toast_timer = 0;
tut_sparks = [];          // celebration particles
tut_saved_path = "";      // user's scene path, put back when the tour ends
tut_mouse_over = false;   // the mouse is over the tour card this frame

// Each step finishes when tut_event(ev) has arrived `need` times while it is
// the current step. `how` is what the card says; `key` is the pulsing badge.
tut_chapters = [
    {
        title: "Getting around", medal: "Explorer",
        steps: [
            { id: "orbit", text: "Look around",       how: "Hold Alt and drag with the middle mouse button to orbit the camera.", key: "Alt + MMB drag", ev: "orbit", need: 25, count: 0, done: false },
            { id: "pan",   text: "Slide the view",    how: "Drag with the middle mouse button (no Alt) to pan across the scene.", key: "MMB drag", ev: "pan", need: 25, count: 0, done: false },
            { id: "zoom",  text: "Zoom in and out",   how: "Roll the mouse wheel a few notches either way.", key: "Wheel", ev: "zoom", need: 4, count: 0, done: false },
            { id: "home",  text: "Back to the start", how: "Press Home to put the camera back where it began.", key: "Home", ev: "reset_view", need: 1, count: 0, done: false }
        ]
    },
    {
        title: "First tiles", medal: "Tile Layer",
        steps: [
            { id: "pal_open", text: "Open the tile palette", how: "Hold Space. The palette pops up under the mouse and stays while Space is held.", key: "Space (hold)", ev: "palette_open", need: 1, count: 0, done: false },
            { id: "pal_pick", text: "Pick a tile",           how: "Keep holding Space and click any tile in the palette.", key: "Space + LMB", ev: "palette_pick", need: 1, count: 0, done: false },
            { id: "place",    text: "Put it down",           how: "Let go of Space and click in the scene to place the tile.", key: "LMB", ev: "place", need: 1, count: 0, done: false },
            { id: "paint",    text: "Paint a row",           how: "Hold the left button and drag across the grid to paint five more tiles.", key: "LMB drag", ev: "paint_drag", need: 5, count: 0, done: false },
            { id: "erase",    text: "Take some away",        how: "Click or drag with the right button over tiles to remove them.", key: "RMB", ev: "erase", need: 1, count: 0, done: false },
            { id: "delete",   text: "Delete just one",       how: "Point straight at a tile and press Delete. Only the tile under the cursor goes.", key: "Del", ev: "delete_tile", need: 1, count: 0, done: false }
        ]
    },
    {
        title: "The brush", medal: "Brush Handler",
        steps: [
            { id: "pal_block", text: "Grab a block",        how: "Hold Space and drag across the palette to pick a 2 x 2 block of tiles.", key: "Space + drag", ev: "palette_pick_block", need: 1, count: 0, done: false },
            { id: "rotate",    text: "Turn it",             how: "Press R to rotate the brush a quarter turn.", key: "R", ev: "rotate_brush", need: 1, count: 0, done: false },
            { id: "flip_x",    text: "Flip it",             how: "Press X to flip it left to right. (Over a placed tile, X flips that tile instead.)", key: "X", ev: "flip_x", need: 1, count: 0, done: false },
            { id: "flip_y",    text: "Flip the other way",  how: "Press Y to flip it top to bottom.", key: "Y", ev: "flip_y", need: 1, count: 0, done: false },
            { id: "stamp",     text: "Stamp the block",     how: "Click in the scene to place the whole block in one go.", key: "LMB", ev: "place", need: 1, count: 0, done: false },
            { id: "alt_pick",  text: "Pick up from the scene", how: "Hold Alt and click a placed tile: it becomes your brush, turned and flipped the same way.", key: "Alt + LMB", ev: "alt_pick", need: 1, count: 0, done: false }
        ]
    },
    {
        title: "Planes and depth", medal: "Surveyor",
        steps: [
            { id: "plane_xy",   text: "Look at the floor",  how: "Orbit until you look down on the grid. The box top-left says Plane: XY - tiles now lie flat.", key: "Alt + MMB drag", ev: "plane_xy", need: 1, count: 0, done: false },
            { id: "depth_q",    text: "Lift the plane",      how: "Press Q a couple of times. The plane you paint on moves up, away from the grid.", key: "Q", ev: "depth_q", need: 2, count: 0, done: false },
            { id: "depth_e",    text: "Lower it again",      how: "Press E to bring the plane back toward you.", key: "E", ev: "depth_e", need: 2, count: 0, done: false },
            { id: "depth_w",    text: "Reset the depth",     how: "Press W to put the plane straight back to zero.", key: "W", ev: "depth_reset", need: 1, count: 0, done: false },
            { id: "match",      text: "Match a tile's depth", how: "Point at one of your tiles and tap Shift (or Tab) on its own. The plane jumps to that tile's height.", key: "Shift or Tab (tap)", ev: "depth_match", need: 1, count: 0, done: false },
            { id: "plane_wall", text: "Face a wall",         how: "Orbit round to look from the side until the box says Plane: XZ or YZ. Now tiles stand upright.", key: "Alt + MMB drag", ev: "plane_wall", need: 1, count: 0, done: false },
            { id: "edge",       text: "Snap to an edge",     how: "Point near the edge of a floor tile and tap Shift or Tab. The wall plane lines up with that edge.", key: "Shift or Tab (tap)", ev: "depth_edge", need: 1, count: 0, done: false },
            { id: "wall",       text: "Build a wall",        how: "Click to place an upright tile along that edge.", key: "LMB", ev: "place_wall", need: 1, count: 0, done: false }
        ]
    },
    {
        title: "Decals and nudging", medal: "Detailer",
        steps: [
            { id: "decal_up",   text: "Float a decal",       how: "Press the full stop twice. Your next tile will hover a little in front of the plane.", key: ".", ev: "decal_fwd", need: 2, count: 0, done: false },
            { id: "decal_put",  text: "Place the decal",     how: "Click over an existing tile to lay the decal on top of it.", key: "LMB", ev: "place_decal", need: 1, count: 0, done: false },
            { id: "decal_down", text: "Push it back",        how: "Press the comma to move the decal offset back the other way.", key: ",", ev: "decal_back", need: 1, count: 0, done: false },
            { id: "decal_zero", text: "Back to flat",        how: "Press 0 to reset the decal offset.", key: "0", ev: "decal_reset", need: 1, count: 0, done: false },
            { id: "nudge",      text: "Nudge the brush",     how: "Tap the arrow keys to shift the brush one texture pixel at a time.", key: "Arrow keys", ev: "nudge", need: 3, count: 0, done: false },
            { id: "nudge_fast", text: "Nudge faster",        how: "Hold Shift and tap an arrow to move four pixels at a time.", key: "Shift + arrows", ev: "nudge_fast", need: 2, count: 0, done: false },
            { id: "nudge_off",  text: "Reset the nudge",     how: "Press N to snap the brush back onto the grid.", key: "N", ev: "nudge_reset", need: 1, count: 0, done: false }
        ]
    },
    {
        title: "Clusters", medal: "Copy Master",
        steps: [
            { id: "select",   text: "Select some tiles",     how: "Hold Ctrl and Shift, then drag a box around a few of your tiles. They light up yellow.", key: "Ctrl + Shift + drag", ev: "select", need: 1, count: 0, done: false },
            { id: "copy",     text: "Copy them",             how: "Press Ctrl+C. The group becomes a cluster in the strip down the left.", key: "Ctrl + C", ev: "copy", need: 1, count: 0, done: false },
            { id: "paste",    text: "Place the cluster",     how: "Click somewhere empty to stamp the whole cluster.", key: "LMB", ev: "paste", need: 1, count: 0, done: false },
            { id: "c_turn",   text: "Turn the cluster",      how: "Press R to turn the held cluster a quarter turn, then click to place it again if you like.", key: "R", ev: "cluster_turn", need: 1, count: 0, done: false },
            { id: "c_mirror", text: "Mirror the cluster",    how: "Press X to mirror it.", key: "X", ev: "cluster_mirror", need: 1, count: 0, done: false },
            { id: "c_drop",   text: "Put it down",           how: "Press Esc to go back to single tiles.", key: "Esc", ev: "cluster_drop", need: 1, count: 0, done: false },
            { id: "c_strip",  text: "Pick it up again",      how: "Click the cluster's picture in the strip on the left to hold it again.", key: "LMB on strip", ev: "strip_pick", need: 1, count: 0, done: false }
        ]
    },
    {
        title: "Seeing clearly", medal: "Sharp Eye",
        steps: [
            { id: "v_grid", text: "Grid off and on",       how: "Press G twice: once to hide the grid, once to bring it back.", key: "G", ev: "grid_toggle", need: 2, count: 0, done: false },
            { id: "v_cull", text: "Backface culling",      how: "Press B twice. With culling on, the back of every tile is hidden.", key: "B", ev: "cull_toggle", need: 2, count: 0, done: false },
            { id: "v_wire", text: "Wireframe",             how: "Press F twice. Wireframe outlines every tile - magenta ones have no graphic and are invisible.", key: "F", ev: "wire_toggle", need: 2, count: 0, done: false },
            { id: "v_filt", text: "Texture filter",        how: "Press T twice to see tiles smoothed, then crisp pixels again.", key: "T", ev: "filter_toggle", need: 2, count: 0, done: false }
        ]
    },
    {
        title: "Pixel editor", medal: "Pixel Painter",
        steps: [
            { id: "pe_open",   text: "Open the pixel editor", how: "Press P. Your whole tileset opens as one image you can paint on.", key: "P", ev: "pe_open", need: 1, count: 0, done: false },
            { id: "pe_paint",  text: "Paint",                 how: "With the pencil (B), click or drag on the sheet with the left button.", key: "B, then LMB", ev: "pe_paint", need: 1, count: 0, done: false },
            { id: "pe_erase",  text: "Erase",                 how: "Right-click paints the second colour, which starts fully transparent - so it erases.", key: "RMB", ev: "pe_erase", need: 1, count: 0, done: false },
            { id: "pe_pick",   text: "Pick a colour",         how: "Hold Alt and click a pixel to take its colour.", key: "Alt + LMB", ev: "pe_pick", need: 1, count: 0, done: false },
            { id: "pe_fill",   text: "Fill an area",          how: "Press G for the fill tool, then click inside an area.", key: "G, then LMB", ev: "pe_fill", need: 1, count: 0, done: false },
            { id: "pe_select", text: "Select a patch",        how: "Press M for select, then drag a box on the sheet.", key: "M, then drag", ev: "pe_select", need: 1, count: 0, done: false },
            { id: "pe_move",   text: "Move it",               how: "Drag from inside the box to lift those pixels and move them.", key: "Drag inside", ev: "pe_move", need: 1, count: 0, done: false },
            { id: "pe_apply",  text: "Apply to the tiles",    how: "Press Enter. Every placed tile updates to your new art.", key: "Enter", ev: "pe_apply", need: 1, count: 0, done: false },
            { id: "pe_close",  text: "Back to 3D",            how: "Press P to close the editor and see the change in the scene.", key: "P", ev: "pe_close", need: 1, count: 0, done: false }
        ]
    },
    {
        title: "Looks", medal: "Showrunner",
        steps: [
            { id: "crt",       text: "Turn on the CRT",       how: "Press F6 for the CRT monitor effect.", key: "F6", ev: "crt_toggle", need: 1, count: 0, done: false },
            { id: "fx_panel",  text: "Open its controls",     how: "Press F7 to open the Post FX panel.", key: "F7", ev: "fx_panel", need: 1, count: 0, done: false },
            { id: "fx_slide",  text: "Play with the sliders", how: "Drag a couple of the sliders and watch the picture change.", key: "LMB drag", ev: "fx_slider", need: 2, count: 0, done: false },
            { id: "fx_reset",  text: "Back to defaults",      how: "Click Reset defaults in the panel (or Post FX > Reset to defaults).", key: "Reset defaults", ev: "fx_reset", need: 1, count: 0, done: false }
        ]
    },
    {
        title: "Keeping your work", medal: "Archivist",
        steps: [
            { id: "save",      text: "Save the scene",        how: "Press Ctrl+S and give this practice scene a name. The tileset and your clusters are saved inside it.", key: "Ctrl + S", ev: "save_scene", need: 1, count: 0, done: false },
            { id: "reload",    text: "Open it again",         how: "Open the File menu and pick it from the recent list near the top (or press Ctrl+L).", key: "File > recent", ev: "scene_loaded", need: 1, count: 0, done: false },
            { id: "file_menu", text: "Find Export",           how: "Open the File menu: Export OBJ (Alt+Shift+S) takes your scene into Blender or any 3D tool.", key: "File menu", ev: "menu_file", need: 1, count: 0, done: false }
        ]
    }
];

// --- RECENT SCENES (File menu) ---
// Keep a copy of the File menu as written above; recent_menu_sync() rebuilds
// the live menu from it every time the list changes.
for (var _fmi = 0; _fmi < array_length(menu_defs); _fmi++)
{
    if (menu_defs[_fmi].title == "File")
    {
        for (var _fii = 0; _fii < array_length(menu_defs[_fmi].items); _fii++)
        {
            array_push(menu_file_base, menu_defs[_fmi].items[_fii]);
        }
    }
}
recent_load();
recent_menu_sync();


// --- PIXEL EDITOR (texture sheet editing; see PIXEL_editor) ---
pe_open = false;
pe_surf = -1;               // display copy of the sheet
pe_buf = -1;                // RGBA sheet data (source of truth)
pe_buf_size = 0;
pe_surf_stale = true;
pe_w = 0;                   // sheet size in pixels
pe_h = 0;
pe_cell = 16;               // tile cell size
pe_cols = 1;                // tiles per row (matches palette_cols)
pe_rows = 1;
pe_frame_count = 0;
pe_dirty = false;           // edited since last Apply
pe_png_dirty = false;       // edited since last PNG save
pe_png_path = "";

// View
pe_zoom_levels = [1, 2, 3, 4, 6, 8, 12, 16, 24, 32];
pe_zoom = 8;
pe_view_x = 0;              // GUI position of the sheet's top-left
pe_view_y = 0;
pe_panning = false;
pe_pan_btn = mb_middle;
pe_pan_mx = 0;
pe_pan_my = 0;
pe_pan_vx = 0;
pe_pan_vy = 0;
pe_show_pixel_grid = true;
pe_show_tile_grid = true;
pe_tile_clip = false;       // keep strokes/fills inside the tile they start in

// Tools
pe_tool = "pencil";
pe_brush = 1;
pe_brush_max = 16;
pe_tools = [
    { act: "tool_pencil",       label: "Pencil",       key: "B" },
    { act: "tool_eraser",       label: "Eraser",       key: "E" },
    { act: "tool_fill",         label: "Fill",         key: "G" },
    { act: "tool_replace",      label: "Replace",      key: "Sh+G" },
    { act: "tool_line",         label: "Line",         key: "L" },
    { act: "tool_rect",         label: "Rect",         key: "U" },
    { act: "tool_rect_fill",    label: "Rect fill",    key: "Sh+U" },
    { act: "tool_ellipse",      label: "Ellipse",      key: "O" },
    { act: "tool_ellipse_fill", label: "Ellipse fill", key: "Sh+O" },
    { act: "tool_picker",       label: "Eyedropper",   key: "I" },
    { act: "tool_select",       label: "Select",       key: "M" }
];
pe_stroking = false;
pe_picking = false;
pe_stroke_btn = mb_left;
pe_stroke_u32 = 0;
pe_start_x = 0;
pe_start_y = 0;
pe_cur_x = 0;
pe_cur_y = 0;
pe_last_x = 0;
pe_last_y = 0;
pe_hover_x = -1;
pe_hover_y = -1;
pe_mouse_in_view = false;
pe_lim_x0 = 0;              // paint limits for the current operation
pe_lim_y0 = 0;
pe_lim_x1 = 0;
pe_lim_y1 = 0;

// Colours (primary / secondary + HSV picker state, 0..255)
pe_col = c_white;
pe_alpha = 255;
pe_col2 = c_black;
pe_alpha2 = 0;              // secondary starts fully transparent, so RMB erases
pe_hue = 0;
pe_sat = 0;
pe_val = 255;
pe_drag_ui = "";            // "sv", "hue", "alpha" while dragging a colour control
pe_palette = [];            // DawnBringer 32
var _db32 = [
    $000000, $222034, $45283C, $663931, $8F563B, $DF7126, $D9A066, $EEC39A,
    $FBF236, $99E550, $6ABE30, $37946E, $4B692F, $524B24, $323C39, $3F3F74,
    $306082, $5B6EE1, $639BFF, $5FCDE4, $CBDBFC, $FFFFFF, $9BADB7, $847E87,
    $696A6A, $595652, $76428A, $AC3232, $D95763, $D77BBA, $8F974A, $8A6F30
];
for (var _pi = 0; _pi < array_length(_db32); _pi++)
{
    array_push(pe_palette, make_color_rgb((_db32[_pi] >> 16) & 255, (_db32[_pi] >> 8) & 255, _db32[_pi] & 255));
}

// Undo
pe_undo = [];               // sheet snapshot buffers
pe_redo = [];
pe_undo_max = 50;

// Selection / floating pixels / clipboard
pe_sel_active = false;
pe_sel_x0 = 0;              // [x0, x1) x [y0, y1) in sheet pixels
pe_sel_y0 = 0;
pe_sel_x1 = 0;
pe_sel_y1 = 0;
pe_sel_mode = "";           // "", "marquee", "move"
pe_move_off_x = 0;
pe_move_off_y = 0;
pe_float_active = false;
pe_float_buf = -1;
pe_float_surf = -1;
pe_float_stale = true;
pe_float_w = 0;
pe_float_h = 0;
pe_float_x = 0;
pe_float_y = 0;
pe_clip_buf = -1;
pe_clip_w = 0;
pe_clip_h = 0;

// Layout (GUI pixels; recomputed every frame in pe_layout)
pe_tool_w = 180;            // widened in pe_layout to fit the longest tool label + key
pe_tool_w_min = 180;
pe_panel_w = 220;
pe_opt_h = 30;
pe_status_h = 24;
pe_vx0 = 0;
pe_vy0 = 0;
pe_vx1 = 0;
pe_vy1 = 0;
pe_buttons = [];
pe_brush_label_y = 0;
pe_brush_value_y = 0;
pe_swatch_x = 0;
pe_swatch_y = 0;
pe_sv_x = 0;
pe_sv_y = 0;
pe_sv_size = 200;
pe_hue_x = 0;
pe_hue_y = 0;
pe_alpha_x = 0;
pe_alpha_y = 0;
pe_bar_w = 200;
pe_bar_h = 14;
pe_pal_x = 0;
pe_pal_y = 0;
pe_pal_cols = 8;
pe_pal_size = 22;
pe_pal_gap = 3;
pe_info_y = 0;
pe_checker_surf = -1;
pe_checker_w = 0;
pe_checker_h = 0;
pe_message = "";
pe_message_timer = 0;
pe_col_bg = make_color_rgb(24, 25, 30);
pe_col_panel = make_color_rgb(34, 36, 44);
pe_col_button = make_color_rgb(46, 49, 60);
pe_col_check_a = make_color_rgb(90, 90, 96);
pe_col_check_b = make_color_rgb(120, 120, 128);
pe_col_tile_grid = make_color_rgb(255, 210, 90);

// --- GUIDED TOUR: offer it on launch until it's done or declined ---
tut_load();
if (!tut_dont_ask && tut_totals().done < tut_totals().steps)
{
    tut_prompt = true;
}
