package editor

import "../scene"
import "../camera"
import "../input"
import "../operations"
import "../resources"
import "../selection"
import "../serialization"
import "../ui"
import "../model_import"
import "../gizmo"
import "../plugins"
import "../editor_state"
import rl "vendor:raylib"

State :: editor_state.State

init :: proc() -> State {
    // Enable MSAA for smooth grid lines before creating window
    rl.SetConfigFlags(rl.ConfigFlags{.MSAA_4X_HINT})
    rl.InitWindow(3100, 1360, "Midgard - An Odin 3D Editor")

    // Initialize FPS settings after window creation
    ui.apply_fps_settings()
    
    // Disable ESC key to close window - we handle ESC for deselection instead
    rl.SetExitKey(rl.KeyboardKey(0)) // Use key code 0 for no key
    
    editor_state := State {
        camera_state = camera.init(),
        selection_state = selection.init(),
        ui_state = ui.init(),
        scene = scene.init(),
        gizmo_state = gizmo.init(),
        viewport_gizmo_state = gizmo.init_viewport_gizmo(),
        environment = resources.Environment_State{
            grid_visible = true,
            background_visible = true,
            intensity = 1.0, // Default intensity for skybox
            sky_color = {55, 70, 90, 255}, // Default dark blue-gray
        },
    }

    // Initialize centralized font configuration
    ui.load_all_fonts()

    // Initialize hierarchy panel
    ui.hierarchy_state = ui.init_hierarchy()

    // Initialize viewport gizmo position
    gizmo.update_viewport_gizmo_position(&editor_state.viewport_gizmo_state, 
                                       editor_state.ui_state.right_panel.visible, 
                                       editor_state.ui_state.right_panel_width)

    return editor_state
}

