from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[4]
out=Path('/private/tmp/syncthing-layout-check')
out.mkdir(exist_ok=True)
for version in ('before','after'):
    source=subprocess.check_output(['git','show','v1.6.1:01_Project/syncthingStatus/Views.swift'],cwd=root,text=True) if version=='before' else (root/'01_Project/syncthingStatus/Views.swift').read_text()
    row=source[source.index('struct FolderStatusRow:'):source.index('// MARK: - Stuck Deletes Cleanup Window')]
    compact=row[row.index('    private var compactView:'):row.index('    private var localFilesAndSizeColumns:')]
    icons=row[row.index('    private var statusIcon:'):]
    (out/f'{version}.swift').write_text('import SwiftUI\nstruct FixtureRow: View {\nlet syncthingClient = SyncthingClient()\nlet folder: SyncthingFolder\nlet status: SyncthingFolderStatus?\nvar body: some View { compactView }\n'+compact+icons)

for version in ('before', 'after'):
    binary=out/version
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', str(Path(__file__).with_name('Harness.swift')), str(out/f'{version}.swift'), *[str(root/'01_Project/syncthingStatus'/f'{name}.swift') for name in ('Models','Constants','Helpers')], '-o', str(binary)], check=True)
    result=subprocess.run([str(binary), version], capture_output=True, text=True, check=True)
    print(result.stdout, end='')
    (out/f'{version}.txt').write_text(result.stdout)
    if version == 'after':
        import re
        heights={}
        for line in result.stdout.splitlines():
            match=re.fullmatch(r'after width=(\S+) state=(\S+) long=(\S+) height=(\S+)', line)
            assert match, line
            width,state,long,height=match.groups()
            height=float(height)
            assert height < 100, line
            key=(width,state)
            if long == 'true':
                assert height == heights[key], line
            else:
                heights[key]=height
        assert len(heights) == 10
        print('PASS: long names preserve short-name row heights across 20 cases')
