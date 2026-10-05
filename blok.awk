# blok.awk - terjemahkan blok BK ke BK dasar (bk v14, dipakai lewat bkb)
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function isw(c) { return (c != "" && c ~ /[A-Za-z0-9_]/) }
function die(msg) {
  printf "error: baris %d: %s\n", NR, msg > "/dev/stderr"
  gagal = 1
  exit 1
}
function cetak(t) { print pre t; pre = "" }
function push(t, id) {
  sp++; tipe[sp] = t; fid[sp] = id; fbaris[sp] = NR
  kn[sp] = 0; pend[sp] = 0; ada_e[sp] = 0; ada_l[sp] = 0
}
# posisi kata MAKA di luar tanda kutip, 0 kalau tidak ada
function cari_maka(s,   i, n, c, q, u) {
  n = length(s); q = 0; u = toupper(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (c == "\"") { q = !q; continue }
    if (q) continue
    if (substr(u, i, 4) == "MAKA" && (i == 1 || !isw(substr(s, i - 1, 1))) && !isw(substr(s, i + 4, 1)))
      return i
  }
  return 0
}
# pisah "kiri op kanan" -> C_L C_OP C_R (operator pertama di luar kutip dan kurung)
function pisah(s,   i, n, c, c2, d, q, o) {
  n = length(s); d = 0; q = 0
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (c == "\"") { q = !q; continue }
    if (q) continue
    if (c == "(") { d++; continue }
    if (c == ")") { d--; continue }
    if (d != 0) continue
    if (c == "<" || c == ">" || c == "=" || c == "!") {
      c2 = substr(s, i + 1, 1)
      o = c
      if ((c == "<" && (c2 == ">" || c2 == "=")) || (c == ">" && c2 == "=") || (c == "!" && c2 == "=")) o = c c2
      else if (c == "!") return 0
      C_L = trim(substr(s, 1, i - 1)); C_OP = o; C_R = trim(substr(s, i + length(o)))
      return (C_L != "" && C_R != "")
    }
  }
  return 0
}
function balik(o) {
  if (o == "=") return "<>"
  if (o == "<>" || o == "!=") return "="
  if (o == "<") return ">="
  if (o == "<=") return ">"
  if (o == ">") return "<="
  return "<"
}
function jikanot(lab) { cetak("JIKA " C_L " " balik(C_OP) " " C_R " LOMPAT " lab) }

{
  sub(/\r$/, "")
  line = $0
  pre = ""
  rest = trim(line)
  if (match(rest, /^[0-9]+/)) {
    pre = substr(rest, 1, RLENGTH) " "
    rest = trim(substr(rest, RLENGTH + 1))
  }
  kw = ""; arg = ""
  if (match(rest, /^[A-Za-z]+/)) {
    k = substr(rest, 1, RLENGTH)
    nx = substr(rest, RLENGTH + 1, 1)
    if (nx !~ /[0-9_$]/) { kw = toupper(k); arg = trim(substr(rest, RLENGTH + 1)) }
  }

  if (kw == "LABEL") { nlabel++; print line; next }

  if (kw == "UNTUK") { push("F", 0); print line; next }
  if (kw == "LANJUT") {
    if (sp > 0 && tipe[sp] != "F") die("LANJUT padahal blok JIKA/SELAMA di baris " fbaris[sp] " belum ditutup")
    if (sp > 0) sp--
    print line; next
  }

  if (kw == "JIKA") {
    m = cari_maka(arg)
    if (m == 0) { print line; next }          # JIKA ... LOMPAT/GOSUB biasa
    kond = trim(substr(arg, 1, m - 1)); sisa = trim(substr(arg, m + 4))
    if (!pisah(kond)) die("syarat JIKA tidak lengkap: " kond)
    id = ++uid
    if (sisa != "") {                         # satu baris
      lab = "zzi" id "x0"
      jikanot(lab); cetak(sisa); cetak("LABEL " lab); nlabel++
    } else {
      push("I", id); pend[sp] = 1
      jikanot("zzi" id "x0")
    }
    next
  }

  if (kw == "LAINNYA") {
    if (sp == 0 || tipe[sp] != "I") die("LAINNYA tanpa JIKA ... MAKA")
    if (ada_l[sp]) die("LAINNYA kedua dalam satu blok JIKA")
    id = fid[sp]
    cetak("LOMPAT zzi" id "e"); ada_e[sp] = 1
    cetak("LABEL zzi" id "x" kn[sp]); nlabel++; kn[sp]++
    if (toupper(substr(arg, 1, 4)) == "JIKA" && !isw(substr(arg, 5, 1))) {
      arg2 = trim(substr(arg, 5))
      m = cari_maka(arg2)
      if (m == 0) die("LAINNYA JIKA perlu MAKA")
      if (trim(substr(arg2, m + 4)) != "") die("LAINNYA JIKA ... MAKA harus berakhir di MAKA")
      if (!pisah(trim(substr(arg2, 1, m - 1)))) die("syarat LAINNYA JIKA tidak lengkap")
      jikanot("zzi" id "x" kn[sp])
    } else {
      if (arg != "") die("setelah LAINNYA hanya boleh JIKA ... MAKA")
      pend[sp] = 0; ada_l[sp] = 1
    }
    next
  }

  if (kw == "AKHIRJIKA") {
    if (sp == 0 || tipe[sp] != "I") die("AKHIRJIKA tanpa JIKA ... MAKA")
    id = fid[sp]
    if (pend[sp]) { cetak("LABEL zzi" id "x" kn[sp]); nlabel++ }
    if (ada_e[sp]) { cetak("LABEL zzi" id "e"); nlabel++ }
    sp--
    next
  }

  if (kw == "SELAMA") {
    id = ++uid
    if (!pisah(arg)) die("syarat SELAMA tidak lengkap: " arg)
    push("W", id)
    cetak("LABEL zzw" id); nlabel++
    jikanot("zzx" id)
    next
  }
  if (kw == "AKHIRSELAMA") {
    if (sp == 0 || tipe[sp] != "W") die("AKHIRSELAMA tanpa SELAMA")
    id = fid[sp]
    cetak("LOMPAT zzw" id); cetak("LABEL zzx" id); nlabel++
    sp--
    next
  }
  if (kw == "KELUAR" || kw == "TERUSKAN") {
    for (j = sp; j >= 1; j--) {
      if (tipe[j] == "F") die(kw " di dalam UNTUK tidak aman, pakai SELAMA")
      if (tipe[j] == "W") break
    }
    if (j < 1) die(kw " di luar SELAMA")
    cetak("LOMPAT " (kw == "KELUAR" ? "zzx" : "zzw") fid[j])
    next
  }

  print line
}

END {
  if (gagal) exit 1
  for (j = sp; j >= 1; j--)
    if (tipe[j] != "F") {
      printf "error: blok %s dibuka di baris %d tidak ditutup\n", (tipe[j] == "I" ? "JIKA" : "SELAMA"), fbaris[j] > "/dev/stderr"
      exit 1
    }
  if (nlabel > 64) {
    printf "error: label (termasuk buatan blok) %d, batas bk 64\n", nlabel > "/dev/stderr"
    exit 1
  }
}
