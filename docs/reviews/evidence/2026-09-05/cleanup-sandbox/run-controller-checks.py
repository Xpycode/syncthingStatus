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
    return result.stdout
def seed():
    for path in [root/'candidate/sentinel', root.parent/'candidate/sentinel', root.parent/'OtherProject/candidate/sentinel']:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('disposable-sentinel')
def check(deleted):
    assert (root/'candidate/sentinel').exists() != deleted
    for path in [root.parent/'candidate/sentinel', root.parent/'OtherProject/candidate/sentinel']:
        assert path.read_text() == 'disposable-sentinel'
    log.append('sentinels=passed;intendedDeleted=' + str(deleted) + '\n')
    print(log[-1], end='', flush=True)
seed()
run('EXACT_PICKER_CONTROLLER', 'python3', str(base/'run-grant.py'), 'controller')
out = run('EXACT_PERSISTED_CONTROLLER_DELETION', str(app), 'controller-delete', str(root), str(root))
assert 'deleted=1;failed=0;blocked=false;obsolete=false' in out
check(True)
seed()
run('ANCESTOR_PICKER_CONTROLLER', 'python3', str(base/'run-grant.py'), 'controller', 'ancestor')
out = run('ANCESTOR_PERSISTED_CONTROLLER_DELETION', str(app), 'controller-delete', str(root), str(root.parent))
assert 'deleted=1;failed=0;blocked=false;obsolete=false' in out
check(True)
seed()
out = run('OPEN_CONTROLLER_AUTHORITATIVE_PATH_CHANGED', str(app), 'controller-path-change', str(root), str(root.parent))
assert 'deleted=0;failed=1;blocked=false;obsolete=true' in out
check(False)
run('CLEAR_BOOKMARK', str(app), 'clear', str(root), str(root.parent))
out = run('CLEARED_BOOKMARK_FRESH_CONTROLLER', str(app), 'controller-delete', str(root), str(root.parent))
assert 'deleted=0;failed=0;blocked=true;obsolete=false' in out
check(False)
(base/'controller-results.txt').write_text('\n'.join(log))
