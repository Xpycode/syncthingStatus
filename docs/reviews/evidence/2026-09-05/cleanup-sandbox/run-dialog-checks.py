from pathlib import Path
import subprocess, time
base = Path('/private/tmp/syncthingStatus-sandbox-probe')
app = base/'FixtureAccess.app/Contents/MacOS/FixtureAccess'
root = base/'fixtures/Sync/Project'
log=[]
def record(value):
    log.append(value)
    print(value,end='',flush=True)
record(subprocess.run(['python3',str(base/'run-grant.py'),'controller','ancestor'],check=True,capture_output=True,text=True,timeout=45).stdout)
for mode, button, accepted in [('cancel','Cancel',False),('stale','Cancel',False),('many','Cancel',False),('delete','Delete Permanently',True)]:
    sentinel=root/'candidate/sentinel'
    sentinel.parent.mkdir(parents=True,exist_ok=True)
    sentinel.write_text('disposable-sentinel')
    proc = subprocess.Popen([str(app),'controller-dialog-'+mode,str(root),str(root.parent)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    record('DIALOG_'+mode.upper()+'\n')
    pressed=None
    try:
        for _ in range(40):
            if proc.poll() is not None: break
            result=subprocess.run([str(base/'ax-dialog'),str(proc.pid),button],capture_output=True,text=True)
            if result.returncode==0:
                pressed=result.stdout
                record(pressed)
                break
            time.sleep(0.25)
        out=proc.communicate(timeout=15)[0]
        record(out)
    except subprocess.TimeoutExpired:
        proc.terminate()
        record(proc.communicate(timeout=5)[0])
        raise
    assert pressed is not None
    assert 'scrollArea=true' in pressed
    assert 'selectionText=candidate' in pressed
    if mode == 'many': assert 'candidate-080' in pressed
    if mode == 'stale': assert 'obsolete=true' in out
    assert 'Configured folder root:' in pressed
    assert 'deleteEnabled='+str(mode!='stale').lower() in pressed
    assert 'dialogAccepted='+str(accepted).lower() in out
    assert sentinel.exists()!=accepted
    assert (root.parent/'candidate/sentinel').read_text()=='disposable-sentinel'
    record('dialogAndSentinels=passed\n')
(base/'dialog-results.txt').write_text('\n'.join(log))
