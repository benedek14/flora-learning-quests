#!/bin/zsh
# Builds the public site in docs/ (served by GitHub Pages) and the offline copies bundled in the iPad app.
#
#   hub.html               -> docs/index.html           (the "Flora's Learning Quests" home screen)
#   <quest>/index.html     -> docs/<quest>/index.html   (one folder per quest, e.g. fractions/)
#   docs/manifest.json     lists every page; the app downloads them all so they work offline.
#
# Quest pages may be written without <html>/<head> (claude.ai artifact style); they get wrapped here.
set -e
cd "$(dirname "$0")"
rm -rf docs && mkdir -p docs
python3 - <<'EOF'
import glob, json, os

HEAD = '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#0f1d19">
<style>
:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}
body{margin:0}
img{max-width:100%}
html{-webkit-text-size-adjust:100%}
</style>
'''

def wrap(src):
    if src.lstrip().lower().startswith('<!doctype'):
        return src
    src = src.replace('<meta name="claude:viewport-fit-sides" content="cover">\n', '')
    # head material = everything before the first <div (title, fonts, style)
    i = src.index('<div')
    return HEAD + src[:i] + '</head>\n<body>\n' + src[i:] + '\n</body>\n</html>\n'

pages = {'': open('hub.html', encoding='utf-8').read()}
for f in sorted(glob.glob('*/index.html')):
    d = os.path.dirname(f)
    if d in ('docs', 'ios'):
        continue
    pages[d + '/'] = wrap(open(f, encoding='utf-8').read())

bundle = 'ios/LearningQuests/Pages'
os.makedirs(bundle, exist_ok=True)
for old in glob.glob(bundle + '/*.html'):
    os.remove(old)
for path, html in pages.items():
    os.makedirs('docs/' + path, exist_ok=True)
    open('docs/' + path + 'index.html', 'w', encoding='utf-8').write(html)
    name = path.strip('/') or 'home'
    open(f'{bundle}/{name}.html', 'w', encoding='utf-8').write(html)
json.dump({'pages': list(pages)}, open('docs/manifest.json', 'w'))
open('docs/.nojekyll', 'w').close()
print('built pages:', ', '.join(p or '(home)' for p in pages))
EOF
