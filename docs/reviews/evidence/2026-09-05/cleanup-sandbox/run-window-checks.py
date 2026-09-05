from pathlib import Path
import subprocess,time,json
b=Path('/private/tmp/syncthingStatus-sandbox-probe'); r=b/'fixtures/Sync/Project'; log=[]
def record(s): log.append(s); print(s,flush=True)
def dump(p): return json.loads(subprocess.run([str(b/'ax-window'),str(p.pid),'dump'],check=True,capture_output=True,text=True).stdout)
def wait(p,predicate):
    end=time.monotonic()+12
    while time.monotonic()<end:
        rows=dump(p)
        if predicate(rows): return rows
        if p.poll() is not None: raise RuntimeError('Harness exited early')
        time.sleep(.1)
    raise RuntimeError('Timed out waiting for owned fixture control: '+json.dumps(rows))
def node(rows,name): return next((x for x in rows if x['title']==name or x['label']==name),None)
def press(p,name):
    wait(p,lambda rows:(x:=node(rows,name)) is not None and x['enabled'])
    out=subprocess.run([str(b/'ax-window'),str(p.pid),name],check=True,capture_output=True,text=True).stdout.strip()
    record(name+': '+out)
def check(p,name,enabled=True):
    wait(p,lambda rows:(x:=node(rows,name)) is not None and x['enabled']==enabled)
    record(name+': enabled='+str(enabled))
def text(p,value):
    wait(p,lambda rows:any(value in str(x.get('value','')) for x in rows))
    record('visible='+value)
def sentinel():
    (r/'candidate').mkdir(exist_ok=True)
    (r/'candidate/sentinel').write_text('disposable-sentinel')
    (r.parent/'candidate').mkdir(exist_ok=True)
    (r.parent/'candidate/sentinel').write_text('disposable-sentinel')
record(subprocess.run(['python3',str(b/'run-grant.py'),'controller','ancestor'],check=True,capture_output=True,text=True,timeout=45).stdout)
for mode in ['controller-window','controller-window-failure','controller-window-partial']:
    sentinel(); record(mode)
    p=subprocess.Popen([str(b/'FixtureAccess.app/Contents/MacOS/FixtureAccess'),mode,str(r),str(r.parent)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    try:
        check(p,'Delete selected',False)
        rows=wait(p,lambda rows:any(x['role']=='AXCheckBox' for x in rows))
        record('checkboxLabels='+json.dumps([x['label'] for x in rows if x['role']=='AXCheckBox']))
        press(p,'Select All'); count=2 if mode.endswith('partial') else 1
        check(p,f'Delete {count} selected')
        press(p,'Deselect All'); check(p,'Delete selected',False)
        press(p,'Select All'); press(p,f'Delete {count} selected')
        press(p,'Cancel'); check(p,f'Delete {count} selected')
        assert (r/'candidate/sentinel').read_text()=='disposable-sentinel'
        press(p,f'Delete {count} selected'); press(p,'Delete Permanently')
        if mode.endswith('failure'):
            text(p,'Cleanup needs attention')
            assert (r/'candidate/sentinel').read_text()=='disposable-sentinel'
            check(p,'Delete 1 selected',False)
            press(p,'Retry'); check(p,'Delete 1 selected')
            record('failedPreflightSelectionRetained=true')
            press(p,'Delete 1 selected'); press(p,'Delete Permanently')
        if mode.endswith('partial'):
            text(p,'1 deleted, 1 failed'); check(p,'Delete 1 selected')
            rows=dump(p)
            assert any(x['role']=='AXCheckBox' and '../unsafe' in x['label'] and x['value']==1 for x in rows)
            record('partialFailureSelectionRetained=true')
        else:
            text(p,'No stuck deletions found')
            text(p,'Cleaned up 1 folder. Syncthing has been asked to rescan')
        assert not (r/'candidate').exists()
        assert (r.parent/'candidate/sentinel').read_text()=='disposable-sentinel'
        press(p,'Close'); out=p.communicate(timeout=10)[0]; record(out)
        assert 'unexpectedHTTP=0' in out
        record('windowAndSentinels=passed')
    finally:
        if p.poll() is None: p.terminate(); p.communicate(timeout=5)
(b/'window-results.txt').write_text('\n'.join(log))
