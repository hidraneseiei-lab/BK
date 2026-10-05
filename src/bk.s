// BK v1 - interpreter bahasa BK untuk ARM64 Linux
// x21=program x22=variabel x24=kursor x26=akumulator x27=operator
.global _start
.text
_start_lama:
    adrp x21, prog
    add  x21, x21, :lo12:prog
    adrp x22, vars
    add  x22, x22, :lo12:vars
    mov  x28, #0
    ldr  x0, [sp]               // argc
    cmp  x0, #2
    b.lt pakai
    ldr  x1, [sp, #16]          // argv[1]
    mov  x0, #-100              // AT_FDCWD
    mov  x2, #0                 // O_RDONLY
    mov  x8, #56                // openat
    svc  #0
    cmp  x0, #0
    b.lt gagal_buka
    mov  x23, x0                // fd
    mov  x25, #0                // byte terbaca
    mov  x26, #65000            // batas
baca_loop:
    mov  x0, x23
    add  x1, x21, x25
    sub  x2, x26, x25
    mov  x8, #63                // read
    svc  #0
    cmp  x0, #0
    b.le baca_selesai
    add  x25, x25, x0
    cmp  x25, x26
    b.lt baca_loop
baca_selesai:
    mov  x0, x23
    mov  x8, #57                // close
    svc  #0
    mov  x24, x21

// ---------- awal baris ----------
baris:
    bl   skip
    ldrb w9, [x24]
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi pernyataan
    bl   angka                  // nomor baris diabaikan
    bl   skip
pernyataan:
    ldrb w9, [x24]
    cbz  w9, berhenti
    cmp  w9, #10
    b.eq akhir
    cmp  w9, #35                // '#'
    b.eq akhir
    ldrb w10, [x24, #1]
    cmp  w10, #97
    b.ge ps_kecil
    cmp  w10, #65
    b.lt tugas
    cmp  w10, #90
    b.le kata
    b    tugas
ps_kecil:
    cmp  w10, #122
    b.le kata
    b    tugas
kata:
    cmp  w9, #97
    b.lt kt_1
    sub  w9, w9, #32
kt_1:
    cmp  w10, #97
    b.lt kt_2
    sub  w10, w10, #32
kt_2:
    b    kata_baru
kata_lama:
    cmp  w9, #84                // T = TULIS
    b.eq do_tulis
    cmp  w9, #76                // L = LOMPAT
    b.eq do_lompat
    cmp  w9, #74                // J = JIKA
    b.eq do_jika
    cmp  w9, #71
    b.eq do_gosub
    cmp  w9, #75
    b.eq do_kembali
    cmp  w9, #66                // B = BERHENTI / BACA
    b.ne error
    cmp  w10, #69               // E
    b.eq berhenti
    cmp  w10, #65               // A
    b.eq do_baca
    b    error

// buang sisa baris lalu ke baris berikutnya
akhir_lama:
    ldrb w9, [x24]
    cbz  w9, baris
    add  x24, x24, #1
    cmp  w9, #10
    b.ne akhir_v14
    b    baris

berhenti:
    mov  x0, #0
    mov  x8, #93
    svc  #0

// ---------- A = ekspresi ----------
tugas_lama:
    bl   indeks_var
    mov  x19, x0
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #61
    b.ne error
    add  x24, x24, #1
    bl   expr
    str  x0, [x22, x19, lsl #3]
    b    akhir

// ---------- TULIS ----------
do_tulis_lama:
    bl   lewat_kata
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #34                // '"'
    b.eq tulis_teks
    bl   expr
    bl   cetak_angka
    b    tulis_akhir
tulis_teks:
    add  x24, x24, #1
    mov  x1, x24
    mov  x2, #0
tt_len:
    ldrb w9, [x24]
    cbz  w9, error
    cmp  w9, #10
    b.eq error
    cmp  w9, #34
    b.eq tt_cetak
    add  x24, x24, #1
    add  x2, x2, #1
    b    tt_len
tt_cetak:
    mov  x0, #1
    mov  x8, #64
    svc  #0
    add  x24, x24, #1
tulis_akhir:
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #59                // ';' = jangan pindah baris
    b.eq akhir
    bl   cetak_nl
    b    akhir

// ---------- LOMPAT ----------
do_lompat_lama:
    ldrb w9, [x24]
    cmp  w9, #71
    b.eq do_gosub
    cmp  w9, #103
    b.eq do_gosub
    bl   lewat_kata
    bl   skip
    ldrb w9, [x24]
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi error
    bl   angka
    bl   cari_baris
    b    baris

// ---------- JIKA ----------
do_jika_lama:
    bl   lewat_kata
    bl   expr
    mov  x19, x0
    bl   skip
    ldrb w9, [x24]
    ldrb w10, [x24, #1]
    cmp  w9, #61                // =
    b.ne jk_1
    add  x24, x24, #1
    mov  x20, #0
    b    jk_kanan
jk_1:
    cmp  w9, #33                // !=
    b.ne jk_2
    cmp  w10, #61
    b.ne error
    add  x24, x24, #2
    mov  x20, #1
    b    jk_kanan
jk_2:
    cmp  w9, #62                // > atau >=
    b.ne jk_3
    cmp  w10, #61
    b.eq jk_ge
    add  x24, x24, #1
    mov  x20, #2
    b    jk_kanan
jk_ge:
    add  x24, x24, #2
    mov  x20, #3
    b    jk_kanan
jk_3:
    cmp  w9, #60                // < <= <>
    b.ne error
    cmp  w10, #61
    b.eq jk_le
    cmp  w10, #62
    b.eq jk_ne
    add  x24, x24, #1
    mov  x20, #4
    b    jk_kanan
jk_le:
    add  x24, x24, #2
    mov  x20, #5
    b    jk_kanan
jk_ne:
    add  x24, x24, #2
    mov  x20, #1
jk_kanan:
    bl   expr
    mov  x12, x0
    cbnz x20, jk_c1
    cmp  x19, x12
    b.eq do_lompat
    b    akhir
jk_c1:
    cmp  x20, #1
    b.ne jk_c2
    cmp  x19, x12
    b.ne do_lompat
    b    akhir
jk_c2:
    cmp  x20, #2
    b.ne jk_c3
    cmp  x19, x12
    b.gt do_lompat
    b    akhir
jk_c3:
    cmp  x20, #3
    b.ne jk_c4
    cmp  x19, x12
    b.ge do_lompat
    b    akhir
jk_c4:
    cmp  x20, #4
    b.ne jk_c5
    cmp  x19, x12
    b.lt do_lompat
    b    akhir
jk_c5:
    cmp  x19, x12
    b.le do_lompat
    b    akhir

// ---------- BACA ----------
do_baca_lama:
    bl   lewat_kata
    bl   skip
    bl   indeks_var
    mov  x12, x0
    mov  x13, #0
    mov  x14, #0
    adrp x15, buf
    add  x15, x15, :lo12:buf
    add  x15, x15, #48
baca_in:
    mov  x0, #0
    mov  x1, x15
    mov  x2, #1
    mov  x8, #63
    svc  #0
    cmp  x0, #1
    b.ne baca_in_selesai
    ldrb w9, [x15]
    cmp  w9, #10
    b.eq baca_in_selesai
    cmp  w9, #45
    b.ne baca_in_digit
    mov  x14, #1
    b    baca_in
baca_in_digit:
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi baca_in
    mov  x11, #10
    madd x13, x13, x11, x10
    b    baca_in
baca_in_selesai:
    cbz  x14, baca_in_simpan
    neg  x13, x13
baca_in_simpan:
    str  x13, [x22, x12, lsl #3]
    b    akhir

// ---------- subrutin ----------
skip:                           // lewati spasi, tab, CR
    ldrb w9, [x24]
    cmp  w9, #32
    b.eq skip_maju
    cmp  w9, #9
    b.eq skip_maju
    cmp  w9, #13
    b.ne skip_selesai
skip_maju:
    add  x24, x24, #1
    b    skip
skip_selesai:
    ret

lewat_kata:                     // lewati huruf
    ldrb w9, [x24]
    cmp  w9, #97
    b.lt lk_besar
    cmp  w9, #122
    b.gt lk_selesai
    b    lk_maju
lk_besar:
    cmp  w9, #65
    b.lt lk_selesai
    cmp  w9, #90
    b.gt lk_selesai
lk_maju:
    add  x24, x24, #1
    b    lewat_kata
lk_selesai:
    ret

angka:                          // baca bilangan -> x0
    mov  x0, #0
angka_loop:
    ldrb w9, [x24]
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi angka_selesai
    mov  x11, #10
    madd x0, x0, x11, x10
    add  x24, x24, #1
    b    angka_loop
angka_selesai:
    ret

indeks_var:                     // huruf A-Z -> x0 = 0..25
    ldrb w9, [x24]
    cmp  w9, #97
    b.lt iv_1
    sub  w9, w9, #32
iv_1:
    sub  w9, w9, #65
    cmp  w9, #25
    b.hi error
    mov  x0, x9
    add  x24, x24, #1
    ret

term:                           // angka, variabel, atau -term
    stp  x29, x30, [sp, #-16]!
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #45
    b.ne term_1
    add  x24, x24, #1
    bl   term
    neg  x0, x0
    b    term_keluar
term_1:
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi term_var
    bl   angka
    b    term_keluar
term_var:
    bl   indeks_var
    ldr  x0, [x22, x0, lsl #3]
term_keluar:
    ldp  x29, x30, [sp], #16
    ret

expr_lama:                           // term (op term)* kiri ke kanan -> x0
    stp  x29, x30, [sp, #-16]!
    bl   term
    mov  x26, x0
expr_loop:
    bl   skip
    ldrb w27, [x24]
    cmp  w27, #43
    b.eq expr_op
    cmp  w27, #45
    b.eq expr_op
    cmp  w27, #42
    b.eq expr_op
    cmp  w27, #37
    b.eq expr_op
    cmp  w27, #47
    b.ne expr_selesai
expr_op:
    add  x24, x24, #1
    bl   term
    cmp  w27, #43
    b.ne expr_1
    add  x26, x26, x0
    b    expr_loop
expr_1:
    cmp  w27, #45
    b.ne expr_2
    sub  x26, x26, x0
    b    expr_loop
expr_2:
    cmp  w27, #42
    b.ne expr_3
    mul  x26, x26, x0
    b    expr_loop
expr_3:
    cmp  w27, #37
    b.eq expr_mod
    sdiv x26, x26, x0
    b    expr_loop
expr_selesai:
    mov  x0, x26
    ldp  x29, x30, [sp], #16
    ret

cari_baris_lama:                     // x0 = nomor tujuan -> x24 = awal baris itu
    stp  x29, x30, [sp, #-16]!
    mov  x15, x0
    mov  x24, x21
cari_loop:
    bl   skip
    ldrb w9, [x24]
    cbz  w9, error_baris
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi cari_lanjut
    mov  x16, x24
    bl   angka
    cmp  x0, x15
    b.ne cari_lanjut
    mov  x24, x16
    ldp  x29, x30, [sp], #16
    ret
cari_lanjut:
    ldrb w9, [x24]
    cbz  w9, error_baris
    add  x24, x24, #1
    cmp  w9, #10
    b.ne cari_lanjut
    b    cari_loop

cetak_angka:                    // cetak x0 (bertanda) tanpa newline
    adrp x1, buf
    add  x1, x1, :lo12:buf
    add  x1, x1, #32
    mov  x2, x1
    mov  x3, #0
    cmp  x0, #0
    b.ge ca_loop
    neg  x0, x0
    mov  x3, #1
ca_loop:
    mov  x4, #10
    udiv x5, x0, x4
    msub x6, x5, x4, x0
    add  x6, x6, #48
    sub  x1, x1, #1
    strb w6, [x1]
    mov  x0, x5
    cbnz x0, ca_loop
    cbz  x3, ca_cetak
    sub  x1, x1, #1
    mov  w6, #45
    strb w6, [x1]
ca_cetak:
    sub  x2, x2, x1
    mov  x0, #1
    mov  x8, #64
    svc  #0
    ret

cetak_nl:
    adrp x1, buf
    add  x1, x1, :lo12:buf
    add  x1, x1, #48
    mov  w2, #10
    strb w2, [x1]
    mov  x2, #1
    mov  x0, #1
    mov  x8, #64
    svc  #0
    ret

cetak_z:                        // x0=fd, x1=string berakhir 0
    mov  x2, #0
cz_len:
    ldrb w9, [x1, x2]
    cbz  w9, cz_tulis
    add  x2, x2, #1
    b    cz_len
cz_tulis:
    mov  x8, #64
    svc  #0
    ret

// ---------- error ----------
error:
    mov  x0, #2
    adr  x1, pesan_err
    bl   cetak_z
    mov  x1, x24
    mov  x2, #0
err_len:
    ldrb w9, [x1, x2]
    cbz  w9, err_cetak
    cmp  w9, #10
    b.eq err_cetak
    add  x2, x2, #1
    cmp  x2, #40
    b.lt err_len
err_cetak:
    mov  x0, #2
    mov  x8, #64
    svc  #0
    mov  x0, #2
    adr  x1, pesan_nl
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0
error_baris:
    mov  x0, #2
    adr  x1, pesan_baris
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0
pakai:
    mov  x0, #2
    adr  x1, pesan_pakai
    bl   cetak_z
    mov  x0, #1
    mov  x8, #93
    svc  #0
gagal_buka:
    mov  x0, #2
    adr  x1, pesan_buka
    bl   cetak_z
    mov  x0, #1
    mov  x8, #93
    svc  #0

pesan_err:   .asciz "error di dekat: "
pesan_nl:    .asciz "\n"
pesan_baris: .asciz "error: nomor baris tujuan tidak ada\n"
pesan_pakai: .asciz "pakai: bk file.bk\n"
pesan_buka:  .asciz "gagal membuka file\n"

.bss
.balign 16
vars: .skip 208
buf:  .skip 64
prog: .skip 65536

.text
.balign 4
do_gosub_lama:
    bl   lewat_kata
    bl   skip
    ldrb w9, [x24]
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi error
    bl   angka
    cmp  x28, #64
    b.ge error_stack
    adrp x13, rstack
    add  x13, x13, :lo12:rstack
    str  x24, [x13, x28, lsl #3]
    add  x28, x28, #1
    bl   cari_baris
    b    baris
do_kembali:
    cbz  x28, error_stack
    sub  x28, x28, #1
    adrp x13, rstack
    add  x13, x13, :lo12:rstack
    ldr  x24, [x13, x28, lsl #3]
    b    akhir
expr_mod:
    sdiv x5, x26, x0
    msub x26, x5, x0, x26
    b    expr_loop
error_stack:
    mov  x0, #2
    adr  x1, pesan_stack
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0
pesan_stack: .asciz "error: GOSUB/KEMBALI tidak cocok\n"

.bss
.balign 16
rstack: .skip 512

.text
.balign 4
kata_v7:
    cmp  w9, #85                // U = UNTUK
    b.eq do_untuk
    cmp  w9, #76                // LA = LANJUT
    b.ne kata_lama
    cmp  w10, #65
    b.eq do_lanjut
    b    kata_lama

do_untuk:
    bl   lewat_kata             // lewati UNTUK
    bl   skip
    bl   indeks_var
    mov  x19, x0                // variabel loop
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #61
    b.ne error
    add  x24, x24, #1
    bl   expr                   // nilai awal
    str  x0, [x22, x19, lsl #3]
    bl   lewat_kata             // lewati SAMPAI
    bl   expr
    mov  x20, x0                // batas
    mov  x12, #1                // langkah bawaan
    ldrb w9, [x24]
    cmp  w9, #76
    b.eq untuk_langkah
    cmp  w9, #108
    b.ne untuk_eol
untuk_langkah:
    bl   lewat_kata             // lewati LANGKAH
    bl   expr
    mov  x12, x0
untuk_eol:                      // x24 = awal baris berikutnya
    ldrb w9, [x24]
    cbz  w9, untuk_cek
    add  x24, x24, #1
    cmp  w9, #10
    b.ne untuk_eol
untuk_cek:
    ldr  x0, [x22, x19, lsl #3]
    cmp  x12, #0
    b.lt untuk_cek_turun
    cmp  x0, x20
    b.gt untuk_lewati
    b    untuk_push
untuk_cek_turun:
    cmp  x0, x20
    b.lt untuk_lewati
untuk_push:
    adrp x13, fsp
    add  x13, x13, :lo12:fsp
    ldr  x14, [x13]
    cmp  x14, #16
    b.ge error_for
    adrp x15, rfor
    add  x15, x15, :lo12:rfor
    add  x15, x15, x14, lsl #5
    stp  x19, x20, [x15]
    stp  x12, x24, [x15, #16]
    add  x14, x14, #1
    str  x14, [x13]
    b    baris

// loop 0 kali: cari LANJUT yang cocok (hitung UNTUK bersarang)
untuk_lewati:
    mov  x13, #0
ul_baris:
    bl   skip
    ldrb w9, [x24]
    cbz  w9, berhenti
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi ul_kata
    bl   angka
    bl   skip
ul_kata:
    ldrb w9, [x24]
    ldrb w10, [x24, #1]
    cmp  w9, #97
    b.lt ul_1
    sub  w9, w9, #32
ul_1:
    cmp  w10, #97
    b.lt ul_2
    sub  w10, w10, #32
ul_2:
    cmp  w9, #85
    b.ne ul_3
    cmp  w10, #78
    b.ne ul_next
    add  x13, x13, #1
    b    ul_next
ul_3:
    cmp  w9, #76
    b.ne ul_next
    cmp  w10, #65
    b.ne ul_next
    cbz  x13, akhir
    sub  x13, x13, #1
ul_next:
    ldrb w9, [x24]
    cbz  w9, ul_baris
    add  x24, x24, #1
    cmp  w9, #10
    b.ne ul_next
    b    ul_baris

do_lanjut:
    adrp x13, fsp
    add  x13, x13, :lo12:fsp
    ldr  x14, [x13]
    cbz  x14, error_for
    sub  x15, x14, #1
    adrp x16, rfor
    add  x16, x16, :lo12:rfor
    add  x16, x16, x15, lsl #5
    ldp  x19, x20, [x16]
    ldp  x12, x17, [x16, #16]
    ldr  x0, [x22, x19, lsl #3]
    add  x0, x0, x12
    str  x0, [x22, x19, lsl #3]
    cmp  x12, #0
    b.lt lanjut_turun
    cmp  x0, x20
    b.gt lanjut_selesai
    mov  x24, x17
    b    baris
lanjut_turun:
    cmp  x0, x20
    b.lt lanjut_selesai
    mov  x24, x17
    b    baris
lanjut_selesai:
    str  x15, [x13]
    b    akhir

error_for:
    mov  x0, #2
    adr  x1, pesan_for
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0
pesan_for: .asciz "error: UNTUK/LANJUT tidak cocok\n"

.bss
.balign 16
fsp:  .skip 16
rfor: .skip 512

.text
.balign 4
// ---------- ekspresi dengan prioritas ----------
expr:                           // + - (prioritas terendah)
    stp  x29, x30, [sp, #-16]!
    bl   suku
ex_loop:
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #43
    b.eq ex_op
    cmp  w9, #45
    b.ne ex_selesai
ex_op:
    stp  x0, x9, [sp, #-16]!
    add  x24, x24, #1
    bl   suku
    ldp  x1, x9, [sp], #16
    cmp  w9, #43
    b.ne ex_kurang
    add  x0, x1, x0
    b    ex_loop
ex_kurang:
    sub  x0, x1, x0
    b    ex_loop
ex_selesai:
    ldp  x29, x30, [sp], #16
    ret

suku:                           // * / %
    stp  x29, x30, [sp, #-16]!
    bl   faktor
su_loop:
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #42
    b.eq su_op
    cmp  w9, #47
    b.eq su_op
    cmp  w9, #37
    b.ne su_selesai
su_op:
    stp  x0, x9, [sp, #-16]!
    add  x24, x24, #1
    bl   faktor
    ldp  x1, x9, [sp], #16
    cmp  w9, #42
    b.ne su_bagi
    mul  x0, x1, x0
    b    su_loop
su_bagi:
    cbz  x0, error_bagi
    cmp  w9, #47
    b.ne su_sisa
    sdiv x0, x1, x0
    b    su_loop
su_sisa:
    sdiv x2, x1, x0
    msub x0, x2, x0, x1
    b    su_loop
su_selesai:
    ldp  x29, x30, [sp], #16
    ret

faktor:                         // -x, (ekspresi), angka, variabel, array
    stp  x29, x30, [sp, #-16]!
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #45
    b.ne fk_kurung
    add  x24, x24, #1
    bl   faktor
    neg  x0, x0
    b    fk_keluar
fk_kurung:
    cmp  w9, #40
    b.ne fk_angka
    add  x24, x24, #1
    bl   expr
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #41
    b.ne error
    add  x24, x24, #1
    b    fk_keluar
fk_angka:
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi fk_var
    bl   angka
    b    fk_keluar
fk_var_lama:
    bl   indeks_var
    mov  x1, x0
    ldrb w9, [x24]
    cmp  w9, #40
    b.eq fk_arr
    ldr  x0, [x22, x1, lsl #3]
    b    fk_keluar
fk_arr:
    add  x24, x24, #1
    str  x1, [sp, #-16]!
    bl   expr
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #41
    b.ne error
    add  x24, x24, #1
    ldr  x1, [sp], #16
    bl   alamat_arr
    ldr  x0, [x0]
fk_keluar:
    ldp  x29, x30, [sp], #16
    ret

alamat_arr:                     // x1 = huruf (0..25), x0 = indeks -> x0 = alamat
    cmp  x0, #99
    b.hi error_idx
    mov  x9, #100
    madd x0, x1, x9, x0
    adrp x9, arr
    add  x9, x9, :lo12:arr
    add  x0, x9, x0, lsl #3
    ret

// ---------- A = ... dan A(i) = ... ----------
tugas_v4:
    bl   indeks_var
    mov  x19, x0
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #40
    b.eq tugas_arr
    cmp  w9, #61
    b.ne error
    add  x24, x24, #1
    bl   expr
    str  x0, [x22, x19, lsl #3]
    b    akhir
tugas_arr:
    add  x24, x24, #1
    bl   expr
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #41
    b.ne error
    add  x24, x24, #1
    mov  x1, x19
    bl   alamat_arr
    str  x0, [sp, #-16]!
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #61
    b.ne error
    add  x24, x24, #1
    bl   expr
    ldr  x1, [sp], #16
    str  x0, [x1]
    b    akhir

error_idx:
    mov  x0, #2
    adr  x1, pesan_idx
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0
error_bagi:
    mov  x0, #2
    adr  x1, pesan_bagi
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0
pesan_idx:  .asciz "error: indeks array harus 0-99\n"
pesan_bagi: .asciz "error: pembagian dengan nol\n"

.bss
.balign 16
arr: .skip 20800

.text
.balign 4
// ---------- fungsi bawaan ----------
fk_var:                         // huruf diikuti huruf = nama fungsi
    ldrb w9, [x24]
    ldrb w10, [x24, #1]
    cmp  w10, #97
    b.lt fv_1
    cmp  w10, #122
    b.le fk_fungsi
    b    fk_var_lama
fv_1:
    cmp  w10, #65
    b.lt fk_var_lama
    cmp  w10, #90
    b.le fk_fungsi
    b    fk_var_lama

fk_fungsi_lama:
    cmp  w9, #97
    b.lt ff_1
    sub  w9, w9, #32
ff_1:
    cmp  w10, #97
    b.lt ff_2
    sub  w10, w10, #32
ff_2:
    cmp  w9, #65                // harus diawali A
    b.ne error
    mov  x1, #0                 // 0 = ACAK
    cmp  w10, #67               // C
    b.eq ff_arg
    mov  x1, #1                 // 1 = ABS
    cmp  w10, #66               // B
    b.ne error
ff_arg:
    str  x1, [sp, #-16]!
    bl   lewat_kata
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #40
    b.ne error
    add  x24, x24, #1
    bl   expr
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #41
    b.ne error
    add  x24, x24, #1
    ldr  x1, [sp], #16
    cbnz x1, ff_abs
    cmp  x0, #0                 // ACAK(n): 0..n-1
    b.le error_acak
    mov  x2, x0
    bl   acak_berikut
    udiv x3, x0, x2
    msub x0, x3, x2, x0
    b    fk_keluar
ff_abs:
    cmp  x0, #0
    cneg x0, x0, lt
    b    fk_keluar

acak_berikut:                   // xorshift64 -> x0
    adrp x4, acak_state
    add  x4, x4, :lo12:acak_state
    ldr  x0, [x4]
    cbnz x0, ab_lanjut
    sub  sp, sp, #16            // pertama kali: ambil seed dari jam
    mov  x0, #1                 // CLOCK_MONOTONIC
    mov  x1, sp
    mov  x8, #113               // clock_gettime
    svc  #0
    ldp  x0, x1, [sp]
    add  sp, sp, #16
    eor  x0, x1, x0, lsl #32
    orr  x0, x0, #1
ab_lanjut:
    eor  x1, x0, x0, lsl #13
    eor  x1, x1, x1, lsr #7
    eor  x0, x1, x1, lsl #17
    str  x0, [x4]
    ret

// ---------- BACA v / BACA v(i) ----------
do_baca_v5:
    bl   lewat_kata
    bl   skip
    bl   indeks_var
    mov  x19, x0
    ldrb w9, [x24]
    cmp  w9, #40
    b.ne db_biasa
    add  x24, x24, #1
    bl   expr
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #41
    b.ne error
    add  x24, x24, #1
    mov  x1, x19
    bl   alamat_arr
    mov  x19, x0                // x19 = alamat tujuan
    b    db_masuk
db_biasa:
    add  x19, x22, x19, lsl #3
db_masuk:
    mov  x13, #0
    mov  x14, #0
    adrp x15, buf
    add  x15, x15, :lo12:buf
    add  x15, x15, #48
db_loop:
    mov  x0, #0
    mov  x1, x15
    mov  x2, #1
    mov  x8, #63
    svc  #0
    cmp  x0, #1
    b.ne db_selesai
    ldrb w9, [x15]
    cmp  w9, #10
    b.eq db_selesai
    cmp  w9, #45
    b.ne db_digit
    mov  x14, #1
    b    db_loop
db_digit:
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi db_loop
    mov  x11, #10
    madd x13, x13, x11, x10
    b    db_loop
db_selesai:
    cbz  x14, db_simpan
    neg  x13, x13
db_simpan:
    str  x13, [x19]
    b    akhir

error_acak:
    mov  x0, #2
    adr  x1, pesan_acak
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0
pesan_acak: .asciz "error: ACAK(n) butuh n lebih dari 0\n"

.bss
.balign 16
acak_state: .skip 16

.text
.balign 4
// ---------- TULIS item [; item]... ----------
do_tulis_v6:
    bl   lewat_kata
tl_item:
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #34
    b.eq tl_teks
    ldrb w10, [x24, #1]
    cmp  w10, #36
    b.eq tl_str
    bl   expr
    bl   cetak_angka
    b    tl_sesudah
tl_teks:
    add  x24, x24, #1
    mov  x1, x24
    mov  x2, #0
tl_len:
    ldrb w9, [x24]
    cbz  w9, error
    cmp  w9, #10
    b.eq error
    cmp  w9, #34
    b.eq tl_cetak
    add  x24, x24, #1
    add  x2, x2, #1
    b    tl_len
tl_cetak:
    mov  x0, #1
    mov  x8, #64
    svc  #0
    add  x24, x24, #1
    b    tl_sesudah
tl_str:
    bl   indeks_var
    add  x24, x24, #1
    adrp x1, strs
    add  x1, x1, :lo12:strs
    mov  x2, #64
    madd x1, x0, x2, x1
    mov  x2, #0
tl_slen:
    ldrb w9, [x1, x2]
    cbz  w9, tl_scetak
    add  x2, x2, #1
    b    tl_slen
tl_scetak:
    mov  x0, #1
    mov  x8, #64
    svc  #0
tl_sesudah:
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #59
    b.ne tl_nl
    add  x24, x24, #1
    bl   skip
    ldrb w9, [x24]
    cbz  w9, akhir
    cmp  w9, #10
    b.eq akhir
    cmp  w9, #35
    b.eq akhir
    b    tl_item
tl_nl:
    bl   cetak_nl
    b    akhir

// ---------- A$ = ... ----------
tugas_v6:
    ldrb w9, [x24, #1]
    cmp  w9, #36
    b.eq tugas_str
    b    tugas_v4
tugas_str:
    bl   indeks_var
    add  x24, x24, #1
    adrp x19, strs
    add  x19, x19, :lo12:strs
    mov  x2, #64
    madd x19, x0, x2, x19
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #61
    b.ne error
    add  x24, x24, #1
    adrp x20, tmps
    add  x20, x20, :lo12:tmps
    mov  x13, #0
ts_item:
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #34
    b.eq ts_lit
    ldrb w10, [x24, #1]
    cmp  w10, #36
    b.ne error
    bl   indeks_var
    add  x24, x24, #1
    adrp x1, strs
    add  x1, x1, :lo12:strs
    mov  x2, #64
    madd x1, x0, x2, x1
ts_cs:
    ldrb w9, [x1], #1
    cbz  w9, ts_sesudah
    cmp  x13, #63
    b.ge ts_cs
    strb w9, [x20, x13]
    add  x13, x13, #1
    b    ts_cs
ts_lit:
    add  x24, x24, #1
ts_cl:
    ldrb w9, [x24]
    cbz  w9, error
    cmp  w9, #10
    b.eq error
    add  x24, x24, #1
    cmp  w9, #34
    b.eq ts_sesudah
    cmp  x13, #63
    b.ge ts_cl
    strb w9, [x20, x13]
    add  x13, x13, #1
    b    ts_cl
ts_sesudah:
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #43
    b.ne ts_salin
    add  x24, x24, #1
    b    ts_item
ts_salin:
    strb wzr, [x20, x13]
    mov  x2, #0
ts_s2:
    ldrb w9, [x20, x2]
    strb w9, [x19, x2]
    add  x2, x2, #1
    cmp  x2, x13
    b.le ts_s2
    b    akhir

// ---------- BACA A$ ----------
do_baca_v18:
    mov  x16, x24
    bl   lewat_kata
    bl   skip
    ldrb w9, [x24, #1]
    cmp  w9, #36
    b.eq baca_str
    mov  x24, x16
    b    do_baca_v5
baca_str:
    bl   indeks_var
    add  x24, x24, #1
    adrp x19, strs
    add  x19, x19, :lo12:strs
    mov  x2, #64
    madd x19, x0, x2, x19
bs_masuk:
    mov  x13, #0
    adrp x15, buf
    add  x15, x15, :lo12:buf
    add  x15, x15, #48
bs_loop:
    mov  x0, #0
    mov  x1, x15
    mov  x2, #1
    mov  x8, #63
    svc  #0
    cmp  x0, #1
    b.ne bs_selesai
    ldrb w9, [x15]
    cmp  w9, #10
    b.eq bs_selesai
    cmp  w9, #13
    b.eq bs_loop
    cmp  x13, #63
    b.ge bs_loop
    strb w9, [x19, x13]
    add  x13, x13, #1
    b    bs_loop
bs_selesai:
    strb wzr, [x19, x13]
    b    akhir

// ---------- ambil operand teks: x1 = buffer sementara, hasil x0 ----------
ambil_str:
    stp  x29, x30, [sp, #-16]!
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #34
    b.eq as_lit
    ldrb w10, [x24, #1]
    cmp  w10, #36
    b.ne error
    bl   indeks_var
    add  x24, x24, #1
    adrp x1, strs
    add  x1, x1, :lo12:strs
    mov  x2, #64
    madd x0, x0, x2, x1
    b    as_keluar
as_lit:
    add  x24, x24, #1
    mov  x0, x1
    mov  x2, #0
as_l:
    ldrb w9, [x24]
    cbz  w9, error
    cmp  w9, #10
    b.eq error
    add  x24, x24, #1
    cmp  w9, #34
    b.eq as_tutup
    cmp  x2, #63
    b.ge as_l
    strb w9, [x0, x2]
    add  x2, x2, #1
    b    as_l
as_tutup:
    strb wzr, [x0, x2]
as_keluar:
    ldp  x29, x30, [sp], #16
    ret

// ---------- JIKA dengan teks ----------
do_jika_v6:
    mov  x16, x24
    bl   lewat_kata
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #34
    b.eq js_mulai
    ldrb w10, [x24, #1]
    cmp  w10, #36
    b.eq js_mulai
    mov  x24, x16
    b    do_jika_lama
js_mulai:
    adrp x1, tmps
    add  x1, x1, :lo12:tmps
    bl   ambil_str
    mov  x19, x0
    bl   skip
    ldrb w9, [x24]
    ldrb w10, [x24, #1]
    cmp  w9, #61
    b.ne js_1
    add  x24, x24, #1
    mov  x20, #0
    b    js_kanan
js_1:
    cmp  w9, #33
    b.ne js_2
    cmp  w10, #61
    b.ne error
    add  x24, x24, #2
    mov  x20, #1
    b    js_kanan
js_2:
    cmp  w9, #60
    b.ne error
    cmp  w10, #62
    b.ne error
    add  x24, x24, #2
    mov  x20, #1
js_kanan:
    adrp x1, tmps2
    add  x1, x1, :lo12:tmps2
    bl   ambil_str
    mov  x12, x0
    bl   skip
    mov  x2, #0
js_cmp:
    ldrb w3, [x19, x2]
    ldrb w4, [x12, x2]
    cmp  w3, w4
    b.ne js_beda
    cbz  w3, js_sama
    add  x2, x2, #1
    b    js_cmp
js_sama:
    cbnz x20, akhir
    b    do_lompat
js_beda:
    cbz  x20, akhir
    b    do_lompat

.bss
.balign 16
strs:  .skip 1664
tmps:  .skip 64
tmps2: .skip 64

.text
.balign 4
// ---------- apakah item di x24 berupa teks? x0 = 1 teks, 0 angka ----------
adalah_str_v17:
    ldrb w9, [x24]
    cmp  w9, #34
    b.ne as2_1
    mov  x0, #1
    ret
as2_1:
    mov  x2, #0
as2_l:
    ldrb w9, [x24, x2]
    cmp  w9, #97
    b.lt as2_b
    cmp  w9, #122
    b.gt as2_t
    b    as2_maju
as2_b:
    cmp  w9, #65
    b.lt as2_t
    cmp  w9, #90
    b.gt as2_t
as2_maju:
    add  x2, x2, #1
    b    as2_l
as2_t:
    cbz  x2, as2_no
    cmp  w9, #36
    b.ne as2_no
    mov  x0, #1
    ret
as2_no:
    mov  x0, #0
    ret

// ---------- nilai teks: x1 = buffer tujuan (64 byte) -> x0 = x1 ----------
nilai_str:
    stp  x29, x30, [sp, #-16]!
    stp  x19, x20, [sp, #-16]!
    mov  x19, x1
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #34
    b.eq ns_lit
    ldrb w10, [x24, #1]
    cmp  w10, #36
    b.eq ns_var
    b    ns_fungsi

ns_lit:
    add  x24, x24, #1
    mov  x2, #0
ns_l:
    ldrb w9, [x24]
    cbz  w9, error
    cmp  w9, #10
    b.eq error
    add  x24, x24, #1
    cmp  w9, #34
    b.eq ns_lit_tutup
    cmp  x2, #63
    b.ge ns_l
    strb w9, [x19, x2]
    add  x2, x2, #1
    b    ns_l
ns_lit_tutup:
    strb wzr, [x19, x2]
    b    ns_keluar

ns_var:
    bl   indeks_var
    add  x24, x24, #1
    adrp x1, strs
    add  x1, x1, :lo12:strs
    mov  x2, #64
    madd x1, x0, x2, x1
    mov  x2, #0
ns_v:
    ldrb w9, [x1, x2]
    strb w9, [x19, x2]
    cbz  w9, ns_keluar
    add  x2, x2, #1
    b    ns_v

ns_fungsi_v15:                      // 0 KIRI, 1 KANAN, 2 TENGAH, 3 KAR, 4 TEKS
    ldrb w9, [x24]
    cmp  w9, #97
    b.lt ns_u1
    sub  w9, w9, #32
ns_u1:
    ldrb w10, [x24, #1]
    cmp  w10, #97
    b.lt ns_u2
    sub  w10, w10, #32
ns_u2:
    ldrb w11, [x24, #2]
    cmp  w11, #97
    b.lt ns_u3
    sub  w11, w11, #32
ns_u3:
    cmp  w9, #75                // K
    b.ne ns_f_t
    cmp  w10, #73               // KI = KIRI
    b.ne ns_f_ka
    mov  x20, #0
    b    ns_f_ok
ns_f_ka:
    cmp  w10, #65
    b.ne error
    mov  x20, #1                // KAN = KANAN
    cmp  w11, #78
    b.eq ns_f_ok
    mov  x20, #3                // KAR = KAR$
    cmp  w11, #82
    b.eq ns_f_ok
    b    error
ns_f_t:
    cmp  w9, #84                // T
    b.ne error
    cmp  w10, #69
    b.ne error
    mov  x20, #2                // TEN = TENGAH
    cmp  w11, #78
    b.eq ns_f_ok
    mov  x20, #4                // TEK = TEKS
    cmp  w11, #75
    b.eq ns_f_ok
    b    error

ns_f_ok:
    bl   lewat_kata
    ldrb w9, [x24]
    cmp  w9, #36                // '$'
    b.ne error
    add  x24, x24, #1
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #40                // '('
    b.ne error
    add  x24, x24, #1
    sub  sp, sp, #80            // [sp]=teks, [sp+64]=a, [sp+72]=b
    cmp  x20, #3
    b.ge ns_f_arg1
    mov  x1, sp
    bl   nilai_str
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #44                // ','
    b.ne error
    add  x24, x24, #1
ns_f_arg1:
    bl   expr
    str  x0, [sp, #64]
    cmp  x20, #2
    b.ne ns_f_tutup
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #44
    b.ne error
    add  x24, x24, #1
    bl   expr
    str  x0, [sp, #72]
ns_f_tutup:
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #41                // ')'
    b.ne error
    add  x24, x24, #1

    cmp  x20, #3
    b.ge ns_f_numerik
    mov  x3, #0                 // panjang teks sumber
ns_len:
    ldrb w9, [sp, x3]
    cbz  w9, ns_len_ok
    add  x3, x3, #1
    b    ns_len
ns_len_ok:
    ldr  x4, [sp, #64]
    cmp  x20, #0
    b.ne ns_f_kanan
    mov  x5, #0                 // KIRI: mulai 0, jumlah n
    mov  x6, x4
    b    ns_f_potong
ns_f_kanan:
    cmp  x20, #1
    b.ne ns_f_tengah
    mov  x6, x4                 // KANAN: jumlah n, mulai panjang-n
    sub  x5, x3, x4
    b    ns_f_potong
ns_f_tengah:
    sub  x5, x4, #1             // TENGAH: mulai i-1, jumlah n
    ldr  x6, [sp, #72]
ns_f_potong:
    cmp  x5, #0
    csel x5, xzr, x5, lt
    cmp  x6, #0
    csel x6, xzr, x6, lt
    cmp  x5, x3
    csel x5, x3, x5, gt
    sub  x7, x3, x5
    cmp  x6, x7
    csel x6, x7, x6, gt
    mov  x8, #63
    cmp  x6, x8
    csel x6, x8, x6, gt
    mov  x2, #0
ns_cp:
    cmp  x2, x6
    b.ge ns_cp_tutup
    add  x7, x5, x2
    ldrb w9, [sp, x7]
    strb w9, [x19, x2]
    add  x2, x2, #1
    b    ns_cp
ns_cp_tutup:
    strb wzr, [x19, x2]
    b    ns_f_bersih

ns_f_numerik:
    ldr  x0, [sp, #64]
    cmp  x20, #3
    b.ne ns_f_teks
    strb w0, [x19]              // KAR$(n)
    strb wzr, [x19, #1]
    b    ns_f_bersih
ns_f_teks:                      // TEKS$(n)
    mov  x3, #0
    cmp  x0, #0
    b.ge nt_mulai
    neg  x0, x0
    mov  x3, #1
nt_mulai:
    add  x1, sp, #40
    mov  x2, x1
    mov  x4, #10
nt_loop:
    udiv x5, x0, x4
    msub x6, x5, x4, x0
    add  x6, x6, #48
    sub  x1, x1, #1
    strb w6, [x1]
    mov  x0, x5
    cbnz x0, nt_loop
    cbz  x3, nt_salin
    sub  x1, x1, #1
    mov  w6, #45
    strb w6, [x1]
nt_salin:
    mov  x7, #0
nt_s:
    cmp  x1, x2
    b.ge nt_tutup
    ldrb w9, [x1], #1
    strb w9, [x19, x7]
    add  x7, x7, #1
    b    nt_s
nt_tutup:
    strb wzr, [x19, x7]
ns_f_bersih:
    add  sp, sp, #80
ns_keluar:
    mov  x0, x19
    ldp  x19, x20, [sp], #16
    ldp  x29, x30, [sp], #16
    ret

// ---------- fungsi angka atas teks: PANJANG KODE ANGKA CARI ----------
fk_fungsi_v7:                      // dari fk_var: w9,w10 = dua huruf pertama
    cmp  w9, #97
    b.lt nf_u1
    sub  w9, w9, #32
nf_u1:
    cmp  w10, #97
    b.lt nf_u2
    sub  w10, w10, #32
nf_u2:
    mov  x3, #0                 // PANJANG
    cmp  w9, #80
    b.ne nf_k
    cmp  w10, #65
    b.eq nf_mulai
    b    fk_fungsi_lama
nf_k:
    mov  x3, #1                 // KODE
    cmp  w9, #75
    b.ne nf_a
    cmp  w10, #79
    b.eq nf_mulai
    b    fk_fungsi_lama
nf_a:
    mov  x3, #2                 // ANGKA
    cmp  w9, #65
    b.ne nf_c
    cmp  w10, #78
    b.eq nf_mulai
    b    fk_fungsi_lama
nf_c:
    mov  x3, #3                 // CARI
    cmp  w9, #67
    b.ne fk_fungsi_lama
    cmp  w10, #65
    b.eq nf_mulai
    b    fk_fungsi_lama

nf_mulai:
    sub  sp, sp, #144           // [sp]=teks1, [sp+64]=teks2, [sp+128]=id
    str  x3, [sp, #128]
    bl   lewat_kata
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #40
    b.ne error
    add  x24, x24, #1
    mov  x1, sp
    bl   nilai_str
    ldr  x3, [sp, #128]
    cmp  x3, #3
    b.ne nf_tutup
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #44
    b.ne error
    add  x24, x24, #1
    add  x1, sp, #64
    bl   nilai_str
nf_tutup:
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #41
    b.ne error
    add  x24, x24, #1
    ldr  x3, [sp, #128]
    cmp  x3, #0
    b.eq nf_panjang
    cmp  x3, #1
    b.eq nf_kode
    cmp  x3, #2
    b.eq nf_angka
    b    nf_cari

nf_panjang:
    mov  x0, #0
nf_p1:
    ldrb w9, [sp, x0]
    cbz  w9, nf_beres
    add  x0, x0, #1
    b    nf_p1
nf_kode:
    ldrb w0, [sp]
    b    nf_beres
nf_angka:
    mov  x0, #0
    mov  x2, #0
    mov  x3, #0
    ldrb w9, [sp]
    cmp  w9, #45
    b.ne nf_a1
    mov  x2, #1
    mov  x3, #1
nf_a1:
    ldrb w9, [sp, x3]
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi nf_a2
    mov  x11, #10
    madd x0, x0, x11, x10
    add  x3, x3, #1
    b    nf_a1
nf_a2:
    cbz  x2, nf_beres
    neg  x0, x0
    b    nf_beres
nf_cari:
    mov  x0, #0
    add  x4, sp, #64
nc_luar:
    mov  x2, #0
nc_dalam:
    ldrb w5, [x4, x2]
    cbz  w5, nc_ketemu
    add  x6, x0, x2
    ldrb w7, [sp, x6]
    cmp  w5, w7
    b.ne nc_maju
    add  x2, x2, #1
    b    nc_dalam
nc_maju:
    ldrb w9, [sp, x0]
    cbz  w9, nc_tidak
    add  x0, x0, #1
    b    nc_luar
nc_ketemu:
    add  x0, x0, #1
    b    nf_beres
nc_tidak:
    mov  x0, #0
nf_beres:
    add  sp, sp, #144
    b    fk_keluar

// ---------- TULIS item [; item]... (item boleh fungsi teks) ----------
do_tulis:
    bl   lewat_kata
tw_item:
    bl   skip
    bl   adalah_str
    cbnz x0, tw_str
    bl   expr
    bl   cetak_angka
    b    tw_sesudah
tw_str:
    adrp x1, tmps
    add  x1, x1, :lo12:tmps
    bl   nilai_str
    mov  x1, x0
    mov  x2, #0
tw_len:
    ldrb w9, [x1, x2]
    cbz  w9, tw_cetak
    add  x2, x2, #1
    b    tw_len
tw_cetak:
    mov  x0, #1
    mov  x8, #64
    svc  #0
tw_sesudah:
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #59
    b.ne tw_nl
    add  x24, x24, #1
    bl   skip
    ldrb w9, [x24]
    cbz  w9, akhir
    cmp  w9, #10
    b.eq akhir
    cmp  w9, #35
    b.eq akhir
    b    tw_item
tw_nl:
    bl   cetak_nl
    b    akhir

// ---------- A$ = item + item ... ----------
tugas:
    ldrb w9, [x24, #1]
    cmp  w9, #36
    b.eq tg_str
    b    tugas_v6
tg_str:
    bl   indeks_var
    add  x24, x24, #1
    adrp x19, strs
    add  x19, x19, :lo12:strs
    mov  x2, #64
    madd x19, x0, x2, x19
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #61
    b.ne error
    add  x24, x24, #1
    adrp x20, tmps
    add  x20, x20, :lo12:tmps
    mov  x13, #0
tg_item:
    sub  sp, sp, #64
    mov  x1, sp
    bl   nilai_str
    mov  x2, #0
tg_c:
    ldrb w9, [x0, x2]
    cbz  w9, tg_c_selesai
    add  x2, x2, #1
    cmp  x13, #63
    b.ge tg_c
    strb w9, [x20, x13]
    add  x13, x13, #1
    b    tg_c
tg_c_selesai:
    add  sp, sp, #64
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #43
    b.ne tg_salin
    add  x24, x24, #1
    b    tg_item
tg_salin:
    strb wzr, [x20, x13]
    mov  x2, #0
tg_s:
    ldrb w9, [x20, x2]
    strb w9, [x19, x2]
    add  x2, x2, #1
    cmp  x2, x13
    b.le tg_s
    b    akhir

// ---------- JIKA teks = teks (operand boleh fungsi teks) ----------
do_jika:
    mov  x16, x24
    bl   lewat_kata
    bl   skip
    bl   adalah_str
    cbnz x0, jq_str
    mov  x24, x16
    b    do_jika_v6
jq_str:
    sub  sp, sp, #128           // [sp]=kiri, [sp+64]=kanan
    mov  x1, sp
    bl   nilai_str
    bl   skip
    ldrb w9, [x24]
    ldrb w10, [x24, #1]
    cmp  w9, #61
    b.ne jq_1
    add  x24, x24, #1
    mov  x20, #0
    b    jq_kanan
jq_1:
    cmp  w9, #33
    b.ne jq_2
    cmp  w10, #61
    b.ne error
    add  x24, x24, #2
    mov  x20, #1
    b    jq_kanan
jq_2:
    cmp  w9, #60
    b.ne error
    cmp  w10, #62
    b.ne error
    add  x24, x24, #2
    mov  x20, #1
jq_kanan:
    add  x1, sp, #64
    bl   nilai_str
    bl   skip
    mov  x2, #0
jq_cmp:
    ldrb w3, [sp, x2]
    add  x4, sp, #64
    ldrb w5, [x4, x2]
    cmp  w3, w5
    b.ne jq_beda
    cbz  w3, jq_sama
    add  x2, x2, #1
    b    jq_cmp
jq_sama:
    add  sp, sp, #128
    cbnz x20, akhir
    b    do_lompat
jq_beda:
    add  sp, sp, #128
    cbz  x20, akhir
    b    do_lompat

.text
.balign 4
// ---------- pengenal kata: x1 = kata kunci (HURUF BESAR, berakhir 0) ----------
// hasil x0 = 1 kalau kata di x24 sama persis. w9 dan w10 tidak disentuh.
cocok_kata:
    mov  x2, #0
ck_l:
    ldrb w3, [x1, x2]
    ldrb w4, [x24, x2]
    cmp  w4, #97
    b.lt ck_u
    sub  w4, w4, #32
ck_u:
    cbz  w3, ck_habis
    cmp  w3, w4
    b.ne ck_tidak
    add  x2, x2, #1
    b    ck_l
ck_habis:
    cmp  w4, #65
    b.lt ck_ya
    cmp  w4, #90
    b.le ck_tidak
ck_ya:
    mov  x0, #1
    ret
ck_tidak:
    mov  x0, #0
    ret

kata_v8:
    adr  x1, kw_buka
    bl   cocok_kata
    cbnz x0, do_buka
    adr  x1, kw_tutup
    bl   cocok_kata
    cbnz x0, do_tutup
    adr  x1, kw_bacafile
    bl   cocok_kata
    cbnz x0, do_bacafile
    adr  x1, kw_tulisfile
    bl   cocok_kata
    cbnz x0, do_tulisfile
    b    kata_v7

// ---------- nomor file x0 (1..4) -> x0 = fd, error kalau tidak valid ----------
ambil_fd:
    sub  x1, x0, #1
    cmp  x1, #3
    b.hi error_file
    adrp x13, fdtab
    add  x13, x13, :lo12:fdtab
    ldr  x0, [x13, x1, lsl #3]
    cbz  x0, error_file
    ret

// ---------- BUKA n, nama, mode ----------
do_buka:
    bl   lewat_kata
    bl   expr
    sub  x1, x0, #1
    cmp  x1, #3
    b.hi error_file
    str  x0, [sp, #-16]!
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #44
    b.ne error
    add  x24, x24, #1
    sub  sp, sp, #128           // [sp]=nama, [sp+64]=mode
    mov  x1, sp
    bl   nilai_str
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #44
    b.ne error
    add  x24, x24, #1
    add  x1, sp, #64
    bl   nilai_str
    bl   skip
    ldrb w9, [sp, #64]
    mov  x2, #0                 // r = O_RDONLY
    cmp  w9, #114
    b.eq fo_buka2
    cmp  w9, #82
    b.eq fo_buka2
    mov  x2, #577               // w = O_WRONLY|O_CREAT|O_TRUNC
    cmp  w9, #119
    b.eq fo_buka2
    cmp  w9, #87
    b.eq fo_buka2
    mov  x2, #1089              // a = O_WRONLY|O_CREAT|O_APPEND
    cmp  w9, #97
    b.eq fo_buka2
    cmp  w9, #65
    b.ne error
fo_buka2:
    mov  x0, #-100              // AT_FDCWD
    mov  x1, sp
    mov  x3, #420               // 0644
    mov  x8, #56                // openat
    svc  #0
    cmp  x0, #0
    b.lt error_file
    mov  x11, x0
    add  sp, sp, #128
    ldr  x1, [sp], #16
    sub  x1, x1, #1
    adrp x13, fdtab
    add  x13, x13, :lo12:fdtab
    ldr  x14, [x13, x1, lsl #3]
    cbz  x14, fo_simpan
    mov  x0, x14                // slot sudah terpakai: tutup yang lama
    mov  x8, #57
    svc  #0
fo_simpan:
    str  x11, [x13, x1, lsl #3]
    b    akhir

// ---------- TUTUP n ----------
do_tutup:
    bl   lewat_kata
    bl   expr
    sub  x1, x0, #1
    cmp  x1, #3
    b.hi error_file
    adrp x13, fdtab
    add  x13, x13, :lo12:fdtab
    ldr  x0, [x13, x1, lsl #3]
    cbz  x0, akhir
    str  xzr, [x13, x1, lsl #3]
    mov  x8, #57                // close
    svc  #0
    b    akhir

// ---------- BACAFILE n, A$ ----------
do_bacafile:
    bl   lewat_kata
    bl   expr
    bl   ambil_fd
    mov  x16, x0
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #44
    b.ne error
    add  x24, x24, #1
    bl   skip
    ldrb w9, [x24, #1]
    cmp  w9, #36
    b.ne error
    bl   indeks_var
    add  x24, x24, #1
    adrp x19, strs
    add  x19, x19, :lo12:strs
    mov  x2, #64
    madd x19, x0, x2, x19
    mov  x13, #0
    adrp x15, buf
    add  x15, x15, :lo12:buf
    add  x15, x15, #48
fo_rl:
    mov  x0, x16
    mov  x1, x15
    mov  x2, #1
    mov  x8, #63                // read
    svc  #0
    cmp  x0, #1
    b.ne fo_rs
    ldrb w9, [x15]
    cmp  w9, #10
    b.eq fo_rs
    cmp  w9, #13
    b.eq fo_rl
    cmp  x13, #63
    b.ge fo_rl
    strb w9, [x19, x13]
    add  x13, x13, #1
    b    fo_rl
fo_rs:
    strb wzr, [x19, x13]
    b    akhir

// ---------- TULISFILE n, item [; item]... ----------
do_tulisfile:
    bl   lewat_kata
    bl   expr
    bl   ambil_fd
    mov  x16, x0
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #44
    b.ne error
    add  x24, x24, #1
    mov  x0, #1
    mov  x8, #23                // dup(1): simpan stdout asli
    svc  #0
    cmp  x0, #0
    b.lt error_file
    adrp x13, ofl
    add  x13, x13, :lo12:ofl
    str  x0, [x13]
    mov  x0, x16
    mov  x1, #1
    mov  x2, #0
    mov  x8, #24                // dup3(file, 1, 0): stdout -> file
    svc  #0
    b    tw_item                // pakai mesin TULIS yang sudah ada

// ---------- akhir pernyataan: kembalikan stdout kalau tadi dialihkan ----------
akhir_v14:
    adrp x13, ofl
    add  x13, x13, :lo12:ofl
    ldr  x14, [x13]
    cbz  x14, akhir_lama
    str  xzr, [x13]
    mov  x0, x14
    mov  x1, #1
    mov  x2, #0
    mov  x8, #24                // dup3(simpanan, 1, 0)
    svc  #0
    mov  x0, x14
    mov  x8, #57                // close(simpanan)
    svc  #0
    b    akhir_lama

// ---------- AKHIR(n): 1 kalau sudah di akhir file ----------
fk_fungsi_v8:
    mov  w11, w9
    cmp  w11, #97
    b.lt ak_1
    sub  w11, w11, #32
ak_1:
    mov  w12, w10
    cmp  w12, #97
    b.lt ak_2
    sub  w12, w12, #32
ak_2:
    cmp  w11, #65               // A
    b.ne fk_fungsi_v7
    cmp  w12, #75               // K
    b.ne fk_fungsi_v7
    bl   lewat_kata
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #40
    b.ne error
    add  x24, x24, #1
    bl   expr
    bl   ambil_fd
    mov  x16, x0
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #41
    b.ne error
    add  x24, x24, #1
    sub  sp, sp, #16
    mov  x0, x16
    mov  x1, sp
    mov  x2, #1
    mov  x8, #63                // read 1 byte (mengintip)
    svc  #0
    cmp  x0, #0
    b.le ak_eof
    mov  x0, x16
    mov  x1, #-1
    mov  x2, #1                 // SEEK_CUR
    mov  x8, #62                // lseek mundur 1 byte
    svc  #0
    mov  x0, #0
    b    ak_selesai
ak_eof:
    mov  x0, #1
ak_selesai:
    add  sp, sp, #16
    b    fk_keluar

error_file:
    mov  x0, #2
    adr  x1, pesan_file
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0

kw_buka:      .asciz "BUKA"
kw_tutup:     .asciz "TUTUP"
kw_bacafile:  .asciz "BACAFILE"
kw_tulisfile: .asciz "TULISFILE"
pesan_file:   .asciz "error: operasi file gagal (nomor 1-4, file tidak ada, atau slot belum dibuka)\n"

.bss
.balign 16
fdtab: .skip 32
ofl:   .skip 16

.text
.balign 4
// cari_baris cepat: x0 = nomor tujuan -> x24 = awal baris itu
// tabel lintab[n] = alamat baris bernomor n (0..9999), dibuat sekali
cari_baris:
    mov  x5, #9999
    cmp  x0, x5
    b.hi cari_baris_lama
    adrp x1, lintab
    add  x1, x1, :lo12:lintab
    adrp x2, lintab_ok
    add  x2, x2, :lo12:lintab_ok
    ldr  x3, [x2]
    cbnz x3, tb_cari
    mov  x3, #1
    str  x3, [x2]
    mov  x4, x21                // penunjuk baca
tb_baris:
tb_skip:
    ldrb w6, [x4]
    cmp  w6, #32
    b.eq tb_maju
    cmp  w6, #9
    b.eq tb_maju
    cmp  w6, #13
    b.ne tb_skip_selesai
tb_maju:
    add  x4, x4, #1
    b    tb_skip
tb_skip_selesai:
    cbz  w6, tb_cari            // akhir file
    mov  x7, x4                 // awal angka
    mov  x10, #0
tb_num:
    ldrb w6, [x4]
    sub  w9, w6, #48
    cmp  w9, #9
    b.hi tb_num_selesai
    mov  x11, #10
    madd x10, x10, x11, x9
    add  x4, x4, #1
    b    tb_num
tb_num_selesai:
    cmp  x4, x7                 // tidak ada angka: bukan baris bernomor
    b.eq tb_lanjut
    mov  x5, #9999
    cmp  x10, x5
    b.hi tb_lanjut
    ldr  x9, [x1, x10, lsl #3]
    cbnz x9, tb_lanjut          // sudah ada: yang pertama menang
    str  x7, [x1, x10, lsl #3]
tb_lanjut:
    ldrb w6, [x4]
    cbz  w6, tb_cari
    add  x4, x4, #1
    cmp  w6, #10
    b.ne tb_lanjut
    b    tb_baris
tb_cari:
    ldr  x9, [x1, x0, lsl #3]
    cbz  x9, error_baris
    mov  x24, x9
    ret

.bss
.balign 16
lintab:    .skip 80000
lintab_ok: .skip 16

.text
.balign 4
// ---------- kata kunci LABEL (dicek sebelum kata lain) ----------
kata_v10:
    adr  x1, kw_label
    bl   cocok_kata
    cbnz x0, akhir              // LABEL tidak melakukan apa-apa
    b    kata_v8

// ---------- karakter nama: w9 -> huruf besar/angka/_ , selain itu 0 ----------
nm_norm:
    cmp  w9, #97
    b.lt nn_1
    cmp  w9, #122
    b.gt nn_nol
    sub  w9, w9, #32
    ret
nn_1:
    cmp  w9, #95
    b.eq nn_ok
    cmp  w9, #65
    b.lt nn_digit
    cmp  w9, #90
    b.le nn_ok
    b    nn_nol
nn_digit:
    cmp  w9, #48
    b.lt nn_nol
    cmp  w9, #57
    b.le nn_ok
nn_nol:
    mov  w9, #0
nn_ok:
    ret

lewat_nama:                     // x24 melewati karakter nama
    stp  x29, x30, [sp, #-16]!
ln_l:
    ldrb w9, [x24]
    bl   nm_norm
    cbz  w9, ln_selesai
    add  x24, x24, #1
    b    ln_l
ln_selesai:
    ldp  x29, x30, [sp], #16
    ret

// ---------- isi tabel label dari program (sekali saja) ----------
// labtab[i] = (awal baris, awal nama), maksimal 64
bangun_label:
    adrp x1, labtab
    add  x1, x1, :lo12:labtab
    adr  x7, kw_label
    mov  x5, #0
    mov  x4, x21
lb_baris:
    mov  x6, x4
lb_s1:
    ldrb w9, [x4]
    cmp  w9, #32
    b.eq lb_s1m
    cmp  w9, #9
    b.eq lb_s1m
    cmp  w9, #13
    b.ne lb_n
lb_s1m:
    add  x4, x4, #1
    b    lb_s1
lb_n:
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi lb_s2
    add  x4, x4, #1
    ldrb w9, [x4]
    b    lb_n
lb_s2:
    cmp  w9, #32
    b.eq lb_s2m
    cmp  w9, #9
    b.eq lb_s2m
    cmp  w9, #13
    b.ne lb_kata
lb_s2m:
    add  x4, x4, #1
    ldrb w9, [x4]
    b    lb_s2
lb_kata:
    cbz  w9, lb_selesai
    mov  x10, #0
lb_cmp:
    ldrb w12, [x7, x10]
    ldrb w9, [x4, x10]
    cmp  w9, #97
    b.lt lb_cu
    sub  w9, w9, #32
lb_cu:
    cbz  w12, lb_cocok
    cmp  w12, w9
    b.ne lb_baris_lain
    add  x10, x10, #1
    b    lb_cmp
lb_cocok:
    ldrb w9, [x4, x10]
    cmp  w9, #32
    b.eq lb_nama
    cmp  w9, #9
    b.ne lb_baris_lain
lb_nama:
    add  x4, x4, x10
lb_s3:
    ldrb w9, [x4]
    cmp  w9, #32
    b.eq lb_s3m
    cmp  w9, #9
    b.ne lb_simpan
lb_s3m:
    add  x4, x4, #1
    b    lb_s3
lb_simpan:
    cmp  x5, #64
    b.ge error_labpenuh
    add  x11, x1, x5, lsl #4
    stp  x6, x4, [x11]
    add  x5, x5, #1
lb_baris_lain:
    ldrb w9, [x4]
    cbz  w9, lb_selesai
    add  x4, x4, #1
    cmp  w9, #10
    b.ne lb_baris_lain
    b    lb_baris
lb_selesai:
    adrp x2, labn
    add  x2, x2, :lo12:labn
    str  x5, [x2]
    ret

// ---------- x0 = awal nama -> x24 = awal baris LABEL itu ----------
cari_label:
    stp  x29, x30, [sp, #-16]!
    mov  x14, x0
    ldrb w9, [x14]
    bl   nm_norm
    cbz  w9, cl_tidak
    adrp x2, labok
    add  x2, x2, :lo12:labok
    ldr  x3, [x2]
    cbnz x3, cl_cari
    mov  x3, #1
    str  x3, [x2]
    bl   bangun_label
cl_cari:
    adrp x1, labtab
    add  x1, x1, :lo12:labtab
    adrp x2, labn
    add  x2, x2, :lo12:labn
    ldr  x5, [x2]
    mov  x6, #0
cl_entri:
    cmp  x6, x5
    b.ge cl_tidak
    add  x7, x1, x6, lsl #4
    ldr  x8, [x7, #8]
    mov  x10, #0
cl_cmp:
    ldrb w9, [x14, x10]
    bl   nm_norm
    mov  w11, w9
    ldrb w9, [x8, x10]
    bl   nm_norm
    cmp  w11, w9
    b.ne cl_lanjut
    cbz  w9, cl_ketemu
    add  x10, x10, #1
    b    cl_cmp
cl_lanjut:
    add  x6, x6, #1
    b    cl_entri
cl_ketemu:
    ldr  x24, [x7]
    ldp  x29, x30, [sp], #16
    ret
cl_tidak:
    mov  x24, x14
    b    error_label

// ---------- LOMPAT angka atau nama ----------
do_lompat_v14:
    ldrb w9, [x24]
    cmp  w9, #71
    b.eq do_gosub
    cmp  w9, #103
    b.eq do_gosub
    mov  x16, x24
    bl   lewat_kata
    bl   skip
    ldrb w9, [x24]
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi dl_label
    mov  x24, x16
    b    do_lompat_lama
dl_label:
    mov  x0, x24
    bl   cari_label
    b    baris

// ---------- GOSUB angka atau nama ----------
do_gosub:
    mov  x16, x24
    bl   lewat_kata
    bl   skip
    ldrb w9, [x24]
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi dg_label
    mov  x24, x16
    b    do_gosub_lama
dg_label:
    mov  x15, x24
    bl   lewat_nama
    cmp  x28, #64
    b.ge error_stack
    adrp x13, rstack
    add  x13, x13, :lo12:rstack
    str  x24, [x13, x28, lsl #3]
    add  x28, x28, #1
    mov  x0, x15
    bl   cari_label
    b    baris

// ---------- error ----------
error_label:
    mov  x0, #2
    adr  x1, pesan_label
    bl   cetak_z
    mov  x1, x24
    mov  x2, #0
el_len:
    ldrb w9, [x1, x2]
    cbz  w9, el_cetak
    cmp  w9, #10
    b.eq el_cetak
    cmp  w9, #32
    b.eq el_cetak
    add  x2, x2, #1
    cmp  x2, #40
    b.lt el_len
el_cetak:
    mov  x0, #2
    mov  x8, #64
    svc  #0
    mov  x0, #2
    adr  x1, pesan_nl
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0
error_labpenuh:
    mov  x0, #2
    adr  x1, pesan_labpenuh
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0

kw_label:        .asciz "LABEL"
pesan_label:     .asciz "error: label tidak ada: "
pesan_labpenuh:  .asciz "error: terlalu banyak label (maksimal 64)\n"

.bss
.balign 16
labtab: .skip 1024
labn:   .skip 16
labok:  .skip 16

.text
.balign 4
kata_v11:
    adr  x1, kw_include
    bl   cocok_kata
    cbnz x0, do_include
    b    kata_v10

// INCLUDE nama: tempel isi file di akhir program, didahului BERHENTI penjaga
do_include:
    bl   lewat_kata
    sub  sp, sp, #64
    mov  x1, sp
    bl   nilai_str              // nama file di [sp]
    mov  x0, #-100              // AT_FDCWD
    mov  x1, sp
    mov  x2, #0                 // O_RDONLY
    mov  x8, #56                // openat
    svc  #0
    add  sp, sp, #64
    cmp  x0, #0
    b.lt error_include
    mov  x16, x0                // fd
    mov  x4, x21                // cari akhir program (byte nol pertama)
di_end:
    ldrb w5, [x4]
    cbz  w5, di_end_ok
    add  x4, x4, #1
    b    di_end
di_end_ok:
    mov  x6, #65000
    add  x6, x21, x6            // batas penulisan
    adr  x1, kw_sisip
di_cp:
    ldrb w5, [x1], #1
    cbz  w5, di_cp_ok
    cmp  x4, x6
    b.ge error_include
    strb w5, [x4], #1
    b    di_cp
di_cp_ok:
di_rd:
    sub  x2, x6, x4
    cmp  x2, #0
    b.le di_tutup
    mov  x0, x16
    mov  x1, x4
    mov  x8, #63                // read
    svc  #0
    cmp  x0, #0
    b.le di_tutup
    add  x4, x4, x0
    b    di_rd
di_tutup:
    mov  x0, x16
    mov  x8, #57                // close
    svc  #0
    adrp x1, lintab_ok          // paksa tabel baris dan label dibangun ulang
    add  x1, x1, :lo12:lintab_ok
    str  xzr, [x1]
    adrp x1, labok
    add  x1, x1, :lo12:labok
    str  xzr, [x1]
    b    akhir

error_include:
    mov  x0, #2
    adr  x1, pesan_include
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0

kw_include:    .asciz "INCLUDE"
kw_sisip:      .asciz "\nBERHENTI\n"
pesan_include: .asciz "error: INCLUDE gagal (file tidak ada atau program terlalu besar)\n"

.text
.balign 4
// ---------- kata kunci baru ----------
kata_v12:
    adr  x1, kw_fungsi
    bl   cocok_kata
    cbnz x0, do_fungsi
    adr  x1, kw_akhirf
    bl   cocok_kata
    cbnz x0, do_akhirf
    adr  x1, kw_hasil
    bl   cocok_kata
    cbnz x0, do_hasil
    adr  x1, kw_panggil
    bl   cocok_kata
    cbnz x0, do_panggil
    b    kata_v11

// FUNGSI dijalankan langsung: lewati sampai baris AKHIRFUNGSI
do_fungsi:
df_baris:
    ldrb w9, [x24]
    cbz  w9, berhenti
    add  x24, x24, #1
    cmp  w9, #10
    b.ne df_baris
    bl   skip
    ldrb w9, [x24]
    cbz  w9, berhenti
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi df_kata
    bl   angka
    bl   skip
df_kata:
    adr  x1, kw_akhirf
    bl   cocok_kata
    cbz  x0, df_baris
    b    akhir

// AKHIRFUNGSI dijalankan di dalam panggilan: kembali dengan nilai 0
do_akhirf:
    adrp x1, pgl_n
    add  x1, x1, :lo12:pgl_n
    ldr  x2, [x1]
    cbz  x2, akhir
    mov  x0, #0
    b    uf_kembali

// PANGGIL nama(args): hitung sebagai ekspresi, buang hasilnya
do_panggil:
    bl   lewat_kata
    bl   expr
    b    akhir

// HASIL ekspresi
do_hasil:
    bl   lewat_kata
    bl   expr
    b    uf_kembali

// ---------- tabel fungsi: fn_tab[i] = alamat nama di baris FUNGSI ----------
// fn_meta[0] = jumlah, fn_meta[8] = alamat akhir program saat tabel dibuat
bangun_fungsi:
    stp  x29, x30, [sp, #-16]!
    str  x24, [sp, #-16]!
    adrp x6, fn_tab
    add  x6, x6, :lo12:fn_tab
    mov  x5, #0
    mov  x24, x21
bf_baris:
    bl   skip
    ldrb w9, [x24]
    cbz  w9, bf_selesai
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi bf_kata
    bl   angka
    bl   skip
bf_kata:
    adr  x1, kw_fungsi
    bl   cocok_kata
    cbz  x0, bf_lain
    add  x24, x24, #6
    bl   skip
    cmp  x5, #32
    b.ge error_fpenuh
    str  x24, [x6, x5, lsl #3]
    add  x5, x5, #1
bf_lain:
    ldrb w9, [x24]
    cbz  w9, bf_selesai
    add  x24, x24, #1
    cmp  w9, #10
    b.ne bf_lain
    b    bf_baris
bf_selesai:
    adrp x2, fn_meta
    add  x2, x2, :lo12:fn_meta
    str  x5, [x2]
    str  x24, [x2, #8]
    ldr  x24, [sp], #16
    ldp  x29, x30, [sp], #16
    ret

// x0 = awal nama pada pemanggilan -> x0 = alamat nama di deklarasi, atau 0
cari_fungsi:
    stp  x29, x30, [sp, #-16]!
    str  x0, [sp, #-16]!
    adrp x2, fn_meta
    add  x2, x2, :lo12:fn_meta
    ldr  x3, [x2, #8]
    cbz  x3, cf_bangun
    ldrb w4, [x3]               // tabel basi kalau INCLUDE menambah teks
    cbz  w4, cf_cari
cf_bangun:
    bl   bangun_fungsi
cf_cari:
    ldr  x0, [sp]
    adrp x2, fn_meta
    add  x2, x2, :lo12:fn_meta
    ldr  x5, [x2]
    adrp x1, fn_tab
    add  x1, x1, :lo12:fn_tab
    mov  x6, #0
cf_entri:
    cmp  x6, x5
    b.ge cf_tidak
    ldr  x7, [x1, x6, lsl #3]
    mov  x10, #0
cf_cmp:
    ldrb w9, [x0, x10]
    bl   nm_norm
    mov  w11, w9
    ldrb w9, [x7, x10]
    bl   nm_norm
    cmp  w11, w9
    b.ne cf_lanjut
    cbz  w9, cf_ketemu
    add  x10, x10, #1
    b    cf_cmp
cf_lanjut:
    add  x6, x6, #1
    b    cf_entri
cf_ketemu:
    mov  x0, x7
    b    cf_keluar
cf_tidak:
    mov  x0, #0
cf_keluar:
    add  sp, sp, #16
    ldp  x29, x30, [sp], #16
    ret

// ---------- pemanggilan dari ekspresi (dicek sebelum fungsi bawaan) ----------
fk_fungsi_v17:
    mov  x0, x24
    bl   cari_fungsi
    cbnz x0, uf_panggil
    ldrb w9, [x24]
    ldrb w10, [x24, #1]
    b    fk_fungsi_v8

// Bingkai panggilan (336 byte), sp = F:
//  +0 alamat kembali   +8 jumlah parameter   +16 indeks[4]   +48 nilai lama[4]
//  +80 x12..x20        +160 tmps dan tmps2   +288 x28   +296 fsp   +304 argumen[4]
uf_panggil:                     // x0 = nama di deklarasi FUNGSI
    sub  sp, sp, #848
    stp  x12, x13, [sp, #80]
    stp  x14, x15, [sp, #96]
    stp  x16, x17, [sp, #112]
    stp  x18, x19, [sp, #128]
    str  x20, [sp, #144]
    str  x28, [sp, #288]
    adrp x1, fsp
    add  x1, x1, :lo12:fsp
    ldr  x2, [x1]
    str  x2, [sp, #296]
    adrp x1, tmps               // tmps dan tmps2 berurutan di memori
    add  x1, x1, :lo12:tmps
    add  x2, sp, #160
    mov  x3, #0
uf_sv:
    ldr  x4, [x1, x3]
    str  x4, [x2, x3]
    add  x3, x3, #8
    cmp  x3, #128
    b.lt uf_sv
    mov  x20, x0
    // lewati nama pada pemanggilan
uf_n1:
    ldrb w9, [x24]
    bl   nm_norm
    cbz  w9, uf_n1_ok
    add  x24, x24, #1
    b    uf_n1
uf_n1_ok:
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #40
    b.ne error
    add  x24, x24, #1
    mov  x19, #0                // jumlah argumen
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #41
    b.eq uf_a_ok
uf_arg:
    cmp  x19, #4
    b.ge error
    bl   usf_arg
    add  x1, sp, #304
    str  x0, [x1, x19, lsl #3]
    add  x19, x19, #1
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #44
    b.ne uf_a_tutup
    add  x24, x24, #1
    b    uf_arg
uf_a_tutup:
    cmp  w9, #41
    b.ne error
uf_a_ok:
    add  x24, x24, #1
    str  x24, [sp]              // posisi kembali
    // baca parameter dari deklarasi
    mov  x24, x20
uf_d1:
    ldrb w9, [x24]
    bl   nm_norm
    cbz  w9, uf_d1_ok
    add  x24, x24, #1
    b    uf_d1
uf_d1_ok:
    ldrb w9, [x24]
    cmp  w9, #36
    b.ne usf_nd
    add  x24, x24, #1
usf_nd:
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #40
    b.ne error
    add  x24, x24, #1
    mov  x20, #0                // jumlah parameter
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #41
    b.eq uf_p_ok
uf_par:
    cmp  x20, #4
    b.ge error
    bl   skip
    bl   usf_par
    add  x1, sp, #16
    str  x0, [x1, x20, lsl #3]
    add  x20, x20, #1
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #44
    b.ne uf_p_tutup
    add  x24, x24, #1
    b    uf_par
uf_p_tutup:
    cmp  w9, #41
    b.ne error
uf_p_ok:
    add  x24, x24, #1
    str  x20, [sp, #8]
uf_eol:                         // x24 = awal isi fungsi (baris berikutnya)
    ldrb w9, [x24]
    cbz  w9, uf_eol_ok
    add  x24, x24, #1
    cmp  w9, #10
    b.ne uf_eol
uf_eol_ok:
    // isi parameter: simpan nilai lama, pasang argumen (atau 0)
    mov  x3, #0
uf_bind:
    cmp  x3, x20
    b.ge uf_bind_ok
    add  x1, sp, #16
    ldr  x4, [x1, x3, lsl #3]
    tbnz x4, #8, usf_bind_teks
    ldr  x5, [x22, x4, lsl #3]
    add  x1, sp, #48
    str  x5, [x1, x3, lsl #3]
    mov  x6, #0
    cmp  x3, x19
    b.ge uf_set
    add  x1, sp, #304
    ldr  x6, [x1, x3, lsl #3]
uf_set:
    str  x6, [x22, x4, lsl #3]
    add  x3, x3, #1
    b    uf_bind
uf_bind_ok:
    adrp x1, pgl_n
    add  x1, x1, :lo12:pgl_n
    ldr  x2, [x1]
    cmp  x2, #64
    b.ge error_rekursi
    adrp x3, pgl_stk
    add  x3, x3, :lo12:pgl_stk
    mov  x4, sp
    str  x4, [x3, x2, lsl #3]
    add  x2, x2, #1
    str  x2, [x1]
    b    baris                  // jalankan isi fungsi

// ---------- keluar dari fungsi: x0 = hasil ----------
uf_kembali:
    adrp x1, pgl_n
    add  x1, x1, :lo12:pgl_n
    ldr  x2, [x1]
    cbz  x2, error_hasil
    sub  x2, x2, #1
    str  x2, [x1]
    adrp x3, pgl_stk
    add  x3, x3, :lo12:pgl_stk
    ldr  x4, [x3, x2, lsl #3]
    mov  sp, x4                 // kembali ke bingkai panggilan
    ldr  x5, [sp, #8]
uf_rs:                          // kembalikan parameter, dari belakang
    cbz  x5, uf_rs_ok
    sub  x5, x5, #1
    add  x1, sp, #16
    ldr  x6, [x1, x5, lsl #3]
    tbnz x6, #8, usf_rest_teks
    add  x1, sp, #48
    ldr  x7, [x1, x5, lsl #3]
    str  x7, [x22, x6, lsl #3]
    b    uf_rs
uf_rs_ok:
    adrp x1, tmps
    add  x1, x1, :lo12:tmps
    add  x2, sp, #160
    mov  x3, #0
uf_rt:
    ldr  x4, [x2, x3]
    str  x4, [x1, x3]
    add  x3, x3, #8
    cmp  x3, #128
    b.lt uf_rt
    ldr  x28, [sp, #288]
    ldr  x2, [sp, #296]
    adrp x1, fsp
    add  x1, x1, :lo12:fsp
    str  x2, [x1]
    ldp  x12, x13, [sp, #80]
    ldp  x14, x15, [sp, #96]
    ldp  x16, x17, [sp, #112]
    ldp  x18, x19, [sp, #128]
    ldr  x20, [sp, #144]
    ldr  x24, [sp]
    add  sp, sp, #848
    b    fk_keluar

// ---------- error ----------
error_hasil:
    mov  x0, #2
    adr  x1, pesan_hasil
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0
error_rekursi:
    ldr  x24, [sp]
    mov  x0, #2
    adr  x1, pesan_rekursi
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0
error_fpenuh:
    mov  x0, #2
    adr  x1, pesan_fpenuh
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0

kw_fungsi:      .asciz "FUNGSI"
kw_akhirf:      .asciz "AKHIRFUNGSI"
kw_hasil:       .asciz "HASIL"
kw_panggil:     .asciz "PANGGIL"
pesan_hasil:    .asciz "error: HASIL di luar fungsi\n"
pesan_rekursi:  .asciz "error: panggilan fungsi terlalu dalam (maksimal 64)\n"
pesan_fpenuh:   .asciz "error: terlalu banyak fungsi (maksimal 32)\n"

.bss
.balign 16
fn_tab:  .skip 256
fn_meta: .skip 16
pgl_n:   .skip 16
pgl_stk: .skip 512

.text
.balign 8
magic_paket: .ascii "BKPAKET1"
path_self:   .asciz "/proc/self/exe"
.balign 4
// titik masuk baru: cek dulu apakah file ini membawa program tertanam
_start:
    sub  sp, sp, #32
    mov  x0, #-100              // AT_FDCWD
    adr  x1, path_self
    mov  x2, #0                 // O_RDONLY
    mov  x8, #56                // openat
    svc  #0
    cmp  x0, #0
    b.lt st_biasa
    mov  x23, x0                // fd diri sendiri
    mov  x0, x23
    mov  x1, #-16
    mov  x2, #2                 // SEEK_END
    mov  x8, #62                // lseek
    svc  #0
    cmp  x0, #0
    b.lt st_tutup
    mov  x0, x23
    mov  x1, sp
    mov  x2, #16
    mov  x8, #63                // read ekor: magic(8) + panjang(8)
    svc  #0
    cmp  x0, #16
    b.ne st_tutup
    adr  x3, magic_paket
    ldr  x4, [x3]
    ldr  x5, [sp]
    cmp  x4, x5
    b.ne st_tutup
    ldr  x25, [sp, #8]          // panjang program tertanam
    cmp  x25, #0
    b.le st_tutup
    mov  x26, #65000
    cmp  x25, x26
    b.ge st_tutup
    add  x1, x25, #16
    neg  x1, x1
    mov  x0, x23
    mov  x2, #2                 // SEEK_END
    mov  x8, #62                // lseek ke awal program
    svc  #0
    cmp  x0, #0
    b.lt st_tutup
    adrp x21, prog
    add  x21, x21, :lo12:prog
    mov  x4, #0                 // byte yang sudah terbaca
st_baca:
    mov  x0, x23
    add  x1, x21, x4
    sub  x2, x25, x4
    mov  x8, #63                // read
    svc  #0
    cmp  x0, #0
    b.le gagal_buka
    add  x4, x4, x0
    cmp  x4, x25
    b.lt st_baca
    adrp x22, vars
    add  x22, x22, :lo12:vars
    mov  x28, #0
    add  sp, sp, #32
    b    baca_selesai           // menutup x23, lalu x24 = awal program
st_tutup:
    mov  x0, x23
    mov  x8, #57                // close
    svc  #0
st_biasa:
    add  sp, sp, #32
    b    _start_lama

.text
.balign 4
// cetak "  pada baris N: teks" ke stderr; x24 = kursor, x21 = awal program
lapor_baris:
    stp  x29, x30, [sp, #-16]!
    sub  x9, x24, x21
    mov  x10, #65536
    cmp  x9, x10
    b.hs lpr_selesai             // kursor di luar program: lewati
    mov  x13, x24               // cari awal baris
lpr_mundur:
    cmp  x13, x21
    b.ls lpr_awal
    ldrb w9, [x13, #-1]
    cmp  w9, #10
    b.eq lpr_awal
    sub  x13, x13, #1
    b    lpr_mundur
lpr_awal:
    mov  x3, x21                // hitung nomor baris
    mov  x4, #1
lpr_hitung:
    cmp  x3, x13
    b.hs lpr_cetak
    ldrb w9, [x3], #1
    cmp  w9, #10
    b.ne lpr_hitung
    add  x4, x4, #1
    b    lpr_hitung
lpr_cetak:
    mov  x0, #2
    adr  x1, pesan_pada
    bl   cetak_z
    sub  sp, sp, #48
    add  x1, sp, #32
    mov  x2, x1
lpr_digit:
    mov  x5, #10
    udiv x6, x4, x5
    msub x7, x6, x5, x4
    add  x7, x7, #48
    sub  x1, x1, #1
    strb w7, [x1]
    mov  x4, x6
    cbnz x4, lpr_digit
    sub  x2, x2, x1
    mov  x0, #2
    mov  x8, #64
    svc  #0
    add  sp, sp, #48
    mov  x0, #2
    adr  x1, pesan_titik
    bl   cetak_z
    mov  x2, #0
lpr_len:
    ldrb w9, [x13, x2]
    cbz  w9, lpr_tulis
    cmp  w9, #10
    b.eq lpr_tulis
    add  x2, x2, #1
    cmp  x2, #60
    b.lt lpr_len
lpr_tulis:
    mov  x0, #2
    mov  x1, x13
    mov  x8, #64
    svc  #0
    mov  x0, #2
    adr  x1, pesan_nl
    bl   cetak_z
lpr_selesai:
    ldp  x29, x30, [sp], #16
    ret
pesan_pada:  .asciz "  pada baris "
pesan_titik: .asciz ": "

.text
.balign 4
// ---------- KALAU/LAIN/AKHIRKALAU dan SELAMA/AKHIRSELAMA ----------
kata_v15:
    cmp  w9, #75                // K
    b.eq blk_cek
    cmp  w9, #76                // L
    b.eq blk_cek
    cmp  w9, #65                // A
    b.eq blk_cek
    cmp  w9, #83                // S
    b.eq blk_cek
    b    kata_v12
blk_cek:
    adr  x1, kw_kalau
    bl   cocok_kata
    cbnz x0, do_kalau
    adr  x1, kw_lain
    bl   cocok_kata
    cbnz x0, do_lain
    adr  x1, kw_akhirkalau
    bl   cocok_kata
    cbnz x0, do_akhirkalau
    adr  x1, kw_selama
    bl   cocok_kata
    cbnz x0, do_selama
    adr  x1, kw_akhirselama
    bl   cocok_kata
    cbnz x0, do_akhirselama
    b    kata_v12

// KALAU/SELAMA memakai mesin kondisi JIKA: jenisnya dicatat per kedalaman
// panggilan fungsi (kl_mode[pgl_n]); hasil kondisi ditangkap oleh do_lompat
// (benar) atau akhir (salah)
do_kalau:
    mov  x1, #1
    b    blk_mulai
do_selama:
    mov  x1, #2
blk_mulai:
    adrp x2, pgl_n
    add  x2, x2, :lo12:pgl_n
    ldr  x3, [x2]
    adrp x2, kl_mode
    add  x2, x2, :lo12:kl_mode
    str  x1, [x2, x3, lsl #3]
    b    do_jika

do_lompat:
    adrp x9, pgl_n
    add  x9, x9, :lo12:pgl_n
    ldr  x10, [x9]
    adrp x9, kl_mode
    add  x9, x9, :lo12:kl_mode
    ldr  x11, [x9, x10, lsl #3]
    cbz  x11, do_lompat_v14
    str  xzr, [x9, x10, lsl #3]  // kondisi benar: lanjut ke baris berikutnya
    b    akhir

akhir:
    adrp x9, pgl_n
    add  x9, x9, :lo12:pgl_n
    ldr  x10, [x9]
    adrp x9, kl_mode
    add  x9, x9, :lo12:kl_mode
    ldr  x12, [x9, x10, lsl #3]
    cbz  x12, akhir_v14
    str  xzr, [x9, x10, lsl #3]  // kondisi salah: lompati isi blok (x12 = jenis)

blk_salah:
    mov  x13, x24
blk_s1:
    ldrb w9, [x13]
    cbz  w9, error_blok
    add  x13, x13, #1
    cmp  w9, #10
    b.ne blk_s1
    cmp  x12, #2
    b.eq blk_s2
    mov  x14, #1                // cari LAIN atau AKHIRKALAU
    bl   sk_maju
    cmp  w0, #3
    b.ne blk_pindah             // AKHIRKALAU: mulai dari barisnya
blk_lewat:                      // LAIN: mulai dari baris sesudahnya
    ldrb w9, [x13]
    cbz  w9, blk_pindah
    add  x13, x13, #1
    cmp  w9, #10
    b.ne blk_lewat
blk_pindah:
    mov  x24, x13
    b    baris
blk_s2:
    mov  x14, #3                // cari AKHIRSELAMA
    bl   sk_maju
    b    blk_lewat

// LAIN dijalankan dari cabang benar: lompat ke AKHIRKALAU
do_lain:
    mov  x13, x24
blk_l1:
    ldrb w9, [x13]
    cbz  w9, error_blok
    add  x13, x13, #1
    cmp  w9, #10
    b.ne blk_l1
    mov  x14, #2
    bl   sk_maju
    mov  x24, x13
    b    baris

do_akhirkalau:
    b    akhir

// AKHIRSELAMA: mundur ke SELAMA pasangannya, lalu evaluasi ulang
do_akhirselama:
    mov  x13, x24
blk_m1:
    cmp  x13, x21
    b.ls blk_m2
    ldrb w9, [x13, #-1]
    cmp  w9, #10
    b.eq blk_m2
    sub  x13, x13, #1
    b    blk_m1
blk_m2:
    bl   sk_mundur
    mov  x24, x13
    b    baris

// x13 = awal baris -> x0 = jenis kata di baris itu:
// 1 KALAU, 2 AKHIRKALAU, 3 LAIN, 4 SELAMA, 5 AKHIRSELAMA, 0 lainnya
kw_kode:
    stp  x29, x30, [sp, #-16]!
    str  x24, [sp, #-16]!
    mov  x24, x13
    bl   skip
    ldrb w9, [x24]
    sub  w10, w9, #48
    cmp  w10, #9
    b.hi blk_k1
    bl   angka
    bl   skip
blk_k1:
    adr  x1, kw_kalau
    bl   cocok_kata
    mov  x5, #1
    cbnz x0, blk_k2
    adr  x1, kw_akhirkalau
    bl   cocok_kata
    mov  x5, #2
    cbnz x0, blk_k2
    adr  x1, kw_lain
    bl   cocok_kata
    mov  x5, #3
    cbnz x0, blk_k2
    adr  x1, kw_selama
    bl   cocok_kata
    mov  x5, #4
    cbnz x0, blk_k2
    adr  x1, kw_akhirselama
    bl   cocok_kata
    mov  x5, #5
    cbnz x0, blk_k2
    mov  x5, #0
blk_k2:
    mov  x0, x5
    ldr  x24, [sp], #16
    ldp  x29, x30, [sp], #16
    ret

// maju dari baris x13. x14 = 1 cari LAIN/AKHIRKALAU, 2 cari AKHIRKALAU, 3 cari AKHIRSELAMA
// hasil: x13 = awal baris yang ditemukan, x0 = jenisnya
sk_maju:
    stp  x29, x30, [sp, #-16]!
    mov  x15, #0
sm_baris:
    ldrb w9, [x13]
    cbz  w9, error_blok
    bl   kw_kode
    cmp  x14, #3
    b.eq sm_loop
    cmp  w0, #1
    b.ne sm_a
    add  x15, x15, #1
    b    sm_lanjut
sm_a:
    cmp  w0, #2
    b.ne sm_b
    cbz  x15, sm_ketemu
    sub  x15, x15, #1
    b    sm_lanjut
sm_b:
    cmp  w0, #3
    b.ne sm_lanjut
    cmp  x14, #1
    b.ne sm_lanjut
    cbz  x15, sm_ketemu
    b    sm_lanjut
sm_loop:
    cmp  w0, #4
    b.ne sm_c
    add  x15, x15, #1
    b    sm_lanjut
sm_c:
    cmp  w0, #5
    b.ne sm_lanjut
    cbz  x15, sm_ketemu
    sub  x15, x15, #1
sm_lanjut:
    ldrb w9, [x13]
    cbz  w9, error_blok
    add  x13, x13, #1
    cmp  w9, #10
    b.ne sm_lanjut
    b    sm_baris
sm_ketemu:
    ldp  x29, x30, [sp], #16
    ret

// mundur dari baris x13 (AKHIRSELAMA) ke SELAMA pasangannya -> x13
sk_mundur:
    stp  x29, x30, [sp, #-16]!
    mov  x15, #0
mu_baris:
    cmp  x13, x21
    b.ls error_blok
    sub  x13, x13, #1
mu_cari:
    cmp  x13, x21
    b.ls mu_kls
    ldrb w9, [x13, #-1]
    cmp  w9, #10
    b.eq mu_kls
    sub  x13, x13, #1
    b    mu_cari
mu_kls:
    bl   kw_kode
    cmp  w0, #5
    b.ne mu_a
    add  x15, x15, #1
    b    mu_baris
mu_a:
    cmp  w0, #4
    b.ne mu_baris
    cbz  x15, mu_ketemu
    sub  x15, x15, #1
    b    mu_baris
mu_ketemu:
    ldp  x29, x30, [sp], #16
    ret

error_blok:
    mov  x0, #2
    adr  x1, pesan_blok
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0

kw_kalau:       .asciz "KALAU"
kw_lain:        .asciz "LAIN"
kw_akhirkalau:  .asciz "AKHIRKALAU"
kw_selama:      .asciz "SELAMA"
kw_akhirselama: .asciz "AKHIRSELAMA"
pesan_blok:     .asciz "error: KALAU/SELAMA tanpa pasangan\n"

.bss
.balign 16
kl_mode: .skip 576

.text
.balign 4
// ---------- fungsi yang mengembalikan teks: FUNGSI nama$(P), HASILTEKS, nama$(x) ----------
kata_v16:
    cmp  w9, #72                // H
    b.ne kata_v15
    adr  x1, kw_hasilteks
    bl   cocok_kata
    cbnz x0, do_hasilteks
    b    kata_v15

// HASILTEKS item + item ...: gabung di [sp], salin ke ret_str, keluar dari fungsi
do_hasilteks:
    bl   lewat_kata
    sub  sp, sp, #128           // [sp] = hasil gabungan, [sp+64] = item
    strb wzr, [sp]
ht_item:
    add  x1, sp, #64
    bl   nilai_str
    mov  x2, #0
ht_akhir:
    ldrb w9, [sp, x2]
    cbz  w9, ht_a2
    add  x2, x2, #1
    b    ht_akhir
ht_a2:
    mov  x4, #0
ht_salin:
    cmp  x2, #63
    b.ge ht_tutup
    add  x5, sp, #64
    ldrb w9, [x5, x4]
    cbz  w9, ht_tutup
    strb w9, [sp, x2]
    add  x2, x2, #1
    add  x4, x4, #1
    b    ht_salin
ht_tutup:
    strb wzr, [sp, x2]
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #43                // '+'
    b.ne ht_selesai
    add  x24, x24, #1
    b    ht_item
ht_selesai:
    adrp x1, ret_str
    add  x1, x1, :lo12:ret_str
    mov  x2, #0
ht_k:
    ldrb w9, [sp, x2]
    strb w9, [x1, x2]
    add  x2, x2, #1
    cbnz w9, ht_k
    add  sp, sp, #128
    mov  x0, #0
    b    uf_kembali

// nilai teks: cek dulu apakah item adalah nama$(...) milik fungsi buatan
ns_fungsi_v16:
    mov  x0, x24
    bl   cari_fungsi
    cbz  x0, ns_fungsi_v15
    mov  x20, x0                // alamat deklarasi
    mov  x1, x24
usf_n:
    ldrb w9, [x1]
    bl   nm_norm
    cbz  w9, usf_n_ok
    add  x1, x1, #1
    b    usf_n
usf_n_ok:
    ldrb w9, [x1]
    cmp  w9, #36                // '$' setelah nama = panggilan teks
    b.ne ns_fungsi_v15
    add  x24, x1, #1
    adrp x1, ret_str
    add  x1, x1, :lo12:ret_str
    strb wzr, [x1]
    mov  x0, x20
    bl   usf_panggil
    adrp x1, ret_str
    add  x1, x1, :lo12:ret_str
    mov  x2, #0
usf_salin:
    ldrb w9, [x1, x2]
    strb w9, [x19, x2]
    cbz  w9, ns_keluar
    add  x2, x2, #1
    b    usf_salin
usf_panggil:                    // meniru bingkai faktor, lalu pakai pemanggil v12
    stp  x29, x30, [sp, #-16]!
    b    uf_panggil

kw_hasilteks: .asciz "HASILTEKS"

.bss
.balign 16
ret_str: .skip 80

.text
.balign 4
// ---------- parameter teks: FUNGSI nama(S$, N). Bingkai: +336 argumen teks, +592 teks lama ----------

// x0 = alamat deklarasi, x1 = indeks parameter -> x0 = 1 bila parameter itu teks (X$)
usf_tipe:
    stp  x29, x30, [sp, #-16]!
ut_nama:
    ldrb w9, [x0]
    bl   nm_norm
    cbz  w9, ut_n2
    add  x0, x0, #1
    b    ut_nama
ut_n2:
    ldrb w9, [x0]
    cmp  w9, #36
    b.ne ut_sp1
    add  x0, x0, #1
ut_sp1:
    ldrb w9, [x0]
    cmp  w9, #32
    b.ne ut_kurung
    add  x0, x0, #1
    b    ut_sp1
ut_kurung:
    cmp  w9, #40
    b.ne ut_tidak
    add  x0, x0, #1
ut_param:
    ldrb w9, [x0]
    cmp  w9, #32
    b.ne ut_huruf
    add  x0, x0, #1
    b    ut_param
ut_huruf:
    cmp  w9, #41
    b.eq ut_tidak
    cbz  w9, ut_tidak
    add  x0, x0, #1             // lewati huruf
    cbz  x1, ut_putus
ut_koma:                        // bukan parameter yang dicari: maju ke koma berikutnya
    ldrb w9, [x0]
    cbz  w9, ut_tidak
    cmp  w9, #10
    b.eq ut_tidak
    cmp  w9, #41
    b.eq ut_tidak
    add  x0, x0, #1
    cmp  w9, #44
    b.ne ut_koma
    sub  x1, x1, #1
    b    ut_param
ut_putus:
    ldrb w9, [x0]
    cmp  w9, #36
    b.ne ut_tidak
    mov  x0, #1
    b    ut_selesai
ut_tidak:
    mov  x0, #0
ut_selesai:
    ldp  x29, x30, [sp], #16
    ret

// hitung satu argumen: teks bila parameternya X$ (disimpan di bingkai), selain itu angka
usf_arg:
    stp  x29, x30, [sp, #-16]!
    mov  x0, x20
    mov  x1, x19
    bl   usf_tipe
    cbz  x0, ua_angka
    add  x1, sp, #16            // bingkai panggilan
    add  x1, x1, #336
    lsl  x2, x19, #6
    add  x1, x1, x2
    bl   nilai_str
    mov  x0, #0
    b    ua_selesai
ua_angka:
    bl   expr
ua_selesai:
    ldp  x29, x30, [sp], #16
    ret

// baca satu parameter di deklarasi: huruf, lalu '$' bila teks (ditandai bit 8)
usf_par:
    stp  x29, x30, [sp, #-16]!
    bl   indeks_var
    ldrb w9, [x24]
    cmp  w9, #36
    b.ne up_selesai
    add  x24, x24, #1
    orr  x0, x0, #256
up_selesai:
    ldp  x29, x30, [sp], #16
    ret

// pasang parameter teks: x3 = indeks parameter, x4 = indeks variabel | 256
usf_bind_teks:
    and  x4, x4, #255
    adrp x7, strs
    add  x7, x7, :lo12:strs
    mov  x8, #64
    madd x7, x4, x8, x7         // &strs[var]
    add  x10, sp, #592
    madd x10, x3, x8, x10       // tempat teks lama
    add  x11, sp, #336
    madd x11, x3, x8, x11       // teks argumen
    cmp  x3, x19
    b.lt ubt_ada
    strb wzr, [x11]             // argumen kurang: teks kosong
ubt_ada:
    mov  x12, #0
ubt_salin:
    ldrb w13, [x7, x12]
    strb w13, [x10, x12]
    ldrb w13, [x11, x12]
    strb w13, [x7, x12]
    add  x12, x12, #1
    cmp  x12, #64
    b.lt ubt_salin
    add  x3, x3, #1
    b    uf_bind

// kembalikan parameter teks: x5 = indeks parameter, x6 = indeks variabel | 256
usf_rest_teks:
    and  x6, x6, #255
    adrp x7, strs
    add  x7, x7, :lo12:strs
    mov  x8, #64
    madd x7, x6, x8, x7
    add  x10, sp, #592
    madd x10, x5, x8, x10
    mov  x12, #0
urt_salin:
    ldrb w13, [x10, x12]
    strb w13, [x7, x12]
    add  x12, x12, #1
    cmp  x12, #64
    b.lt urt_salin
    b    uf_rs

.text
.balign 4
// ---------- rekaman: nama.bidang, nama.bidang$, nama.bidang(indeks) ----------

// pra-pemindai murah: x0 = 1 bila ada '.' sebelum karakter di bawah '0' (spasi, kutip, kurung, $, ...)
rek_cepat:
    mov  x1, x24
rcp_l:
    ldrb w11, [x1], #1
    cmp  w11, #46
    b.eq rcp_ya
    cmp  w11, #48
    b.ge rcp_l
    mov  x0, #0
    ret
rcp_ya:
    mov  x0, #1
    ret

// x0 = 1 bila teks di x24 berbentuk "nama." (nama = huruf/angka/_)
rek_adalah:
    stp  x29, x30, [sp, #-16]!
    mov  x2, #0
ra_l:
    ldrb w9, [x24, x2]
    bl   nm_norm
    cbz  w9, ra_t
    add  x2, x2, #1
    b    ra_l
ra_t:
    mov  x0, #0
    cbz  x2, ra_x
    ldrb w9, [x24, x2]
    cmp  w9, #46
    b.ne ra_x
    mov  x0, #1
ra_x:
    ldp  x29, x30, [sp], #16
    ret

// x24 = awal "nama.bidang[$][(indeks)]", x1 = penyangga kunci (32 byte)
// -> kunci (huruf besar) di penyangga, x24 melewati referensi, x0 = 1 bila bidang teks
rek_kunci:
    stp  x29, x30, [sp, #-16]!
    stp  x19, x20, [sp, #-16]!
    mov  x19, x1
    mov  x20, #0
rk_nama:
    ldrb w9, [x24]
    bl   nm_norm
    cbz  w9, rk_titik
    cmp  x20, #22
    b.ge error
    strb w9, [x19, x20]
    add  x20, x20, #1
    add  x24, x24, #1
    b    rk_nama
rk_titik:
    ldrb w9, [x24]
    cmp  w9, #46
    b.ne error
    strb w9, [x19, x20]
    add  x20, x20, #1
    add  x24, x24, #1
rk_bidang:
    ldrb w9, [x24]
    bl   nm_norm
    cbz  w9, rk_dolar
    cmp  x20, #23
    b.ge error
    strb w9, [x19, x20]
    add  x20, x20, #1
    add  x24, x24, #1
    b    rk_bidang
rk_dolar:
    ldrb w9, [x24]
    cmp  w9, #36
    b.ne rk_idx
    strb w9, [x19, x20]
    add  x20, x20, #1
    add  x24, x24, #1
rk_idx:
    ldrb w9, [x24]
    cmp  w9, #40
    b.ne rk_selesai
    add  x24, x24, #1
    bl   expr
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #41
    b.ne error
    add  x24, x24, #1
    mov  x2, #65535
    cmp  x0, x2
    b.hi error                  // negatif atau terlalu besar
    mov  w9, #40
    strb w9, [x19, x20]
    add  x20, x20, #1
    sub  sp, sp, #16
    add  x4, sp, #16
    mov  x5, #10
rk_dg:
    udiv x6, x0, x5
    msub x7, x6, x5, x0
    add  x7, x7, #48
    sub  x4, x4, #1
    strb w7, [x4]
    mov  x0, x6
    cbnz x0, rk_dg
    add  x8, sp, #16
rk_cp:
    cmp  x4, x8
    b.ge rk_cp_ok
    ldrb w7, [x4], #1
    strb w7, [x19, x20]
    add  x20, x20, #1
    b    rk_cp
rk_cp_ok:
    add  sp, sp, #16
    mov  w9, #41
    strb w9, [x19, x20]
    add  x20, x20, #1
rk_selesai:
    strb wzr, [x19, x20]
    mov  x0, #0
    mov  x2, #0
rk_f:
    ldrb w9, [x19, x2]
    cbz  w9, rk_f_ok
    cmp  w9, #36
    b.ne rk_f_lanjut
    mov  x0, #1
rk_f_lanjut:
    add  x2, x2, #1
    b    rk_f
rk_f_ok:
    ldp  x19, x20, [sp], #16
    ldp  x29, x30, [sp], #16
    ret

// x1 = kunci, x2 = 1 buat bila belum ada -> x0 = nomor entri, atau -1 bila tak ada
rek_cari:
    adrp x3, rek_keys
    add  x3, x3, :lo12:rek_keys
    mov  x4, #0
rc_loop:
    cmp  x4, #512
    b.ge rc_penuh
    add  x5, x3, x4, lsl #5
    ldrb w9, [x5]
    cbz  w9, rc_kosong
    mov  x6, #0
rc_cmp:
    ldrb w9, [x5, x6]
    ldrb w10, [x1, x6]
    cmp  w9, w10
    b.ne rc_lanjut
    cbz  w9, rc_ketemu
    add  x6, x6, #1
    b    rc_cmp
rc_lanjut:
    add  x4, x4, #1
    b    rc_loop
rc_ketemu:
    mov  x0, x4
    ret
rc_kosong:
    cbz  x2, rc_tak
    mov  x6, #0
rc_salin:
    ldrb w9, [x1, x6]
    strb w9, [x5, x6]
    cbz  w9, rc_salin_ok
    add  x6, x6, #1
    b    rc_salin
rc_salin_ok:
    mov  x0, x4
    ret
rc_penuh:
    cbz  x2, rc_tak
    b    error_rekpenuh
rc_tak:
    mov  x0, #-1
    ret

// pernyataan "nama.bidang = ..." dikenali sebelum rantai kata kunci
kata_v18:
    bl   rek_cepat
    cbz  x0, kata_v16
    mov  w12, w9
    mov  w13, w10
    bl   rek_adalah
    mov  w9, w12
    mov  w10, w13
    cbnz x0, do_rektugas
    b    kata_v16

do_rektugas:
    sub  sp, sp, #48            // [sp] kunci, [sp+32] nilai, [sp+40] jenis
    mov  x1, sp
    bl   rek_kunci
rtg_tail:
    str  x0, [sp, #40]
    bl   skip
    ldrb w9, [x24]
    cmp  w9, #61
    b.ne error
    add  x24, x24, #1
    ldr  x0, [sp, #40]
    cbnz x0, rtg_teks
    bl   expr
    str  x0, [sp, #32]
    mov  x1, sp
    mov  x2, #1
    bl   rek_cari
    adrp x1, rek_num
    add  x1, x1, :lo12:rek_num
    ldr  x2, [sp, #32]
    str  x2, [x1, x0, lsl #3]
    add  sp, sp, #48
    b    akhir
rtg_teks:
    mov  x1, sp
    mov  x2, #1
    bl   rek_cari
    adrp x19, rek_str
    add  x19, x19, :lo12:rek_str
    mov  x2, #64
    madd x19, x0, x2, x19
    adrp x20, tmps
    add  x20, x20, :lo12:tmps
    mov  x13, #0
    add  sp, sp, #48
    b    tg_item                // lanjutkan seperti penugasan A$ = ...

// baca angka: nama.bidang di ekspresi (0 bila belum pernah diisi)
fk_fungsi_v18:
    bl   rek_cepat
    cbz  x0, fk_fungsi_v17
    bl   rek_adalah
    cbz  x0, fk_fungsi_v17
    sub  sp, sp, #32
    mov  x1, sp
    bl   rek_kunci
    cbnz x0, error              // bidang teks dipakai sebagai angka
    mov  x1, sp
    mov  x2, #0
    bl   rek_cari
    mov  x1, #0
    cmp  x0, #0
    b.lt rf_nol
    adrp x1, rek_num
    add  x1, x1, :lo12:rek_num
    ldr  x1, [x1, x0, lsl #3]
rf_nol:
    mov  x0, x1
    add  sp, sp, #32
    b    fk_keluar

// baca teks: nama.bidang$ (kosong bila belum pernah diisi)
ns_fungsi_v18:
    bl   rek_cepat
    cbz  x0, ns_fungsi_v16
    bl   rek_adalah
    cbz  x0, ns_fungsi_v16
    sub  sp, sp, #32
    mov  x1, sp
    bl   rek_kunci
    cbz  x0, error              // harus bidang teks
    mov  x1, sp
    mov  x2, #0
    bl   rek_cari
    cmp  x0, #0
    b.lt rs_kosong
    adrp x1, rek_str
    add  x1, x1, :lo12:rek_str
    mov  x2, #64
    madd x1, x0, x2, x1
    mov  x2, #0
rs_salin:
    ldrb w9, [x1, x2]
    strb w9, [x19, x2]
    cbz  w9, rs_selesai
    add  x2, x2, #1
    b    rs_salin
rs_kosong:
    strb wzr, [x19]
rs_selesai:
    add  sp, sp, #32
    b    ns_keluar

// apakah item berbentuk nama.bidang$ ? selain itu pakai aturan lama
adalah_str_v18:
    stp  x29, x30, [sp, #-16]!
    bl   rek_cepat
    cbz  x0, as3_lama
    mov  x2, #0
as3_a:
    ldrb w9, [x24, x2]
    bl   nm_norm
    cbz  w9, as3_t
    add  x2, x2, #1
    b    as3_a
as3_t:
    cbz  x2, as3_lama
    ldrb w9, [x24, x2]
    cmp  w9, #46
    b.ne as3_lama
    add  x2, x2, #1
as3_b:
    ldrb w9, [x24, x2]
    bl   nm_norm
    cbz  w9, as3_d
    add  x2, x2, #1
    b    as3_b
as3_d:
    ldrb w9, [x24, x2]
    mov  x0, #0
    cmp  w9, #36
    b.ne as3_x
    mov  x0, #1
as3_x:
    ldp  x29, x30, [sp], #16
    ret
as3_lama:
    ldp  x29, x30, [sp], #16
    b    adalah_str_v17

error_rekpenuh:
    mov  x0, #2
    adr  x1, pesan_rekpenuh
    bl   cetak_z
    bl   lapor_baris
    mov  x0, #1
    mov  x8, #93
    svc  #0
pesan_rekpenuh: .asciz "error: tabel rekaman penuh (maksimal 512)\n"

.bss
.balign 16
rek_keys: .skip 16384
rek_num:  .skip 4096
rek_str:  .skip 32768

.text
.balign 4
// ---------- nama variabel panjang: jumlah = 5, nama$ = "Ani", BACA nama$ ----------
// disimpan di tabel rekaman dengan kunci "JUMLAH" / "NAMA$" (tanpa titik)

// x1 = akhir nama yang mulai di x24, w9 = karakter di situ (pemindai murah, tanpa bl)
var_akhir:
    mov  x1, x24
va_l:
    ldrb w9, [x1]
    cmp  w9, #48
    b.lt va_x
    cmp  w9, #58
    b.lt va_ok
    cmp  w9, #65
    b.lt va_x
va_ok:
    add  x1, x1, #1
    b    va_l
va_x:
    ret

// x0 = 1 bila pernyataan di x24 berbentuk "nama[$] = ...", 2 bila nama diikuti '.', selain itu 0
var_cepat:
    mov  x1, x24
vc_l:
    ldrb w11, [x1]
    cmp  w11, #48
    b.lt vc_t
    cmp  w11, #58
    b.lt vc_ok
    cmp  w11, #65
    b.lt vc_t
vc_ok:
    add  x1, x1, #1
    b    vc_l
vc_t:
    cmp  w11, #46
    b.ne vc_d
    mov  x0, #2
    ret
vc_d:
    cmp  w11, #36
    b.ne vc_s
    add  x1, x1, #1
    ldrb w11, [x1]
vc_s:
    cmp  w11, #32
    b.ne vc_c
    add  x1, x1, #1
    ldrb w11, [x1]
    b    vc_s
vc_c:
    mov  x0, #0
    cmp  w11, #61
    b.ne vc_x
    ldrb w11, [x1, #1]
    cmp  w11, #61               // "==" bukan penugasan
    b.eq vc_x
    mov  x0, #1
vc_x:
    ret

// x24 = awal nama[$], x1 = penyangga 32 byte -> kunci huruf besar, x24 maju, x0 = 1 bila teks
var_kunci:
    stp  x29, x30, [sp, #-16]!
    mov  x2, #0
vk_l:
    ldrb w9, [x24]
    bl   nm_norm
    cbz  w9, vk_t
    cmp  x2, #24
    b.ge error
    strb w9, [x1, x2]
    add  x2, x2, #1
    add  x24, x24, #1
    b    vk_l
vk_t:
    mov  x0, #0
    ldrb w9, [x24]
    cmp  w9, #36
    b.ne vk_x
    strb w9, [x1, x2]
    add  x2, x2, #1
    add  x24, x24, #1
    mov  x0, #1
vk_x:
    strb wzr, [x1, x2]
    ldp  x29, x30, [sp], #16
    ret

// pernyataan "nama = ..." atau "nama$ = ..." (dua huruf atau lebih)
kata_baru:
    bl   var_cepat
    cmp  x0, #1
    b.eq do_vartugas
    cmp  x0, #2
    b.eq kata_v18               // "nama." = rekaman
    b    kata_v16

do_vartugas:
    sub  sp, sp, #48
    mov  x1, sp
    bl   var_kunci
    b    rtg_tail               // lanjutkan seperti penugasan rekaman

// baca angka: nama tanpa "(" dan tanpa "." = variabel panjang (0 bila belum diisi)
fk_fungsi:
    bl   var_akhir
    cmp  w9, #46
    b.eq fk_fungsi_v18          // rekaman
    cmp  w9, #36
    b.eq fk_fungsi_v17
fn_sp:
    cmp  w9, #32
    b.ne fn_c
    add  x1, x1, #1
    ldrb w9, [x1]
    b    fn_sp
fn_c:
    cmp  w9, #40
    b.eq fk_fungsi_v17          // pemanggilan fungsi
    sub  sp, sp, #32
    mov  x1, sp
    bl   var_kunci
    mov  x1, sp
    mov  x2, #0
    bl   rek_cari
    mov  x1, #0
    cmp  x0, #0
    b.lt vr_nol
    adrp x1, rek_num
    add  x1, x1, :lo12:rek_num
    ldr  x1, [x1, x0, lsl #3]
vr_nol:
    mov  x0, x1
    add  sp, sp, #32
    b    fk_keluar

// baca teks: nama$ tanpa "(" = variabel teks panjang (kosong bila belum diisi)
ns_fungsi:
    bl   var_akhir
    cmp  w9, #36
    b.ne ns_fungsi_v18
    add  x1, x1, #1
    ldrb w9, [x1]
ns_sp:
    cmp  w9, #32
    b.ne ns_c
    add  x1, x1, #1
    ldrb w9, [x1]
    b    ns_sp
ns_c:
    cmp  w9, #40
    b.eq ns_fungsi_v16          // fungsi teks bawaan atau buatan
    sub  sp, sp, #32
    mov  x1, sp
    bl   var_kunci
    mov  x1, sp
    mov  x2, #0
    bl   rek_cari
    cmp  x0, #0
    b.lt vs_kosong
    adrp x1, rek_str
    add  x1, x1, :lo12:rek_str
    mov  x2, #64
    madd x1, x0, x2, x1
    mov  x2, #0
vs_salin:
    ldrb w9, [x1, x2]
    strb w9, [x19, x2]
    cbz  w9, vs_selesai
    add  x2, x2, #1
    b    vs_salin
vs_kosong:
    strb wzr, [x19]
vs_selesai:
    add  sp, sp, #32
    b    ns_keluar

// item berbentuk nama$ (nama apa pun) adalah teks
adalah_str:
    stp  x29, x30, [sp, #-16]!
    bl   var_akhir
    cmp  w9, #36
    b.ne as4_lama
    mov  x0, #1
    ldp  x29, x30, [sp], #16
    ret
as4_lama:
    ldp  x29, x30, [sp], #16
    cmp  w9, #46
    b.eq adalah_str_v18         // rekaman
    b    adalah_str_v17

// BACA nama / BACA nama$ untuk nama panjang (huruf kedua adalah huruf)
do_baca:
    mov  x16, x24
    bl   lewat_kata
    bl   skip
    ldrb w9, [x24, #1]
    cmp  w9, #65
    b.lt bc_lama
    cmp  w9, #90
    b.le bc_panjang
    cmp  w9, #97
    b.lt bc_lama
    cmp  w9, #122
    b.gt bc_lama
bc_panjang:
    sub  sp, sp, #32
    mov  x1, sp
    bl   var_kunci
    mov  x12, x0
    mov  x1, sp
    mov  x2, #1
    bl   rek_cari
    add  sp, sp, #32
    cbnz x12, bc_teks
    adrp x1, rek_num
    add  x1, x1, :lo12:rek_num
    add  x19, x1, x0, lsl #3
    b    db_masuk
bc_teks:
    adrp x19, rek_str
    add  x19, x19, :lo12:rek_str
    mov  x2, #64
    madd x19, x0, x2, x19
    b    bs_masuk
bc_lama:
    mov  x24, x16
    b    do_baca_v18
