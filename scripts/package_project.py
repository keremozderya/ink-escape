"""Create a clean native source ZIP alongside the project, without caches or secrets."""
from pathlib import Path
import zipfile
root=Path(__file__).resolve().parents[1]
out=root.parent/'ink_escape_flutter_v0_3.zip'
roots=['lib','assets','android','ios','test','scripts','docs','.vscode']
files=['pubspec.yaml','pubspec.lock','analysis_options.yaml','README.md','.gitignore','.metadata']
exclude={'.git','.dart_tool','.idea','build','dist','.gradle','Pods','.symlinks','__pycache__','ephemeral'}
excluded_names={'local.properties','key.properties','Generated.xcconfig','flutter_export_environment.sh','.flutter-plugins-dependencies'}
paths=[root/p for p in files if (root/p).is_file()]
paths.extend(p for name in roots for p in (root/name).rglob('*') if p.is_file())
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in sorted(paths):
        rel=p.relative_to(root)
        if any(part in exclude for part in rel.parts) or p.name in excluded_names or p.suffix in {'.log','.jks','.keystore'}:continue
        z.write(p,'ink-escape/'+str(rel))
print(out)
print('Files:',len(zipfile.ZipFile(out).namelist()),'MiB:',round(out.stat().st_size/1024/1024,2))
