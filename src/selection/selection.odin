package selection

import "../scene"
import rl "vendor:raylib"

State :: struct {
    selected_id: int,  // ID of currently selected object (-1 if none)
    hovered_id: int,   // ID of currently hovered object (-1 if none)
    selection_changed: bool, // Flag set when selection changes (for UI updates)
}

init :: proc() -> State {
    return State {
        selected_id = -1,
        hovered_id = -1,
        selection_changed = false,
    }
}

// Update selection based on mouse input
update :: proc(selection_state: ^State, mouse_pos: rl.Vector2, camera: rl.Camera3D, scene_data: ^scene.Scene, left_clicked: bool) {
    // Clear selection changed flag at start of frame
    selection_state.selection_changed = false
    
    // Skip raycast during flying mode (RMB held) to prevent corruption
    if rl.IsMouseButtonDown(.RIGHT) {
        // Clear hover during flying mode
        selection_state.hovered_id = -1
        return  // Don't do any raycast operations during flying
    }
    
    // Update hover state - only when not flying
    selection_state.hovered_id = raycast_from_mouse(mouse_pos, camera, scene_data)
    
    // Update selection on left click
    if left_clicked {
        old_selected_id := selection_state.selected_id
        selection_state.selected_id = selection_state.hovered_id
        
        // Set flag if selection actually changed
        if old_selected_id != selection_state.selected_id {
            selection_state.selection_changed = true
        }
    }
}

// Check if object is currently selected
is_selected :: proc(selection_state: ^State, object_id: int) -> bool {
    return selection_state.selected_id == object_id
}

// Check if object is currently hovered
is_hovered :: proc(selection_state: ^State, object_id: int) -> bool {
    return selection_state.hovered_id == object_id
}

// Get currently selected object from scene (returns nil if none selected)
get_selected_object :: proc(selection_state: ^State, scene_data: ^scene.Scene) -> ^scene.Scene_Object {
    if selection_state.selected_id == -1 {
        return nil
    }
    
    for &object in scene_data.objects {
        if object.id == selection_state.selected_id {
            return &object
        }
    }
    
    return nil
}

// Check if selection changed this frame
has_selection_changed :: proc(selection_state: ^State) -> bool {
    return selection_state.selection_changed
}

