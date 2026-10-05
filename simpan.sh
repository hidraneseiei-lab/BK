#!/data/data/com.termux/files/usr/bin/sh
cd "$HOME/bahasaku" || exit 1
[ -f catatan.md ] || touch catatan.md
mkdir -p contoh

sh tes.sh || { echo "dibatalkan: perbaiki dulu tesnya"; exit 1; }
sh bikin-seed.sh || { echo "dibatalkan: seed gagal"; exit 1; }
bash murni.sh || { echo "dibatalkan: jalur murni gagal"; exit 1; }

cat stub.sh > bahasaku.sh
tar czf - src contoh alat seed build.sh stub.sh simpan.sh tes.sh murni.sh bikin-seed.sh ekspor.sh paket.sh blok.awk bkb.sh tes-blok.sh rakit.sh catatan.md | base64 >> bahasaku.sh
echo "bungkus: bahasaku.sh ($(wc -c < bahasaku.sh) byte)"

T=$(mktemp -d)
if HOME="$T" sh bahasaku.sh >/dev/null 2>&1 \
   && [ "$(echo '48 69' | "$T/bahasaku/bin/hex0")" = "Hi" ] \
   && [ "$("$T/bahasaku/bin/bk" "$T/bahasaku/contoh/mundur.bk" | head -n 1)" = "5" ] \
   && bash "$T/bahasaku/murni.sh" >/dev/null 2>&1; then
  echo "tes pemulihan: OK"
else
  echo "tes pemulihan: GAGAL (bahasaku.sh jangan dipakai)"
  rm -rf "$T"; exit 1
fi
rm -rf "$T"

mkdir -p backup
cp bahasaku.sh "backup/bahasaku-$(date +%Y%m%d-%H%M%S).sh"
ls -t backup/*.sh | tail -n +6 | xargs -r rm

sh ekspor.sh
