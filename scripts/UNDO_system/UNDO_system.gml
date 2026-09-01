function undo_push_snapshot()
{
    // Save the CURRENT state before a mutating action, so undo restores it.
    array_push(global.undo_stack, variable_clone(global.world_tiles));

    // Cap the stack: drop the oldest if over the limit
    if (array_length(global.undo_stack) > global.undo_max)
    {
        array_delete(global.undo_stack, 0, 1);
    }

    // Any new action invalidates the redo history
    global.redo_stack = [];
}

function undo_perform()
{
    if (array_length(global.undo_stack) == 0) { return; }

    // Current state goes onto the redo stack
    array_push(global.redo_stack, variable_clone(global.world_tiles));

    // Pop the most recent snapshot and restore it
    var _snap = array_pop(global.undo_stack);
    global.world_tiles = _snap;
}

function redo_perform()
{
    if (array_length(global.redo_stack) == 0) { return; }

    // Current state goes back onto the undo stack
    array_push(global.undo_stack, variable_clone(global.world_tiles));

    var _snap = array_pop(global.redo_stack);
    global.world_tiles = _snap;
}