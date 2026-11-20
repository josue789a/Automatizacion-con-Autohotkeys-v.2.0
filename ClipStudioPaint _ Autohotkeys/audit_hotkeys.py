import os, re

root_dir = r"C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys"
out_a = os.path.join(root_dir, "hotkeys_sin_gatear.txt")
out_b = os.path.join(root_dir, "hotkeys_dinamicos.txt")

lines_a = []
lines_b = []

# Regex patterns
re_hotif = re.compile(r"^\s*#HotIf\b(.*)$", re.IGNORECASE)
re_hk = re.compile(r"^\s*([~*$<>!+^#]*[^\s:;{,\"]+(?:\s+&\s+[^\s:;{,\"]+)?(?:\s+up)?)::")
re_dyn = re.compile(r"^\s*(HotIf\(|Hotkey\()", re.IGNORECASE)

for root, dirs, files in os.walk(root_dir):
    # Skip baks, respaldos, historico
    if any(x in root.lower() for x in ["respaldos", "bak", "_historico", ".git"]):
        continue
    for f in sorted(files):
        if f.endswith(".ahk") and not ".bak" in f:
            fpath = os.path.join(root, f)
            rel_name = os.path.relpath(fpath, root_dir)
            with open(fpath, "r", encoding="utf-8", errors="ignore") as fp:
                file_lines = fp.readlines()
            
            ctx = ""
            for idx, l in enumerate(file_lines):
                n = idx + 1
                # Check HotIf
                m_hotif = re_hotif.match(l)
                if m_hotif:
                    ctx = m_hotif.group(1).strip()
                    continue
                
                # Check static hotkey without gate
                if ctx and not any(k in ctx for k in ["Cap_Armado", "CspLibre"]):
                    m_hk = re_hk.match(l)
                    if m_hk:
                        hk_name = m_hk.group(1)
                        lines_a.append(f"{rel_name}:{n} | {hk_name} | #HotIf {ctx}")
                
                # Check dynamic HotIf / Hotkey
                if re_dyn.search(l):
                    lines_b.append(f"{rel_name}:{n}: {l.strip()}")

with open(out_a, "w", encoding="utf-8") as fp:
    fp.write("\n".join(lines_a) + "\n")

with open(out_b, "w", encoding="utf-8") as fp:
    fp.write("\n".join(lines_b) + "\n")

print(f"Auditoría A: {len(lines_a)} líneas -> {out_a}")
print(f"Auditoría B: {len(lines_b)} líneas -> {out_b}")
