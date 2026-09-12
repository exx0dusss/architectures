"""Advisory PostToolUse context; bundled verbatim into standalone hook plugins."""
import json
import re
import sys


def context(kind, event):
    if not isinstance(event, dict) or event.get('hook_event_name') != 'PostToolUse':
        return None
    if event.get('tool_name') not in ('Edit', 'Write'):
        return None
    data = event.get('tool_input')
    if not isinstance(data, dict) or not isinstance(data.get('file_path'), str):
        return None
    path = data['file_path'].replace('\\', '/')
    if kind == 'ui' and re.search(r'components/|styles/|globals\.css$|tailwind', path):
        return 'UI surface changed: read the owning app instructions and arch-ui before adding variants, colours or text sizes.'
    if kind == 'schema' and re.search(r'database/schema/|drizzle\.config|/migrations/|\.sql$', path):
        return 'Schema or migration touched: generate, review SQL, then migrate; never push. Read the owning app migration instructions and arch-services.'
    content = '\n'.join(data.get(key, '') for key in ('new_string', 'content') if isinstance(data.get(key, ''), str))
    if kind == 'module' and re.search(r'src/modules/[\w-]+/', path) and re.search(r'from\s+[\'"][^\'"\n]*modules/', content):
        return 'Module import touched: read arch-modules and the owning app boundary rules; distinguish supported public interfaces from another module\'s internals before choosing synchronous calls or events.'
    return None


def main():
    try:
        event = json.load(sys.stdin)
    except (ValueError, UnicodeError):
        return
    message = context(sys.argv[1], event)
    if message:
        print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': message}}))


if __name__ == '__main__':
    main()
