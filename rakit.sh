#!/data/data/com.termux/files/usr/bin/sh
# rakit: assembler mini yang ditulis dalam BK (tahap 1)
# pakai: rakit berkas.s keluaran
D="$HOME/bahasaku"
[ -f "$1" ] && [ -n "$2" ] || { echo "pakai: rakit berkas.s keluaran"; exit 1; }
[ -f "$D/alat/asm1.bk" ] || { echo "rakit: alat/asm1.bk tidak ada"; exit 1; }
H=$(mktemp)
cp "$1" "$D/.rakit.s" || exit 1
( cd "$D" && echo .rakit.s | bin/bk alat/asm1.bk ) > "$H" 2>&1
rm -f "$D/.rakit.s"
if grep -q '^!!\|^error' "$H"; then
  echo "rakit: gagal"
  grep '^!!\|^error\|^  pada' "$H" | head -4
  rm -f "$H"
  exit 1
fi
"$D/bin/hex0" < "$H" > "$2" || { rm -f "$H"; exit 1; }
rm -f "$H"
chmod +x "$2"
echo "rakit: $2 ($(wc -c < "$2" | tr -d ' ') byte)"
