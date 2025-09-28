package input

import rl "vendor:raylib"

State :: struct {
    mouse_position: rl.Vector2,
    mouse_delta: rl.Vector2,
    mouse_wheel: f32,
    left_mouse_clicked: bool,
    right_mouse_held: bool,
    key_pressed: map[rl.KeyboardKey]bool,
}

update :: proc(input_state: ^State) {
    // Capture mouse position and movement
    input_state.mouse_position = rl.GetMousePosition()
    input_state.mouse_delta = rl.GetMouseDelta()

    // Capture mouse wheel for zooming
    input_state.mouse_wheel = rl.GetMouseWheelMove()

    // Check for left mouse click for selection
    input_state.left_mouse_clicked = rl.IsMouseButtonPressed(.LEFT)

    // Check if right mouse button is held for orbiting
    input_state.right_mouse_held = rl.IsMouseButtonDown(.RIGHT)

    // Middle mouse not stored as state, checked directly in controls
}