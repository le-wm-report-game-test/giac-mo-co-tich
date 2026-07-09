# Headless Godot Patterns (no MCP)

When MCP is unavailable or overkill, headless `SceneTree`-based scripts give you runtime introspection with zero setup.

## Pattern: instant scene dump

```gdscript
# res://src/tests/dump_scene.gd
extends SceneTree

func _initialize() -> void:
    var packed := load("res://src/world/world.tscn") as PackedScene
    if packed == null:
        push_error("Cannot load scene"); quit(1); return
    var inst: Node = packed.instantiate()
    root.add_child(inst)
    await process_frame
    await process_frame
    _dump(inst, 0)
    print("=== END ===")
    quit(0)

func _dump(n: Node, depth: int) -> void:
    print("  ".repeat(depth) + str(n.name) + " (" + n.get_class() + ")")
    for child in n.get_children():
        _dump(child, depth + 1)
```

Run: `godot --headless --path . --script res://src/tests/dump_scene.gd`

## Pattern: read live node property

```gdscript
extends SceneTree

func _initialize() -> void:
    var packed := load("res://src/world/world.tscn") as PackedScene
    root.add_child(packed.instantiate())
    await process_frame

    var light := root.get_node_or_null("/root/World/LightingDirector/ActorReadabilityLight") as DirectionalLight3D
    if light:
        print("light_energy = ", light.light_energy)
        print("light_color = ", light.light_color)

    quit(0)
```

## Pattern: drive a profile/state change and read back

```gdscript
extends SceneTree

func _initialize() -> void:
    var packed := load("res://src/world/world.tscn") as PackedScene
    root.add_child(packed.instantiate())
    await process_frame

    var ld := root.get_node("/root/World/LightingDirector")
    for weather in ["clear", "rain", "storm"]:
        ld.call("set_weather", weather, false)
        await process_frame
        var profile: Resource = ld.get(weather + "_profile")
        var light := ld.get_node("ActorReadabilityLight") as DirectionalLight3D
        print("%s: profile=%.2f runtime=%.2f" % [weather, profile.actor_fill_energy, light.light_energy])

    quit(0)
```

## Pattern: capture viewport screenshot

```gdscript
extends SceneTree

func _initialize() -> void:
    var packed := load("res://src/world/world.tscn") as PackedScene
    var inst: Node3D = packed.instantiate()
    root.add_child(inst)

    # Wait for terrain/lighting to settle
    for i in 30:
        await process_frame

    var img := inst.get_viewport().get_texture().get_image()
    img.save_png("user://screenshot.png")
    print("Saved to user://screenshot.png")
    quit(0)
```

`user://` resolves to:
- Windows: `%APPDATA%\Godot\app_userdata\<project>\`
- Linux: `~/.local/share/godot/app_userdata/<project>/`
- macOS: `~/Library/Application Support/Godot/app_userdata/<project>/`

To capture from headless, must enable a viewport — Forward+ renderer requires `display-driver` or you may need to use `--rendering-driver vulkan` with a fake display. On Windows, console Godot captures the offscreen viewport fine for screenshots.

## Pattern: detect parse errors only

```bash
godot --headless --path . --check-only --script res://src/player/player.gd
```

Returns non-zero exit if script has syntax errors. Fast pre-commit gate.

## Pattern: list loaded resources at runtime

```gdscript
extends SceneTree

func _initialize() -> void:
    var packed := load("res://src/world/world.tscn") as PackedScene
    root.add_child(packed.instantiate())
    await process_frame
    for path in ProjectSettings.get_property_list().map(func(p): return p.name):
        pass  # custom logic
    quit(0)
```

## Tips

- Always call `quit(0)` (or `quit(1)`) — without it, headless keeps running until killed.
- `await process_frame` is needed after `add_child` because `_ready` runs in the next idle frame.
- For longer simulations, use `await get_tree().create_timer(seconds).timeout`.
- Combine `--quit-after N` with `--script` to bound execution:

```bash
godot --headless --path . --quit-after 60 --script res://src/tests/long_sim.gd
```

- Pipe to a temp file if you need to grep the output:

```bash
godot --headless --path . --script res://src/tests/dump.gd > /tmp/dump.txt 2>&1
grep "ERROR" /tmp/dump.txt
```