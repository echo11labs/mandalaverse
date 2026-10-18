"""Repack selected CC0 KayKit archive models without changing geometry/materials."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "Resources/KayKit_Forest_Nature_Pack_1.0_FREE.zip"
OUT = ROOT / "game/assets/models/nature/kaykit"
PREFIX = PurePosixPath("KayKit_Forest_Nature_Pack_1.0_FREE")
SELECTED = ["Bush_3_A", "Bush_4_A", "Grass_2_A", "Grass_2_B", "Rock_1_B", "Rock_3_B"]

def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    source_hashes = {}
    files = {}
    with zipfile.ZipFile(ARCHIVE) as archive:
        license_data = archive.read(str(PREFIX / "License.txt"))
        if license_data != (OUT / "LICENSE.txt").read_bytes():
            raise ValueError("Source license differs from the admitted CC0 package")
        for name in SELECTED:
            path = PREFIX / "Assets/gltf" / (name + "_Color1.gltf")
            raw = archive.read(str(path))
            source_hashes[str(path)] = digest(raw)
            document = json.loads(raw)
            if len(document["buffers"]) != 1:
                raise ValueError("Expected one source buffer")
            def dependency(uri):
                # The source references siblings only. Reject absolute/traversal paths.
                part = PurePosixPath(uri)
                if part.is_absolute() or ".." in part.parts:
                    raise ValueError("Unsafe archive dependency")
                dep = path.parent / part
                data = archive.read(str(dep))
                source_hashes[str(dep)] = digest(data)
                return data
            blob = bytearray(dependency(document["buffers"][0].pop("uri")))
            for image in document.get("images", []):
                data = dependency(image.pop("uri"))
                blob.extend(b"\0" * (-len(blob) % 4))
                image["bufferView"] = len(document.setdefault("bufferViews", []))
                document["bufferViews"].append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)})
                blob.extend(data)
            document["buffers"][0]["byteLength"] = len(blob)
            blob.extend(b"\0" * (-len(blob) % 4))
            encoded = json.dumps(document, separators=(",", ":")).encode()
            encoded += b" " * (-len(encoded) % 4)
            data = struct.pack("<III", 0x46546C67, 2, 28 + len(encoded) + len(blob))
            data += struct.pack("<II", len(encoded), 0x4E4F534A) + encoded
            data += struct.pack("<II", len(blob), 0x004E4942) + blob
            target = OUT / (name + ".glb")
            if target.exists() and target.read_bytes() != data:
                raise ValueError("Refusing to overwrite a different admitted model")
            target.write_bytes(data)
            files[target.name] = digest(data)
    receipt = {
        "date": "2026-10-12", "license": "CC0-1.0", "license_file": "LICENSE.txt",
        "author": "Kay Lousberg", "source_url": "https://kaylousberg.itch.io/kaykit-forest",
        "source_archive": str(ARCHIVE.relative_to(ROOT)), "archive_sha256": digest(ARCHIVE.read_bytes()),
        "license_sha256": digest(license_data), "models": SELECTED,
        "conversion": "Original glTF/bin/PNG repacked into self-contained GLB. Geometry, UVs and embedded atlas unchanged. Runtime fits existing metre profiles; thatch receives an instance-only straw material.",
        "source_sha256": source_hashes, "files": files,
    }
    (OUT / "resource-refresh-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("Admitted six CC0 variants with source/output hashes")

if __name__ == "__main__":
    main()
