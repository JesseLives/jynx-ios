import json, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "App", "Assets.xcassets")
FONT = "/usr/local/lib/python3.14/dist-packages/matplotlib/mpl-data/fonts/ttf/DejaVuSans-Bold.ttf"
N = 1024

def centered_text(img, text, size, fill, dy=0):
    d = ImageDraw.Draw(img); f = ImageFont.truetype(FONT, size)
    l, t, r, b = d.textbbox((0, 0), text, font=f)
    d.text(((N - (r - l)) / 2 - l, (N - (b - t)) / 2 - t + dy), text, font=f, fill=fill)

def from_file(name, bg, scale):
    src = Image.open(os.path.join(HERE, "src", f"{name}.png")).convert("RGBA")
    img = Image.new("RGBA", (N, N), bg)
    side = int(N * scale); src.thumbnail((side, side), Image.LANCZOS)
    img.alpha_composite(src, ((N - src.width) // 2, (N - src.height) // 2))
    return img

def main_icon():
    img = Image.new("RGBA", (N, N), "#000000")
    ImageDraw.Draw(img).rounded_rectangle((212, 212, 812, 812), radius=120, fill="#ffffff")
    centered_text(img, "$", 520, "#000000", dy=10)
    return img

def letter(bg, text, size, fill="#ffffff"):
    img = Image.new("RGBA", (N, N), bg); centered_text(img, text, size, fill); return img

def icon(name):
    if os.path.exists(os.path.join(HERE, "src", f"{name}.png")):
        return from_file(name, "#ffffff", 0.86)
    return {"main": main_icon, "stripe": lambda: letter("#635bff", "S", 640),
            "stan": lambda: letter("#111111", "stan", 330)}[name]()

def write(path, contents, files):
    os.makedirs(path, exist_ok=True)
    for fn, im in files.items(): im.convert("RGB").save(os.path.join(path, fn))  # app icons must not have alpha
    json.dump(contents, open(os.path.join(path, "Contents.json"), "w"), indent=2)

os.makedirs(ASSETS, exist_ok=True)
json.dump({"info": {"author": "xcode", "version": 1}}, open(os.path.join(ASSETS, "Contents.json"), "w"), indent=2)
for name in ["main", "shopify", "stripe", "stan"]:
    im = icon(name)
    setname = "AppIcon" if name == "main" else f"AppIcon-{name.capitalize()}"
    write(os.path.join(ASSETS, f"{setname}.appiconset"),
          {"images": [{"filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}},
          {"icon.png": im})
    write(os.path.join(ASSETS, f"logo-{name}.imageset"),
          {"images": [{"filename": "logo.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
          {"logo.png": im.resize((180, 180), Image.LANCZOS)})
print("icons written")
