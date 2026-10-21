#!/usr/bin/env python3
"""Export native icon sizes from the existing approved pixels; no artwork generation."""
from pathlib import Path
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]/'flutter_app'
SOURCE=ROOT/'web/branding/bahtzay-icon-1024.png'
EXPECTED='41251af70aac9f4ce9a2cd79f1581c1b2cf991aea4fd93d52dae6762e267fd05'
def main():
 if hashlib.sha256(SOURCE.read_bytes()).hexdigest()!=EXPECTED:raise RuntimeError('Approved source changed')
 image=Image.open(SOURCE).convert('RGB')
 for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
  path=ROOT/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png';path.parent.mkdir(parents=True,exist_ok=True)
  image.resize((size,size),Image.Resampling.LANCZOS).save(path,optimize=True)
 folder=ROOT/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
 for item in json.loads((folder/'Contents.json').read_text())['images']:
  size=round(float(item['size'].split('x')[0])*float(item['scale'].rstrip('x')))
  image.resize((size,size),Image.Resampling.LANCZOS).save(folder/item['filename'],optimize=True)
 for scale in (1,2,3):
  suffix='' if scale==1 else f'@{scale}x'
  image.resize((168*scale,168*scale),Image.Resampling.LANCZOS).save(ROOT/f'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{suffix}.png',optimize=True)
 print('Android/iOS icons exported from the approved logo.')
if __name__=='__main__':main()
