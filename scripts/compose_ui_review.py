"""Assemble unmodified Flutter renders; never synthesize interface elements."""
from pathlib import Path
import json
import os
from PIL import Image, ImageDraw, ImageFont

root = Path('design/reviews')
font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 18)
small = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 14)
for state in ['before', 'after']:
    pages = [Image.open(root / state / f'390-my-{i}.png').convert('RGB') for i in range(4)]
    gutter, top, bottom = 24, 92, 56
    width = sum(p.width for p in pages) + gutter * 5
    board = Image.new('RGB', (width, top + max(p.height for p in pages) + bottom), '#e8eeeb')
    draw = ImageDraw.Draw(board)
    draw.text((gutter, 16), f'BAHTZAY / {state.upper()} / REAL FLUTTER RENDER', font=font, fill='#173c33')
    draw.text((gutter, 44), 'Same app, fixture data and 390px viewport. Sample data, not live rates.', font=small, fill='#5b7068')
    left = gutter
    for i, (name, page) in enumerate(zip(['HOME', 'CALCULATOR', 'WALLET', 'HISTORY'], pages)):
        draw.text((left, 72), f'0{i+1} / {name}', font=small, fill='#173c33')
        board.paste(page, (left, top))
        left += page.width + gutter
    draw.text((gutter, board.height - 32), 'Source baseline: f0fb89a (v1) | Interface images are unmodified screenshots.', font=small, fill='#5b7068')
    board.save(root / f'{state}-four-pages.png')
(root / 'manifest.json').write_text(json.dumps({'baseline':'f0fb89a1d65ba20e5587c5a2db1623590ba5888c','candidate':os.environ['CANDIDATE_SHA'],'render':'Flutter widget test with actual fonts','data':'isolated synthetic fixture; no production writes'}, indent=2))
