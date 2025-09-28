# Gizmo System Documentation

## Overview

The Midgard 3D Editor gizmo system provides interactive 3D manipulation tools for transforming objects in 3D space. The system supports three primary transformation modes: translation, rotation, and scale, with visual feedback and precise control mechanisms. The system uses a screen-space overlay approach with distance compensation to ensure consistent interaction regardless of camera position.

## Architecture

### Core Components

**Files:**
- `src/gizmo/gizmo_state.odin` - Core state management and type definitions
- `src/gizmo/gizmo_interaction.odin` - Main coordination and update logic
- `src/gizmo/gizmo_math.odin` - Mathematical helper functions for transformations
- `src/gizmo/gizmo_collision.odin` - Handle collision detection and selection
- `src/gizmo/gizmo_drag.odin` - Drag handling and transformation calculations
- `src/gizmo/gizmo_render.odin` - Visual rendering of gizmo handles

**Key Types:**
- `Gizmo_State` - Central state container for all gizmo data
- `Gizmo_Mode` - Transformation mode enumeration (NONE, TRANSLATE, ROTATE, SCALE, TRANSFORM)
- `Handle_Type` - Specific handle identification for collision detection
- `Axis_Mask` - Constraint system for limiting transformations to specific axes

### State Management

```odin
Gizmo_State :: struct {
    // Core state
    mode: Gizmo_Mode,
    visible: bool,
    is_dragging: bool,
    
    // Visual properties
    center_2d: rl.Vector2,        // Screen-space gizmo center
    axes_2d: [3]rl.Vector2,       // Screen-space axis directions  
    base_size: f32,               // Distance-compensated size
    
    // Interaction state
    hovered_handle: Handle_Type,
    drag_handle: Handle_Type,
    drag_start_mouse: rl.Vector2,
    
    // Transform caching
    initial_rotation: rl.Vector3,
    initial_transform: rl.Vector3,
    initial_scale: rl.Vector3,
    
    // Constraint system
    active_axes: Axis_Mask,
    snap_enabled: bool,
}
```

**`src/gizmo/gizmo_render.odin`** - Visualization and rendering
```odin
draw() -> void                      // Main drawing function
update_screen_state() -> void       // Update screen-space coordinates
draw_axis_arrow_2d() -> void        // Draw single axis handle
draw_plane_handle_2d() -> void      // Draw plane handle
```

**`src/gizmo/gizmo_interaction.odin`** - Main coordination and update logic
```odin
update() -> (transform_changed: bool, consumed_input: bool)  // Main interaction update
start_drag_enhanced() -> void                                // Initialize drag operation
```

**`src/gizmo/gizmo_collision.odin`** - Handle collision detection and selection
```odin
check_handle_collision_enhanced() -> Handle_Type             // Main collision detection entry point
check_rotation_collision() -> Handle_Type                    // Rotation handle collision
check_scale_collision() -> Handle_Type                       // Scale handle collision
check_translation_collision() -> Handle_Type                 // Translation handle collision
```

**`src/gizmo/gizmo_drag.odin`** - Drag handling and transformation calculations
```odin
handle_drag() -> bool                                        // Main drag processing
handle_translation_drag() -> bool                           // Translation drag logic
handle_rotation_drag() -> bool                              // Rotation drag logic
handle_scale_drag() -> bool                                 // Scale drag logic
```

**`src/gizmo/gizmo_math.odin`** - Mathematical helper functions
```odin
calculate_ring_angle() -> f32                               // Calculate radial angle for rotation
apply_world_rotation() -> rl.Vector3                       // Apply world-space rotation
matrix_to_euler_degrees() -> rl.Vector3                    // Convert rotation matrix to Euler
project_ray_on_line() -> f32                               // Ray-line projection for constraints
snap_to_grid() -> rl.Vector3                               // Grid snapping functions
```

## Transformation Modes

### Translation Mode (.TRANSLATE)

**Visual Design:**
- Red, green, blue arrows for X, Y, Z axes respectively
- Colored plane squares for bi-axial movement (XY, XZ, YZ planes)
- Arrows extend from object center along world coordinate axes

**Interaction:**
- Single-axis: Click and drag along axis arrows for constrained movement
- Bi-axial: Click and drag plane squares for movement within two axes
- 3D ray-casting projects mouse movement onto constraint surfaces

### Rotation Mode (.ROTATE)  

**Visual Design:**
- Sphere-based visualization with colored circles for each axis
- Red circle (YZ plane) for X-axis rotation around world X
- Green circle (XZ plane) for Y-axis rotation around world Y  
- Blue circle (XY plane) for Z-axis rotation around world Z
- White outer circle for view-relative rotation
- Circles render as front-facing halves to reduce visual clutter

**Interaction - Radial Trackball Motion:**

All rotation handles use proper radial circular mouse movement:

