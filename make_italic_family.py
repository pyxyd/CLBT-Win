"""
Turn the *Italic* style of a Nerd Font into its own standalone family so that
Windows Terminal can select it as a normal font face.

Windows Terminal lists font *families* only (and has no italic option), so a
family whose "Regular" face is drawn with italic glyphs is the only way to get
an all-italic terminal.
"""
import os
import shutil
from fontTools.ttLib import TTFont

SRC = r"D:\e2489fa5-12ed-4762-b054-dccb91f65c90\0xProtoNerdFontMono-Italic.ttf"
OUTDIR = r"D:\e2489fa5-12ed-4762-b054-dccb91f65c90\italic-family"
OUTNAME = "0xProtoMonoItalic-Regular.ttf"

# NOTE: the family name must NOT be "<original family> Italic", because Windows
# keys HKLM\...\Fonts by "<family> <style> (TrueType)" -- that would collide with
# the original family's Italic *style* entry and clobber it.
NEW_FAMILY = "0xProto Mono Italic"
NEW_PS = "0xProtoMonoItalic"                  # PostScript name: ASCII, no spaces, unique
NEW_UNIQUE = f"{NEW_FAMILY};v1;{NEW_PS}"

os.makedirs(OUTDIR, exist_ok=True)
out = os.path.join(OUTDIR, OUTNAME)

font = TTFont(SRC)
name = font["name"]


def dump(label: str) -> None:
    print(f"--- {label} ---")
    for nid in (1, 2, 3, 4, 6, 16, 17, 18, 21, 22):
        rec = name.getDebugName(nid)
        if rec is not None:
            print(f"  nameID {nid:>2}: {rec}")
    os2 = font["OS/2"]
    print(f"  fsSelection : 0x{os2.fsSelection:04X}  (ITALIC={os2.fsSelection & 1}, "
          f"BOLD={(os2.fsSelection >> 5) & 1}, REGULAR={(os2.fsSelection >> 6) & 1})")
    print(f"  usWeightClass: {os2.usWeightClass}")
    print(f"  head.macStyle: 0x{font['head'].macStyle:04X}  "
          f"(bold={font['head'].macStyle & 1}, italic={(font['head'].macStyle >> 1) & 1})")
    print(f"  post.italicAngle: {font['post'].italicAngle}")


dump("BEFORE")

# 1) rewrite the name records we care about, preserving platform/encoding/lang
new_values = {
    1: NEW_FAMILY,    # family
    2: "Regular",     # subfamily -> this face IS the regular one of the new family
    3: NEW_UNIQUE,    # unique identifier
    4: NEW_FAMILY,    # full name
    6: NEW_PS,        # PostScript name
    16: NEW_FAMILY,   # typographic family
    17: "Regular",    # typographic subfamily
}
for rec in list(name.names):
    if rec.nameID in new_values:
        name.setName(new_values[rec.nameID], rec.nameID,
                     rec.platformID, rec.platEncID, rec.langID)

# drop stale compatibility/WWS name records that still carry the old family name
for nid in (18, 21, 22):
    name.removeNames(nameID=nid)

# 2) clear the italic/bold style bits so DirectWrite treats this as the family's Regular
os2 = font["OS/2"]
os2.fsSelection = (os2.fsSelection & ~0x01 & ~0x20) | 0x40   # clear ITALIC|BOLD, set REGULAR
os2.usWeightClass = 400

head = font["head"]
head.macStyle &= ~0x01 & ~0x02                                # clear bold + italic

font["post"].italicAngle = 0.0                                # glyphs stay slanted; metadata says Regular

dump("AFTER (in-memory)")

font.save(out)
print(f"\nSaved: {out}  ({os.path.getsize(out)} bytes)")

# 3) re-open the written file and confirm what Windows will see
check = TTFont(out)
print("\n--- RE-READ from disk ---")
for nid in (1, 2, 4, 6, 16, 17):
    print(f"  nameID {nid:>2}: {check['name'].getDebugName(nid)}")
print(f"  fsSelection: 0x{check['OS/2'].fsSelection:04X}, macStyle: 0x{check['head'].macStyle:04X}, "
      f"italicAngle: {check['post'].italicAngle}")
print(f"  glyph count: {check['maxp'].numGlyphs}, cmap subtables: {len(check['cmap'].tables)}")
print(f"  unitsPerEm: {check['head'].unitsPerEm}")
