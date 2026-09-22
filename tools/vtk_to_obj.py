"""Convert the public Cas A VTK layers to lightweight OBJ intermediates.

This is an import-time utility only. The runtime loads the generated native
Godot scenes, never the VTK archive or these OBJ intermediates.
"""
from pathlib import Path
import argparse
import zipfile


def convert(archive: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as source:
        for name in source.namelist():
            if not name.endswith(".vtk"):
                continue
            tokens = source.read(name).decode("ascii").split()
            points_at = tokens.index("POINTS")
            count = int(tokens[points_at + 1])
            points = [tuple(map(float, tokens[points_at + 3 + i:points_at + 6 + i])) for i in range(0, count * 3, 3)]
            strips_at = tokens.index("TRIANGLE_STRIPS")
            strip_count = int(tokens[strips_at + 1])
            cursor = strips_at + 3
            faces = []
            for _ in range(strip_count):
                length = int(tokens[cursor])
                strip = list(map(int, tokens[cursor + 1:cursor + 1 + length]))
                cursor += length + 1
                for i in range(length - 2):
                    faces.append((strip[i], strip[i + 1], strip[i + 2]) if i % 2 == 0 else (strip[i + 1], strip[i], strip[i + 2]))
            step = max(1, len(faces) // 12000)
            faces = faces[::step]
            used = sorted({index for face in faces for index in face})
            mapping = {old: new for new, old in enumerate(used, 1)}
            stem = Path(name).stem.replace("-ascii", "")
            lines = ["v %f %f %f" % points[index] for index in used]
            lines += ["f %d %d %d" % tuple(mapping[index] for index in face) for face in faces]
            (output_dir / (stem + ".obj")).write_text("\n".join(lines), encoding="utf8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    convert(args.archive, args.output_dir)
