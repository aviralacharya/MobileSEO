"""Generate compact UI and launch PNGs from the original artwork (requires Pillow)."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/branding/mobileseo_icon.png"


def rounded_logo(source, size):
    image = source.resize((size, size), Image.Resampling.LANCZOS)
    # Supersample the corner mask so small logos retain smooth edges.
    mask = Image.new("L", (size * 4, size * 4))
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size * 4 - 1, size * 4 - 1), radius=size * 0.22 * 4, fill=255
    )
    image.putalpha(mask.resize((size, size), Image.Resampling.LANCZOS))
    return image


def save(image, relative_path):
    path = ROOT / relative_path
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)
    print(f"{relative_path}: {image.width} x {image.height}")


def main():
    # Pillow detects the source encoding; the supplied .png is JPEG-encoded.
    # Always write derived files, retaining the original artwork.
    with Image.open(SOURCE) as original:
        source = original.convert("RGBA")

    save(rounded_logo(source, 128), "assets/branding/mobileseo_logo.png")
    save(rounded_logo(source, 288), "web/splash/logo.png")

    resources = "android/app/src/main/res"
    for bucket, scale in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
        logo = rounded_logo(source, round(96 * scale))
        save(logo, f"{resources}/drawable-{bucket}/launch_logo.png")
        # Android 12 uses a 288dp icon canvas with a 192dp circular safe zone.
        # Center the 96dp logo inside it so the system mask cannot clip it.
        icon = Image.new("RGBA", (round(288 * scale), round(288 * scale)))
        inset = (icon.width - logo.width) // 2
        icon.alpha_composite(logo, (inset, inset))
        save(icon, f"{resources}/drawable-{bucket}/launch_icon.png")

    for scale in (1, 2, 3):
        suffix = "" if scale == 1 else f"@{scale}x"
        save(
            rounded_logo(source, 96 * scale),
            f"ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{suffix}.png",
        )


if __name__ == "__main__":
    main()
