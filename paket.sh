#!/data/data/com.termux/files/usr/bin/sh
# paket: bungkus program .bk jadi satu file yang bisa dijalankan sendiri
# pakai: paket program.bk [keluaran]
BIN="${BKBIN:-$HOME/bahasaku/bin/bk}"
[ -n "$1" ] || { echo "pakai: paket program.bk [keluaran]"; exit 1; }
[ -f "$1" ] || { echo "paket: file tidak ada: $1"; exit 1; }
[ -x "$BIN" ] || { echo "paket: bk belum dibangun, jalankan: sh ~/bahasaku/build.sh"; exit 1; }
OUT="${2:-${1%.bk}}"
[ "$OUT" != "$1" ] || { echo "paket: beri nama keluaran sebagai argumen kedua"; exit 1; }
L=$(wc -c < "$1" | tr -d ' ')
[ "$L" -gt 0 ] || { echo "paket: program kosong"; exit 1; }
[ "$L" -lt 64000 ] || { echo "paket: program terlalu besar (maksimal 64000 byte)"; exit 1; }
grep -q 'INCLUDE' "$1" && echo "peringatan: INCLUDE tetap membaca file saat program dijalankan"
cat "$BIN" "$1" > "$OUT" || exit 1
printf 'BKPAKET1' >> "$OUT"
i=0
while [ "$i" -lt 8 ]; do
  printf "\\$(printf '%03o' $(( (L >> (8 * i)) & 255 )))" >> "$OUT"
  i=$((i + 1))
done
chmod +x "$OUT"
echo "paket: $OUT ($(wc -c < "$OUT" | tr -d ' ') byte)"
