package camera

import rl "vendor:raylib"

State :: struct {
    camera: rl.Camera3D,
    zoom_speed: f32,
    orbit_speed: f32,
    movement_speed: f32,
    is_orthographic: bool,
    ortho_size: f32,
    ortho_zoom_speed: f32,
}

init :: proc() -> State {
    camera_state := State {
        // Initialize camera with reasonable defaults:
        camera = rl.Camera3D {
            position = {4, 3, 5},     // Start position - will be calculated from orbit
            target = {0.5, 0.5, 0.5},         // Look at world origin
            up = {0, 1, 0},             // World up vector (Y is up)
            fovy = 75.0,              // Field of view - reduced for better precision
            projection = .PERSPECTIVE,
        },
        zoom_speed = 2.0,
        orbit_speed = 0.003,
        movement_speed = 3.6,  // meters per second
        is_orthographic = false,
        ortho_size = 20.0,
        ortho_zoom_speed = 1.5,
    }
    return camera_state
}