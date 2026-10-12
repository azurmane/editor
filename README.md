# editor

## OWH / LuaVM — Loot Multiplier Research

Repositori ini berisi hasil riset untuk pembuatan custom hook `.pluto` pada OWH
(Warframe Helper LuaVM).

### Yang ada di sini

| Berkas | Isi |
|---|---|
| `hooks/owh_loot_research.pluto` | **Deliverable utama.** Harness diagnostik read-only + simulator loot multiplier ×2–×5. |
| `docs/ANALYSIS.md` | **Mulai dari sini.** Analisis, status terbukti/belum terbukti, instalasi, pengujian, pernyataan eksplisit. |
| `tests/compat_driver.lua` | Penguji portabilitas & ketahanan (27 skenario). |
| `tests/reference/*.txt` | Output terverifikasi dari Pluto 0.13.1 dan Lua 5.4.7 (exit 0, 18/18 self-test, 9/9 error tertangkap). |

### Status singkat

**Loot multiplier ×2–×5 yang benar-benar bekerja TIDAK dapat dibuat dengan API
yang terbukti tersedia.** VM Lua tidak bisa memasang detour x86-64; ia hanya
bisa memanggil apa yang di-*export* host, dan belum ada bukti bahwa OWH
mengekspos API loot. Yang dikirimkan karena itu adalah **alternatif diagnostik
read-only + simulator** sesuai permintaan.

Baca `docs/ANALYSIS.md` untuk rinciannya.

### Catatan

Tiga referensi yang disebut dalam permintaan (`_docs.pluto`, source DX11Hook,
screenshot hasil uji) **tidak ikut terlampir**, jadi tidak ada satu pun alamat,
signature, offset, atau nama fungsi yang dikarang di sini.
