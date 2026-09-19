/// FILE_system
/// Wrappers around the OS file dialogs.
///
/// These used to drop out of fullscreen and back around each dialog, because
/// a modal dialog over an EXCLUSIVE fullscreen window traps focus. The editor
/// no longer uses exclusive fullscreen at all (see WINDOW_system - "fullscreen"
/// is a borderless window filling the display), so that dance is not needed,
/// and it was costing a full swap chain teardown and rebuild on every save and
/// load. A modal dialog over a borderless window behaves itself.

/// @desc Show an open-file dialog.
function get_open_filename_safe(_filter, _fname)
{
    return get_open_filename(_filter, _fname);
}

/// @desc Show a save-file dialog.
function get_save_filename_safe(_filter, _fname)
{
    return get_save_filename(_filter, _fname);
}
