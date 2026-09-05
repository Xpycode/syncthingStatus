from pathlib import Path
import subprocess
base=Path('/private/tmp/syncthingStatus-sandbox-probe')
app=base/'FixtureAccess.app/Contents/MacOS/FixtureAccess'
root=base/'fixtures/Sync/Project'
retired=root.parent/'RetiredProject'
log=[]
def run(label,*args):
    result=subprocess.run(args,check=True,capture_output=True,text=True,timeout=45)
    message=label+'\n'+result.stdout
    log.append(message)
    print(message,end='',flush=True)
    return result.stdout
(root/'candidate').mkdir(exist_ok=True)
(root/'candidate/sentinel').write_text('disposable-sentinel')
run('ANCESTOR_PICKER','python3',str(base/'run-grant.py'),'controller','ancestor')
try:
    root.chmod(0o000)
    out=run('FILESYSTEM_PERMISSION_REVOKED',str(app),'controller-delete',str(root),str(root.parent))
    assert 'deleted=0;failed=0;blocked=true;obsolete=false' in out
finally:
    root.chmod(0o755)
assert (root/'candidate/sentinel').read_text()=='disposable-sentinel'
run('EXACT_PICKER','python3',str(base/'run-grant.py'),'controller')
other=root.parent/'OtherProject'
(other/'candidate').mkdir(parents=True,exist_ok=True)
(other/'candidate/sentinel').write_text('other-sentinel')
out=run('OBSOLETE_EXACT_BOOKMARK_FOR_CHANGED_CONFIG_ROOT',str(app),'controller-delete',str(other),str(root))
assert 'deleted=0;failed=0;blocked=true;obsolete=false' in out
assert (root/'candidate/sentinel').read_text()=='disposable-sentinel'
assert (other/'candidate/sentinel').read_text()=='other-sentinel'
(other/'candidate/sentinel').write_text('disposable-sentinel')
run('CLEAR_FIXTURE_BOOKMARK',str(app),'clear',str(root),str(root))
log.append('revocationAndObsoleteGrantSentinels=passed\n')
print(log[-1],end='',flush=True)
(base/'revocation-results.txt').write_text('\n'.join(log))
