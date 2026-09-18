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
global.tile_cell = 16;             // expected cell size for imported sheets
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
palette_pad = 2         // gap between cells
palette_x = 0;           // top-left of palette, set to mouse on open
palette_y = 0;

// --- PLANE OFFSETS ---
plane_offset_XY = { left_right: 0, up_down: 0, depth: 0 };
plane_offset_XZ = { left_right: 0, up_down: 0, depth: 0 };
plane_offset_YZ = { left_right: 0, up_down: 0, depth: 0 };
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
            { label: "Export OBJ...",    key: "Alt+Shift+S",  act: "export_obj",    mode: "3d" },
            { label: "-",                key: "",             act: "",              mode: "3d" },
            { label: "Restart",          key: "Enter",        act: "restart",       mode: "3d" },
            { label: "Quit",             key: "Esc",          act: "quit",          mode: "3d" }
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
            { label: "Flip brush V",        key: "Y",      act: "flip_y", mode: "3d" }
        ]
    },
    {
        title: "View", mode: "all",
        items: [
            { label: "Reset view",       key: "Home", act: "reset_view", mode: "3d" },
            { label: "-",                key: "",     act: "",           mode: "3d" },
            { label: "Grid",             key: "G",    act: "grid",       mode: "3d" },
            { label: "Texture filter",   key: "T",    act: "tex_filter", mode: "3d" },
            { label: "Backface culling", key: "B",    act: "cull",       mode: "3d" }
        ]
    },
    {
        title: "Place", mode: "3d",
        items: [
            { label: "Depth in",       key: "Q",     act: "depth_in",    mode: "3d" },
            { label: "Depth out",      key: "E",     act: "depth_out",   mode: "3d" },
            { label: "Reset depth",    key: "W",     act: "depth_reset", mode: "3d" },
            { label: "-",              key: "",      act: "",            mode: "3d" },
            { label: "Decal forward",  key: "1",     act: "decal_fwd",   mode: "3d" },
            { label: "Decal back",     key: "Tab+1", act: "decal_back",  mode: "3d" },
            { label: "Reset decal",    key: "0",     act: "decal_reset", mode: "3d" }
        ]
    },
    {
        title: "Tileset", mode: "3d",
        items: [
            { label: "Import PNG...",     key: "Ctrl+I", act: "tiles_import",  mode: "3d" },
            { label: "-",                 key: "",       act: "",              mode: "3d" },
            { label: "Built-in tileset",  key: "F1",     act: "tiles_builtin", mode: "3d" },
            { label: "Custom tileset",    key: "F2",     act: "tiles_custom",  mode: "3d" }
        ]
    },
    {
        title: "Help", mode: "all",
        items: [
            { label: "Place / replace", key: "LMB",          act: "", mode: "3d" },
            { label: "Remove",          key: "RMB / Del",    act: "", mode: "3d" },
            { label: "Tile palette",    key: "Space (hold)", act: "", mode: "3d" },
            { label: "Pick brush",      key: "Space+drag",   act: "", mode: "3d" },
            { label: "Pan",             key: "MMB drag",     act: "", mode: "3d" },
            { label: "Orbit",           key: "Alt+MMB drag", act: "", mode: "3d" },
            { label: "Zoom",            key: "Wheel",        act: "", mode: "3d" }
        ]
    }
];
