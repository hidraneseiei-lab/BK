# Bahasa BK

Interpreter: src/bk.s (ARM64). Penerjemah hex: src/hex0.s.
Seed hex: seed/*.hex. Bangun murni: bash murni.sh. Simpan: simpan. Tes: tes.

## Perintah
A = ekspresi        variabel A-Z, bilangan bulat, hitung kiri ke kanan
TULIS A / "teks"    cetak, tambah ; di akhir supaya tidak pindah baris
BACA A              baca satu angka
LOMPAT n            ke baris bernomor n
JIKA x op y LOMPAT n   op: = <> != > >= < <=
GOSUB n / KEMBALI   subrutin, maksimal 64 tingkat
BERHENTI            selesai
# komentar

## Operator
+ - * / %   tanpa prioritas, 2 + 3 * 4 = 20

## Loop (bk v3)
UNTUK I = a SAMPAI b [LANGKAH n]   mulai loop, batas dihitung sekali, bisa 0 kali
LANJUT                             akhir loop, maksimal 16 tingkat bersarang
JIKA x op y GOSUB n                kondisi yang memanggil subrutin
Jangan keluar loop dengan LOMPAT: arahkan ke baris LANJUT.

## bk v5
ACAK(n)        angka acak 0..n-1 (n harus > 0), seed dari jam sistem
ABS(x)         nilai mutlak
BACA D(i)      input langsung ke array
Fungsi bisa dipakai di semua ekspresi, termasuk JIKA ACAK(10) > 5 GOSUB 100.

## bk v7 (fungsi teks)
PANJANG(s$)  KODE(s$)  ANGKA(s$)  CARI(s$, t$)     hasil angka
KIRI$(s$, n)  KANAN$(s$, n)  TENGAH$(s$, i, n)     potong teks (i mulai dari 1)
KAR$(n)  TEKS$(n)                                   kode -> karakter, angka -> teks
Argumen teks boleh literal, variabel, atau fungsi teks lain (bersarang).
Fungsi teks bisa dipakai di A$ = ..., TULIS, dan JIKA ... = ...
Di TULIS, gabungkan teks dengan ; (bukan +). Di A$ = ..., gabungkan dengan +.
Posisi/jumlah di luar jangkauan dipotong tanpa error. Hasil maksimal 63 karakter.

## bk v8 (file)
BUKA n, nama, mode        n = 1..4, mode "r" baca, "w" tulis (hapus isi), "a" tambah
TULISFILE n, item; item   seperti TULIS tapi ke file (; di akhir = tanpa baris baru)
BACAFILE n, A$            baca satu baris ke variabel teks (maksimal 63 karakter)
AKHIR(n)                  1 kalau sudah di akhir file, selain itu 0
TUTUP n                   tutup file (slot yang belum dibuka diabaikan)
Path relatif ke folder tempat bk dijalankan. Baca angka: ANGKA(L$).
Cara baca semua baris: ulangi JIKA AKHIR(n) = 1 LOMPAT ... lalu BACAFILE.

## bk v10 (label bernama)
LABEL nama                 menandai tempat (tidak melakukan apa-apa saat dijalankan)
LOMPAT nama / GOSUB nama   lompat atau panggil subrutin ke label
JIKA ... LOMPAT nama       juga berlaku untuk GOSUB
Nama label: huruf, angka, _ (tidak peka huruf besar/kecil), maksimal 64 label per program.
Nomor baris sekarang opsional; program boleh tanpa nomor. LOMPAT angka tetap jalan
untuk baris bernomor, dan keduanya boleh dicampur.
Label dobel: yang pertama dipakai. Label tak ada: error.
Jangan keluar dari UNTUK ... LANJUT dengan LOMPAT label (sama seperti LOMPAT angka).

## bk v12 (fungsi)
FUNGSI nama(P, Q)   definisi, parameter huruf A-Z (maksimal 4), badan sampai AKHIRFUNGSI
HASIL ekspresi      kembalikan nilai dan keluar dari fungsi
AKHIRFUNGSI         penutup; sampai sini tanpa HASIL berarti hasil 0
nama(a, b)          panggil di ekspresi manapun; PANGGIL nama(a) untuk membuang hasil
Parameter bersifat lokal (nilai lama dikembalikan). Parameter tanpa argumen bernilai 0,
jadi bisa dipakai sebagai variabel lokal tambahan. Variabel lain, array, teks: global.
Nama fungsi diawali dua huruf dan jangan sama dengan fungsi bawaan.
Rekursi maksimal 64 tingkat, maksimal 32 fungsi. Hasil hanya angka.
Keluar fungsi hanya lewat HASIL/AKHIRFUNGSI. Jangan panggil fungsi di dalam TULISFILE.
Fungsi dari INCLUDE bisa dipakai setelah barisnya dijalankan.

## bk v13 (paket mandiri)
paket program.bk [keluaran]   bungkus program jadi satu file yang jalan sendiri, tanpa bk
Isi file: salinan bk, teks program, lalu ekor 16 byte ("BKPAKET1" + panjang program).
Saat dijalankan, bk membuka /proc/self/exe, membaca ekornya, dan memakai program tertanam
(argumen baris perintah diabaikan). Tanpa ekor, bk bekerja seperti biasa.
Batas program 64000 byte. INCLUDE tetap membaca file dari folder kerja saat jalan.
File hasil hanya bisa dijalankan di tempat yang mengizinkan eksekusi (folder Termux, bukan /sdcard).

## bk v14 (blok, dijalankan lewat bkb)
bkb program.bk       jalankan program yang memakai blok (bk biasa tidak mengerti blok)
bkb -l program.bk    lihat hasil terjemahan ke BK dasar
bkb -p program.bk x  bungkus jadi file mandiri
JIKA x op y MAKA ... LAINNYA JIKA x op y MAKA ... LAINNYA ... AKHIRJIKA
JIKA x op y MAKA perintah          versi satu baris
SELAMA x op y ... AKHIRSELAMA      loop dengan syarat
KELUAR / TERUSKAN                  keluar / lanjut di SELAMA terdalam
Diterjemahkan jadi JIKA ... LOMPAT dan LABEL (nama zzi*, zzw*, zzx*), jadi ikut batas 64 label.
KELUAR/TERUSKAN tidak boleh di dalam UNTUK. File INCLUDE tidak ikut diterjemahkan.
Butuh awk (pkg install gawk).

## bk v14 (error bernomor baris)
Setiap error mencetak baris kedua ke stderr: "  pada baris N: teks baris" (maks 60 karakter).
Pesan lama tetap di baris pertama. N adalah nomor baris fisik di file, bukan nomor BASIC.
INCLUDE menempel isi file di akhir program, jadi baris file include dinomori lanjutan.
Error rekursi menunjuk baris pemanggil. Error sebelum program terbaca tidak punya nomor baris.
Kerja kode: lapor_baris dipanggil dari setiap rutin error_* sebelum keluar (kode 1).

## bk v15 (blok KALAU dan SELAMA)
KALAU kondisi / LAIN / AKHIRKALAU   percabangan blok (LAIN boleh dihilangkan)
SELAMA kondisi / AKHIRSELAMA        loop selama kondisi benar
Kondisi sama dengan JIKA (angka, teks, panggilan fungsi). Boleh bersarang dan di dalam fungsi.
JIKA ... LOMPAT/GOSUB tetap ada. LOMPAT keluar dari SELAMA aman (tidak ada keadaan tersimpan).
Tanpa pasangan: "error: KALAU/SELAMA tanpa pasangan" + nomor baris.
Kerja kode: kondisi dievaluasi oleh mesin JIKA; hasilnya ditangkap do_lompat (benar) atau akhir
(salah) lewat bendera kl_mode[kedalaman panggilan]. Pasangan dicari dengan memindai teks program.

## bk v16 (fungsi teks)
FUNGSI nama$(P)     fungsi yang mengembalikan teks ($ boleh dihilangkan di definisi)
HASILTEKS a + b     kembalikan teks (gabungan dengan +) dan keluar dari fungsi
nama$(args)         panggil di mana pun teks boleh dipakai (TULIS, A$ = ..., KIRI$(...), KALAU)
Parameter tetap angka A-Z; teks dioper lewat variabel teks global. Tanpa HASILTEKS hasilnya "".
Maksimal 63 karakter. Nama fungsi unik (dengan atau tanpa $).
Kerja kode: ns_fungsi mengecek nama$( ke tabel fungsi, memakai pemanggil v12 (uf_panggil),
lalu menyalin ret_str ke buffer tujuan nilai_str.

## bk v17 (parameter teks)
FUNGSI nama(S$, N)  parameter boleh teks (X$), maksimal 4, campur dengan angka
Parameter teks bersifat lokal: nilai lama variabel X$ dikembalikan saat fungsi selesai.
Argumen kurang -> angka 0 / teks kosong. Argumen harus cocok tipenya dengan parameter.
Variabel teks selain parameter tetap global. Bingkai panggilan 848 byte (336 lama + 512 teks).
Kerja kode: usf_arg memilih nilai_str/expr berdasarkan tipe parameter (usf_tipe memindai
deklarasi); usf_bind_teks/usf_rest_teks menyalin teks ke/dari strs[] di bingkai.

## bk v18 (rekaman nama.bidang)
nama.bidang = angka     nama.bidang$ = teks     nama.bidang(i) = ...   (i = 0..65535)
Dibaca di ekspresi/teks seperti variabel; belum diisi = 0 atau teks kosong.
Nama minimal dua huruf, huruf besar/kecil sama. Global (tidak disimpan oleh fungsi).
Maksimal 128 bidang (tiap indeks dihitung satu), teks 63 karakter, nama+bidang sekitar 23 karakter.
Kerja kode: kunci "NAMA.BIDANG(i)" dibangun di rek_kunci, dicari linear di rek_keys (128 x 32 byte);
nilai di rek_num / rek_str. Hook: kata_baru (penugasan), fk_fungsi (angka), ns_fungsi + adalah_str (teks).
rek_cepat adalah pra-pemindai murah supaya pernyataan biasa hampir tidak melambat.

## bk v19 (nama variabel panjang)
nama = ekspresi     nama$ = teks     BACA nama / BACA nama$     (huruf kedua harus huruf, maks 24)
Dipakai di ekspresi, TULIS, KALAU/JIKA, indeks array, argumen fungsi. Global; belum diisi = 0 / "".
Nama tanpa "(" adalah variabel, dengan "(" adalah fungsi: "hitung" dan "hitung(3)" boleh berdampingan.
Belum didukung: UNTUK nama = ... (loop tetap huruf tunggal) dan array bernama panjang.
Disimpan di tabel rekaman (kunci "JUMLAH"/"NAMA$"), sekarang 512 slot (rek_keys/rek_num/rek_str).
Kerja kode: var_cepat/var_akhir (pemindai murah) -> var_kunci -> rek_cari; hook: kata_baru,
fk_fungsi, ns_fungsi, adalah_str, do_baca (memakai db_masuk/bs_masuk milik BACA lama).

## alat/asm1.bk dan rakit (assembler mini tahap 1, ditulis dalam BK)
rakit berkas.s keluaran   asm1.bk membaca .s dan mencetak hex; hex0 mengubahnya jadi ELF (tanpa as/ld).
Didukung: sub add mov cmp cbz ldrb strb lsl orr b b.kondisi svc, label, .global/.text.
Belum: data (.asciz .balign .skip .bss), adrp/adr, ldr/str/ldp/stp, cset dll (sasaran tahap 2).
Kesalahan: baris "!! baris N: ..." (rakit berhenti, tidak ada biner). Keluaran 396 byte untuk hex0.s
(tanpa tabel section, beda dari 840 byte hasil ld, perilaku sama). Verifikasi: hex0 hasil rakit = hex0
hasil assembler Python, dan mengonversi seed/hex0.hex ke hex0 asli.
Catatan penulisan BK: parameter fungsi hanya satu huruf (maks 4); program ini memakai catatan global
(op.t$, lab.n$, kode.t$) dan tabel rekaman 512 slot, jadi masukan besar (ribuan baris) butuh tabel lebih besar.

## alat/asm1.bk dan rakit (assembler mini tahap 1, ditulis dalam BK)
rakit berkas.s keluaran   asm1.bk membaca .s dan mencetak hex; hex0 mengubahnya jadi ELF (tanpa as/ld).
Didukung: sub add mov cmp cbz ldrb strb lsl orr b b.kondisi svc, label, .global/.text.
Belum: data (.asciz .balign .skip .bss), adrp/adr, ldr/str/ldp/stp, cset dll (sasaran tahap 2).
Kesalahan: baris "!! baris N: ..." (rakit berhenti, tidak ada biner). Keluaran 396 byte untuk hex0.s
(tanpa tabel section, beda dari 840 byte hasil ld, perilaku sama). Verifikasi: hex0 hasil rakit = hex0
hasil assembler Python, dan mengonversi seed/hex0.hex ke hex0 asli.
Catatan penulisan BK: parameter fungsi hanya satu huruf (maks 4); program ini memakai catatan global
(op.t$, lab.n$, kode.t$) dan tabel rekaman 512 slot, jadi masukan besar (ribuan baris) butuh tabel lebih besar.
