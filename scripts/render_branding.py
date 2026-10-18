#!/usr/bin/env python3
"""Reproduce approved exports from the original board (maintainer-only tooling).
The board is retained outside the deployment tree; supply --reference-board PATH.
Run scripts/fetch_fonts.py first for the pinned Myanmar wordmark font.
No renderer or network access is used by the application.
"""
from io import BytesIO
from pathlib import Path
import argparse
import cairosvg
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / 'flutter_app/web'
VERSION = 'bahtzay-v2'
parser = argparse.ArgumentParser()
parser.add_argument('--reference-board', type=Path, required=True)
args = parser.parse_args()
reference = args.reference_board.resolve()
if not reference.is_file():
    parser.error('Supply the original owner-approved Concept A PNG board.')
svg = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 512 512" width="512" height="512" role="img" aria-labelledby="title desc">\n<title id="title">ဘတ်ဈေး — approved reference artwork</title>\n<desc id="desc">The exact serif Thai Baht and tapered exchange arrows from the owner-approved branding board. The source pixels are preserved through an SVG viewport, rather than redrawing or generating different letterforms.</desc>\n<defs>\n<linearGradient id="teal" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#0EA88A"/><stop offset="1" stop-color="#005344"/></linearGradient>\n<clipPath id="icon-crop"><rect width="512" height="512" rx="130"/></clipPath>\n</defs>\n<rect id="background" width="512" height="512" rx="130" fill="url(#teal)"/>\n<g id="artwork" clip-path="url(#icon-crop)">\n<svg viewBox="114 55 518 504" width="512" height="512" preserveAspectRatio="none">\n<image xlink:href="approved-reference-board.png" width="1448" height="1086"/>\n</svg>\n</g>\n</svg>\n'
svg = svg.replace('approved-reference-board.png', reference.as_uri())

def render(source, size):
    return Image.open(BytesIO(cairosvg.svg2png(
        bytestring=source.encode(), url=str(WEB / 'branding/bahtzay-icon.svg'), unsafe=True, output_width=size, output_height=size))).convert('RGBA')

maskable = svg.replace('id="background" width="512" height="512" rx="130"', 'id="background" width="512" height="512" rx="0"').replace(
    '<g id="artwork"', '<g transform="translate(256 256) scale(0.88) translate(-256 -256)" id="artwork"')
opaque = svg.replace('id="background" width="512" height="512" rx="130"', 'id="background" width="512" height="512" rx="0"')
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
render(svg, 192).save(ROOT / f'flutter_app/assets/branding/bahtzay-icon-{VERSION}.png')

# Validate the opaque maskable export. Foreground safe-area checks run in Node.
image = render(maskable, 512)
assert image.getextrema()[3] == (255, 255)

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
print('Exported approved reference pixels, opaque maskable assets and shaped Myanmar wordmark.')
