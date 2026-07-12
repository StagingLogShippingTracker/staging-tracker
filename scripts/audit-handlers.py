import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
pages = ['index.html', 'stage.html', 'ship.html', 'reports.html', 'contacts.html', 'notifications.html']

js_files = list(root.glob('*.js'))
js_content = '\n'.join(f.read_text(encoding='utf-8') for f in js_files)
defined = set(re.findall(r'window\.(\w+)\s*=\s*(?:async\s+)?function', js_content))

handler_re = re.compile(r'window\.(\w+)\s*\(')
inline_re = re.compile(r'on(?:click|input|change|submit)\s*=\s*["\']([^"\']+)["\']', re.I)

issues = 0
for page in pages:
    html = (root / page).read_text(encoding='utf-8')
    scripts = [m.split('?')[0] for m in re.findall(r'<script src="([^"]+\.js)', html)]
    handlers = set(handler_re.findall(html))
    for m in inline_re.finditer(html):
        handlers.update(re.findall(r'window\.(\w+)', m.group(1)))

    page_js = ''
    for s in scripts:
        p = root / s
        if p.exists():
            page_js += p.read_text(encoding='utf-8') + '\n'
    page_defined = set(re.findall(r'window\.(\w+)\s*=\s*(?:async\s+)?function', page_js))

    missing = sorted(h for h in handlers if h not in page_defined and h not in defined)
    print(f'\n=== {page} ({len(scripts)} scripts, {len(handlers)} handlers) ===')
    if missing:
        issues += len(missing)
        print('MISSING:', ', '.join(missing))
    else:
        print('OK — all inline handlers resolve to a loaded script')

print(f"\n{'Found ' + str(issues) + ' unresolved handler(s)' if issues else 'All pages passed handler audit'}")
sys.exit(1 if issues else 0)
