# Rendering System

## Overview

The rendering system is responsible for drawing everything visible on screen, from the 3D scene to the 2D UI overlays. It uses a multi-pass pipeline to ensure correct layering and depth, guaranteeing that UI elements like gizmos are never obscured by 3D objects.

## Architecture

**Files:**
- `src/rendering/renderer.odin` - The main orchestrator containing the `render` procedure.
- `src/rendering/grid.odin` - Logic for drawing the adaptive 3D grid and coordinate axes.
- `src/rendering/objects.odin` - Logic for rendering all `Scene_Object`s.
- `src/rendering/ui.odin` - The top-level procedure for drawing the entire 2D UI.

## Render Pipeline

The `rendering.render` procedure executes the following steps in a strict order each frame:

1.  **`rl.BeginDrawing()`**: Starts the frame buffer.
2.  **`rl.ClearBackground()`**: Clears the screen to the sky color.
3.  **3D Pass (`rl.BeginMode3D`):**
    a.  `draw_adaptive_grid()`: Renders the 2-level circular ground grid.
    b.  `draw_infinite_axes()`: Renders the world coordinate axes (X, Y, Z).
    c.  `render_scene()`: Renders all objects in the scene. This involves:
        i.  Separating objects into opaque and transparent lists.
        ii. Rendering all opaque objects.
        iii. Sorting transparent objects from back-to-front based on camera distance.
        iv. Rendering the sorted transparent objects with alpha blending.
    d.  `rl.DrawPlane()`: Renders the semi-transparent ground plane.
4.  **`rl.EndMode3D()`**: Ends the 3D rendering pass.
5.  **Gizmo Overlay Pass:**
    a.  `gizmo.draw()`: The main transformation gizmo is drawn in 2D screen-space *after* the 3D scene is complete. This ensures it is always visible and correctly layered on top of all 3D objects.
    b.  `gizmo.draw_viewport_gizmo()`: The viewport navigation gizmo in the corner is drawn.
6.  **UI Pass:**
    a.  `render_ui()`: A single call that orchestrates the drawing of all 2D UI panels, including the menu bar, hierarchy, inspector, keymap, and plugin panels.
7.  **`rl.EndDrawing()`**: Flips the back buffer to the screen.

## Key Components

-   **`render_scene`:** The core of 3D object rendering. Its opaque/transparent sorting pass is critical for correct alpha blending, especially for selected objects which are rendered semi-transparently.
-   **`draw_adaptive_grid`:** Provides crucial spatial awareness for the user. The grid is circular and fades with distance to reduce visual noise.
-   **Gizmo Rendering:** The decision to render the gizmo as a 2D overlay is a key architectural choice that solves many common layering and depth-fighting issues found in other editors.