```odin
// X rotation: radial motion around YZ plane circle
y_dir := state.axes_2d[1]  // Screen Y direction
z_dir := state.axes_2d[2]  // Screen Z direction

initial_y_proj := rl.Vector2DotProduct(initial_offset, y_dir)
initial_z_proj := rl.Vector2DotProduct(initial_offset, z_dir)
initial_angle := math.atan2(initial_z_proj, initial_y_proj)

current_y_proj := rl.Vector2DotProduct(current_offset, y_dir)  
current_z_proj := rl.Vector2DotProduct(current_offset, z_dir)
current_angle := math.atan2(current_z_proj, current_y_proj)

delta_rotation := (current_angle - initial_angle) * 180.0 / math.PI
```

**Critical Design Decisions:**

1. **World-Space Only:** All rotations occur around world coordinate axes, never local/object-relative axes
2. **Pure Quaternion Mathematics:** **MANDATORY** - Uses quaternions for ALL rotation operations to completely eliminate floating-point precision errors, gimbal lock, and rotation limits
3. **Radial Motion Only:** All circles use circular/radial mouse movement, never linear horizontal/vertical movement
4. **Plane Projection:** Each axis projects mouse movement onto its corresponding coordinate plane using screen-space axis directions
5. **Single Conversion Point:** Euler-to-quaternion conversion happens only once at drag start, quaternion-to-Euler only once at final output

**Quaternion Implementation Requirements:**
- **All rotation gizmos use `rl.QuaternionFromAxisAngle()` for world-space rotations**
- **Object transformations combine using quaternion multiplication: `new_quat = rotation_quat * initial_quat`**
- **NEVER use matrix rotations (`rl.MatrixRotate`) or Euler angle calculations in rotation pipeline**
- **Conversion to/from Euler angles happens ONLY at object interface boundaries**

### Scale Mode (.SCALE)

**Visual Design:**
- Colored cubes at the ends of each axis for single-axis scaling
- Central yellow cube for uniform scaling
- Size proportional to camera distance

**Interaction:**
- Single-axis: Drag axis cubes for scaling along that dimension
- Uniform: Drag center cube for proportional scaling in all dimensions
- Scale factor calculated from mouse movement distance

### Transform Mode (.TRANSFORM)

**Visual Design:**
- A combination of all other gizmos.
- Translation: Arrow tips (cones) for axis movement and planar squares.
- Rotation: Colored rings for world-space rotation.
- Scale: Cubes at the end of each axis for scaling.

**Interaction:**
- The handle that is hovered determines the operation.
- Dragging an arrow tip or plane translates the object.
- Dragging a ring rotates the object.
- Dragging a cube scales the object.

## Constraint System

### Axis Masks

```odin
Axis_Mask :: bit_set[Axis; u8]
Axis :: enum u8 { X, Y, Z }
```

**Usage:**
- `active_axes: Axis_Mask` - Controls which axes are available for interaction
- Dynamic constraint toggling via keyboard shortcuts (X, Y, Z keys)
- Plane constraints (Shift+X for YZ plane, etc.)

### Grid Snapping

```odin
snap_enabled: bool
snap_increment: f32           // Translation snap distance
rotation_snap_increment: f32  // Rotation snap angle (degrees)
```

**Implementation:**
- Translation snapping rounds positions to grid increments
- Rotation snapping rounds angles to degree increments
- Toggle via G key during interaction

## Rendering System

### Distance Compensation

```odin
calculate_world_radius_for_screen_size :: proc(world_pos: rl.Vector3, camera: rl.Camera3D, 
                                              screen_size: f32) -> f32
```

Maintains consistent screen-space gizmo size regardless of camera distance:
- Projects world position to screen space
- Calculates appropriate 3D size to achieve target pixel size
- Updates `base_size` for consistent visual scaling

### Screen-Space Projection

```odin
update_screen_projection :: proc(state: ^Gizmo_State, object_pos: rl.Vector3, camera: rl.Camera3D)
```

Converts 3D gizmo geometry to 2D screen coordinates:
- `center_2d` - Object center in screen coordinates  
- `axes_2d[3]` - World axis directions projected to screen space
- Used for collision detection and mouse interaction

### Collision Detection

**Hierarchical Priority System:**
1. Axes (highest priority) - Direct line collision with tolerance
2. Planes (medium priority) - Quad intersection tests
3. Rings/circles (rotation mode) - Elliptical ring distance calculation

**Elliptical Ring Collision:**
```odin
calculate_distance_to_ellipse_ring :: proc(state: ^Gizmo_State, mouse_pos: rl.Vector2, 
                                          radius: f32, axis1_idx: int, axis2_idx: int) -> f32
```

- Samples points around projected circle/ellipse
- Finds closest point to mouse cursor
- Accounts for perspective foreshortening of circles

