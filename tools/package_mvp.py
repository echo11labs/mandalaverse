"""Build an isolated macOS MVP; never mutate the development project's autoloads."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "game"
STAGE = ROOT / ".tools/mvp-release/game"
ENGINE = ROOT / ".tools/godot/Godot.app/Contents/MacOS/Godot"
TEMPLATE = ROOT / ".tools/godot/templates/macos.zip"
OUT = ROOT / "builds/mvp"

def run(args, name):
    log = OUT / (name + ".log")
    with log.open("w") as output:
        result = subprocess.run([str(ENGINE), "--headless", "--path", str(STAGE), *args], stdout=output, stderr=subprocess.STDOUT, timeout=300)
    text = log.read_text(errors="replace")
    # Preserve the pinned editor's known shutdown diagnostic in the receipt.
    checked = text.replace('ERROR: Condition "!thread.is_started()" is true.\n', "")
    if result.returncode or re.search(r"(?:SCRIPT ERROR:|(?:^|\n)ERROR:)", checked):
        raise RuntimeError("Package stage failed; inspect " + str(log))
    return {"log": str(log.relative_to(ROOT)), "exit_code": result.returncode, "warnings": re.findall(r"^WARNING: (.*)$", text, re.MULTILINE), "known_shutdown_error": 'Condition "!thread.is_started()"' in text}

def main():
    if not TEMPLATE.is_file(): raise SystemExit("Matching macOS export template is missing.")
    OUT.mkdir(parents=True, exist_ok=True)
    STAGE.mkdir(parents=True, exist_ok=True)
    # The stage is exclusively owned by this packaging script.
    for name in ["core", "data", "assets", "scenes", "addons"]:
        target = STAGE / name
        if target.exists(): shutil.rmtree(target)
    ignore = shutil.ignore_patterns(".DS_Store", "__pycache__")
    shutil.copytree(SOURCE / "core", STAGE / "core", ignore=ignore)
    shutil.rmtree(STAGE / "core/tools")
    shutil.copytree(SOURCE / "data", STAGE / "data", ignore=ignore)
    for folder in ["fonts", "materials", "prototype", "terrain", "ui"]:
        shutil.copytree(SOURCE / "assets" / folder, STAGE / "assets" / folder, ignore=ignore)
    for folder in ["kenney_survival", "kenney_workers", "stone_scatter", "trees/PolyHavenFoliage"]:
        shutil.copytree(SOURCE / "assets/models" / folder, STAGE / "assets/models" / folder, ignore=ignore)
    shutil.copy2(SOURCE / "assets/manifest.json", STAGE / "assets/manifest.json")
    for folder in ["landscape", "ui", "world"]:
        shutil.copytree(SOURCE / "scenes" / folder, STAGE / "scenes" / folder, ignore=ignore)
    shutil.copy2(SOURCE / "scenes/mvp.tscn", STAGE / "scenes/mvp.tscn")
    for folder in ["at-icons", "ez-tree-godot-port", "waterways", "proton_scatter"]:
        shutil.copytree(SOURCE / "addons" / folder, STAGE / "addons" / folder, ignore=ignore)
    project = (SOURCE / "project.godot").read_text()
    project = re.sub(r'^(MCPRuntimeServer|Godai|GUIDE)=.*\n', '', project, flags=re.M)
    project = re.sub(r'^enabled=PackedStringArray\(.*\)$', 'enabled=PackedStringArray()', project, flags=re.M)
    project = project.replace('config/features=', 'config/use_custom_user_dir=true\nconfig/custom_user_dir_name="GOPALA-MVP"\nconfig/features=')
    project = project.replace("[rendering]", "[rendering]\n\ntextures/vram_compression/import_etc2_astc=true\ntextures/vram_compression/import_s3tc_bptc=true")
    (STAGE / "project.godot").write_text(project)
    (STAGE / "export_presets.cfg").write_text('''[preset.0]
name="macOS MVP"
platform="macOS"
runnable=true
export_filter="all_resources"
include_filter="*.json,*.f32,*.csv,*.txt,*.md,*.geojson,*.pdf"
exclude_filter="addons/*/plugin.cfg,addons/*/demos/*,addons/*/examples/*"
export_path=""
script_export_mode=0

[preset.0.options]
custom_template/debug="%s"
custom_template/release="%s"
application/bundle_identifier="org.gopala.mvp"
application/short_version="0.1.0"
application/version="0.1.0"
application/copyright="GOPALA prototype; see bundled asset license receipts"
codesign/codesign=1
notarization/notarization=0
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
''' % (TEMPLATE, TEMPLATE))
    receipts = [run(["--editor", "--import"], "import")]
    receipts.append(run(["--export-release", "macOS MVP", str(OUT / "GOPALA-MVP.zip")], "export"))
    package = OUT / "GOPALA-MVP.zip"
    # Notices and the used geographic database are accessible outside the PCK.
    import zipfile
    with zipfile.ZipFile(package, "a", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.write(ROOT / "docs/GOPALA-MVP-Cattle-and-Scenario.md", "README.md")
        for path in (SOURCE / "data/licenses").rglob("*"):
            if path.is_file(): archive.write(path, "Licenses/"+path.relative_to(SOURCE / "data/licenses").as_posix())
        for path in (SOURCE / "data/geography").rglob("*"):
            if path.is_file() and path.suffix in [".json", ".geojson", ".f32"]: archive.write(path, "MapData/"+path.relative_to(SOURCE / "data/geography").as_posix())
        for path in (SOURCE / "assets").rglob("*"):
            if path.is_file() and ("license" in path.name.lower() or path.name.startswith("OFL-") or path.name == "source-receipt.json"):
                archive.write(path, "Licenses/"+path.relative_to(SOURCE).as_posix())
        for folder in ["at-icons", "ez-tree-godot-port", "waterways", "proton_scatter"]:
            for path in (SOURCE / "addons" / folder).glob("*LICENSE*"):
                if path.is_file(): archive.write(path, "Licenses/"+path.relative_to(SOURCE).as_posix())
    report = {"engine": "4.7.2.stable.official.ed1daf0bf", "package": str(package.relative_to(ROOT)), "sha256": hashlib.file_digest(package.open('rb'), 'sha256').hexdigest(), "bytes": package.stat().st_size, "stages": receipts, "scope": "macOS local MVP; ad-hoc signed, not notarized. Manual visual acceptance and target-device performance are separate."}
    (OUT / "build-receipt.json").write_text(json.dumps(report, indent=2) + '\n')
    (ROOT / "reports/mvp-build.json").write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))

if __name__ == "__main__": main()
