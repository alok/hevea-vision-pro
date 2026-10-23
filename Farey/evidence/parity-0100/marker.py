"""Bounding box of the isolated (3,0,3) marker near the top of the cone, same window for every image."""
import sys, json
from PIL import Image
def measure(path, box=(1880, 560, 1960, 620)):
    image = Image.open(path).convert('RGB')
    pixels = []
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            r, g, b = image.getpixel((x, y))
            if g > 60 and g > r + 20 and g > b:  # greenish marker pixels on the dark background
                pixels.append((x, y, (r, g, b)))
    if not pixels:
        return {'greenPixels': 0}
    xs, ys = [p[0] for p in pixels], [p[1] for p in pixels]
    return {'greenPixels': len(pixels), 'bbox': [min(xs), min(ys), max(xs), max(ys)],
            'size': [max(xs) - min(xs) + 1, max(ys) - min(ys) + 1]}
print(json.dumps({name: measure(path) for name, path in zip(sys.argv[1::2], sys.argv[2::2])}, indent=1))
