#!/usr/bin/env python3
"""Export the checked-in vector with CairoSVG + Pillow (maintainer-only tooling).
Run scripts/fetch_fonts.py first for the pinned Myanmar wordmark font.
No renderer or network access is used by the application.
"""
from io import BytesIO
from pathlib import Path
import json
import cairosvg
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / 'flutter_app/web'
VERSION = 'bahtzay-v1'
svg = (WEB / 'branding/bahtzay-icon.svg').read_text()

def render(source, size):
    return Image.open(BytesIO(cairosvg.svg2png(
        bytestring=source.encode(), output_width=size, output_height=size))).convert('RGBA')

maskable = svg.replace('rx="112"', 'rx="0"').replace(
    '<g id="symbol">', '<g id="symbol" transform="translate(256 256) scale(0.88) translate(-256 -256)">')
opaque = svg.replace('rx="112"', 'rx="0"')
for size in [192, 512]:
    for stem, source in [('Icon', svg), ('Icon-maskable', maskable)]:
        image = render(source, size)
        image.save(WEB / f'icons/{stem}-{size}.png')
        image.save(WEB / f'icons/{stem}-{size}-{VERSION}.png')
render(opaque, 180).convert('RGB').save(WEB / f'icons/apple-touch-icon-{VERSION}.png')
render(svg, 32).save(WEB / 'favicon.png')
render(svg, 32).save(WEB / f'favicon-{VERSION}.png')
render(svg, 1024).save(WEB / 'branding/bahtzay-icon-1024.png')
render(svg, 192).save(ROOT / 'flutter_app/assets/branding/bahtzay-icon.png')

# The foreground of the maskable icon must fit within the radius-40% safe zone.
background = maskable[:maskable.index('<g id="symbol"')] + '</svg>'
image, base = render(maskable, 512), render(background, 512)
for y in range(512):
    for x in range(512):
        assert image.getpixel((x,y))[3] == 255
        if image.getpixel((x,y)) != base.getpixel((x,y)):
            assert (x-255.5)**2+(y-255.5)**2 < (512*.4)**2

# Actual Myanmar shaping via RAQM, rather than AI-generated lettering.
font_path = ROOT / 'flutter_app/assets/fonts/NotoSansMyanmar.ttf'
font = ImageFont.truetype(str(font_path), 87, layout_engine=ImageFont.Layout.RAQM)
small = ImageFont.truetype(str(font_path), 29, layout_engine=ImageFont.Layout.RAQM)
social = Image.new('RGB', (1200,630), '#F3F7F5')
d = ImageDraw.Draw(social)
d.rounded_rectangle((48,48,1152,582), radius=45, fill='#FFFFFF')
icon=render(svg,288);social.paste(icon,(100,171),icon)
d.text((444,171),'ဘတ်ဈေး',font=font,fill='#065F46')
d.text((450,332),'နေ့စဉ် ဘတ် / ကျပ်ဈေး',font=small,fill='#315B51')
d.text((450,391),'ငွေတွက် · ကိုယ့်ငွေစာရင်း',font=small,fill='#315B51')
social.save(WEB / 'og-image.png')
social.save(WEB / f'og-image-{VERSION}.png')
print('Exported Baht identity, verified opaque maskable safe zone and shaped Myanmar wordmark.')
