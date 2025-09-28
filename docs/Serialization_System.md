# Serialization System

## Overview

Handles scene persistence using a human-readable JSON format. The system also manages file I/O through a two-tier file dialog system that prefers native OS dialogs with a text-based fallback.

## Architecture

**Files:**
- `src/serialization/save_load.odin` - Core logic for saving and loading the `Scene` struct to/from JSON.
- `src/serialization/file_dialog.odin` - The text-based fallback file dialog UI and state management.
- `src/serialization/native_file_dialog.odin` - Windows-specific implementation for native file dialogs.

## File Format

The scene is serialized into an intermediate, portable format to avoid saving engine-specific types like `rl.Vector3`.

**Core Data Structures:**
```odin
// Serializable scene format
Scene_File :: struct {
    version: int,
    next_id: int,
    objects: []Object_Data,
}

// Serializable object data
Object_Data :: struct {
    id:               int,
    name:             string,
    object_type:      string,
    transform:        Transform_Data,
    color:            [4]u8,
    mesh_source_file: string `json:"mesh_source_file,omitempty"`,
}

// Serializable transform
Transform_Data :: struct {
    position: [3]f32,
    rotation: [3]f32,
    scale:    [3]f32,
}
```
-   **Versioning:** The `version` field allows for future format changes and migration.
-   **Mesh Handling:** For `MESH` objects, only the `source_file` path is saved. The model data is reloaded from this path when the scene is loaded.

## File Dialog System

The system provides a robust user experience by prioritizing native dialogs.

1.  **Native Dialogs (Windows):** `show_native_..._dialog()` procedures in `native_file_dialog.odin` use the Windows API (`OPENFILENAMEW`) to show standard file pickers. If a file is successfully chosen, the system sets a completion flag and bypasses the text dialog entirely.
2.  **Text Fallback:** If the native dialog is cancelled, fails, or on a non-Windows OS, the system falls back to a simple, immediate-mode text input dialog managed by `file_dialog.odin`.
3.  **State Management:** A global `file_dialog_state` tracks visibility, mode (`SAVE`, `LOAD`, `IMPORT`), and completion. The main editor loop is blocked via `is_file_dialog_visible()` and polls for completion with `check_dialog_completion()`.

## Integration

-   **Editor Loop:** The `editor` calls serialization functions (`save_scene`, `show_load_dialog`, etc.) in response to menu actions or keyboard shortcuts.
-   **Unsaved Changes:** Any operation that modifies the scene (creating, deleting, transforming objects) calls `serialization.mark_unsaved()`. This sets a flag used to display an asterisk (`*`) next to the filename in the menu bar.