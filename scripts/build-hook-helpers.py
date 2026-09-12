"""Bundle the shared hook transport into independently installed plugins."""
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
source = (root / 'scripts/hook_reminder.py').read_bytes()
stale = []
for plugin in ('arch-nextjs', 'arch-tanstack-start', 'arch-nestjs-backend'):
    target = root / 'plugins' / plugin / 'scripts/hook_reminder.py'
    if args.check:
        if not target.is_file() or target.read_bytes() != source:
            stale.append(str(target.relative_to(root)))
    else:
        target.write_bytes(source)
if stale:
    raise SystemExit('Stale hook helpers: ' + ', '.join(stale))
print('hook helpers: IN SYNC' if args.check else 'hook helpers: regenerated')
