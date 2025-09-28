# Inspector System

## Overview

Real-time property editor for 3D objects. Immediate-mode GUI with drag-through input handling.

## Architecture

### Core Components

**`src/ui/ui_state.odin`** - UI state management
```odin
UI_State :: struct {
    inspector: Inspector_State,
    mouse_over_ui: bool,
    active_widget: Widget_ID,
    hot_widget: Widget_ID,
    drag_started_in_world: bool,
    widget_navigation_requested: Navigation_Direction,
}
```

**`src/ui/widgets.odin`** - Widget library
```odin
float_input() -> Widget_Result
vector3_input() -> Widget_Result
draw_section_header()
```

**`src/ui/inspector.odin`** - Inspector panel logic
```odin
draw_inspector() -> bool
draw_object_inspector() -> bool
handle_inspector_input()
```

### Input System

**Smart Blocking Logic**:
- `should_block_scene_input()` - Allows camera drag-through when started in world
- RMB/MMB drags work through UI when originated outside inspector
- Left clicks blocked by UI for proper selection

**Widget Navigation**:
- Sequential widget IDs (1-9): Position X/Y/Z → Rotation X/Y/Z → Scale X/Y/Z
- Arrow keys: ↑/↓ adjust values, ←/→ navigate fields
- Precision modifiers: Shift (0.01), Ctrl (1.0), Normal (0.1)

### Integration Points

**Editor Loop** (`src/editor/editor.odin`):
```odin
ui.begin_ui(&editor_state.ui_state)
ui.handle_inspector_input(&editor_state.ui_state)
if !ui.should_block_scene_input(&editor_state.ui_state) {
    // Camera and selection updates
}
ui.end_ui(&editor_state.ui_state)
```

**Rendering** (`src/rendering/ui.odin`):
```odin
ui.draw_inspector(&editor_state.ui_state, &editor_state.selection_state, &editor_state.scene)
```

**Selection Integration**:
- `selection.has_selection_changed()` triggers inspector cache reset
- `selection.get_selected_object()` provides object data

## Transform System

Matrix transformations using rlgl:
```odin
rlgl.PushMatrix()
rlgl.Translatef(pos.x, pos.y, pos.z)
rlgl.Rotatef(rotation.z, 0, 0, 1)  // Z-Y-X rotation order
rlgl.Rotatef(rotation.y, 0, 1, 0)
rlgl.Rotatef(rotation.x, 1, 0, 0)
rlgl.Scalef(scale.x, scale.y, scale.z)
rlgl.PopMatrix()
```

## Controls

| Key | Action |
|-----|--------|
| `I` | Toggle inspector |
| `Left Click` | Select object |
| `↑/↓` | Adjust value |
| `→/←` | Navigate fields |
| `Shift + ↑/↓` | Fine adjust (0.01) |
| `Ctrl + ↑/↓` | Coarse adjust (1.0) |
| `Escape` | Deactivate field |

## Data Flow

1. Object selection → Selection system updates
2. Inspector renders → Reads cached object properties  
3. Value modification → Direct object transform update
4. Frame reset → Widget IDs regenerated, navigation state preserved

## Performance

- **IMGUI Design**: Widgets recreated each frame (~200 bytes state)
- **Selection Caching**: Properties cached until selection changes
- **Input Blocking**: 3D processing disabled over UI
- **Change Detection**: Updates only on actual modifications