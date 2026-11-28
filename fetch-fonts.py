"""Downloads the game fonts (Lilita One, Nunito) from Google Fonts once and writes fonts/fonts.css
with the font files embedded, so every page works offline with the right fonts.
Run automatically by build-site.sh when fonts/fonts.css is missing."""
import base64, os, re, urllib.request

CSS_URL = 'https://fonts.googleapis.com/css2?family=Lilita+One&family=Nunito:wght@500;700;800;900&display=swap'
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15'
KEEP = {'latin', 'latin-ext'}   # English + accented letters; skips cyrillic, vietnamese etc.

def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': UA}), timeout=20).read()

css = get(CSS_URL).decode()
blocks = re.findall(r'/\* ([\w-]+) \*/\s*(@font-face\s*{[^}]*})', css)
out, cache = [], {}
for subset, block in blocks:
    if subset not in KEEP:
        continue
    url = re.search(r'url\((https://[^)]+)\)', block).group(1)
    if url not in cache:
        cache[url] = 'data:font/woff2;base64,' + base64.b64encode(get(url)).decode()
    out.append(block.replace(url, cache[url]))
os.makedirs('fonts', exist_ok=True)
open('fonts/fonts.css', 'w').write('\n'.join(out) + '\n')
print(f'fonts/fonts.css: {len(out)} faces, {len(cache)} files, {os.path.getsize("fonts/fonts.css")//1024} KB')
