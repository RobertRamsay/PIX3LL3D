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