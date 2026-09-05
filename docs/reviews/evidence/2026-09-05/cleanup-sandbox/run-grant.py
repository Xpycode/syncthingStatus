from pathlib import Path
import subprocess, time, sys
base = Path('/private/tmp/syncthingStatus-sandbox-probe')
app = base / 'FixtureAccess.app/Contents/MacOS/FixtureAccess'
fixture = base / 'fixtures/Sync/Project'
scope = fixture.parent if 'ancestor' in sys.argv else fixture
mode = 'controller-grant' if 'controller' in sys.argv else 'grant'
proc = subprocess.Popen([str(app), mode, str(fixture), str(scope)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
print('harness_pid=' + str(proc.pid), flush=True)
try:
    for _ in range(25):
        if proc.poll() is not None:
            break
        pressed = subprocess.run([str(base / 'ax-press'), str(proc.pid)], capture_output=True, text=True)
        if pressed.returncode == 0:
            print(pressed.stdout, end='', flush=True)
            break
        time.sleep(0.4)
    print(proc.communicate(timeout=15)[0], end='')
except subprocess.TimeoutExpired:
    proc.terminate()
    print(proc.communicate(timeout=5)[0], end='')
    raise
