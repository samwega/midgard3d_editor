package camera

import "../input"
import rl "vendor:raylib"
import "core:math"

update :: proc(camera_state: ^State, input_state: ^input.State) {
    using camera_state

    if input_state.right_mouse_held {
        //----------------------------------
        // FREE-LOOK MODE (RMB held)
        //----------------------------------
        
        // Mouse look - rotate view direction
        if input_state.mouse_delta.x != 0 || input_state.mouse_delta.y != 0 {
            yaw := -input_state.mouse_delta.x * orbit_speed
            pitch := -input_state.mouse_delta.y * orbit_speed
            
            // Get current forward direction
            forward := rl.Vector3Normalize(camera.target - camera.position)
            
            // Full quaternion-based rotation for flying mode - unlimited rotation
            // Calculate right vector once to avoid numerical drift
            right := rl.Vector3Normalize(rl.Vector3CrossProduct(forward, camera.up))
            
            // Horizontal rotation around world Y-axis
            yaw_quat := rl.QuaternionFromAxisAngle({0, 1, 0}, yaw)
            forward = rl.Vector3RotateByQuaternion(forward, yaw_quat)
            camera.up = rl.Vector3RotateByQuaternion(camera.up, yaw_quat)
            // Also rotate the right vector to maintain consistency
            right = rl.Vector3RotateByQuaternion(right, yaw_quat)
            
            // Vertical rotation around the rotated right axis
            pitch_quat := rl.QuaternionFromAxisAngle(right, pitch)
            forward = rl.Vector3RotateByQuaternion(forward, pitch_quat)
            camera.up = rl.Vector3RotateByQuaternion(camera.up, pitch_quat)
            
            // Update target to maintain distance
            distance := rl.Vector3Length(camera.target - camera.position)
            camera.target = camera.position + forward * distance
        }

        // Mouse wheel changes movement speed
        if input_state.mouse_wheel != 0 {
            if input_state.mouse_wheel > 0 {
                camera_state.movement_speed *= 1.1
            } else {
                camera_state.movement_speed *= 0.9
            }
            
            // Clamp movement speed to reasonable limits (m/s)
            camera_state.movement_speed = math.clamp(camera_state.movement_speed, 0.1, 50.0)
        }
        
        // WASD movement - convert speed from m/s to units per frame using delta time
        effective_speed := camera_state.movement_speed * rl.GetFrameTime()
        if rl.IsKeyDown(.LEFT_SHIFT) {
            effective_speed *= 2.0
        }
        
        movement := rl.Vector3{0, 0, 0}
        forward := rl.Vector3Normalize(camera.target - camera.position)
        right := rl.Vector3Normalize(rl.Vector3CrossProduct(forward, {0, 1, 0}))
        
        if rl.IsKeyDown(.W) {movement += forward}
        if rl.IsKeyDown(.S) {movement -= forward}
        if rl.IsKeyDown(.A) {movement -= right}
        if rl.IsKeyDown(.D) {movement += right}
        if rl.IsKeyDown(.E) {movement += {0, 1, 0}}
        if rl.IsKeyDown(.Q) {movement -= {0, 1, 0}}
        
        if movement.x != 0 || movement.y != 0 || movement.z != 0 {
            movement = rl.Vector3Normalize(movement) * effective_speed
            camera.position += movement
            camera.target += movement  // Move target with camera to maintain look direction
            
            // No gimbal lock fixes - allow full freedom like Blender
        }
    } else {
        //----------------------------------
        // ORBIT/PAN MODE (RMB not held)
        //----------------------------------
        
        // Mouse wheel zoom - different behavior for orthographic vs perspective
        if input_state.mouse_wheel != 0 {
            if camera.projection == .ORTHOGRAPHIC {
                // Orthographic zoom - change view size
                zoom_factor := input_state.mouse_wheel * ortho_zoom_speed
                camera.fovy = math.clamp(camera.fovy - zoom_factor, 1.0, 100.0)
            } else {
                // Perspective zoom - move camera closer/further from target
                current_distance := rl.Vector3Length(camera.target - camera.position)
                zoom_amount := input_state.mouse_wheel * zoom_speed
                
                // Prevent zooming past target (which causes direction flip)
                new_distance := current_distance - zoom_amount
                
                // Clamp the new distance instead of position - increased minimum for editor precision
                new_distance = math.clamp(new_distance, 3.5, 100.0)
                
                // Calculate new position at exact clamped distance
                direction := rl.Vector3Normalize(camera.target - camera.position)
                camera.position = camera.target - direction * new_distance
            }
        }

        // Middle mouse button controls
        if rl.IsMouseButtonDown(.MIDDLE) {
            if rl.IsKeyDown(.LEFT_SHIFT) {
                // Pan - move both camera and target together
                pan_speed := f32(0.01)
                forward := rl.Vector3Normalize(camera.target - camera.position)
                right := rl.Vector3Normalize(rl.Vector3CrossProduct(forward, {0, 1, 0}))
                up := rl.Vector3Normalize(rl.Vector3CrossProduct(right, forward))
                
                pan_movement := right * (-input_state.mouse_delta.x * pan_speed) + up * (input_state.mouse_delta.y * pan_speed)
                
                camera.position += pan_movement
                camera.target += pan_movement
            } else {
                // Orbit - rotate camera around target
                if input_state.mouse_delta.x != 0 || input_state.mouse_delta.y != 0 {
                    // Get current position relative to target
                    offset := camera.position - camera.target
                    
                    // Calculate rotation amounts (invert for natural feel)
                    yaw := -input_state.mouse_delta.x * orbit_speed
                    pitch := -input_state.mouse_delta.y * orbit_speed
                    
                    // Quaternion-based orbit rotation - same approach as flying mode
                    // This ensures mathematical consistency between orbit and flying modes
                    
                    // Calculate right vector from current camera state once to avoid drift
                    forward := rl.Vector3Normalize(-offset)
                    right := rl.Vector3Normalize(rl.Vector3CrossProduct(forward, camera.up))
                    
                    // Step 1: Horizontal rotation around world Y-axis
                    yaw_quat := rl.QuaternionFromAxisAngle({0, 1, 0}, yaw)
                    offset = rl.Vector3RotateByQuaternion(offset, yaw_quat)
                    camera.up = rl.Vector3RotateByQuaternion(camera.up, yaw_quat)
                    // Also rotate the right vector to maintain consistency
                    right = rl.Vector3RotateByQuaternion(right, yaw_quat)
                    
                    // Step 2: Vertical rotation around the rotated right axis
                    pitch_quat := rl.QuaternionFromAxisAngle(right, pitch)
                    offset = rl.Vector3RotateByQuaternion(offset, pitch_quat)
                    camera.up = rl.Vector3RotateByQuaternion(camera.up, pitch_quat)
                    
                    // Update camera position
                    camera.position = camera.target + offset
                }
            }
        }
    }
}