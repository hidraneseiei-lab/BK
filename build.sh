#!/data/data/com.termux/files/usr/bin/sh
cd "$(dirname "$0")" || exit 1
mkdir -p bin
bangun() {
  if [ ! -x "bin/$1" ] || [ "src/$1.s" -nt "bin/$1" ]; then
    as "src/$1.s" -o "bin/$1.o" && ld "bin/$1.o" -o "bin/$1" || exit 1
    echo "build: bin/$1 (dari $1.s)"
  fi
}
if command -v as >/dev/null 2>&1 && command -v ld >/dev/null 2>&1; then
  bangun hex0
  bangun bk
else
  echo "as/ld tidak ada: pakai jalur murni (seed hex)"
  bash murni.sh >/dev/null || { echo "jalur murni GAGAL"; exit 1; }
  cp bin-murni/hex0 bin-murni/bk bin/
fi
for f in src/*.hex; do
  [ -f "$f" ] || continue
  nama=$(basename "$f" .hex)
  bin/hex0 < "$f" > "bin/$nama" && chmod +x "bin/$nama"
  echo "build: bin/$nama ($(wc -c < "bin/$nama") byte)"
done
if [ -n "$PREFIX" ] && [ -d "$PREFIX/bin" ]; then
  for c in simpan tes paket bkb; do
    printf '#!/data/data/com.termux/files/usr/bin/sh\nexec sh "$HOME/bahasaku/%s.sh" "$@"\n' "$c" > "$PREFIX/bin/$c"
    chmod +x "$PREFIX/bin/$c"
  done
  printf '#!/data/data/com.termux/files/usr/bin/sh\nexec "$HOME/bahasaku/bin/bk" "$@"\n' > "$PREFIX/bin/bk"
  chmod +x "$PREFIX/bin/bk"
fi
