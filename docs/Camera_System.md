# Camera System

## Overview

Provides a professional-grade, dual-mode 3D camera with unlimited rotation freedom. The system is built on a **pure quaternion mathematics** foundation to eliminate gimbal lock and ensure smooth, predictable control, mirroring functionality found in tools like Blender.

## Architecture

**Files:**
- `src/camera/camera.odin` - Defines the `State` struct and initialization.
- `src/camera/controls.odin` - Contains all interactive update logic.

**Core Data Structure (`camera.State`):**
```odin
State :: struct {
    camera:          rl.Camera3D,
    zoom_speed:      f32,
    orbit_speed:     f32,
    movement_speed:  f32,
    is_orthographic: bool,
    // ... ortho-specific fields
}
```

## Control Logic

The system operates in two distinct modes based on whether the right mouse button is held.

### 1. Free-Look Mode (RMB Held)

-   **Activation:** `input_state.right_mouse_held == true`.
-   **Movement:** Standard WASD for planar movement, Q/E for vertical. Speed is frame-rate independent and adjustable with the mouse wheel.
-   **Rotation:** Mouse movement directly controls camera orientation.

**Quaternion Implementation:**
Rotation is calculated using pure quaternions to ensure the camera's `up` and `forward` vectors remain orthogonal and stable, even when looking straight up or down.

```odin
// Yaw (horizontal) rotation around world Y-axis
yaw_quat := rl.QuaternionFromAxisAngle({0, 1, 0}, yaw)
forward = rl.Vector3RotateByQuaternion(forward, yaw_quat)
camera.up = rl.Vector3RotateByQuaternion(camera.up, yaw_quat)
right = rl.Vector3RotateByQuaternion(right, yaw_quat)

// Pitch (vertical) rotation around the camera's local right-axis
pitch_quat := rl.QuaternionFromAxisAngle(right, pitch)
forward = rl.Vector3RotateByQuaternion(forward, pitch_quat)
camera.up = rl.Vector3RotateByQuaternion(camera.up, pitch_quat)
```

### 2. Orbit/Pan Mode (RMB Not Held)

-   **Activation:** `input_state.right_mouse_held == false`.
-   **Orbit (MMB):** Rotates the camera position around the `camera.target` point.
-   **Pan (Shift+MMB):** Moves both `camera.position` and `camera.target` together.
-   **Zoom (Mouse Wheel):** Moves the camera along its forward vector towards the target.

**Quaternion Implementation:**
Orbiting also uses quaternions to rotate the camera's `offset` vector from the target, ensuring smooth, gimbal-lock-free rotation. The camera's `up` vector is rotated simultaneously to maintain orientation.

```odin
yaw_quat := rl.QuaternionFromAxisAngle({0, 1, 0}, yaw)
right := rl.Vector3Normalize(rl.Vector3CrossProduct(forward, camera.up))
pitch_quat := rl.QuaternionFromAxisAngle(right, pitch)

combined_quat := pitch_quat * yaw_quat
offset = rl.Vector3RotateByQuaternion(offset, combined_quat)
camera.up = rl.Vector3RotateByQuaternion(camera.up, combined_quat)```

## Integration

The `editor` module owns the `camera.State` and calls `camera.update()` once per frame, passing the current `input.State`.

```odin
// In editor.update()
if !ui.should_block_scene_input(&editor_state.ui_state) {
    camera.update(&editor_state.camera_state, &editor_state.input_state)
    // ...
}
```