#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")" || exit 1
mkdir -p bin-murni
gagal=0
cek() {
  if [ "$2" = "$3" ]; then echo "OK    $1"
  else echo "GAGAL $1 (dapat '$2', harapan '$3')"; gagal=1; fi
}

# 1. lahirkan hex0 cuma dengan printf bash
sed 's/#.*//' seed/hex0.hex | tr -s ' \t\n' '\n' | while read -r b; do
  [ -n "$b" ] && printf "\\x$b"
done > bin-murni/hex0
chmod +x bin-murni/hex0

# 2. hex0 harus bisa menerjemahkan dirinya sendiri
bin-murni/hex0 < seed/hex0.hex > bin-murni/hex0.ulang
if cmp -s bin-murni/hex0 bin-murni/hex0.ulang; then r=sama; else r=beda; fi
rm -f bin-murni/hex0.ulang
cek "murni: hex0 membangun dirinya sendiri" "$r" "sama"

# 3. bk dibangun oleh hex0
bin-murni/hex0 < seed/bk.hex > bin-murni/bk
chmod +x bin-murni/bk
B=bin-murni/bk
cek "murni: bk hitung mundur" "$($B contoh/mundur.bk | tr '\n' ' ')" "5 4 3 2 1 "
cek "murni: bk aritmetika"    "$($B contoh/hitung.bk | tr '\n' ' ')" "14 10 -5 -14 "
cek "murni: bk gosub"         "$($B contoh/sub.bk | tr '\n' ' ')"    "9 4 1 selesai "
cek "murni: bk fizzbuzz"      "$($B contoh/fizzbuzz.bk | tr '\n' ' ')" "1 2 Fizz 4 Buzz Fizz 7 8 Fizz Buzz 11 Fizz 13 14 FizzBuzz "
cek "murni: bk prioritas"     "$($B contoh/prioritas.bk | tr '\n' ' ')" "14 20 85 13 1 -5 "
cek "murni: bk urut"          "$($B contoh/urut.bk | tr '\n' ' ')"      "1 2 5 7 9 "
cek "murni: bk fungsi"        "$($B contoh/fungsi.bk | tr '\n' ' ')"    "7 8 5 "
cek "murni: bk string"        "$($B contoh/string.bk | tr '\n' '|')"    "Halo, Budi|Budi dan Ani|x=10|"
cek "murni: bk potong teks"   "$($B contoh/potong.bk | tr '\n' '|')"   "Sel|pagi|mat|Hi|-45!|"
PM=$(mktemp -d)
BKBIN="$PWD/bin-murni/bk" sh paket.sh contoh/fizzbuzz.bk "$PM/fb" >/dev/null 2>&1
cek "murni: paket mandiri" "$("$PM/fb" | tr '\n' ' ')" "1 2 Fizz 4 Buzz Fizz 7 8 Fizz Buzz 11 Fizz 13 14 FizzBuzz "
rm -rf "$PM"
cek "murni: bk fungsi buatan" "$($B contoh/fungsi3.bk | tr '\n' '|')"   "55|"
cek "murni: bk include"       "$($B contoh/pakai.bk | tr '\n' '|')"     "49|halo dari lib|selesai|"
cek "murni: bk label"         "$($B contoh/label2.bk | tr '\n' '|')"    "hai|hai|akhir|"
cek "murni: bk lompat cepat"  "$(timeout 20 $B contoh/cepat.bk)"        "100000"
P=$PWD; FM=$(mktemp -d)
cek "murni: bk file"          "$(cd "$FM" && "$P/$B" "$P/contoh/tulisfile.bk" | tr '\n' '|')" "[baris satu]|[angka 42]|[tanpa-nl]|"
rm -rf "$FM"
[ $gagal = 0 ] && echo "JALUR MURNI LULUS" || echo "JALUR MURNI GAGAL"
exit $gagal
