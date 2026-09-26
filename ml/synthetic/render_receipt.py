"""Render composed receipts to images with automatic ground truth (issue #18).

Takes the JSONL produced by `compose_receipt` (merchant, items, total,
ocr_text) and writes, per record:

    <out>/<id>/receipt.png     thermal-like render (tilt/blur optional)
    <out>/<id>/expected.json   ground truth in the debug-corpus schema
    <out>/<id>/meta.json       source record + render params (ocr_text)
    <out>/index.json           manifest

This gives an endless, labelled eval set that respects the data policy
(public/synthetic only). The OCR step is on-device (ML Kit): run the app
over the generated PNGs, save each `[OCR-TEXT]`/`[OCR-GEOM]` dump as
`<out>/<id>/ocr.log`, then:

    DEBUG_CORPUS_DIR=<out> flutter test test/eval_corpus_test.dart

which writes docs/OCR_EVAL.md.
"""

import argparse
import json
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

_PAPER = (242, 240, 232)
_INK = (28, 28, 28)


def _font(size: int) -> ImageFont.FreeTypeFont:
    for path in (
        "/System/Library/Fonts/Supplemental/Andale Mono.ttf",
        "/System/Library/Fonts/Menlo.ttc",
        "/Library/Fonts/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    ):
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    # Pillow >= 10 supports a sized default bitmap font.
    return ImageFont.load_default(size=size)


def render_image(
    text: str,
    *,
    size: int = 26,
    rotate_deg: float = 0.0,
    blur: float = 0.0,
    margin: int = 40,
    rng: random.Random | None = None,
) -> Image.Image:
    font = _font(size)
    lines = text.split("\n")
    width = max((int(font.getlength(ln)) for ln in lines), default=10)
    ascent, descent = font.getmetrics()
    line_h = ascent + descent
    img_w = width + 2 * margin
    img_h = line_h * max(len(lines), 1) + 2 * margin

    img = Image.new("RGB", (img_w, img_h), _PAPER)
    draw = ImageDraw.Draw(img)
    y = margin
    for ln in lines:
        draw.text((margin, y), ln, font=font, fill=_INK)
        y += line_h

    if rng is not None and rng.random() < 0.5:
        _speckle(draw, img_w, img_h, rng)

    if rotate_deg:
        img = img.rotate(
            rotate_deg, expand=True, resample=Image.BILINEAR, fillcolor=_PAPER
        )
    if blur > 0:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return img


def _speckle(draw: ImageDraw.ImageDraw, w: int, h: int, rng: random.Random) -> None:
    for _ in range((w * h) // 4000):
        x = rng.randint(0, w - 1)
        y = rng.randint(0, h - 1)
        g = rng.randint(150, 215)
        draw.point((x, y), fill=(g, g, g))


def render_dataset(
    in_path: str,
    out_dir: str,
    *,
    n: int | None = None,
    seed: int = 42,
    rotate_deg: float = 0.0,
    blur: float = 0.0,
) -> int:
    rng = random.Random(seed)
    os.makedirs(out_dir, exist_ok=True)
    index = []
    with open(in_path, encoding="utf-8") as f:
        for i, line in enumerate(f):
            if n is not None and i >= n:
                break
            rec = json.loads(line)
            sid = f"{i:05d}"
            sample_dir = os.path.join(out_dir, sid)
            os.makedirs(sample_dir, exist_ok=True)

            img = render_image(
                rec["ocr_text"],
                rotate_deg=rotate_deg,
                blur=blur,
                rng=rng,
            )
            img_path = os.path.join(sample_dir, "receipt.png")
            img.save(img_path, "PNG")

            expected = {
                "merchant": rec["merchant"]["raw_name"],
                "total": rec["amount"]["total"],
                "items": [
                    {"description": _abbrev(it["raw_description"]), "price": it["total"]}
                    for it in rec["items"]
                ],
            }
            with open(
                os.path.join(sample_dir, "expected.json"), "w", encoding="utf-8"
            ) as ef:
                json.dump(expected, ef, ensure_ascii=False, indent=2)

            with open(
                os.path.join(sample_dir, "meta.json"), "w", encoding="utf-8"
            ) as mf:
                json.dump(
                    {
                        "id": sid,
                        "category": rec.get("category"),
                        "merchant_type": rec["merchant"]["merchant_type"],
                        "ocr_text": rec["ocr_text"],
                        "rotate_deg": rotate_deg,
                        "blur": blur,
                    },
                    mf,
                    ensure_ascii=False,
                    indent=2,
                )

            index.append({"id": sid, "image": f"{sid}/receipt.png"})

    with open(os.path.join(out_dir, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)
    return len(index)


def _abbrev(desc: str) -> str:
    # Mirror the composer's rendered form so the eval compares like with
    # like (the receipt prints the abbreviated product name).
    from ml.datasets.normalize import abbreviate

    return abbreviate(desc)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--in", dest="in_path", required=True)
    parser.add_argument("--out", dest="out_dir", required=True)
    parser.add_argument("--n", type=int, default=None)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--rotate-deg", type=float, default=0.0)
    parser.add_argument("--blur", type=float, default=0.0)
    args = parser.parse_args()
    count = render_dataset(
        args.in_path,
        args.out_dir,
        n=args.n,
        seed=args.seed,
        rotate_deg=args.rotate_deg,
        blur=args.blur,
    )
    print(f"rendered {count} samples to {args.out_dir}")


if __name__ == "__main__":
    main()
