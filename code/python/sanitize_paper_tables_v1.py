from pathlib import Path

BASE = Path('/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war/paper/assets/tables')

for path in BASE.glob('*.tex'):
    text = path.read_text()
    lines = text.splitlines()
    out = []
    for line in lines:
        if line.startswith(r'\def\sym#1'):
            out.append(line)
        else:
            out.append(line.replace('#', r'\#'))
    path.write_text('\n'.join(out) + ('\n' if text.endswith('\n') else ''))
    print(path.name)
