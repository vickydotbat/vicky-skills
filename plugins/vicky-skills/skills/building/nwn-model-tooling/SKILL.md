---
name: nwn-model-tooling
description: Neverwinter Nights model work with Blender and the command line. Use when handling any NWN:EE `.mdl` import, export, decompile or repair, NWN2 `.mdb` files, Neverblender, `cleanmodels`, packing HAK or ERF files, or headless Blender scripts.
---

# NWN model tooling

> _These aren't the Blenders you're looking for: only the one with Neverblender opens an `.mdl`._

The plugin settings under `/plugin` name the tools. A blank setting means the tool is not set up: say so and stop before work that needs it.

| Tool | Setting | Use |
| --- | --- | --- |
| `${user_config.nwn_blender}` | `nwn_blender` | Blender with the Neverblender add-on. Every `.mdl` import and export. Any other Blender lacks the add-on: keep it away from model work. |
| `${user_config.nwn2_blender}` | `nwn2_blender` | Blender with the `nwn2mdk` add-on, for NWN2 `.mdb` files. Its converters (`nw2fbx.exe`, `fbx2nw.exe`) are Windows programs and need `wine`. |
| `cleanmodels` | on `PATH` | Check, repair, compile and decompile `.mdl` files. |
| `nwn_erf` and the other `nwn_*` tools from neverwinter.nim | on `PATH` | Pack and unpack HAK and ERF files, read 2da, TLK and GFF files. |

Render, inspect, import and edit `.mdl` files with these tools only: headless Blender with Neverblender, and `cleanmodels` for check and repair. Never write your own renderer, parser or mesh editor.

Stock game resources, unpacked one folder per BIF, are in `${user_config.nwn_refs}`. Read that folder's `AGENTS.md` first when it has one. Copy a stock file into your scratch folder before you edit it.

## cleanmodels

- `cleanmodels decompile -r <in dir> <out dir>` turns binary `.mdl` files into ASCII and applies no fixes. `compile` and `repair` take the same form, output last.
- `cleanmodels check <input>...` reports and writes nothing. With `--fix`, its last argument is the output.
- Output is flat: subfolders are not mirrored.
- With one input file, name an output file. An output folder fails.
- A decompile and compile round trip is not lossless. It rewelds or drops vertices on meshes (18 to 14 on a body node, 164 to 70 on a hidden head) and nudges key floats. A Neverblender re-export splits every shared vertex per face, so the mesh shades in facets (a dog's skin went from 879 vertices to 3,726).
  - To change one number (a node position, a key), patch that float in place in the original binary and leave the rest of its bytes alone. Then decompile the result and diff it against the original's decompile: one changed line is the proof.
  - When a mesh edit needs a compile, decompile your output and diff each node against the original's decompile, beside a control: the original compiled unchanged. A vertex or face count the edit did not mean to change is a defect. Fix it before anyone looks at the model in game.
  Proven by: plugins/vicky-skills/evals/nwn-model-tooling/roundtrip-audit

## Packing

`nwn_erf -c -f <out>.hak <files or folders>...` packs a HAK. The extension picks the archive type. `-x -f <in>.hak` unpacks into the current folder, and `-t -f <in>.hak` lists it.

## Headless Blender

```sh
${user_config.nwn_blender} --background --python <scratch folder>/<script>.py
```

Prefer this to a Blender MCP server. Use one only when `claude mcp list` shows it registered and the user has Blender open with its add-on running.

Charter: C3 ([CHARTER.md](../../CHARTER.md)).
