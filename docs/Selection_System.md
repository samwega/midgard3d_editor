# Selection System

## Overview

Manages object selection and hover states via mouse-based raycasting. It provides clear visual feedback and is designed to avoid interfering with other interactions like camera movement or gizmo manipulation.

## Architecture

**Files:**
- `src/selection/selection.odin` - Defines the `State` struct and manages selection logic.
- `src/selection/raycast.odin` - Implements the raycasting logic against scene objects.

**Core Data Structure (`selection.State`):**
```odin
State :: struct {
    selected_id:       int,  // ID of currently selected object (-1 if none)
    hovered_id:        int,  // ID of currently hovered object (-1 if none)
    selection_changed: bool, // Flag for UI updates
}
```

## Logic Flow

The selection logic is executed once per frame in `selection.update()`:

1.  **Input Guard:** If the right mouse button is held (camera fly mode), all raycasting and selection logic is skipped. This is a critical optimization and prevents unwanted selections while navigating.
2.  **Hover Detection:** A ray is cast from the current mouse position into the scene using `raycast_from_mouse()`. The ID of the first intersected object is stored in `hovered_id`.
3.  **Selection Update:** If the left mouse button is clicked (`left_clicked == true`), the `selected_id` is set to the current `hovered_id`. This can result in selecting an object (`hovered_id > 0`) or deselecting all (`hovered_id == -1`).
4.  **Change Flag:** The `selection_changed` flag is set to `true` if `selected_id` was modified. The UI system uses this flag to invalidate caches (e.g., the Inspector panel).

## Raycasting Implementation

-   `get_mouse_ray()`: Converts the 2D mouse position into a 3D `rl.Ray` using the current camera.
-   `get_object_bounding_box()`: Calculates an axis-aligned bounding box (AABB) for a given `Scene_Object`, correctly transforming it based on the object's position and scale. For `MESH` types, it uses the pre-calculated bounds from `Mesh_Data`.
-   `raycast_scene()`: Iterates through all objects in the scene, checks for intersection between the mouse ray and each object's AABB using `rl.GetRayCollisionBox`, and returns the ID of the closest hit object.

## Integration

-   The `editor` owns the `selection.State`.
-   `editor.update()` calls `selection.update()` only when scene input is not blocked by the UI and after gizmo interaction has been processed, preventing deselection when clicking a gizmo handle.
-   The `rendering` module queries the selection state (`is_selected`, `is_hovered`) to draw appropriate visual feedback (orange/yellow wireframes).