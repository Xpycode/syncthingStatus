from pathlib import Path
import subprocess, time
b=Path('/private/tmp/syncthingStatus-sandbox-probe')
r=b/'fixtures/Sync/Project'
subprocess.run(['python3',str(b/'run-grant.py'),'controller','ancestor'],check=True)
p=subprocess.Popen([str(b/'FixtureAccess.app/Contents/MacOS/FixtureAccess'),'controller-window',str(r),str(r.parent)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
try:
    time.sleep(1)
    print(subprocess.run([str(b/'ax-window'),str(p.pid),'dump'],capture_output=True,text=True).stdout)
    subprocess.run([str(b/'ax-window'),str(p.pid),'Close'],check=True)
    print(p.communicate(timeout=10)[0])
finally:
    if p.poll() is None: p.terminate()
