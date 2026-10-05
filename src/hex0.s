.global _start
_start:
    sub  sp, sp, #16
    mov  x20, #-1
baca:
    mov  x0, #0
    mov  x1, sp
    mov  x2, #1
    mov  x8, #63
    svc  #0
    cbz  x0, selesai
    ldrb w3, [sp]
    cmp  w3, #35
    b.eq komentar
    cmp  w3, #48
    b.lt baca
    cmp  w3, #57
    b.le angka
    cmp  w3, #65
    b.lt baca
    cmp  w3, #70
    b.le besar
    cmp  w3, #97
    b.lt baca
    cmp  w3, #102
    b.gt baca
    sub  w3, w3, #87
    b    nibble
besar:
    sub  w3, w3, #55
    b    nibble
angka:
    sub  w3, w3, #48
nibble:
    cmp  x20, #0
    b.lt simpan
    lsl  w4, w20, #4
    orr  w4, w4, w3
    strb w4, [sp]
    mov  x0, #1
    mov  x1, sp
    mov  x2, #1
    mov  x8, #64
    svc  #0
    mov  x20, #-1
    b    baca
simpan:
    mov  x20, x3
    b    baca
komentar:
    mov  x0, #0
    mov  x1, sp
    mov  x2, #1
    mov  x8, #63
    svc  #0
    cbz  x0, selesai
    ldrb w3, [sp]
    cmp  w3, #10
    b.ne komentar
    b    baca
selesai:
    mov  x0, #0
    mov  x8, #93
    svc  #0
