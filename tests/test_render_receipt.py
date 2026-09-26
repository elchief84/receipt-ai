import json
import random

from PIL import Image

from ml.synthetic.compose_receipt import compose_record, load_seeds
from ml.synthetic.render_receipt import render_dataset


def _write_jsonl(path, n=3):
    seeds = load_seeds("", "", fixture=True)
    rng = random.Random(0)
    with open(path, "w", encoding="utf-8") as f:
        for _ in range(n):
            f.write(json.dumps(compose_record(rng, seeds)) + "\n")


def test_render_dataset_ground_truth_and_images(tmp_path):
    src = tmp_path / "synth.jsonl"
    out = tmp_path / "images"
    _write_jsonl(src, n=3)

    count = render_dataset(str(src), str(out), n=3, seed=42)
    assert count == 3

    index = json.loads((out / "index.json").read_text(encoding="utf-8"))
    assert len(index) == 3

    records = [json.loads(l) for l in src.read_text(encoding="utf-8").splitlines()]
    for i, rec in enumerate(records):
        sid = f"{i:05d}"
        png = out / sid / "receipt.png"
        assert png.exists()
        with Image.open(png) as im:
            assert im.format == "PNG"
            assert im.width > 0 and im.height > 0

        expected = json.loads((out / sid / "expected.json").read_text(encoding="utf-8"))
        assert expected["total"] == rec["amount"]["total"]
        assert len(expected["items"]) == len(rec["items"])
        assert expected["merchant"] == rec["merchant"]["raw_name"]

        meta = json.loads((out / sid / "meta.json").read_text(encoding="utf-8"))
        assert meta["ocr_text"] == rec["ocr_text"]


def test_render_dataset_is_deterministic(tmp_path):
    src = tmp_path / "synth.jsonl"
    _write_jsonl(src, n=2)
    a, b = tmp_path / "a", tmp_path / "b"
    render_dataset(str(src), str(a), n=2, seed=7)
    render_dataset(str(src), str(b), n=2, seed=7)
    for sid in ("00000", "00001"):
        assert (a / sid / "receipt.png").read_bytes() == (
            b / sid / "receipt.png"
        ).read_bytes()


def test_rotation_and_blur_change_the_image(tmp_path):
    src = tmp_path / "synth.jsonl"
    _write_jsonl(src, n=1)
    plain, tilted = tmp_path / "plain", tmp_path / "tilted"
    render_dataset(str(src), str(plain), n=1, seed=1)
    render_dataset(str(src), str(tilted), n=1, seed=1, rotate_deg=3.0, blur=1.2)
    assert (plain / "00000" / "receipt.png").read_bytes() != (
        tilted / "00000" / "receipt.png"
    ).read_bytes()
