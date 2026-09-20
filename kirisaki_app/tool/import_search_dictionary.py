"""Import a pinned DanbooruSearchOnline CSV. No model or API dependency.

Usage: python tool/import_search_dictionary.py PATH_TO_CSV
"""
import csv
import hashlib
import io
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
raw = Path(sys.argv[1]).read_bytes()
for encoding in ('utf-8-sig', 'gbk', 'gb18030'):
    try:
        text = raw.decode(encoding)
        break
    except UnicodeDecodeError:
        continue
else:
    raise ValueError('Unsupported CSV encoding')
rows = []
seen = set()
for item in csv.DictReader(io.StringIO(text)):
    name = item['name'].strip()
    if not name or name in seen or item['category'] not in ('0', '3', '4'):
        continue
    seen.add(name)
    aliases = list(dict.fromkeys(x.strip() for x in
        re.split(r'[,，;；\n]', item['cn_name']) if x.strip()))
    if not aliases:
        aliases = [name]
    rows.append([name, aliases, int(item['category']),
                 int(item['post_count'] or 0), item['nsfw'].strip()])
rows.sort(key=lambda r: (-r[3], r[0]))
result = {'version': 1, 'source_commit': '6cf30e7d38b729eb18fe8903f242dbbc5ce13399',
          'source_sha256': hashlib.sha256(raw).hexdigest(),
          'encoding': encoding, 'rows': rows}
out = ROOT / 'assets/search/danbooru_local.json'
out.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
print(f'Imported {len(rows)} entries; {out.stat().st_size} bytes; encoding={encoding}')
