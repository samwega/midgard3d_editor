package rendering

import "../scene"
import "../selection"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"
import "core:slice"
import "core:fmt"

// Temporary structure for sorting transparent objects
Object_Draw_Data :: struct {
    object: ^scene.Scene_Object,
    is_selected: bool,
    is_hovered: bool,
    camera_distance: f32,
}

render_scene :: proc(scene: ^scene.Scene, selection_state: ^selection.State, camera_pos: rl.Vector3) {
    opaque_objects: [dynamic]Object_Draw_Data
    transparent_objects: [dynamic]Object_Draw_Data
    defer delete(opaque_objects)
    defer delete(transparent_objects)
    
    // Separate objects by transparency and calculate camera distances
    for &object in scene.objects {
        is_selected := selection.is_selected(selection_state, object.id)
        is_hovered := selection.is_hovered(selection_state, object.id)
        
        // Calculate distance from camera to object center
        distance := rl.Vector3Distance(camera_pos, object.transform.position)
        
        draw_data := Object_Draw_Data{
            object = &object,
            is_selected = is_selected,
            is_hovered = is_hovered,
            camera_distance = distance,
        }
        
        // Check if object has intrinsic transparency - selection/hover highlights don't count
        has_transparency := object.color.a < 255
        if has_transparency {
            append(&transparent_objects, draw_data)
        } else {
            append(&opaque_objects, draw_data)
        }
    }
    
    // Render opaque objects first (order doesn't matter for opaque objects)
    for &draw_data in opaque_objects {
        render_opaque_object(draw_data.object, draw_data.is_selected, draw_data.is_hovered)
    }
    
    // Sort transparent objects back-to-front (farthest first)
    slice.sort_by(transparent_objects[:], proc(a, b: Object_Draw_Data) -> bool {
        return a.camera_distance > b.camera_distance
    })
    
    // Render transparent objects back-to-front with proper blending
    if len(transparent_objects) > 0 {
        rl.BeginBlendMode(.ALPHA)
        for &draw_data in transparent_objects {
            render_transparent_object(draw_data.object, draw_data.is_selected, draw_data.is_hovered)
        }
        rl.EndBlendMode()
    }
}

render_opaque_object :: proc(object: ^scene.Scene_Object, is_selected: bool, is_hovered: bool) {
    pos := object.transform.position
    rotation := object.transform.rotation
    scale := object.transform.scale

    // Determine colors based on selection state
    base_color := object.color
    wireframe_color := rl.ColorAlpha(rl.BLACK, 0.3)
    
    // For opaque objects, don't apply transparency effects - use wireframe only for selection feedback
    if is_selected {
        wireframe_color = rl.ORANGE // Bright orange for selected
    } else if is_hovered {
        wireframe_color = rl.YELLOW // Yellow for hovered
    }

    // Apply transformation matrix (position, rotation, scale)
    rlgl.PushMatrix()
    defer rlgl.PopMatrix()
    
    // Translate to position
    rlgl.Translatef(pos.x, pos.y, pos.z)
    
    // Apply rotations (in degrees) - order: Z, Y, X (typical game engine convention)
    rlgl.Rotatef(rotation.z, 0, 0, 1) // Z rotation (roll)
    rlgl.Rotatef(rotation.y, 0, 1, 0) // Y rotation (yaw)
    rlgl.Rotatef(rotation.x, 1, 0, 0) // X rotation (pitch)
    
    // Apply scale
    rlgl.Scalef(scale.x, scale.y, scale.z)

    // Draw the base object at origin (0,0,0) since we've already applied transformations
    switch object.object_type {
    case .CUBE:
        rl.DrawCube({0, 0, 0}, 1, 1, 1, base_color)
        rl.DrawCubeWires({0, 0, 0}, 1, 1, 1, wireframe_color)
    case .SPHERE:
        rl.DrawSphere({0, 0, 0}, 1, base_color)
        rl.DrawSphereWires({0, 0, 0}, 1, 16, 32, wireframe_color)
    case .CYLINDER:
        rl.DrawCylinder({0, 0, 0}, 1, 1, 1, 22, base_color)
        rl.DrawCylinderWires({0, 0, 0}, 1, 1, 1, 22, wireframe_color)
    case .MESH:
        if object.mesh_data != nil {
            // Draw the model normally - let Raylib handle materials properly
            rl.DrawModel(object.mesh_data.model, {0, 0, 0}, 1.0, rl.Color{255, 255, 255, 255})
        }
    }
    
    // Draw additional highlight wireframe for selected/hovered objects
    if is_selected || is_hovered {
        wireframe_highlight := is_selected ? rl.ColorAlpha(rl.ORANGE, 0.9) : rl.ColorAlpha(rl.YELLOW, 0.7)
        switch object.object_type {
        case .CUBE:
            rl.DrawCubeWires({0, 0, 0}, 1, 1, 1, wireframe_highlight)
        case .SPHERE:
            rl.DrawSphereWires({0, 0, 0}, 1, 8, 8, wireframe_highlight)
        case .CYLINDER:
            rl.DrawCylinderWires({0, 0, 0}, 1, 1, 1, 22, wireframe_highlight)
        case .MESH:
            if object.mesh_data != nil {
                rl.DrawModelWires(object.mesh_data.model, {0, 0, 0}, 1.0, wireframe_highlight)
            }
        }
    }
}

