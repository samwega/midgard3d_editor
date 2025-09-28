package operations

import "../scene"
import "../selection"
import "../model_import"

// Delete selected object(s)
delete_selected :: proc(scene_data: ^scene.Scene, 
                        selection_state: ^selection.State) -> bool {
    if selection_state.selected_id <= 0 {
        return false  // Nothing selected
    }
    
    // Find and remove the selected object
    for obj, i in scene_data.objects {
        if obj.id == selection_state.selected_id {
            // Cleanup mesh data if it's a mesh object
            if obj.object_type == .MESH && obj.mesh_data != nil {
                model_import.cleanup_mesh_data(obj.mesh_data)
            }
            
            ordered_remove(&scene_data.objects, i)
            
            // Clear selection
            selection_state.selected_id = -1
            selection_state.selection_changed = true
            
            return true
        }
    }
    
    return false
}

// Delete specific object by ID
delete_object :: proc(scene_data: ^scene.Scene, object_id: int) -> bool {
    for obj, i in scene_data.objects {
        if obj.id == object_id {
            // Cleanup mesh data if it's a mesh object
            if obj.object_type == .MESH && obj.mesh_data != nil {
                model_import.cleanup_mesh_data(obj.mesh_data)
            }
            
            ordered_remove(&scene_data.objects, i)
            return true
        }
    }
    return false
}

// Cycle through all objects (since we don't have multi-select yet)
select_all :: proc(scene_data: ^scene.Scene, selection_state: ^selection.State) {
    if len(scene_data.objects) == 0 {
        return
    }
    
    // Find current selection index
    current_index := -1
    for obj, i in scene_data.objects {
        if obj.id == selection_state.selected_id {
            current_index = i
            break
        }
    }
    
    // Cycle to next object (or select first if none selected)
    next_index := (current_index + 1) % len(scene_data.objects)
    selection_state.selected_id = scene_data.objects[next_index].id
    selection_state.selection_changed = true
}

// Deselect all
deselect_all :: proc(selection_state: ^selection.State) {
    if selection_state.selected_id != -1 {
        selection_state.selected_id = -1
        selection_state.selection_changed = true
    }
}