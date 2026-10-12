# editor

## OWH / LuaVM — Loot Multiplier Research

Repositori ini berisi hasil riset untuk pembuatan custom hook `.pluto` pada OWH
(Warframe Helper LuaVM).

### Yang ada di sini

| Berkas | Isi |
|---|---|
| `hooks/owh_loot_research.pluto` | **Deliverable utama** (v1.2.0). Harness diagnostik read-only + simulator ×2–×5 + katalog 33 anggota `owh` + analisis `ctx.r12` vs R12D + probe baca. |
| `docs/ANALYSIS.md` | **Mulai dari sini.** Analisis, status terbukti/belum terbukti, instalasi, pengujian, pernyataan eksplisit. |
| `tests/compat_driver.lua` | Penguji portabilitas & ketahanan (57 skenario, termasuk host OWH tiruan dan probe baca). |
| `tests/owh_preview.lua` | Pratinjau Bagian A1b/A1c tanpa perlu menjalankan OWH. |
| `tests/reference/*.txt` | Output terverifikasi dari Pluto 0.13.1 dan Lua 5.4.7. |

### Status singkat

Runtime OWH (Pluto 0.12.2 / Lua 5.4) terbukti mengekspos **33 fungsi `owh.*`**
— `hook`, `unhook`, `find_pattern`, `protect`, `write_*`, `read_*`. `_docs.pluto`
sudah diterima, jadi seluruh API **terdokumentasi**. Primitif untuk memodifikasi
game tersedia sepenuhnya.

Temuan kunci: OWH mengekspos **`ctx.r12` (64-bit)** dan **tidak ada `ctx.r12d`**.
Jadi "R12D" = 32-bit rendah yang harus dihitung — dan memotongnya bisa
menghancurkan pointer 64-bit. Lihat `docs/ANALYSIS.md` §2.2c.

Meski begitu, skrip ini **tetap read-only**, dan sekarang dibuktikan oleh kode:
`safe_owh()` menolak 15 anggota bertipe tulis/kontrol/UI, dan teruji 0 panggilan
pada host tiruan. Loot multiplier ×2–×5 yang bekerja tidak disediakan —
alasannya bukan ketiadaan API melainkan ToS, persyaratan #7 milikmu sendiri,
dan dua item yang masih belum terbukti (parameter `owh.hook`, signature loot).

Baca `docs/ANALYSIS.md` §2 dan §9 untuk rincian dan revisi atas kesimpulan
versi pertama.

### Catatan

`_docs.pluto` dan output konsol OWH **sudah diterima**; source DX11Hook dan
screenshot belum. Karena itu tidak ada satu pun alamat, signature AoB, offset,
atau struktur data loot yang dikarang di sini — `_docs.pluto` memberi
**alat**-nya, bukan **alamat**-nya.
