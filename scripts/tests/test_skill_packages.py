import json
from pathlib import Path
import re
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SkillPackages(unittest.TestCase):
    def test_codex_packages_are_self_contained(self):
        marketplace = json.loads((ROOT / '.agents/plugins/marketplace.json').read_text())
        claude = {entry['name']: entry['version'] for entry in json.loads((ROOT / '.claude-plugin/marketplace.json').read_text())['plugins']}
        for entry in marketplace['plugins']:
            with self.subTest(plugin=entry['name']), tempfile.TemporaryDirectory() as directory:
                source = ROOT / entry['source']['path']
                package = (Path(directory) / 'isolated-plugin').resolve()
                shutil.copytree(str(source), str(package))
                manifest = json.loads((package / '.codex-plugin/plugin.json').read_text())
                self.assertEqual(manifest['name'], entry['name'])
                self.assertEqual(manifest['version'], claude[entry['name']])
                skills = list((package / manifest['skills']).glob('*/SKILL.md'))
                self.assertTrue(skills)
                pending, visited = skills[:], set()
                while pending:
                    document = pending.pop()
                    if document in visited:
                        continue
                    visited.add(document)
                    text = re.sub(r'```.*?```', '', document.read_text(), flags=re.S)
                    for link in re.findall(r'\]\(([^)]+)\)', text):
                        if '://' in link or link.startswith('#'):
                            continue
                        target = (document.parent / link.split('#')[0]).resolve()
                        self.assertTrue(target.is_relative_to(package) if hasattr(target, 'is_relative_to') else str(target).startswith(str(package) + '/'), (document, link))
                        self.assertTrue(target.exists(), (document, link))
                        if target.suffix == '.md' and target.is_file():
                            pending.append(target)

    def test_hook_helpers_match_source(self):
        source = (ROOT / 'scripts/hook_reminder.py').read_bytes()
        for name in ('arch-nextjs', 'arch-tanstack-start', 'arch-nestjs-backend'):
            self.assertEqual((ROOT / 'plugins' / name / 'scripts/hook_reminder.py').read_bytes(), source)


if __name__ == '__main__':
    unittest.main()