// Render objects with alpha cutout materials (foliage, trees, etc.)
// Uses alpha testing with full depth writing for proper occlusion
render_alpha_cutout_object :: proc(object: ^scene.Scene_Object, is_selected: bool, is_hovered: bool) {
    pos := object.transform.position
    rotation := object.transform.rotation
    scale := object.transform.scale

    // Determine colors based on selection state
    base_color := object.color
    wireframe_color := rl.ColorAlpha(rl.BLACK, 0.3)
    
    // Apply tint for selection/hover feedback
    if is_selected {
        base_color = rl.ColorTint(base_color, rl.ColorAlpha(rl.WHITE, 0.6))
        wireframe_color = rl.ORANGE
    } else if is_hovered {
        base_color = rl.ColorTint(base_color, rl.ColorAlpha(rl.WHITE, 0.95))
        wireframe_color = rl.YELLOW
    }

    // Apply transformation matrix
    rlgl.PushMatrix()
    defer rlgl.PopMatrix()
    
    rlgl.Translatef(pos.x, pos.y, pos.z)
    rlgl.Rotatef(rotation.z, 0, 0, 1)
    rlgl.Rotatef(rotation.y, 0, 1, 0)
    rlgl.Rotatef(rotation.x, 1, 0, 0)
    rlgl.Scalef(scale.x, scale.y, scale.z)

    // For alpha cutout objects, render normally with full alpha
    // Raylib's default shader should handle alpha testing automatically
    switch object.object_type {
    case .CUBE:
        rl.DrawCube({0, 0, 0}, 1, 1, 1, base_color)
        rl.DrawCubeWires({0, 0, 0}, 1, 1, 1, wireframe_color)
    case .SPHERE:
        rl.DrawSphere({0, 0, 0}, 1, base_color)
        rl.DrawSphereWires({0, 0, 0}, 1, 16, 32, wireframe_color)
    case .CYLINDER:
        rl.DrawCylinder({0, 0, 0}, 1, 1, 1, 22, base_color)
        rl.DrawCylinderWires({0, 0, 0}, 1, 1, 1, 22, wireframe_color)
    case .MESH:
        if object.mesh_data != nil {
            // For alpha cutout materials, draw with full color - let the shader handle alpha testing
            // This ensures proper depth writing while still cutting out transparent pixels
            rl.DrawModel(object.mesh_data.model, {0, 0, 0}, 1.0, base_color)
        }
    }
    
    // Draw wireframe highlights for selected/hovered objects
    if is_selected || is_hovered {
        wireframe_highlight := is_selected ? rl.ColorAlpha(rl.ORANGE, 0.9) : rl.ColorAlpha(rl.YELLOW, 0.7)
        switch object.object_type {
        case .CUBE:
            rl.DrawCubeWires({0, 0, 0}, 1, 1, 1, wireframe_highlight)
        case .SPHERE:
            rl.DrawSphereWires({0, 0, 0}, 1, 8, 8, wireframe_highlight)
        case .CYLINDER:
            rl.DrawCylinderWires({0, 0, 0}, 1, 1, 1, 22, wireframe_highlight)
        case .MESH:
            if object.mesh_data != nil {
                rl.DrawModelWires(object.mesh_data.model, {0, 0, 0}, 1.0, wireframe_highlight)
            }
        }
    }
}

