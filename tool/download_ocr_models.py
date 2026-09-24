"""Fetch official small LSTM models for the Android package before building."""
import hashlib
import pathlib
import urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[1]
DEST=ROOT/'qamqor_vision/android/app/src/main/assets/tessdata'
DEST.mkdir(parents=True,exist_ok=True)
for lang in ('rus','kaz'):
    target=DEST/f'{lang}.traineddata'
    if not target.exists():
        urllib.request.urlretrieve(f'https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/{lang}.traineddata',target)
    if target.stat().st_size<100_000: raise RuntimeError('Invalid model download')
    print(lang,target.stat().st_size,hashlib.sha256(target.read_bytes()).hexdigest())
