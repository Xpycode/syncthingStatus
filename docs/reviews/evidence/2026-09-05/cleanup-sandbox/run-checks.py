from pathlib import Path
import subprocess
base = Path('/private/tmp/syncthingStatus-sandbox-probe')
app = base / 'FixtureAccess.app/Contents/MacOS/FixtureAccess'
root = base / 'fixtures/Sync/Project'
log = []
def run(label, *args):
    result = subprocess.run(args, capture_output=True, text=True, check=True, timeout=45)
    log.append(label + '\n' + result.stdout)
    print(log[-1], end='', flush=True)
run('EXACT_PERSISTED', str(app), 'resolve', str(root), str(root))
run('CLEAR', str(app), 'clear', str(root), str(root))
run('CLEARED_FRESH_PROCESS', str(app), 'resolve', str(root), str(root))
run('ANCESTOR_PICKER', 'python3', str(base / 'run-grant.py'), 'ancestor')
run('ANCESTOR_PERSISTED', str(app), 'resolve', str(root), str(root.parent))
run('CLEAR_ANCESTOR', str(app), 'clear', str(root), str(root.parent))
run('CLEARED_ANCESTOR_FRESH_PROCESS', str(app), 'resolve', str(root), str(root.parent))
(base / 'bookmark-results.txt').write_text('\n'.join(log))
