import os
import glob

# Buscar en Desktop, Documentos y Descargas cualquier archivo modificado en los ultimos 10 dias que contenga config o xppen o xml
home = os.path.expanduser("~")
folders = [os.path.join(home, "Desktop"), os.path.join(home, "Documents"), os.path.join(home, "Downloads")]

found = []
for fld in folders:
    for root, dirs, files in os.walk(fld):
        if "node_modules" in root or ".git" in root or "brain" in root:
            continue
        for f in files:
            if f.endswith((".xml", ".xppen", ".cfg", ".json")):
                full = os.path.join(root, f)
                try:
                    mtime = os.path.getmtime(full)
                    found.append((mtime, full))
                except:
                    pass

found.sort(reverse=True)
for mtime, p in found[:20]:
    import datetime
    dt = datetime.datetime.fromtimestamp(mtime).strftime('%Y-%m-%d %H:%M:%S')
    print(f"{dt} -> {p}")
