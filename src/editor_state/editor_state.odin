package editor_state

import "../scene"
import "../camera"
import "../input"
import "../selection"
import "../resources"
import "../ui"
import "../gizmo"

// Editor state definition (separated to avoid circular dependencies)
State :: struct {
    camera_state: camera.State,
    input_state: input.State,
    selection_state: selection.State,
    ui_state: ui.UI_State,
    scene: scene.Scene,
    gizmo_state: gizmo.Gizmo_State,
    viewport_gizmo_state: gizmo.Viewport_Gizmo_State,
    environment: resources.Environment_State,
}