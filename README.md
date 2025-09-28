I .gitignored assets to save on repo size. This means the demo will not load correctly. You can get two meshes and two HDRI files (for skyboxes) [here.](https://drive.google.com/drive/folders/1dX8dS8vkZ3qm_gY3xDT0OgJHHKJ8JspG?usp=sharing) Just place the two .glb files in assets/models and the .hdri files in the assets/skyboxes and you're good to go.

Demo on YouTube: https://www.youtube.com/watch?v=F87GOLFAjeo&list=PLmm7XJgMX1nG5sUoMprfB7NG4i4ZYhwmy&index=1

# Quick Start Guide

## Running the program:
- if using Sublime, you can launch the "sublime_odin.sublime-workspace" (included)
- from there, the build system should just work (F7)

- if not using Sublime or it has issues, run from the root directory with:
`odin run src/main.odin -file -resource:midgard.rc`

**Other useful flags**
- `-show-timings` and `-debug`
- `-o:speed` compiles an optimized version, takes a few more seconds, should run faster 
- `-define:PLUGIN_OBJ_IMPORT=false` this will compile the editor without the obj import plugin. You can use this to include/exclude other plugins in the future.
*Flags -vet and -strict-style will not work at this time, need to clean up the code a bit first.*
So I'd just use `odin run src/main.odin -file -resource:midgard.rc -show-timings -debug -o:speed` or omit the -o:speed for quick load.

## Once it launches:
- Press `m` key to view comprehensive hotkeys map
- Press ctrl+o to open (import) a demo scene I made for a quick start, navigate to: "midgard3d_editor_odin_raylib\assets\scenes\demo_scene.json"
- Most options should be discoverable in File dropdown menu / hotkey map / inspector

# Notes
Currently works with the Raylib included in Odin vendor which is compiled for OpenGL 2.0, however it should be easy to compile Raylib with OpenGL 3.3 flags to get much better 3D support - in particular, the legacy version only supports 16 bit meshes, trying to upload complex meshes now will not work properly. I'm thinking of doing that and including the other Raylib version in this repo.

# Features
- Can load .hdr, .png, even .jpg as skyboxes
- Fully serialized, saves scenes in a .json, loads them, all settings should be serialized already
- Mostly feature complete blender style gizmos implementation - multiple gizmos: Translate, Rotate, Scale,Transform + an interactive global gizmo (trigger top, bottom, side views).
- Plugin system for adding modular features
- .glb/.gltf models load fine up to 65k tris (i.e. 16 bit). The .obj load plugin is just a demo of how the plugin system works, but it's half broken. You can load .obj meshes but materials/textures are broken.
- Keyboard driven inspector (arrow and modifier keys), all object properties can be set precisely, as opposed to mouse less precise edits. Typing the numbers directly not yet implemented.
- Can draw basic shapes without having to import models, for quick sketches.