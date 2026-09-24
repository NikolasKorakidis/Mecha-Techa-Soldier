# Local setup

## Engine
Godot **4.7.2 stable** (standard build, not .NET). Download: https://godotengine.org/download/archive/4.7.2-stable/

Set `GODOT` to the binary for your machine, then run the commands below from the repo root.

| Machine | `GODOT` |
|---|---|
| macOS (dev, MacBook Air) | `/Applications/Godot.app/Contents/MacOS/Godot` |
| Windows (target) | `C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe` (use the `_console` exe so output is visible) |
| Linux / CI / Claude Code cloud | path to `Godot_v4.7.2-stable_linux.x86_64` |

macOS / Linux:
```bash
export GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
```
Windows PowerShell:
```powershell
$env:GODOT = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
```
Adjust the path if you installed Godot elsewhere, and update this table.

## Commands
| Purpose | Command |
|---|---|
| Open in editor | `$GODOT --editor --path .` |
| Play from Main | `$GODOT --path .` |
| Import check (first run + after adding assets) | `$GODOT --headless --path . --import` |
| All tests | `$GODOT --headless --path . --script res://tests/run_tests.gd` |
| Tests matching a file name | `$GODOT --headless --path . --script res://tests/run_tests.gd -- test_health` |
| Boot check (runs Main for 180 frames) | `$GODOT --headless --path . --quit-after 180` |
| Regenerate default input map | `$GODOT --headless --path . --script res://tools/generate_input_map.gd` |

Run the import check once after cloning (it builds the `.godot/` cache the tests need).

A check passes when the exit code is 0 **and** the output contains no `SCRIPT ERROR`, `Parse Error`
or `ERROR:` lines. One-liner for macOS/Linux:
```bash
$GODOT --headless --path . --import >/dev/null 2>&1 && \
$GODOT --headless --path . --script res://tests/run_tests.gd && \
$GODOT --headless --path . --quit-after 180 2>&1 | tee /tmp/boot.log && ! grep -E "SCRIPT ERROR|Parse Error|ERROR:" /tmp/boot.log
```

## Dev keys
| Key | Action |
|---|---|
| F2 | Next developer room |
| F3 | Toggle debug telemetry panel |
| Esc / Start | Pause |

## Web build (GitHub Pages)
`.github/workflows/deploy-web.yml` imports, tests, boot-checks, exports the `Web` preset and deploys
to https://nikolaskorakidis.github.io/Mecha-Techa-Soldier/ on every push to `main` or the working branch.
- Single-threaded export (`variant/thread_support=false`), so no COOP/COEP headers are needed.
- Web uses the Compatibility renderer (`rendering_method.web`); desktop keeps Forward+.
- Local export (needs the 4.7.2 web templates installed):
  `$GODOT --headless --path . --export-release "Web" build/web/index.html`, then serve it with
  `python3 -m http.server 8000 -d build/web` and open http://localhost:8000.
- One-time repo setting: Settings → Pages → Build and deployment → Source: **GitHub Actions**.
