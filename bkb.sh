#!/data/data/com.termux/files/usr/bin/sh
# bkb: jalankan program BK yang memakai blok JIKA/MAKA/LAINNYA/AKHIRJIKA dan SELAMA/AKHIRSELAMA
# pakai: bkb program.bk             jalankan
#        bkb -l program.bk          tampilkan hasil terjemahan saja
#        bkb -p program.bk keluaran bungkus jadi file mandiri
D="$HOME/bahasaku"
BIN="${BKBIN:-$D/bin/bk}"
case "$1" in
  -l) MODE=lihat; shift ;;
  -p) MODE=paket; shift ;;
  *)  MODE=jalan ;;
esac
[ -n "$1" ] || { echo "pakai: bkb program.bk | bkb -l program.bk | bkb -p program.bk keluaran"; exit 1; }
[ -f "$1" ] || { echo "bkb: file tidak ada: $1"; exit 1; }
command -v awk >/dev/null 2>&1 || { echo "bkb: awk belum ada, jalankan: pkg install gawk"; exit 1; }
T=$(mktemp) || exit 1
trap 'rm -f "$T"' EXIT
awk -f "$D/blok.awk" "$1" > "$T" || exit 1
case "$MODE" in
  lihat) cat "$T" ;;
  paket)
    [ -n "$2" ] || { echo "bkb: beri nama keluaran sebagai argumen kedua"; exit 1; }
    BKBIN="$BIN" sh "$D/paket.sh" "$T" "$2" ;;
  *) "$BIN" "$T" ;;
esac
