"""Inspect registered Claude installations; cache presence never proves project availability."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def read_json(path, default=None):
    if not path.exists():
        return {} if default is None else default
    with path.open() as stream:
        result = json.load(stream)
    if not isinstance(result, dict):
        raise ValueError('{} must contain an object'.format(path))
    return result


def git(path, *args):
    result = subprocess.run(['git', '-C', str(path), *args], text=True, capture_output=True)
    return result.stdout.strip() if result.returncode == 0 else None


def common_dir(path):
    value = git(path, 'rev-parse', '--git-common-dir') if path.is_dir() else None
    return (path / value).resolve() if value else None


def select_install(entries, root):
    candidates = []
    shared = common_dir(root)
    for entry in entries:
        scope = entry.get('scope')
        if scope == 'user':
            candidates.append((1, entry))
        elif scope in ('project', 'local') and entry.get('projectPath'):
            project = Path(entry['projectPath']).expanduser().resolve()
            if project == root:
                candidates.append((5 if scope == 'local' else 4, entry))
            elif scope == 'project' and shared and common_dir(project) == shared:
                candidates.append((2, entry))
    if not candidates:
        return None
    rank = max(rank for rank, _ in candidates)
    best = [entry for priority, entry in candidates if priority == rank]
    if len(best) != 1:
        raise ValueError('Ambiguous installation records for {}'.format(root))
    return best[0]


def version_state(installed, advertised):
    if not advertised or not installed:
        return 'UNKNOWN'
    if installed == advertised:
        return 'CURRENT'
    if all(re.fullmatch(r'\d+\.\d+\.\d+', version) for version in (installed, advertised)):
        return 'AHEAD' if tuple(map(int, installed.split('.'))) > tuple(map(int, advertised.split('.'))) else 'BEHIND'
    return 'UNKNOWN'


def local_agents(root):
    tracked = git(root, 'ls-files', '--cached', '--others', '--exclude-standard', '-z')
    if tracked is not None:
        paths = [root / name for name in tracked.split('\0') if name]
    else:
        paths = []
        for directory, dirs, files in os.walk(str(root)):
            dirs[:] = [name for name in dirs if name not in ('.git', 'node_modules', '.worktrees', 'worktrees')]
            paths.extend(Path(directory) / name for name in files if name.endswith('.md'))
    return sorted(set(path for path in paths if '.claude/agents/' in path.as_posix()
                      and path.suffix == '.md' and path.is_file()
                      and not any(part in ('node_modules', '.worktrees', 'worktrees') for part in path.relative_to(root).parts)))


def inspect(root, home, marketplace, config=None):
    config = config or home / '.claude'
    name = marketplace.rsplit('/', 1)[-1]
    settings = read_json(config / 'settings.json').get('enabledPlugins', {}).copy()
    for filename in ('settings.json', 'settings.local.json'):
        settings.update(read_json(root / '.claude' / filename).get('enabledPlugins', {}))
    registry = read_json(config / 'plugins/installed_plugins.json').get('plugins', {})
    known = read_json(config / 'plugins/known_marketplaces.json').get(name, {})
    location = known.get('installLocation')
    marketplace_root = Path(location).expanduser() if location else config / 'plugins/marketplaces' / name
    manifest = read_json(marketplace_root / '.claude-plugin/marketplace.json')
    advertised = {plugin['name']: plugin.get('version') for plugin in manifest.get('plugins', [])}
    rows, agents = {}, {}
    for key, enabled in sorted(settings.items()):
        if enabled is not True or not key.endswith('@' + name):
            continue
        plugin = key.rsplit('@', 1)[0]
        entry = select_install(registry.get(key, []), root)
        row = {'requested': True, 'installed': None, 'advertised': advertised.get(plugin),
               'state': 'MISSING', 'scope': None, 'installPath': None, 'gitCommitSha': None,
               'loaded': 'UNVERIFIED'}
        if entry:
            row.update({field: entry.get(field) for field in ('scope', 'installPath', 'gitCommitSha')})
            row['installed'] = entry.get('version')
            location = Path(entry['installPath']).expanduser() if entry.get('installPath') else None
            artifact = location / '.claude-plugin/plugin.json' if location else None
            if artifact and artifact.is_file():
                metadata = read_json(artifact)
                row['state'] = version_state(row['installed'], row['advertised'])
                if metadata.get('name') != plugin or metadata.get('version') != row['installed']:
                    row['state'] = 'INVALID'
                for path in sorted((location / 'agents').glob('*.md')):
                    agents.setdefault(path.name, []).append((plugin, path))
        rows[plugin] = row
    shadows = []
    for local in local_agents(root):
        for plugin, source in agents.get(local.name, []):
            shadows.append({'agent': local.stem, 'plugin': plugin, 'local': str(local.relative_to(root)),
                            'source': str(source), 'state': 'DUPLICATE' if local.read_bytes() == source.read_bytes() else 'FORK'})
    return {'marketplace': marketplace, 'runtime': 'claude', 'scope': 'effective-project',
            'project': str(root), 'configDirectory': str(config), 'marketplaceRoot': str(marketplace_root), 'checkedAt': datetime.now(timezone.utc).isoformat(),
            'plugins': rows, 'shadowedAgents': shadows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--marketplace', default='exx0dusss/architectures')
    parser.add_argument('--project', type=Path, default=Path.cwd())
    parser.add_argument('--runtime', choices=['claude'], default='claude', help='Other runtimes require their own installation resolver')
    parser.add_argument('--strict', action='store_true', help='Fail any non-current registration or shadow; does not attest live session loading')
    parser.add_argument('--json', action='store_true')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--write', action='store_true', help='Atomically save .claude/blueprint-sync.json')
    mode.add_argument('--check', action='store_true', help='Read-only inspection (default)')
    args = parser.parse_args()
    root = args.project.resolve()
    if not root.is_dir():
        parser.error('project directory does not exist')
    root = Path(git(root, 'rev-parse', '--show-toplevel') or root).resolve()
    try:
        config = Path(os.environ['CLAUDE_CONFIG_DIR']).expanduser().resolve() if os.environ.get('CLAUDE_CONFIG_DIR') else Path.home() / '.claude'
        report = inspect(root, Path.home(), args.marketplace, config)
        if args.write:
            destination = root / '.claude/blueprint-sync.json'
            destination.parent.mkdir(exist_ok=True)
            with tempfile.NamedTemporaryFile(mode='w', dir=str(destination.parent), delete=False) as stream:
                json.dump(report, stream, indent=2)
                stream.write('\n')
                temporary = stream.name
            os.replace(temporary, str(destination))
        if args.json:
            print(json.dumps(report, indent=2))
        else:
            for name, row in report['plugins'].items():
                print('{} {} installed={} advertised={} scope={}'.format(name, row['state'], row['installed'], row['advertised'], row['scope']))
            for row in report['shadowedAgents']:
                print('{} {} {}'.format(row['agent'], row['state'], row['local']))
            if not report['plugins']:
                print('No marketplace plugins requested by effective settings.')
            print('Registration checked; live session loading unverified. ' + ('Snapshot written.' if args.write else 'Read-only; use --write to save snapshot.'))
        return int(args.strict and (bool(report['shadowedAgents']) or any(row['state'] != 'CURRENT' for row in report['plugins'].values())))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print('arch-sync-check: {}'.format(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
