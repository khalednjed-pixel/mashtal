"""Build assets/fonts/MashtalRiyal.ttf: one glyph, the Saudi riyal sign (U+20C1).

Tajawal has no glyph for U+20C1 yet, so the app uses this font as a fallback.
The outline is the official symbol published by the Saudi Central Bank (SAMA),
public domain: https://commons.wikimedia.org/wiki/File:Saudi_Riyal_Symbol.svg

Run: python3 tool/riyal_font/build_font.py   (needs: pip install fonttools)
"""
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.svgLib.path import parse_path

# The two outlines of SAMA's SVG (viewBox 0 0 1124.14 1256.39).
PATHS = [
    "M699.62,1113.02h0c-20.06,44.48-33.32,92.75-38.4,143.37l424.51-90.24c20.06-44.47,33.31-92.75,38.4-143.37l-424.51,90.24Z",
    "M1085.73,895.8c20.06-44.47,33.32-92.75,38.4-143.37l-330.68,70.33v-135.2l292.27-62.11c20.06-44.47,33.32-92.75,38.4-143.37l-330.68,70.27V66.13c-50.67,28.45-95.67,66.32-132.25,110.99v403.35l-132.25,28.11V0c-50.67,28.44-95.67,66.32-132.25,110.99v525.69l-295.91,62.88c-20.06,44.47-33.33,92.75-38.42,143.37l334.33-71.05v170.26l-358.3,76.14c-20.06,44.47-33.32,92.75-38.4,143.37l375.04-79.7c30.53-6.35,56.77-24.4,73.83-49.24l68.78-101.97v-.02c7.14-10.55,11.3-23.27,11.3-36.97v-149.98l132.25-28.11v270.4l424.53-90.28Z",
]
VIEW_W, VIEW_H = 1124.14, 1256.39
UPM = 1000
HEIGHT = 680  # about the height of Tajawal's digits
SIDE = 70     # space on each side of the sign
scale = HEIGHT / VIEW_H
width = round(VIEW_W * scale) + 2 * SIDE

pen = TTGlyphPen(None)
# SVG y grows downwards; fonts grow upwards.
tpen = TransformPen(Cu2QuPen(pen, 1.0, reverse_direction=True), (scale, 0, 0, -scale, SIDE, HEIGHT))
for d in PATHS:
    parse_path(d, tpen)
riyal = pen.glyph()
empty = TTGlyphPen(None).glyph()

fb = FontBuilder(UPM, isTTF=True)
fb.setupGlyphOrder([".notdef", "space", "riyal"])
fb.setupCharacterMap({0x20: "space", 0x20C1: "riyal"})
fb.setupGlyf({".notdef": empty, "space": empty, "riyal": riyal})
fb.setupHorizontalMetrics({".notdef": (500, 0), "space": (250, 0), "riyal": (width, SIDE)})
fb.setupHorizontalHeader(ascent=900, descent=-300)
fb.setupNameTable({"familyName": "MashtalRiyal", "styleName": "Regular"})
fb.setupOS2(sTypoAscender=900, sTypoDescender=-300, usWinAscent=900, usWinDescent=300)
fb.setupPost()
out = Path(__file__).resolve().parents[2] / "assets" / "fonts" / "MashtalRiyal.ttf"
fb.save(str(out))
print("wrote", out)
