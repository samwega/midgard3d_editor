# Running the program:
- if using Sublime, you can launch the "sublime_odin.sublime-workspace"
- from there, the build system should just work (F7)

- if not using sublime or it has issues, run from the root directory with:
`odin run src/main.odin -file -resource:midgard.rc`
- additional good flags: -show-timings -debug -o:speed -define:PLUGIN_OBJ_IMPORT=false
- flags -vet and -strict-style will not work

# Once it launches:
- Press `m` key to view comprehensive hotkeys map
- Press ctrl+o to open (import) a demo scene I made for a quick start, navigate to: "midgard3d_editor_odin_raylib\assets\scenes\demo_scene.json"
- I added a couple of meshes and a couple of skyboxes just so the demo works out of the box, that's most of the 100MB.