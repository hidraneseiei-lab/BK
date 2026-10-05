#!/data/data/com.termux/files/usr/bin/sh
cd "$HOME/bahasaku" || exit 1
gagal=0
cek() {
  if [ "$2" = "$3" ]; then echo "OK    $1"
  else echo "GAGAL $1 (dapat '$2', harapan '$3')"; gagal=1; fi
}
K="sh bkb.sh"
cek "blok jika lainnya"       "$($K contoh/blok1.bk | tr '\n' '|')" "negatif|nol|positif|"
cek "blok selamat keluar"     "$($K contoh/blok2.bk | tr '\n' '|')" "1|3|5|7|selesai|"
cek "blok jika satu baris"    "$($K contoh/blok3.bk | tr '\n' '|')" "besar|akhir|"
cek "blok selama bersarang"   "$($K contoh/blok4.bk | tr '\n' '|')" "*|**|***|"
cek "blok dalam fungsi"       "$($K contoh/blok5.bk | tr '\n' '|')" "-1|0|1|"
cek "blok nomor baris"        "$($K contoh/blok6.bk | tr '\n' '|')" "dua|ok|"
cek "blok lolos tanpa ubah"   "$(awk -f blok.awk contoh/fungsi3.bk | cmp -s - contoh/fungsi3.bk && echo sama)" "sama"
cek "blok lolos bernomor"     "$(awk -f blok.awk contoh/fizzbuzz.bk | cmp -s - contoh/fizzbuzz.bk && echo sama)" "sama"
T=$(mktemp)
printf 'A = 1\nJIKA A = 1 MAKA\nTULIS "x"\nAKHIRJIKA\n' > "$T"
cek "blok terjemahan"         "$($K -l "$T" | tr '\n' '|')" 'A = 1|JIKA A <> 1 LOMPAT zzi1x0|TULIS "x"|LABEL zzi1x0|'
printf 'KELUAR\n' > "$T"
cek "blok keluar di luar"     "$($K "$T" 2>&1 | head -c 5)" "error"
printf 'SELAMA 1 = 1\nUNTUK I = 1 SAMPAI 3\nKELUAR\nLANJUT\nAKHIRSELAMA\n' > "$T"
cek "blok keluar di untuk"    "$($K "$T" 2>&1 | head -c 5)" "error"
printf 'JIKA 1 = 1 MAKA\nTULIS 1\n' > "$T"
cek "blok tak tertutup"       "$($K "$T" 2>&1 | head -c 5)" "error"
printf 'AKHIRJIKA\n' > "$T"
cek "blok akhirjika sendiri"  "$($K "$T" 2>&1 | head -c 5)" "error"
printf 'JIKA 1 MAKA\nAKHIRJIKA\n' > "$T"
cek "blok syarat tanpa op"    "$($K "$T" 2>&1 | head -c 5)" "error"
printf 'LAINNYA\n' > "$T"
cek "blok lainnya sendiri"    "$($K "$T" 2>&1 | head -c 5)" "error"
rm -f "$T"
exit $gagal
