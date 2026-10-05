#!/data/data/com.termux/files/usr/bin/sh
cd "$HOME/bahasaku" || exit 1
D=/sdcard/Bahasaku
if [ ! -d /sdcard ] || [ ! -w /sdcard ]; then
  echo "belum bisa tulis ke /sdcard, jalankan: termux-setup-storage"
  exit 1
fi
mkdir -p "$D/arsip"

# bersihkan salinan lama yang berserakan di /sdcard
rm -rf /sdcard/bahasaku-src /sdcard/bahasaku-contoh /sdcard/bahasaku-seed /sdcard/bahasaku.sh

# salinan lengkap yang bisa dibaca
rm -rf "$D/proyek"
mkdir -p "$D/proyek"
cp -r src contoh alat seed "$D/proyek/" 2>/dev/null
for f in build.sh stub.sh simpan.sh tes.sh murni.sh bikin-seed.sh ekspor.sh paket.sh blok.awk bkb.sh tes-blok.sh rakit.sh catatan.md; do
  [ -f "$f" ] && cp "$f" "$D/proyek/"
done
[ -f bahasaku.sh ] && cp bahasaku.sh "$D/bahasaku.sh"

cat > "$D/BACA-SAYA.txt" <<'TXT'
Proyek bahasa BK.
Pulihkan di Termux (setelah: pkg install binutils):
  sh /sdcard/Bahasaku/bahasaku.sh
Atau dari arsip:
  tar xzf /sdcard/Bahasaku/arsip/NAMA.tar.gz -C ~
  sh ~/bahasaku/build.sh
Folder proyek/ berisi salinan source yang bisa dibaca langsung.
TXT

# arsip bertanda waktu (tanpa hasil build)
W=$(date +%Y%m%d-%H%M%S)
tar czf "$D/arsip/bahasaku-$W.tar.gz" \
  --exclude=bahasaku/bin --exclude=bahasaku/bin-murni \
  --exclude=bahasaku/backup --exclude=bahasaku/bahasaku.sh \
  -C "$HOME" bahasaku
if command -v zip >/dev/null 2>&1; then
  ( cd "$HOME" && zip -rq "$D/arsip/bahasaku-$W.zip" bahasaku \
      -x 'bahasaku/bin/*' 'bahasaku/bin-murni/*' 'bahasaku/backup/*' 'bahasaku/bahasaku.sh' )
fi

# simpan 5 arsip terakhir untuk tiap jenis
for e in tar.gz zip; do
  ls -t "$D"/arsip/*."$e" 2>/dev/null | tail -n +6 | xargs -r rm
done

echo "tersimpan di /storage/emulated/0/Bahasaku/"
ls -1 "$D" "$D/arsip" | head -20