## Integration Points

### Editor Coordination

```odin
// In editor update loop:
gizmo_transform_changed := gizmo.update(&editor_state.gizmo_state, 
                                       selected_object, 
                                       mouse_pos, camera,
                                       mouse_clicked, mouse_released)

if gizmo_transform_changed {
    // Mark scene as modified for save system
    editor_state.scene_modified = true
}
```

### Input System Integration

**Keyboard Shortcuts:**
- `Q` - Set mode to NONE (disable gizmos) - Only when RMB not held
- `W` - Set mode to TRANSLATE - Only when RMB not held  
- `R` - Set mode to ROTATE - Only when RMB not held
- `E` - Set mode to SCALE - Only when RMB not held
- `T` - Set mode to TRANSFORM - Only when RMB not held

**Constraint Keys (during interaction):**
- `X` - Constrain to X-axis (Ctrl+X to toggle, Shift+X for YZ plane)
- `Y` - Constrain to Y-axis (Ctrl+Y to toggle, Shift+Y for XZ plane)
- `Z` - Constrain to Z-axis (Ctrl+Z to toggle, Shift+Z for XY plane)
- `G` - Toggle grid snapping

### Camera Integration

The gizmo system is camera-aware and handles:
- Screen-space projections that update with camera movement
- Distance-based size compensation
- Perspective-corrected collision detection
- View-relative rotation mode for intuitive camera-space manipulation

## Performance Considerations

### Optimization Strategies

1. **Screen Projection Caching:** `axes_2d` and `center_2d` updated only when camera or object moves
2. **Hierarchical Collision:** Early exit when no handles are near cursor
3. **Selective Rendering:** Only draw active mode handles
4. **Distance LOD:** Gizmo size scales with distance, maintaining visual consistency

### Memory Layout

- Compact state structure minimizes cache misses
- No dynamic allocations during interaction
- Static collision tolerance values avoid recalculation

## Error Handling

### CRITICAL: The Great Rotation Bug (16-Hour Solution)

**THE PROBLEM:** Any matrix-to-Euler conversion in rotation gizmos causes catastrophic bugs:
- **Values jump randomly** even with zero mouse movement (just clicking causes jumps)
- **All X/Y/Z values change** when rotating any single axis (impossible to control one axis at a time)
- **Multiple valid Euler representations** for same rotation cause floating-point precision errors
- **Gimbal lock** creates mathematical singularities

**FAILED APPROACHES THAT NEVER WORK:**
- ❌ Direct Euler manipulation (works but rotates around local axes instead of world axes)
- ❌ Matrix-based `apply_world_rotation()` (causes jumping due to matrix-to-Euler conversion)
- ❌ Any approach involving `matrix_to_euler_degrees()` function
- ❌ Mixing quaternions with Euler at multiple points in the pipeline

**THE ONLY SOLUTION - Quaternions:**

```odin
// ✅ CORRECT: Pure quaternion approach
case .X_ROTATION:
    delta_rotation := (current_angle - initial_angle)  // Keep in radians
    
    // Create rotation quaternion around world X-axis
    rotation_quat := rl.QuaternionFromAxisAngle({1, 0, 0}, delta_rotation)
    
    // Apply rotation: new_quat = rotation_quat * initial_quat (modern Odin syntax)
    new_quaternion := rotation_quat * state.initial_quaternion
    
    // Convert back to Euler ONLY at final interface point
    object.transform.rotation = rl.QuaternionToEuler(new_quaternion) * 180.0 / math.PI
```

**KEY PRINCIPLES:**
1. **Single conversion points**: Euler-to-quaternion ONCE at drag start, quaternion-to-Euler ONCE at output
2. **Pure quaternion math**: All rotations use `QuaternionFromAxisAngle()` and quaternion multiplication
3. **World-space axes**: `{1,0,0}`, `{0,1,0}`, `{0,0,1}` for X, Y, Z rotations
4. **No matrix operations**: Never use matrices for rotation calculations

**NEVER FORGET:** This bug consumed 16 hours across multiple sessions. The solution is quaternions, period.

## Future Extensions

### Planned Enhancements

1. **Multi-object gizmos:** Average position/rotation for group manipulation
2. **Custom coordinate spaces:** Local/view/custom axis systems  
3. **Proportional editing:** Affect nearby objects with falloff
4. **Precision input:** Numeric entry during drag operations
5. **Gizmo customization:** User-configurable colors, sizes, sensitivity

### API Stability

The current gizmo system API is designed for stability:
- Core `update()` function signature will remain unchanged
- `Gizmo_State` structure may gain fields but won't remove existing ones
- Mode enumeration is extensible without breaking existing code

---

*This documentation reflects the gizmo system as implemented in Midgard 3D Editor. For implementation details, refer to the source files in `src/gizmo/`.*