import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SYNC = ROOT / 'plugins/arch-core/scripts/arch-sync-check.sh'
HOOKS = [
    ('arch-nextjs', 'ui-change-reminder', 'src/components/ui/button.tsx', ''),
    ('arch-tanstack-start', 'ui-change-reminder', 'src/components/ui/button.tsx', ''),
    ('arch-nestjs-backend', 'schema-change-reminder', 'src/database/schema/orders.ts', ''),
    ('arch-nestjs-backend', 'module-boundary-reminder', 'src/modules/order/order.ts', "import { X } from '~/modules/catalog/domain/x'"),
]


class Hooks(unittest.TestCase):
    def invoke(self, plugin, script, payload):
        env = dict(os.environ)
        env.pop('CLAUDE_TOOL_INPUT', None)
        return subprocess.run(['sh', str(ROOT / 'plugins' / plugin / 'scripts' / (script + '.sh'))],
                              input=payload, text=True, capture_output=True, env=env)

    def test_real_stdin_is_model_context(self):
        for plugin, script, path, content in HOOKS:
            for tool in ['Edit', 'Write']:
                with self.subTest(plugin=plugin, script=script, tool=tool):
                    result = self.invoke(plugin, script, json.dumps({
                        'hook_event_name': 'PostToolUse', 'tool_name': tool,
                        'tool_input': {'file_path': path, 'new_string': content, 'content': content}}))
                    self.assertEqual(result.returncode, 0, result.stderr)
                    output = json.loads(result.stdout)['hookSpecificOutput']
                    self.assertEqual(output['hookEventName'], 'PostToolUse')
                    self.assertTrue(output['additionalContext'])

    def test_irrelevant_malformed_and_other_events_are_silent(self):
        for plugin, script, _, _ in HOOKS:
            for payload in ['not json', 'null', '[]', '{}', json.dumps({
                    'hook_event_name': 'PostToolUse', 'tool_name': 'Read',
                    'tool_input': {'file_path': 'src/components/ui/button.tsx'}}), json.dumps({
                    'hook_event_name': 'PreToolUse', 'tool_name': 'Edit',
                    'tool_input': {'file_path': 'src/components/ui/button.tsx'}}), json.dumps({
                    'hook_event_name': 'PostToolUse', 'tool_name': 'Edit',
                    'tool_input': {'file_path': 'README.md', 'new_string': 'src/components/ui/button.tsx'}})]:
                result = self.invoke(plugin, script, payload)
                self.assertEqual((result.returncode, result.stdout), (0, ''), result.stderr)


class Sync(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'home'
        self.project = Path(self.temp.name) / 'project with spaces'
        self.project.mkdir()
        self.home.mkdir()
        self.manifest = self.home / '.claude/plugins/marketplaces/architectures/.claude-plugin/marketplace.json'
        self.registry = self.home / '.claude/plugins/installed_plugins.json'
        self.write(self.manifest, {'plugins': [{'name': 'arch-core', 'version': '1.9.0'}]})
        self.write(self.project / '.claude/settings.json', {'enabledPlugins': {'arch-core@architectures': True}})

    def write(self, path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data))

    def install(self, version='1.9.0', scope='project', project=None):
        target = self.home / '.claude/plugins/cache/architectures/arch-core' / version
        self.write(target / '.claude-plugin/plugin.json', {'name': 'arch-core', 'version': version})
        entry = {'scope': scope, 'installPath': str(target), 'version': version, 'gitCommitSha': 'fixture'}
        if scope != 'user':
            entry['projectPath'] = str(project or self.project)
        self.write(self.registry, {'plugins': {'arch-core@architectures': [entry]}})
        return target

    def run_sync(self, *args):
        return subprocess.run(['sh', str(SYNC), '--json', *args], cwd=self.project,
                              env={**os.environ, 'HOME': str(self.home)}, text=True, capture_output=True)

    def test_missing_plugin_fails_strict(self):
        result = self.run_sync('--strict')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(json.loads(result.stdout)['plugins']['arch-core']['state'], 'MISSING')

    def test_highest_cache_is_not_project_installation(self):
        self.install('1.8.0')
        self.write(self.home / '.claude/plugins/cache/architectures/arch-core/1.9.0/.claude-plugin/plugin.json', {'version': '1.9.0'})
        result = self.run_sync('--strict')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)['plugins']['arch-core']['installed'], '1.8.0')

    def test_read_only_default_and_explicit_write(self):
        self.install()
        result = self.run_sync('--strict')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.project / '.claude/blueprint-sync.json').exists())
        result = self.run_sync('--write')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((self.project / '.claude/blueprint-sync.json').read_text()), json.loads(result.stdout))

    def test_other_project_does_not_count(self):
        self.install(project=self.home / 'different-project')
        result = self.run_sync('--strict')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)['plugins']['arch-core']['state'], 'MISSING')

    def test_user_install_and_project_disable(self):
        self.install(scope='user')
        self.assertEqual(self.run_sync('--strict').returncode, 0)
        self.write(self.project / '.claude/settings.local.json', {'enabledPlugins': {'arch-core@architectures': False}})
        result = self.run_sync('--strict')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)['plugins'], {})

    def test_ahead_and_invalid_artifact(self):
        target = self.install('2.0.0')
        result = self.run_sync('--strict')
        self.assertEqual(json.loads(result.stdout)['plugins']['arch-core']['state'], 'AHEAD')
        self.assertEqual(result.returncode, 1)
        self.write(target / '.claude-plugin/plugin.json', {'name': 'arch-core', 'version': '1.0.0'})
        result = self.run_sync('--strict')
        self.assertEqual(json.loads(result.stdout)['plugins']['arch-core']['state'], 'INVALID')

    def test_shadowed_agent(self):
        target = self.install()
        (target / 'agents').mkdir()
        (target / 'agents/audit.md').write_text('same')
        local = self.project / 'apps/demo/.claude/agents/audit.md'
        local.parent.mkdir(parents=True)
        local.write_text('same')
        result = self.run_sync('--strict')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)['shadowedAgents'][0]['state'], 'DUPLICATE')

    def test_worktree_inherits_registered_checkout(self):
        subprocess.run(['git', 'init', '-q', str(self.project)], check=True)
        subprocess.run(['git', '-C', str(self.project), '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '--allow-empty', '-qm', 'fixture'], check=True)
        self.install()
        linked = Path(self.temp.name) / 'linked'
        subprocess.run(['git', '-C', str(self.project), 'worktree', 'add', '--detach', str(linked)], check=True, capture_output=True)
        self.write(linked / '.claude/settings.json', {'enabledPlugins': {'arch-core@architectures': True}})
        self.project = linked
        result = self.run_sync('--strict')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['plugins']['arch-core']['installed'], '1.9.0')


if __name__ == '__main__':
    unittest.main()
