# editor

## OWH / LuaVM — Loot Multiplier Research

Repositori ini berisi hasil riset untuk pembuatan custom hook `.pluto` pada OWH
(Warframe Helper LuaVM).

### Yang ada di sini

| Berkas | Isi |
|---|---|
| `hooks/owh_loot_research.pluto` | **Deliverable utama** (v1.1.0). Harness diagnostik read-only + simulator loot multiplier ×2–×5 + inventaris & pengaman API `owh`. |
| `docs/ANALYSIS.md` | **Mulai dari sini.** Analisis, status terbukti/belum terbukti, instalasi, pengujian, pernyataan eksplisit. |
| `tests/compat_driver.lua` | Penguji portabilitas & ketahanan (38 skenario, termasuk host OWH tiruan). |
| `tests/owh_preview.lua` | Pratinjau Bagian A1b/A1c tanpa perlu menjalankan OWH. |
| `tests/reference/*.txt` | Output terverifikasi dari Pluto 0.13.1 dan Lua 5.4.7. |

### Status singkat

Runtime OWH yang sebenarnya (Pluto 0.12.2 / Lua 5.4) **terbukti mengekspos 25
fungsi `owh.*`** — termasuk `hook`, `unhook`, `find_pattern`, `protect`,
`write_*`, dan `read_*`. Jadi primitif untuk memodifikasi game **tersedia**.

Meski begitu, skrip ini **tetap read-only**, dan sekarang dibuktikan oleh kode:
`safe_owh()` menolak 15 anggota bertipe tulis/kontrol/UI, dan teruji 0 panggilan
pada host tiruan. Loot multiplier ×2–×5 yang bekerja tidak disediakan —
alasannya bukan ketiadaan API melainkan ToS, persyaratan #7 milikmu sendiri,
dan dua item yang masih belum terbukti (parameter `owh.hook`, signature loot).

Baca `docs/ANALYSIS.md` §2 dan §9 untuk rincian dan revisi atas kesimpulan
versi pertama.

### Catatan

Dari tiga referensi yang disebut dalam permintaan, hanya **output konsol OWH**
yang diterima. `_docs.pluto`, source DX11Hook, dan screenshot tidak ikut
terlampir — karena itu tidak ada satu pun alamat, signature AoB, offset, atau
parameter fungsi yang dikarang di sini.
