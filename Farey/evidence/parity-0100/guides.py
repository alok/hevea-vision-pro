"""Median background inside the cone fans vs outside, and brightest guide-line pixel along a row, for each image."""
import sys, json, statistics
from PIL import Image
# Coordinates in 3840x2160 capture space; regions avoid dots and the control panel.
INSIDE_UPPER = (1850, 640, 1990, 700)   # inside upper fan, between dots
INSIDE_LOWER = (1700, 1950, 1900, 2050) # inside lower nappe near its rim
OUTSIDE = (300, 1200, 500, 1400)        # empty background
ROW = (1150, 2700, 600)                 # x0, x1, y: crosses the upper rim's guide lines
def median(image, box):
    pixels = [image.getpixel((x, y)) for y in range(box[1], box[3], 4) for x in range(box[0], box[2], 4)]
    return [statistics.median(p[i] for p in pixels) for i in range(3)]
def brightest(image, row):
    return max((image.getpixel((x, row[2])) for x in range(row[0], row[1])), key=sum)
out = {}
for name, path in zip(sys.argv[1::2], sys.argv[2::2]):
    image = Image.open(path).convert('RGB')
    out[name] = {'insideUpper': median(image, INSIDE_UPPER), 'insideLower': median(image, INSIDE_LOWER),
                 'outside': median(image, OUTSIDE), 'rimRowBrightest': brightest(image, ROW)}
print(json.dumps(out))
