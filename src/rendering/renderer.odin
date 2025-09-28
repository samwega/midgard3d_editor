package rendering

import "../editor"
import "../selection"
import "../gizmo"
import "../ui"
import "../resources"
import "core:math"
import "core:fmt"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl" // Import rlgl for advanced render state control

render :: proc(editor_state: ^editor.State) {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    
    // Only clear background if no skybox is active
    if !editor_state.environment.enabled || !editor_state.environment.background_visible {
        rl.ClearBackground(editor_state.environment.sky_color)
    } else {
        // Clear to black when skybox is active - skybox will fill the background
        rl.ClearBackground({0, 0, 0, 255})
    }

    // --- RENDER THE 3D SCENE ---
    rl.BeginMode3D(editor_state.camera_state.camera)
    {        
        // --- RENDER SKYBOX FIRST ---
        if editor_state.environment.enabled && editor_state.environment.background_visible {
            render_hdri_skybox(&editor_state.environment, editor_state.camera_state.camera)
        }
        
        // --- EXISTING SCENE RENDERING ---
        camera_distance := rl.Vector3Length(editor_state.camera_state.camera.position)
        
        // Draw grid if visible
        if editor_state.environment.grid_visible {
            draw_adaptive_grid(camera_distance, editor_state.camera_state.camera.position)
        }
        
        draw_infinite_axes(camera_distance)
        
        render_scene(&editor_state.scene, &editor_state.selection_state, editor_state.camera_state.camera.position)
    }
    rl.EndMode3D()

    // --- RENDER THE 2D GIZMO OVERLAY ---
    // WHY: After the 3D scene is completely finished, we draw the gizmo using 2D screen-space
    // coordinates. This GUARANTEES it is never hidden, clipped, or distorted by 3D perspective.
    // This is the correct, robust architecture for this feature.
    if selected_obj := selection.get_selected_object(&editor_state.selection_state, 
                                                     &editor_state.scene);
       selected_obj != nil {
        
        gizmo.draw(&editor_state.gizmo_state, 
                         selected_obj,
                         editor_state.camera_state.camera)
    }

    // --- RENDER VIEWPORT GIZMO ---
    gizmo.draw_viewport_gizmo(&editor_state.viewport_gizmo_state, editor_state.camera_state.camera, ui.get_font(.GIZMO))

    // --- RENDER 2D UI ---
    // The rest of the UI is drawn on top of the scene and the gizmo.
    render_ui(editor_state)
}

render_hdri_skybox :: proc(env: ^resources.Environment_State, camera: rl.Camera3D) {
    if env.skybox_texture.id == 0 { return }
    
    // Disable backface culling for skybox (we're inside the sphere)
    rlgl.DisableBackfaceCulling()
    defer rlgl.EnableBackfaceCulling()
    
    // Begin using the skybox shader
    rl.BeginShaderMode(env.skybox_shader)
    defer rl.EndShaderMode()
    
    // Set shader uniforms
    rotation_radians := -env.rotation_y * math.PI / 180.0  // Negative for natural rotation direction
    rl.SetShaderValue(env.skybox_shader, rl.GetShaderLocation(env.skybox_shader, "rotationY"), 
                     &rotation_radians, .FLOAT)
    rl.SetShaderValue(env.skybox_shader, rl.GetShaderLocation(env.skybox_shader, "exposure"), 
                     &env.exposure, .FLOAT)
    rl.SetShaderValue(env.skybox_shader, rl.GetShaderLocation(env.skybox_shader, "intensity"), 
                     &env.intensity, .FLOAT)
    
    // Set texture on the material (Raylib will bind it to texture0 automatically)
    rl.SetMaterialTexture(&env.skybox_model.materials[0], .ALBEDO, env.skybox_texture)
    
    // Draw sphere centered on camera with large scale
    // The vertex shader will set depth to maximum (far plane) ensuring it stays in background
    rl.DrawModel(env.skybox_model, camera.position, 500.0, rl.WHITE)
}