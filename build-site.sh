#!/bin/zsh
# Builds docs/index.html (the public GitHub Pages version) from index.html (the game source).
# index.html is written without <html>/<head> tags (the claude.ai artifact adds them),
# so this wraps it in a full standalone document.
set -e
cd "$(dirname "$0")"
mkdir -p docs
python3 - <<'EOF'
src = open('index.html', encoding='utf-8').read()
src = src.replace('<meta name="claude:viewport-fit-sides" content="cover">\n', '')
head = '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="theme-color" content="#0f1d19">
<style>
:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}
body{margin:0}
img{max-width:100%}
html{-webkit-text-size-adjust:100%}
</style>
'''
# everything before the first <div is head material (title, fonts, style)
i = src.index('<div class="sky"')
out = head + src[:i] + '</head>\n<body>\n' + src[i:] + '\n</body>\n</html>\n'
open('docs/index.html', 'w', encoding='utf-8').write(out)
open('docs/.nojekyll', 'w').close()
# offline fallback copy bundled inside the iPad app
import os
if os.path.isdir('ios/FractionQuest'):
    open('ios/FractionQuest/game.html', 'w', encoding='utf-8').write(out)
print('built docs/index.html', len(out), 'bytes')
EOF
