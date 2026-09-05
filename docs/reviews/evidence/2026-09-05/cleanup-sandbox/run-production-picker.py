from pathlib import Path
import subprocess,time,json
b=Path('/private/tmp/syncthingStatus-sandbox-probe'); r=b/'fixtures/Sync/Project'; log=[]
def rec(s):log.append(s);print(s,flush=True)
def rows(p):return json.loads(subprocess.run([str(b/'ax-window'),str(p.pid),'dump'],check=True,capture_output=True,text=True).stdout)
def wait(p,pred):
    end=time.monotonic()+12
    while time.monotonic()<end:
        current=rows(p)
        if pred(current): return current
        time.sleep(.1)
    raise RuntimeError('Expected fixture UI did not appear')
def has(current,name):return any(x['title']==name or x['label']==name or x.get('value')==name for x in current)
def press(p,name):
    wait(p,lambda x:any((n["title"]==name or n["label"]==name) and n["enabled"] for n in x))
    rec(name+': '+subprocess.run([str(b/'ax-window'),str(p.pid),name],check=True,capture_output=True,text=True).stdout.strip())
rec(subprocess.run([str(b/'FixtureAccess.app/Contents/MacOS/FixtureAccess'),'clear',str(r),str(r.parent)],check=True,capture_output=True,text=True).stdout)
(r/'candidate').mkdir(exist_ok=True);(r/'candidate/sentinel').write_text('disposable-sentinel')
p=subprocess.Popen([str(b/'FixtureAccess.app/Contents/MacOS/FixtureAccess'),'controller-window',str(r),str(r.parent)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
try:
    wait(p,lambda x:has(x,'Folder Access Required'));rec('accessGate=visible')
    press(p,'Grant Access')
    wait(p,lambda x:any('Grant syncthingStatus access to' in str(n.get('value','')) for n in x));rec('productionPicker=visible')
    press(p,'Grant Access')
    wait(p,lambda x:has(x,'Select All'));rec('productionPickerGrant=accepted')
    press(p,'Select All');press(p,'Delete 1 selected');press(p,'Delete Permanently')
    wait(p,lambda x:has(x,'No stuck deletions found'))
    assert not (r/'candidate').exists()
    assert (r.parent/'candidate/sentinel').read_text()=='disposable-sentinel'
    press(p,'Close');rec(p.communicate(timeout=10)[0]);rec('productionPickerThroughMutation=passed')
finally:
    if p.poll() is None:p.terminate();p.communicate(timeout=5)
rec(subprocess.run([str(b/'FixtureAccess.app/Contents/MacOS/FixtureAccess'),'clear',str(r),str(r.parent)],check=True,capture_output=True,text=True).stdout)
(b/'production-picker-results.txt').write_text('\n'.join(log))
