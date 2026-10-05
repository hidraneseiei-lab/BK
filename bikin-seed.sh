#!/data/data/com.termux/files/usr/bin/sh
cd "$HOME/bahasaku" || exit 1
mkdir -p seed
T=$(mktemp -d)
for p in hex0 bk; do
  as "src/$p.s" -o "$T/$p.o" && ld -N -s "$T/$p.o" -o "$T/$p" || { echo "seed $p GAGAL"; rm -rf "$T"; exit 1; }
  { echo "# seed $p: dibuat otomatis dari src/$p.s oleh bikin-seed.sh"
    od -An -v -tx1 -w16 "$T/$p"; } > "seed/$p.hex"
  echo "seed/$p.hex ($(wc -c < "$T/$p") byte biner)"
done
rm -rf "$T"
