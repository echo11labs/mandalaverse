"""Repeatable Godot gate: import, parse authored scripts, test, run the main scene."""
import json
from pathlib import Path
import re
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / ".tools/godot/Godot.app/Contents/MacOS/Godot"
REPORTS = ROOT / "reports/local"
ERROR = re.compile(r"(?:SCRIPT ERROR:|(?:^|\n)ERROR:)")


def run_stage(name, arguments, timeout=60, external=False):
    log = REPORTS / f"{name}.log"
    started = time.monotonic()
    command = list(arguments) if external else [str(ENGINE), "--headless", "--path", str(ROOT / "game"), "--log-file", str(REPORTS / f"{name}-engine.log"), *arguments]
    with log.open("w") as output:
        process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        timed_out = False
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            import os
            os.killpg(process.pid, signal.SIGKILL)
            code = process.wait()
    text = log.read_text(errors="replace")
    # Godot 4.7 editor import calls language-server stop even when that thread never started.
    known_import_error = 'ERROR: Condition "!thread.is_started()" is true.\n'
    ignored_errors = text.count(known_import_error)
    text = text.replace(known_import_error, "")
    result = {"stage": name, "ok": code == 0 and not timed_out and not ERROR.search(text), "exit_code": code, "timed_out": timed_out, "seconds": round(time.monotonic() - started, 2), "log": str(log.relative_to(ROOT))}
    result["warnings"] = re.findall(r"^WARNING: (.*)$", text, re.MULTILINE)
    if ignored_errors:
        result["known_engine_errors"] = {"language_server_stop_without_started_thread": ignored_errors}
    marker = "GOPALA_TEST_REPORT="
    for line in text.splitlines():
        if line.startswith(marker):
            result["tests"] = json.loads(line[len(marker):])
            result["ok"] = result["ok"] and result["tests"]["ok"]
    if name in ["content-tests", "landscape-tests", "scenic-tests", "kathmandu-tests", "coordinate-tests", "waterways-tests", "forest-tests", "entity-registry-tests", "selection-tests", "spatial-grid-tests", "simulation-spine-tests", "ui-tests", "component-gallery-tests", "gather-delivery-tests"] and "tests" not in result:
        result["ok"] = False
    print(f"{name}: {'PASS' if result['ok'] else 'FAIL'}", flush=True)
    return result


def main():
    if not ENGINE.is_file():
        raise SystemExit("Pinned Godot missing.")
    REPORTS.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([str(ENGINE), "--version"], text=True).strip()
    if not version.startswith("4.7.2.stable"):
        raise SystemExit("Unexpected engine version: " + version)
    stages = [run_stage("import", ["--editor", "--import"])]
    if stages[-1]["ok"]:
        scripts = list((ROOT / "game/core").rglob("*.gd")) + list((ROOT / "game/scenes").rglob("*.gd")) + list((ROOT / "game/tests").rglob("*.gd")) + list((ROOT / "game/addons/gopala_mcp").rglob("*.gd")) + [path for path in (ROOT / "game/assets/ui").rglob("*.gd") if "generate_" not in path.name]
        for path in sorted(scripts):
            relative = path.relative_to(ROOT / "game").as_posix()
            stages.append(run_stage("parse-" + path.stem, ["--check-only", "--script", relative]))
        stages.append(run_stage("content-tests", ["--script", "tests/run_content_tests.gd"]))
        if (ROOT / "game/scenes/ui/hud.tscn").exists():
            stages.append(run_stage("ui-tests", ["--script", "tests/run_ui_tests.gd"]))
        if (ROOT / "game/scenes/ui/component_gallery.tscn").exists():
            stages.append(run_stage("component-gallery-tests", ["--script", "tests/run_component_gallery_tests.gd"]))
        if (ROOT / "game/tests/run_simulation_spine_tests.gd").exists():
            stages.append(run_stage("simulation-spine-tests", ["--script", "tests/run_simulation_spine_tests.gd"]))
        if (ROOT / "game/tests/run_entity_registry_tests.gd").exists():
            stages.append(run_stage("entity-registry-tests", ["--script", "tests/run_entity_registry_tests.gd"]))
        if (ROOT / "game/tests/run_selection_tests.gd").exists():
            stages.append(run_stage("selection-tests", ["--script", "tests/run_selection_tests.gd"]))
        if (ROOT / "game/tests/run_spatial_grid_tests.gd").exists():
            stages.append(run_stage("spatial-grid-tests", ["--script", "tests/run_spatial_grid_tests.gd"]))
        if (ROOT / "game/tests/run_placement_slice_tests.gd").exists():
            stages.append(run_stage("placement-slice-tests", ["--script", "tests/run_placement_slice_tests.gd"]))
        if (ROOT / "game/tests/run_villager_movement_tests.gd").exists():
            stages.append(run_stage("villager-movement-tests", ["--script", "tests/run_villager_movement_tests.gd"]))
        if (ROOT / "game/tests/run_gather_delivery_tests.gd").exists():
            stages.append(run_stage("gather-delivery-tests", ["--script", "tests/run_gather_delivery_tests.gd"]))
        if (ROOT / "game/scenes/world/valley.tscn").exists():
            stages.append(run_stage("landscape-tests", ["--script", "tests/run_landscape_tests.gd"]))
        if (ROOT / "game/scenes/landscape/scenic_valley.tscn").exists():
            stages.append(run_stage("scenic-tests", ["--script", "tests/run_scenic_tests.gd"]))
        if (ROOT / "game/scenes/landscape/kathmandu_valley.tscn").exists():
            stages.append(run_stage("kathmandu-tests", ["--script", "tests/run_kathmandu_tests.gd"]))
            stages.append(run_stage("waterways-tests", ["--script", "tests/run_waterways_tests.gd"]))
            # MultiMesh transform storage is unavailable through Godot's dummy renderer.
            stages.append(run_stage("forest-tests", [str(ENGINE), "--path", str(ROOT / "game"), "--script", "tests/run_forest_tests.gd"], external=True))
        if (ROOT / "game/data/geography/kathmandu.json").exists():
            stages.append(run_stage("coordinate-tests", [str(ROOT / ".tools/python/bin/python"), str(ROOT / "tools/test_geography.py")], external=True))
        stages.append(run_stage("main-scene", ["--quit-after", "5"]))
    report = {"ok": all(stage["ok"] for stage in stages), "engine": version, "stages": stages, "scope": "Development import, authored scripts, content invariants and headless scene execution. No export, simulation, GPU performance or final art claim."}
    (ROOT / "reports/verification.json").write_text(json.dumps(report, indent=2) + "\n")
    raise SystemExit(0 if report["ok"] else 1)


if __name__ == "__main__":
    main()
