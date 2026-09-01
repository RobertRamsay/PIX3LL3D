/// @desc Show an open-file dialog without the fullscreen focus trap.
function get_open_filename_safe(_filter, _fname)
{
    var _was_full = window_get_fullscreen();
    if (_was_full)
    {
        window_set_fullscreen(false);
    }

    var _result = get_open_filename(_filter, _fname);

    if (_was_full)
    {
        window_set_fullscreen(true);
    }

    return _result;
}

/// @desc Show a save-file dialog without the fullscreen focus trap.
function get_save_filename_safe(_filter, _fname)
{
    var _was_full = window_get_fullscreen();
    if (_was_full)
    {
        window_set_fullscreen(false);
    }

    var _result = get_save_filename(_filter, _fname);

    if (_was_full)
    {
        window_set_fullscreen(true);
    }

    return _result;
}