update :: proc(editor_state: ^State) {
    // Handle window resize
    if rl.IsWindowResized() {
        ui.handle_resize(&editor_state.ui_state)
        ui.handle_hierarchy_resize()
        gizmo.update_viewport_gizmo_position(&editor_state.viewport_gizmo_state, 
                                           editor_state.ui_state.right_panel.visible, 
                                           editor_state.ui_state.right_panel_width)
    }
    
    // Handle file dialog (blocks other input when visible)
    if serialization.is_file_dialog_visible() {
        serialization.update_file_dialog()
        return  // Don't process other input while dialog is open
    }
    
    // Update import status display
    ui.update_import_status()
    
    // Begin UI processing
    ui.begin_ui(&editor_state.ui_state)
    
    // Handle UI input
    inspector_toggled := ui.handle_inspector_input(&editor_state.ui_state)
    ui.handle_navigation_input(&editor_state.ui_state)
    
    // UI panel toggles (work even when objects are selected)
    if rl.IsKeyPressed(.H) {
        ui.toggle_hierarchy()
    }
    
    if rl.IsKeyPressed(.P) {
        editor_state.ui_state.plugin_panel_visible = !editor_state.ui_state.plugin_panel_visible
    }

    if rl.IsKeyPressed(.M) {
        editor_state.ui_state.keymap_visible = !editor_state.ui_state.keymap_visible
    }
    
    // Check for HDRI requests from inspector
    if ui.check_hdri_dialog_request() {
        serialization.show_hdri_dialog()
    }
    if ui.check_hdri_clear_request() {
        resources.unload_hdri_environment(&editor_state.environment)
        serialization.mark_unsaved()
    }
    
    // Update viewport gizmo position if inspector was toggled
    if inspector_toggled {
        gizmo.update_viewport_gizmo_position(&editor_state.viewport_gizmo_state, 
                                           editor_state.ui_state.right_panel.visible, 
                                           editor_state.ui_state.right_panel_width)
    }
    
    // Handle menu selections from UI
    switch editor_state.ui_state.menu_selection {
    case .NEW_SCENE:
        if serialization.has_unsaved_changes() {
            // TODO: Show confirmation dialog in the future
        }
        
        // Clean up old scene before replacing
        scene.cleanup(&editor_state.scene)
        
        // Reset to startup defaults
        editor_state.scene = scene.init()  // This includes the default reference cube
        editor_state.selection_state = selection.init()
        
        // Reset environment to startup defaults (unload any skybox)
        resources.unload_hdri_environment(&editor_state.environment)
        editor_state.environment = resources.Environment_State{
            grid_visible = true,
            background_visible = true,
            intensity = 1.0, // Default intensity for skybox
            sky_color = {55, 70, 90, 255}, // Default dark blue-gray
        }
        
        // Reset file state
        serialization.file_state = {}
        
    case .OPEN_SCENE:
        serialization.show_load_dialog()
        
    case .SAVE_SCENE:
        if serialization.file_state.current_filepath != "" {
            serialization.save_scene(&editor_state.scene, &editor_state.environment,
                                   serialization.file_state.current_filepath)
        } else {
            // No current file, show save dialog
            serialization.show_save_dialog()
        }
        
    case .SAVE_AS_SCENE:
        serialization.show_save_dialog()
    case .IMPORT_ASSET:
        serialization.show_import_dialog()
        
    case .EXIT:
        // TODO: Show save confirmation if unsaved changes
        rl.CloseWindow()
        
    case .NONE:
        // No menu action
    }
    
    // Reset menu selection after processing
    editor_state.ui_state.menu_selection = .NONE
    
    // Check for file dialog completion
    if filepath, mode, completed := serialization.check_dialog_completion(); completed {
        switch mode {
        case .LOAD:
            if new_scene, new_environment, ok := serialization.load_scene(filepath); ok {
                editor_state.scene = new_scene
                editor_state.environment = new_environment
                editor_state.selection_state = selection.init()
                // If environment has HDRI, reload GPU resources
                if new_environment.enabled && new_environment.source_path != "" {
                    if env, success := resources.load_hdri_environment(new_environment.source_path, editor_state.environment); success {
                        editor_state.environment = env
                    }
                }
            }
        case .SAVE:
            serialization.save_scene(&editor_state.scene, &editor_state.environment, filepath)
        case .IMPORT:
            // Try plugins first, then fallback to core glTF loader
            model_loaded := false
            model: rl.Model
            
            // Try plugin import handlers first
            if plugin_model, plugin_ok := plugins.handle_import_via_plugins(filepath); plugin_ok {
                model = plugin_model
                model_loaded = true
            } else {
                // Fallback to core glTF/GLB loader for non-plugin formats
                if gltf_model, gltf_ok := model_import.load_model(filepath); gltf_ok {
                    model = gltf_model
                    model_loaded = true
                }
            }
            
            if model_loaded {
                // Show import status
                ui.show_import_status(filepath, model)
                
                // Create mesh data
                mesh_data := model_import.create_mesh_data(model, filepath)
                
                // Calculate spawn position (5 units in front of camera)
                forward := rl.Vector3Normalize(editor_state.camera_state.camera.target - 
                                              editor_state.camera_state.camera.position)
                spawn_pos := editor_state.camera_state.camera.position + forward * 5.0
                
                // Add to scene
                new_id := operations.create_mesh_object(&editor_state.scene, mesh_data, spawn_pos)
                
                // Select the newly imported object
                if new_id > 0 {
                    editor_state.selection_state.selected_id = new_id
                    editor_state.selection_state.selection_changed = true
                    serialization.mark_unsaved()
                }
            } else {
                // Show error status
                ui.show_import_error(filepath, "Failed to load 3D model")
            }
        case .HDRI_IMPORT:
            if new_env, success := resources.load_hdri_environment(filepath, editor_state.environment); success {
                // Unload previous environment if any
                resources.unload_hdri_environment(&editor_state.environment)
                editor_state.environment = new_env
                serialization.mark_unsaved()
            } else {
                ui.show_import_error(filepath, "Failed to load skybox image")
            }
        }
    }
    
    // Process input
    input.update(&editor_state.input_state)
    
    // Check for shortcuts (only if not typing in UI)
    if editor_state.ui_state.active_widget == 0 {
        // File operation shortcuts
        // New Scene (Ctrl+N)
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.N) {
            if serialization.has_unsaved_changes() {
                // TODO: Show confirmation dialog in the future
            }
            
            // Clean up old scene before replacing
            scene.cleanup(&editor_state.scene)
            
            // Reset to startup defaults
            editor_state.scene = scene.init()  // This includes the default reference cube
            editor_state.selection_state = selection.init()
            
            // Reset environment to startup defaults (unload any skybox)
            resources.unload_hdri_environment(&editor_state.environment)
            editor_state.environment = resources.Environment_State{
                grid_visible = true,
                background_visible = true,
                intensity = 1.0, // Default intensity for skybox
                sky_color = {55, 70, 90, 255}, // Default dark blue-gray
            }
            
            // Reset file state
            serialization.file_state = {}
        }
        
        // Open (Ctrl+O)
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.O) {
            serialization.show_load_dialog()
        }
        
        // Save (Ctrl+S)
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.S) {
            if !rl.IsKeyDown(.LEFT_SHIFT) {
                // Regular save
                if serialization.file_state.current_filepath != "" {
                    serialization.save_scene(&editor_state.scene, &editor_state.environment,
                                           serialization.file_state.current_filepath)
                } else {
                    // No current file, show save dialog
                    serialization.show_save_dialog()
                }
            } else {
                // Save As (Ctrl+Shift+S)
                serialization.show_save_dialog()
            }
        }
        
        // Import 3D model (Ctrl+I or 4 key) - supports glTF/glb/OBJ
        if (rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.I)) || rl.IsKeyPressed(.FOUR) {
            serialization.show_import_dialog()
        }
        
        // Creation shortcuts (standalone keys to avoid conflicts)
        new_id := -1
        
        if rl.IsKeyPressed(.ONE) {  // 1 for Cube
            new_id = operations.create_at_cursor(&editor_state.scene, 
                                                 editor_state.camera_state.camera,
                                                 .CUBE)
        } else if rl.IsKeyPressed(.TWO) {  // 2 for Sphere  
            new_id = operations.create_at_cursor(&editor_state.scene,
                                                 editor_state.camera_state.camera, 
                                                 .SPHERE)
        } else if rl.IsKeyPressed(.THREE) {  // 3 for Cylinder
            new_id = operations.create_at_cursor(&editor_state.scene,
                                                 editor_state.camera_state.camera,
                                                 .CYLINDER)
        }
        
        // Select newly created object
        if new_id > 0 {
            editor_state.selection_state.selected_id = new_id
            editor_state.selection_state.selection_changed = true
            serialization.mark_unsaved()
        }
        
        // Deletion shortcuts (Ctrl+C and Delete key to avoid X axis constraint conflict)
        if rl.IsKeyPressed(.DELETE) || (rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.C)) {
            old_count := len(editor_state.scene.objects)
            operations.delete_selected(&editor_state.scene, &editor_state.selection_state)
            if len(editor_state.scene.objects) != old_count {
                serialization.mark_unsaved()
            }
        }
        
        // Duplication shortcut (Ctrl+D)
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.D) {
            if editor_state.selection_state.selected_id > 0 {
                new_id := operations.duplicate_object(&editor_state.scene, 
                                                      editor_state.selection_state.selected_id)
                if new_id > 0 {
                    editor_state.selection_state.selected_id = new_id
                    editor_state.selection_state.selection_changed = true
                    serialization.mark_unsaved()
                }
            }
        }
        
        // Select/Deselect shortcuts
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.A) {
            operations.select_all(&editor_state.scene, &editor_state.selection_state)
        }
        
        if rl.IsKeyPressed(.ESCAPE) {
            operations.deselect_all(&editor_state.selection_state)
        }
        
        
        // Gizmo mode switching - only when NOT in flying mode (RMB not held)
        if !rl.IsMouseButtonDown(.RIGHT) {
            if rl.IsKeyPressed(.Q) {
                editor_state.gizmo_state.mode = .NONE
            }
            if rl.IsKeyPressed(.W) {
                editor_state.gizmo_state.mode = .TRANSLATE
            }
            if rl.IsKeyPressed(.R) {
                    editor_state.gizmo_state.mode = .ROTATE
            }
            if rl.IsKeyPressed(.E) {
                editor_state.gizmo_state.mode = .SCALE
            }
            if rl.IsKeyPressed(.T) {
                editor_state.gizmo_state.mode = .TRANSFORM
            }
        }
        
        // Axis constraints
        if rl.IsKeyPressed(.X) {
            if rl.IsKeyDown(.LEFT_SHIFT) {
                // Exclude X (YZ plane)
                gizmo.set_plane_constraint(&editor_state.gizmo_state, .X)
            } else {
                // Toggle or exclusive X
                if rl.IsKeyDown(.LEFT_CONTROL) {
                    gizmo.toggle_axis(&editor_state.gizmo_state, .X)
                } else {
                    gizmo.set_single_axis(&editor_state.gizmo_state, .X)
                }
            }
        }
        
        if rl.IsKeyPressed(.Y) {
            if rl.IsKeyDown(.LEFT_SHIFT) {
                // Exclude Y (XZ plane)
                gizmo.set_plane_constraint(&editor_state.gizmo_state, .Y)
            } else {
                // Toggle or exclusive Y
                if rl.IsKeyDown(.LEFT_CONTROL) {
                    gizmo.toggle_axis(&editor_state.gizmo_state, .Y)
                } else {
                    gizmo.set_single_axis(&editor_state.gizmo_state, .Y)
                }
            }
        }
        
        if rl.IsKeyPressed(.Z) {
            if rl.IsKeyDown(.LEFT_SHIFT) {
                // Exclude Z (XY plane)
                gizmo.set_plane_constraint(&editor_state.gizmo_state, .Z)
            } else {
                // Toggle or exclusive Z
                if rl.IsKeyDown(.LEFT_CONTROL) {
                    gizmo.toggle_axis(&editor_state.gizmo_state, .Z)
                } else {
                    gizmo.set_single_axis(&editor_state.gizmo_state, .Z)
                }
            }
        }
        
        // Grid snapping
        if rl.IsKeyPressed(.G) {
            editor_state.gizmo_state.snap_enabled = !editor_state.gizmo_state.snap_enabled
        }
    }
    
    // Handle viewport gizmo FIRST (always check, as it's a UI element)
    viewport_view_changed := gizmo.update_viewport_gizmo(
        &editor_state.viewport_gizmo_state,
        &editor_state.camera_state,
        editor_state.input_state.mouse_position,
        editor_state.input_state.left_mouse_clicked,
        &editor_state.selection_state,
        &editor_state.scene,
    )

    // Update camera and selection (only if UI is not blocking)
    if !ui.should_block_scene_input(&editor_state.ui_state) {
        camera.update(&editor_state.camera_state, &editor_state.input_state)
        
        // New variables to manage input priority.
        gizmo_consumed_input := false
        transform_changed := false

        // Update gizmo interaction FIRST for the selected object.
        if selected_object := selection.get_selected_object(&editor_state.selection_state, 
                                                            &editor_state.scene); 
           selected_object != nil {
            
            // Capture both return values from the updated gizmo.update proc.
            transform_changed, gizmo_consumed_input = gizmo.update(
                &editor_state.gizmo_state,
                selected_object,
                editor_state.input_state.mouse_position,
                editor_state.camera_state.camera,
                editor_state.input_state.left_mouse_clicked,
                rl.IsMouseButtonReleased(.LEFT),
            )
            
            if transform_changed {
                serialization.mark_unsaved()
            }
        }

        // Update scene selection ONLY if no gizmo handled the input and UI should not block scene input.
        // This prevents deselection when clicking gizmo handles, viewport gizmo, or any UI elements including menus.
        if !ui.should_block_scene_input(&editor_state.ui_state) && !gizmo_consumed_input && !viewport_view_changed {
            selection.update(&editor_state.selection_state,
                           editor_state.input_state.mouse_position,
                           editor_state.camera_state.camera,
                           &editor_state.scene,
                           editor_state.input_state.left_mouse_clicked)
        }
    }
    
    // Reset inspector cache if selection changed
    if selection.has_selection_changed(&editor_state.selection_state) {
        ui.reset_inspector_cache()
    }
    
    // End UI processing
    ui.end_ui(&editor_state.ui_state)
}

cleanup :: proc(editor_state: ^State) { // Close window and clean up
    ui.unload_all_fonts()
    scene.cleanup(&editor_state.scene) // Use the new scene cleanup proc
    // delete(editor_state.scene.objects) // This is no longer needed
    rl.CloseWindow()
}