render_transparent_object :: proc(object: ^scene.Scene_Object, is_selected: bool, is_hovered: bool) {
    pos := object.transform.position
    rotation := object.transform.rotation
    scale := object.transform.scale

    // Determine colors based on selection state
    base_color := object.color
    wireframe_color := rl.ColorAlpha(rl.BLACK, 0.3)
    
    // Apply tint for selection/hover feedback
    if is_selected {
        // Selected objects get a bright outline and slight color tint
        base_color = rl.ColorTint(base_color, rl.ColorAlpha(rl.WHITE, 0.6))
        wireframe_color = rl.ORANGE // Bright orange for selected
    } else if is_hovered {
        // Hovered objects get a subtle highlight
        base_color = rl.ColorTint(base_color, rl.ColorAlpha(rl.WHITE, 0.95))
        wireframe_color = rl.YELLOW // Yellow for hovered
    }

    // Apply transformation matrix (position, rotation, scale)
    rlgl.PushMatrix()
    defer rlgl.PopMatrix()
    
    // Translate to position
    rlgl.Translatef(pos.x, pos.y, pos.z)
    
    // Apply rotations (in degrees) - order: Z, Y, X (typical game engine convention)
    rlgl.Rotatef(rotation.z, 0, 0, 1) // Z rotation (roll)
    rlgl.Rotatef(rotation.y, 0, 1, 0) // Y rotation (yaw)
    rlgl.Rotatef(rotation.x, 1, 0, 0) // X rotation (pitch)
    
    // Apply scale
    rlgl.Scalef(scale.x, scale.y, scale.z)

    // For transparent objects, disable depth writing but keep depth testing
    // This allows proper blending without z-fighting between transparent surfaces
    rlgl.DisableDepthMask()
    defer rlgl.EnableDepthMask()
    
    switch object.object_type {
    case .CUBE:
        rl.DrawCube({0, 0, 0}, 1, 1, 1, base_color)
        rl.DrawCubeWires({0, 0, 0}, 1, 1, 1, wireframe_color)
    case .SPHERE:
        rl.DrawSphere({0, 0, 0}, 1, base_color)
        rl.DrawSphereWires({0, 0, 0}, 1, 16, 32, wireframe_color)
    case .CYLINDER:
        rl.DrawCylinder({0, 0, 0}, 1, 1, 1, 22, base_color)
        rl.DrawCylinderWires({0, 0, 0}, 1, 1, 1, 22, wireframe_color)
    case .MESH:
        if object.mesh_data != nil {
            // For meshes with transparent materials, draw normally
            // Raylib's DrawModel handles alpha textures correctly with proper depth testing
            rl.DrawModel(object.mesh_data.model, {0, 0, 0}, 1.0, base_color)
        }
    }
    
    // Draw additional highlight wireframe for selected/hovered objects
    if is_selected || is_hovered {
        wireframe_highlight := is_selected ? rl.ColorAlpha(rl.ORANGE, 0.9) : rl.ColorAlpha(rl.YELLOW, 0.7)
        switch object.object_type {
        case .CUBE:
            rl.DrawCubeWires({0, 0, 0}, 1, 1, 1, wireframe_highlight)
        case .SPHERE:
            rl.DrawSphereWires({0, 0, 0}, 1, 8, 8, wireframe_highlight)
        case .CYLINDER:
            rl.DrawCylinderWires({0, 0, 0}, 1, 1, 1, 22, wireframe_highlight)
        case .MESH:
            if object.mesh_data != nil {
                rl.DrawModelWires(object.mesh_data.model, {0, 0, 0}, 1.0, wireframe_highlight)
            }
        }
    }
}

// Check if an object has materials with transparency - for now, treat all models as opaque
// The real issue is that we need alpha testing, not alpha blending
has_transparent_material :: proc(object: ^scene.Scene_Object) -> bool {
    return false // Disable transparency detection completely for now
}

// Check if a texture has an alpha channel based on its format
texture_has_alpha :: proc(texture: rl.Texture2D) -> bool {
    if texture.id == 0 {
        return false // Invalid texture
    }
    
    // Check the pixel format for alpha channel presence
    #partial switch rl.PixelFormat(texture.format) {
    case .UNCOMPRESSED_GRAY_ALPHA,
         .UNCOMPRESSED_R5G5B5A1,
         .UNCOMPRESSED_R4G4B4A4,
         .UNCOMPRESSED_R8G8B8A8,
         .UNCOMPRESSED_R32G32B32A32,
         .UNCOMPRESSED_R16G16B16A16,
         .COMPRESSED_DXT1_RGBA,
         .COMPRESSED_DXT3_RGBA,
         .COMPRESSED_DXT5_RGBA,
         .COMPRESSED_ETC2_EAC_RGBA,
         .COMPRESSED_PVRT_RGBA,
         .COMPRESSED_ASTC_4x4_RGBA,
         .COMPRESSED_ASTC_8x8_RGBA:
        return true
    case:
        return false
    }
}