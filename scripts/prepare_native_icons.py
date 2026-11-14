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
 image=Image.open(SOURCE).convert('RGBA')
 # Apple requires opaque app icons;
 # composite only transparent edges onto a green sampled from the source.
 opaque=Image.new('RGB',image.size,image.getpixel((image.width//2,0))[:3])
 opaque.paste(image,mask=image.getchannel('A'))
 for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
  path=ROOT/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png';path.parent.mkdir(parents=True,exist_ok=True)
  opaque.resize((size,size),Image.Resampling.LANCZOS).save(path,optimize=True)
  layer_size=round(size*108/48)
  artwork_size=round(layer_size*0.60)
  layer=Image.new('RGBA',(layer_size,layer_size))
  offset=(layer_size-artwork_size)//2
  layer.paste(image.resize((artwork_size,artwork_size),Image.Resampling.LANCZOS),(offset,offset))
  layer.save(path.with_name('ic_launcher_foreground.png'),optimize=True)
 adaptive=ROOT/'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml'
 adaptive.parent.mkdir(parents=True,exist_ok=True)
 adaptive.write_text(
  '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
  '    <background><shape><solid android:color="#065D4D" /></shape></background>\n'
  '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
  '</adaptive-icon>\n',
  encoding='utf-8',
 )
 folder=ROOT/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
 for item in json.loads((folder/'Contents.json').read_text())['images']:
  size=round(float(item['size'].split('x')[0])*float(item['scale'].rstrip('x')))
  opaque.resize((size,size),Image.Resampling.LANCZOS).save(folder/item['filename'],optimize=True)
 for scale in (1,2,3):
  suffix='' if scale==1 else f'@{scale}x'
  image.resize((168*scale,168*scale),Image.Resampling.LANCZOS).save(ROOT/f'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{suffix}.png',optimize=True)
 print('Android/iOS icons exported from the approved logo.')
if __name__=='__main__':main()
