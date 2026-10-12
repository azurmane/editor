# OWH / LuaVM — Loot Multiplier Research

**Tanggal:** 2026-10-12 · **Branch:** `arena/77b9773e-editor`
**Artefak:** `hooks/owh_loot_research.pluto` (v1.0.0) · `tests/compat_driver.lua` · `tests/reference/`

---

## 0. STATUS LAMPIRAN — BACA INI DULU

Ketiga referensi yang kamu sebutkan **tidak ikut terlampir** pada pesanmu. Yang
ada di repositori saat saya mulai hanyalah `README.md` berisi `# editor` (9 byte).

| Referensi | Status | Akibatnya |
|---|---|---|
| 1. `_docs.pluto` dari OWH | **DITERIMA** (2026-10-12) | **P2 selesai** — seluruh API terdokumentasi. Lihat §2.2b |
| 2. Source DX11Hook (`change_loot`, `loot_hook`) | **Tidak diterima** | Saya tidak bisa membaca baris kodenya |
| 3. Screenshot hasil uji `.pluto` | **Tidak diterima** | — |
| **Output konsol OWH-mu** | **DITERIMA** (dua kali) | Menghasilkan katalog **33** anggota — lihat §2.0 & §2.2 |

Konsekuensinya: **saya tidak akan menebak isi ketiga file tersebut.** Persyaratanmu
nomor 3 melarangnya, dan itu juga satu-satunya cara yang jujur. Semua klaim di
bawah ini ditandai sumbernya: **TERBUKTI** (punya bukti yang bisa diulang),
**TERBUKTI-ARSITEKTUR** (fakta CPU yang universal), atau **BELUM TERBUKTI**
(butuh file yang belum kamu kirim).

Untuk menutupi kekosongan itu, skrip yang saya kirim menyertakan **pemindai API
read-only**: ia mendaftar semua global yang *benar-benar* ada di runtime OWH-mu
dan mencetaknya. Itu adalah bukti, bukan tebakan. Kirim hasil cetakannya ke saya
dan saya akan menyesuaikan skripnya ke nama API yang nyata.

> Saya juga **tidak mengunduh** source DX11Hook dari forum/GitHub untuk
> dianalisis. Menulis ulang hook loot multiplier yang bekerja untuk game
> multiplayer live bukan sesuatu yang akan saya lakukan; sisanya di dokumen ini
> menjelaskan alasannya secara teknis.

---

## 1. RINGKASAN ANALISIS SOURCE

### 1.1 Apa yang bisa saya analisis tanpa file-mu

Bukti publik yang tersedia tentang *cara kerja* fitur "loot multiplier" pada
Warframe:

1. **Tekniknya sudah terdokumentasi publik.** Sebuah tabel Cheat Engine yang
   diposting di forum menghooking fungsi `SetResourceEncrypted` dan menyisipkan
   `imul r8d, [multiplier]` di prolog fungsi, dengan "filter min amount"
   opsional [9](https://www.unknowncheats.me/forum/other-fps-games/662459-warframe-loot-modifier.html).
   Ini memperlihatkan bentuk umum `loot_hook`: **kali bilangan bulat 32-bit pada
   register yang memuat jumlah, sesaat sebelum nilai itu dikomit.**
2. **Penulis fitur ini sendiri memperingatkan batasnya.** Thread rilisnya
   menyebut fitur "Loot/Coin changer" dengan mode "Danger", dan berbunyi
   *"Please do not set the loot/coin multiplier higher than 4"*
   [1](https://www.unknowncheats.me/forum/other-fps-games/600451-warframe-chams-loot-coin-changer.html).
   Jadi ×2–×5 yang kamu targetkan **melewati** angka yang penulisnya sarankan.
3. **Ada cap sisi game.** Di thread yang sama ada yang menyatakan *"you can't get
   more than 10k of an item per match"*
   [9](https://www.unknowncheats.me/forum/other-fps-games/662459-warframe-loot-modifier.html).
   Artinya nilai hasil perkalian **tidak serta-merta** menjadi jumlah akhir —
   ini contoh konkret mengapa "register sudah dikali" ≠ "loot sudah berubah".
4. **Warframe menanam VM Lua/Luau sendiri**, dengan opcode yang diacak dan
   `__namecall` menggantikan `__method`
   [1](https://www.unknowncheats.me/forum/other-fps-games/619579-warframe-luau-injection.html),
   [3](https://www.unknowncheats.me/forum/other-fps-games/260316-warframe-lua.html),
   [4](https://www.unknowncheats.me/forum/other-fps-games/564842-warframe-lua-injection-ce-scripts-progress.html).

### 1.2 Apa yang TIDAK bisa saya analisis

| Hal | Mengapa | Status |
|---|---|---|
| Isi `change_loot()` | File tidak dilampirkan | **BELUM TERBUKTI** |
| Isi `loot_hook()` | File tidak dilampirkan | **BELUM TERBUKTI** |
| Apakah `loot_hook` memakai `imul` atau `add`/`lea`/`shl` | Tidak bisa dibaca | **BELUM TERBUKTI** |
| Register mana yang dipakai (R12D vs R8D vs yang lain) | Tidak bisa dibaca | **BELUM TERBUKTI** |
| Signature AoB / offset / alamat | Sengaja tidak saya karang | **TIDAK DIKETAHUI** |

Kalau nanti kamu kirim file-nya, yang akan saya cari di `change_loot`/`loot_hook`
adalah, berurutan: (a) instruksi yang menulis register target **sebelum** titik
hook, (b) apakah operand lebarnya 32/16 bit, (c) apakah hook menyimpan dan
memulihkan flag (pushfq/popfq) — kalau tidak, cabang `jo`/`jc` setelahnya bisa
berubah perilaku, (d) apakah detour memakai stub asm telanjang atau fungsi C
( fungsi C akan mengotori register volatile).

### 1.3 Kesimpulan analisis source

> `change_loot` pada proyek DX11Hook pada dasarnya adalah **detour native ×86-64
> di dalam proses game**: trampoline MinHook/Detours + potongan asm yang
> mengalikan register 32-bit dengan konstanta. Ini adalah operasi **level
> mesin**, bukan operasi level bahasa skrip.

Poin ini yang menentukan jawaban untuk pertanyaan utamamu (bagian 2).

---

## 2. APAKAH LOGIKA ITU PUNYA PADANAN YANG VALID DI API OWH?

> ### ⚠️ REVISI — baca ini dulu
>
> Versi pertama dokumen ini menyimpulkan: **"tidak mungkin karena OWH tidak
> mengekspos primitifnya."** Kesimpulan itu saya tulis **sebelum** melihat
> output runtime-mu. Setelah Bagian A1 terbukti, kesimpulan itu **salah dan
> saya tarik kembali**: OWH **memang mengekspos** primitif baca memori, **tulis
> memori**, pemasangan **hook**, dan **pencarian pola**.
>
> Alasan "tidak bisa" karena itu **gugur**. Yang tersisa bukan masalah
> kemampuan — melainkan tiga hal: dua item yang masih belum terbukti (P2, P3),
> dan satu batasan yang saya pegang secara sadar (lihat §2.4).

### 2.0 Bukti baru: isi namespace `owh` (dari konsolmu, 2026-10-12)

Runtime-mu: **Pluto 0.12.2 / Lua 5.4**. Namespace-nya **`owh`** (huruf kecil;
`OWH` kapital tidak ada). Sedikitnya **25 anggota**:

| Kelas | Anggota | Jumlah |
|---|---|---|
| **read** — hanya membaca memori | `read_bytes`, `read_double`, `read_int16`, `read_int64`, `read_string`, `read_uint64`, `read_uint8` | 7 |
| **write** — **mengubah memori proses** | `memcpy`, `write_bytes`, `write_float`, `write_int16`, `write_int32`, `write_int8`, `write_string`, `write_uint16`, `write_uint64`, `write_uint8` | 10 |
| **control** — mengubah aliran/proteksi/hook | `hook`, `unhook`, `protect`, `on_unload` | 4 |
| **meta** — informasi | `base`, `player_base`, `find_pattern` | 3 |
| **ui** | `msgbox` | 1 |

Catatan: `read_int32` dan `read_uint16`/`read_uint32` **tidak muncul** dalam
daftar, padahal `write_int32` ada. Itu bukan kelupaan saya — memang begitu
yang tercetak di konsolmu. Verifikasi ulang ada di Bagian **A1b**.

### 2.1 Mengapa kesimpulan lama saya salah

Saya menulis §2.1 versi lama ("VM Lua tidak punya primitif untuk memasang
detour") berdasarkan **ketiadaan bukti**, bukan berdasarkan bukti ketiadaan.
Itu cacat metodologis yang harus saya akui. Fakta teknisnya masih benar —
sebuah VM Lua tetap tidak bisa memasang detour **dengan sendirinya** — tetapi
OWH menjembataninya: `owh.hook` dan `owh.find_pattern` adalah fungsi **native**
di dalam DLL OWH yang melakukan pekerjaan C++ itu atas nama skrip. Jadi
pernyataan yang benar adalah:

> **Keterbatasannya bukan pada VM-nya, melainkan pada apa yang host pilih untuk
> diekspos — dan OWH memilih mengekspos cukup banyak.**

### 2.1 Perbandingan level eksekusi (tetap berlaku, tapi dengan catatan)

| | Hook C++ (`loot_hook`) | Skrip `.pluto` murni | Skrip `.pluto` **lewat `owh.*`** |
|---|---|---|---|
| Sisipkan instruksi di alamat game | Ya | Tidak | **Ya, lewat `owh.hook`** |
| Baca memori proses | Ya | Tidak | **Ya, lewat `owh.read_*`** |
| Tulis memori proses | Ya | Tidak | **Ya, lewat `owh.write_*`** |
| Cari pola byte (AoB scan) | Ya | Tidak | **Ya, lewat `owh.find_pattern`** |
| Ubah proteksi memori | Ya | Tidak | **Ya, lewat `owh.protect`** |

Jadi secara kemampuan mentah, jurang antara "hook C++" dan "skrip `.pluto` di
OWH" **jauh lebih sempit** dari yang saya nyatakan sebelumnya. Skrip OWH pada
dasarnya bisa melakukan **jenis operasi yang sama** — bedanya ia
mendelegasikannya ke kode native di dalam OWH, bukan menulis asm sendiri.

### 2.2 Katalog lengkap: 33 anggota (koreksi dari 25)

Versi 1.1.0 mencatat **25** anggota. Itu **salah** — bukan karena OWH
kekurangan fungsi, melainkan karena daftar awal saya **terpotong oleh batas
cetak 25** pada `describe_table`. Deteksi "TIDAK TERCATAT" di v1.1.0 bekerja
dengan benar dan menemukan 8 sisanya. Katalog yang benar, dikonfirmasi silang
dengan `_docs.pluto`:

| Kelas | Anggota | Jml |
|---|---|---|
| **read** | `read_float, read_double, read_int8, read_uint8, read_int16, read_uint16, read_int32, read_uint32, read_int64, read_uint64, read_bytes, read_string` | 12 |
| **scan** | `base, player_base, find_pattern` | 3 |
| **write** ⚠️ | `write_float, write_double, write_int8, write_uint8, write_int16, write_uint16, write_int32, write_uint32, write_int64, write_uint64, write_bytes, write_string, memcpy` | 13 |
| **control** ⚠️ | `hook, unhook, protect, on_unload` | 4 |
| **ui** ⚠️ | `msgbox` | 1 |

### 2.2b P2 SELESAI — `_docs.pluto` sudah diterima

Semua bentuk berikut **dikutip dari `_docs.pluto`**, bukan tebakan:

```lua
local id = owh.hook(addr, function(ctx) ... end)   -- -> id
owh.unhook(id)
owh.find_pattern(module, aob, offs)                -- -> alamat
owh.base()                                         -- -> alamat dasar
owh.player_base()                                  -- -> integer | nil (nil di luar misi)
owh.read_int32(addr) / owh.write_int32(addr, val)  -- + semua lebar lain
owh.read_bytes(addr, n)        -> tabel byte, 1-indexed
owh.read_string(addr [,maxLen])-> string (default 4096)
owh.memcpy(dst, src, n)        -> bool
owh.protect(addr, size, flags) -> oldFlags | nil
owh.msgbox(text [, title])     -> nil  (MEMBLOKIR)
owh.on_unload(fn)              -> nil  (cleanup, LIFO, wajib top-level)
```

**Register yang tersedia di `ctx`** (menurut dokumen):
`rcx, rdx, r8, r9` · `rax, r10, r11, rbx, rbp, rdi, rsi, r12, r13, r14, r15` ·
`rsp` · `xmm0 … xmm15` (float, 32-bit rendah) · `ctx.skip = true`.

### 2.2c Temuan penting: **`ctx.r12` itu 64-bit, dan tidak ada `ctx.r12d`**

Ini menjawab langsung pertanyaan R12D-mu:

1. OWH mengekspos **`ctx.r12`** — register **64-bit penuh**. Dokumen **tidak**
   menyediakan `ctx.r12d`, `ctx.r8d`, `ctx.eax`, atau bentuk 32/16-bit lainnya.
2. Jadi **"R12D" = 32-bit rendah dari `ctx.r12`** — harus dihitung, tidak bisa
   diset langsung.
3. **Bahaya konkret (berdasar A2 arsitektur):** menulis nilai 32-bit ke `r12`
   akan **menolkan bit 32–63**. Kalau `r12` menyimpan **pointer 64-bit**,
   memotongnya ke 32-bit **menghancurkan pointer itu**. Ini alasan teknis
   mengapa G1/G2 wajib dibuktikan sebelum menyentuh register ini.
4. Menulis 32-bit rendah tanpa merusak bit atas butuh **masking**:
   `r12 = (r12 & 0xFFFFFFFF00000000) | (nilai32 & 0xFFFFFFFF)` — bukan sekadar
   perkalian. Skrip menyediakan `M.low32()` dan `M.with_low32()` untuk
   menghitungnya (aritmetika murni, tanpa menyentuh game).
5. **Alternatif yang belum tersingkir:** `ctx.xmm0…xmm15` diekspos sebagai
   float. Kalau jumlah loot disimpan sebagai **float**, yang relevan adalah
   **xmm, bukan r12**. Dokumen tidak memberi tahu yang mana — harus dibuktikan.
6. **Tidak ada dokumentasi flag CPU** (OF/CF/ZF). Padahal A3 menyebut `imul`
   mengubah flag — jadi **tidak ada cara yang terdokumentasi** untuk
   memulihkannya lewat API ini.

> **Kesimpulan:** API-nya memberi **AKSES** ke `r12`, tetapi tidak memberi
> **BUKTI** bahwa `r12` berisi jumlah loot. Akses ≠ pemahaman.

### 2.2d Yang MASIH belum terbukti

| ID | Yang belum diketahui | Mengapa tidak saya isi |
|---|---|---|
| **P3** | Signature AoB / offset fungsi loot, dan struktur data loot | **`_docs.pluto` tidak menyebut loot sama sekali** — tidak ada fungsi loot, tidak ada offset loot, tidak ada AoB loot. Dokumen memberi **ALAT**-nya, bukan **ALAMAT**-nya. Mengarang pola byte melanggar persyaratanmu nomor 3, dan pola yang salah bisa mengenai fungsi yang sama sekali berbeda. |

### 2.3 Jadi, bisakah loot multiplier ×2–×5 dibuat?

**Secara kemampuan: ya, primitifnya tersedia dan sekarang terdokumentasi
lengkap.** P2 sudah selesai; `owh.hook`, `find_pattern`, dan register `ctx`
semuanya jelas. Kalau seseorang punya P3 (signature/offset loot), lintasannya
tinggal merangkai `find_pattern` → `hook` → operasi pada `ctx.*`.

**Saya tidak akan menyediakan rangkaian itu, dan terutama tidak akan
menyediakan P3.** Yang hilang sekarang persis satu hal: **alamat/signature
fungsi loot** — dan itu bukan sesuatu yang bisa ditebak dengan aman.

Yang **bisa** saya bantu, dan ini jalur yang sah untuk menyelesaikan G1–G4:
lihat §12.

### 2.4 Batas yang saya pegang, dan alasannya

Tiga alasan, dan saya sebutkan semuanya agar kamu bisa menilai sendiri:

1. **Persyaratanmu sendiri nomor 7** melarang memasang hook yang memodifikasi
   register atau memori gameplay, mem-patch instruksi, mengubah hasil drop
   aktual, atau melewati anti-cheat. Permintaanmu untuk ×2–×5 berada tepat di
   balik garis yang kamu tarik sendiri.
2. **ToS & risiko ban.** Warframe adalah game multiplayer live dengan ekonomi
   nyata. Penulis fitur loot multiplier aslinya sendiri menulis *"Please do not
   set the loot/coin multiplier higher than 4"*
   [1](https://www.unknowncheats.me/forum/other-fps-games/600451-warframe-chams-loot-coin-changer.html) —
   dan ada indikasi cap sisi game
   [9](https://www.unknowncheats.me/forum/other-fps-games/662459-warframe-loot-modifier.html),
   yang berarti hasilnya bisa dibuang atau memicu deteksi.
3. **Item G1–G4 masih belum terbukti.** Bahkan dengan primitif lengkap, tidak
   ada bukti bahwa nilai yang dikalikan adalah jumlah loot (G1), bahwa ia
   sampai ke inventori (G2), bahwa hook terpanggil sekali per drop (G3), dan
   bahwa hasilnya tidak direkonsiliasi server (G4). Tanpa itu, "berhasil" yang
   kamu lihat bisa jadi angka di layar yang tidak pernah menjadi milikmu.

Batas ini **ditegakkan di dalam kode**, bukan cuma di dokumen: lihat
`safe_owh()` dan Bagian **A1c** pada skrip.

---

## 3. APA YANG TERBUKTI VS BELUM TERBUKTI

### 3.1 TERBUKTI-ARSITEKTUR (fakta CPU, universal, tidak butuh file-mu)

| ID | Klaim | Sumber |
|---|---|---|
| A1 | `R12D` = 32-bit rendah dari `R12`. `R12W` = 16-bit, `R12B` = 8-bit, `R12` = 64-bit. | Intel/AMD SDM penamaan register |
| A2 | Operasi 32-bit pada x86-64 **menolkan** bit 32–63 register induknya. Jadi `imul r12d, ...` membuat `R12 = zero-extend(R12D)`. | Intel SDM Vol.1 §3.4.1.1 |
| A3 | `imul` signed 32-bit yang overflow memotong hasil ke 2^32 dan **membalik tanda**; flag `OF`/`CF` ikut berubah dan dapat mengubah `jo`/`jc` setelahnya. | Intel SDM, entri instruksi `IMUL` |
| A4 | Konvensi pemanggilan Windows x64 melewatkan 4 argumen integer di `RCX, RDX, R8, R9`. `R12` **bukan** register argumen — ia callee-saved. | Dokumentasi Microsoft x64 calling convention |

A4 penting untuk pertanyaan R12D-mu: kalau sebuah hook mengali `R8D`, nilai itu
sangat mungkin argumen ke-3 fungsi tersebut. Kalau ia mengali `R12D`, nilainya
harus **datang dari somewhere** (field struct, hasil komputasi, atau counter
loop) — dan itu harus dibuktikan, tidak boleh diasumsikan.

### 3.2 TERBUKTI (direproduksi)

**Di runtime-mu (dari konsol OWH yang kamu kirim):**

| Klaim | Bukti |
|---|---|
| OWH menjalankan skrip `.pluto` | Output konsolmu: `RUNTIME = true` |
| Runtime-mu adalah **Pluto 0.12.2 / Lua 5.4** | `_PVERSION` dan `_VERSION` di Bagian A2 |
| Namespace-nya `owh`, berisi 25 fungsi baca/tulis/hook/scan | Bagian A1 pada outputmu |
| Self-test dan penanganan error lulus di runtime-mu | `self-test: 18 lulus, 0 gagal`, `tertangkap 9 dari 9` |

**Di komputer ini (direproduksi, lihat `tests/reference/`):**

| Klaim | Bukti |
|---|---|
| Skrip dimuat dan dieksekusi tanpa error | `run_pluto_0.13.1.txt`, `run_lua_5.4.7.txt` (exit 0) |
| Self-test 18/18 lulus | Bagian F1 |
| 9/9 kasus error tertangkap | Bagian E1 |
| Tetap tidak crash saat `print`, `io`, `os`, `debug`, `string.format` dicabut | `compat_*.txt` — 38/38 di Pluto **dan** Lua 5.4.7 |
| **Tidak satu pun fungsi `owh` yang dipanggil** | Skenario 6 pada `compat_*.txt`: host tiruan dengan 25+1 mata-mata, `total_calls == 0` |
| Aritmetika model ×2–×5 benar | Diverifikasi terhadap nilai hitungan manual, Bagian B1/C1/C2/C3 |

### 3.3 BELUM TERBUKTI (butuh `_docs.pluto` atau eksperimen RE)

| ID | Klaim | Uji yang dibutuhkan |
|---|---|---|
| **P2** | Parameter & return `owh.hook`, `owh.find_pattern`, `owh.protect` | Baca `_docs.pluto` |
| **P3** | Signature AoB / offset fungsi loot | RE yang bisa direproduksi — tidak disediakan di sini |

| ID | Klaim | Uji yang dibutuhkan |
|---|---|---|
| G1 | Pada titik hook, `R12D` berisi **jumlah loot** | Telusuri instruksi yang **menulis** `R12D` sebelum titik hook (backward slice). Kalau sumbernya bukan argumen/field jumlah, klaim gugur. |
| G2 | Nilai itu mengalir ke fungsi yang mengomit sumber daya (forward taint) | Tandai nilainya; amati apakah ia sampai ke pembaruan inventori. Pastikan `R12` tidak dipakai sebagai counter/pointer di antaranya. |
| G3 | Titik hook dieksekusi **tepat satu kali** per kejadian drop | Pasang hit-counter pasif; bandingkan dengan jumlah drop yang terlihat di layar. |
| G4 | Hasil perkalian tidak di-clamp / direkonsiliasi server | Bandingkan HUD, layar hasil misi, dan profil setelah misi. Selisih = ada rekonsiliasi. |
| G5 | ×2–×5 aman dari deteksi | **Tidak bisa dibuktikan dari klien.** Ini kebijakan risiko, bukan fakta teknis. |

**Selama G1–G4 belum lulus, menyebut `R12D` sebagai "jumlah loot" adalah asumsi.**
Ini persisnya yang kamu minta di persyaratan nomor 4, dan skrip mencetak
checklist ini setiap kali dijalankan supaya tidak ada yang lupa.

---

## 4. TARGET KONFIGURASI ×2 – ×5

Angka-angka berikut **berasal dari eksekusi skrip yang sesungguhnya** (bagian B1),
bukan dari perkiraan.

| Pengali | Nilai maks aman sebelum wrap | Contoh aman | Contoh yang wrap |
|---|---|---|---|
| ×2 | 1.073.741.823 | `1.000.000.000 → 2.000.000.000` | `2.147.483.647 → -2` |
| ×3 | 715.827.882 | `100 → 300` | `1.000.000.000 → -1.294.967.296` |
| ×4 | 536.870.911 | `250 → 1.000` | `2.147.483.647 → -4` |
| ×5 | 429.496.729 | `100 → 500` | `1.000.000.000 → 705.032.704` |

Dua hal yang sering tertukar dan **sengaja dipisahkan** oleh skrip ini:

1. **Perkalian register ≠ perubahan loot aktual.** Yang pertama adalah operasi
   ALU pada 32 bit. Yang kedua bergantung pada apakah nilai itu lolos clamp,
   cap per misi, dan rekonsiliasi server (G4), dan apakah ia memang jumlah
   sejak awal (G1).
2. **Perkalian jumlah ≠ perkalian peluang.** `imul` mengubah **kuantitas**.
   "Loot multiplier" juga bisa berarti menggandakan **peluang drop**, yang
   secara matematika berbeda: P(≥1) = 1 − (1−p)^m, tidak pernah linear, dan
   dibatasi 100%. Skrip menghitung **keduanya** (Bagian C1 dan C2) supaya
   kamu bisa melihat bedanya.

---

## 5. ARTEFAK YANG DIKIRIM

| Berkas | Isi |
|---|---|
| **`hooks/owh_loot_research.pluto`** | **Deliverable utama.** Harness diagnostik read-only + simulator ×2–×5. |
| `tests/compat_driver.lua` | Penguji 27 skenario (portabilitas + kondisi runtime yang "bermusuhan"). |
| `tests/reference/*.txt` | Output terverifikasi dari Pluto 0.13.1 dan Lua 5.4.7. |
| `docs/ANALYSIS.md` | Dokumen ini. |

### 5.1 Penjelasan tiap fungsi di `owh_loot_research.pluto`

**Utilitas aman**

| Fungsi | Kegunaan | Kenapa aman |
|---|---|---|
| `try(f, ...)` | `pcall` + cek `type(f)=="function"` dulu | Memanggil sesuatu yang bukan fungsi tidak melempar; ia mengembalikan `false, pesan` |
| `tostr(v)` | `tostring` yang tidak pernah error | `__tostring` pada userdata bisa error; dibungkus `pcall` |
| `toint(v)` | Angka → integer; menolak `nil`, NaN, `±inf` | Mencegah `string.format("%d", x)` melempar di Lua 5.3+ |
| `current_env()` | Mengambil env chunk (`_ENV` → `getfenv` → `_G`) | VM tersemat sering memakai env khusus; mengasumsikan `_G` saja itu bug |
| `read_flag(name)` | Baca flag dari env chunk, lalu `_G` | Supaya `OWH_RESEARCH_NO_AUTORUN` terbaca di env apa pun |

**Log**

| Fungsi | Kegunaan |
|---|---|
| `init_sinks()` | Mendeteksi sink output yang **benar-benar ada**. Mode `auto` memilih **satu** sink — memakai `print` **dan** `io.write` sekaligus membuat setiap baris tercetak dua kali (bug nyata yang saya temukan saat menguji). |
| `log(fmt, ...)` | Mencetak ke semua sink + selalu menyimpan ke buffer. Kalau `string.format` gagal atau tidak ada, turun ke `string.gsub`, lalu ke penempelan teks. **Tidak pernah melempar.** |

**Pemindaian API (read-only)**

| Fungsi | Kegunaan |
|---|---|
| `detect_vm()` | Melapor `_VERSION`, ada/tidaknya `debug`/`io`/`os`/`require`, jumlah penanda khusus Pluto. Hanya melapor apa yang ada. |
| `lookup_global(name)` | Membaca nama dari env chunk, lalu `_G`. VM tersemat bisa menaruh namespace host di env khusus — mengasumsikan `_G` saja pernah jadi bug nyata di sini. |
| `collect_globals(limit)` | Mengumpulkan dan mengurutkan kunci `_G`. `pairs` dibungkus `pcall` — kalau `__pairs` host error, ia melapor, bukan crash. |
| `describe_table(name, tbl, limit)` | Mendaftar member tabel sedalam 1 level. **Hanya membaca** — tanpa pemanggilan, tanpa sentuhan metatable. |
| `probe_hypotheses()` | Mengetes 11 nama kandidat dan mencetak `[ADA]`/`[TIDAK ADA]`. Daftar ini **hipotesis, bukan klaim API**; ganti dengan nama asli dari `_docs.pluto`. |

**API OWH + pengaman read-only** (baru di v1.1.0)

| Fungsi | Kegunaan |
|---|---|
| `OWH_API` | 25 anggota yang **terbukti ada** di runtime-mu, masing-masing berlabel `read` / `write` / `control` / `meta` / `ui`. |
| `owh_inventory()` | Memeriksa keberadaan tiap anggota **tanpa memanggilnya**, plus melaporkan anggota host yang belum tercatat. |
| `safe_owh(member, ...)` | **Satu-satunya** jalan keluar ke namespace `owh`. Menolak semua kelas `write`/`control`/`ui`, mencatat setiap usaha, mengembalikan `false, alasan`. |
| `FORBIDDEN` | Daftar 15 anggota yang dilarang: 10 `write` + 4 `control` + 1 `ui`. |
| `get_owh_call_count()` | Mengembalikan `{attempted, executed, refused}` — dipakai untuk membuktikan `executed == 0`. |
| `print_owh_capability()` | Bagian A1b: inventaris + klasifikasi + verdikt kemampuan yang jujur. |
| `print_guard_proof()` | Bagian A1c: sengaja **mencoba** memanggil 9 operasi berbahaya untuk membuktikan semuanya ditolak. |

**Model register**

| Fungsi | Kegunaan |
|---|---|
| `wrap32(x)` | Memotong ke 32-bit signed — persis seperti menyimpan nilai ke `R12D`. |
| `imul_r32(value, m)` | Meniru `imul r32, r32, imm`: mengembalikan hasil terpotong **dan** flag `wrapped`. |
| `overflow_threshold(m)` | Nilai terbesar yang masih aman dikali `m` tanpa wrap. |
| `wrap16(x)` | Varian 16-bit (`R12W`) untuk menunjukkan kenapa "R12" tanpa sufiks itu ambigu. |

**Simulator**

| Fungsi | Kegunaan |
|---|---|
| `validate_drop(d)` | Validasi: `amount` wajib angka ≥ 0; `chance` (bila ada) harus dalam [0,1]. Mengembalikan `nil, pesan` — tidak pernah melempar. |
| `sim_quantity(drop, m, use_reg_model, cap)` | Model **kuantitas**: apa yang dilakukan sebuah `imul`. Mendukung pemotongan 32-bit dan clamp. |
| `sim_chance(drop, m)` | Model **peluang**: P(≥1) = 1 − (1−p)^m. Operasi yang berbeda dari `imul`. |
| `expected_value(drop, m, trials)` | Nilai harapan per kejadian dan total untuk N kejadian. |

**Laporan & modul**

| Fungsi | Kegunaan |
|---|---|
| `print_vm_info()`, `print_hypotheses()`, `print_globals()` | Bagian A0–A2: bukti API |
| `print_register_model()`, `print_width_note()` | Bagian B1–B2: model register |
| `print_simulator()`, `print_chance_model()`, `print_expected_value()` | Bagian C1–C3: simulator ×2–×5 |
| `print_checklist()` | Bagian D1: terbukti vs belum |
| `print_error_demos()` | Bagian E1: 9 kasus error, semuanya harus `TERTANGKAP` |
| `run_selftests()` | Bagian F1: 18 pernyataan yang bisa diverifikasi |
| `evidence_checklist()` | Mengembalikan klaim A*/G* terstruktur |
| `M.get_log()`, `M.get_log_text()` | Ambil log walau tidak ada konsol |
| `M.save_report(path)` | Simpan log ke berkas teks biasa. **Mati secara default** (`CFG.write_report = false`). |
| `M.run()` | Menjalankan semua bagian. Idempoten. Dibungkus `pcall` — error di satu bagian tidak menghentikan sisanya. |

---

## 6. INSTALASI MELALUI CUSTOM HOOKS

1. **Buka OWH**, masuk ke menu **Custom Hooks**.
2. Klik **Open Folder** — Windows Explorer akan membuka folder hooks OWH.
3. Salin `hooks/owh_loot_research.pluto` ke folder tersebut.
   (Berkas harus berakhiran `.pluto` dan berada **langsung** di folder itu,
   bukan di subfolder.)
4. Kembali ke OWH, klik **Reload List**.
5. Nama skrip akan muncul di daftar. Aktifkan / jalankan.
6. Baca konsol OWH. Yang kamu cari:
   - `RUNTIME : skrip selesai dieksekusi = true`
   - Bagian **A1b** — inventaris & klasifikasi 25 anggota `owh`
   - Bagian **A1c** — harus berbunyi `TERBUKTI: 0 panggilan ke operasi mutasi
     dieksekusi.`
   - `self-test: 18 lulus, 0 gagal`
   - `tertangkap 9 dari 9 kasus.`

**Mau lihat dulu sebelum dipasang?** Jalankan `tests/owh_preview.lua` —
ia memalsukan namespace `owh` dan mencetak persis bagaimana A1b dan A1c akan
tampil. Output contohnya ada di `tests/reference/owh_preview.txt`.

**Kalau konsol tidak menampilkan apa pun:** output mungkin tidak terhubung ke
konsol. Log tetap tersimpan di memori. Untuk mengambilnya, set
`CFG.write_report = true` dan panggil `M.save_report("owh_loot_research.log")`
— atau jalankan skrip lain yang memuatnya sebagai pustaka:

```lua
OWH_RESEARCH_NO_AUTORUN = true          -- jangan auto-run saat dimuat
local Loot = dofile("owh_loot_research.pluto")
Loot.run()
print(Loot.get_log_text())              -- seluruh log sekaligus
```

---

## 7. CARA PENGUJIAN

### 7.1 Uji di komputer ini (sudah dilakukan)

```bash
pluto  hooks/owh_loot_research.pluto     # exit 0, 330 baris
lua5.4 hooks/owh_loot_research.pluto     # exit 0, 314 baris
pluto  tests/compat_driver.lua           # 27 lulus, 0 gagal
lua5.4 tests/compat_driver.lua           # 27 lulus, 0 gagal
```

Hasil lengkap ada di `tests/reference/`.

### 7.2 Uji di OWH (yang harus kamu lakukan)

| Langkah | Yang diharapkan | Artinya kalau gagal |
|---|---|---|
| Reload List → skrip muncul | Nama berkas ada di daftar | Ekstensi/lokasi salah |
| Jalankan → `RUNTIME = true` | Skrip selesai tanpa error | Lihat baris `ERROR:` — konsol mencetak nomor barisnya |
| Bagian A1b: `[ADA] owh` + 25 anggota | Namespace host terdeteksi | Kalau `[TIDAK ADA]`, skrip tidak berjalan di dalam OWH |
| Bagian A1b: `tidak-tercatat=0` | Daftar 25 anggota lengkap | Kalau > 0, kirim namanya ke saya |
| Bagian A1c: `dieksekusi=0` | Pengaman read-only bekerja | **Hentikan pemakaian** dan laporkan ke saya |
| `self-test: 18 lulus, 0 gagal` | Aritmetika model benar di VM-mu | VM-mu berbeda; kirim outputnya |
| `tertangkap 9 dari 9` | Penanganan error jalan | Kirim outputnya |
| Bagian A2 terisi | Daftar global OWH | Kalau kosong, `_G` tidak bisa diiterasi di OWH |

### 7.3 Yang TIDAK bisa diuji oleh skrip ini

Skrip ini **tidak bisa** membuktikan bahwa loot di game berubah. Tidak ada
bagian pun yang membaca memori game, jadi tidak ada bagian pun yang bisa
mendeteksi perubahan gameplay. Kalau suatu hari kamu mengubah loot secara
nyata, verifikasinya harus dilakukan **di layar hasil misi dan di profil
pemain**, bukan di konsol Lua.

---

## 8. CONTOH PENANGANAN ERROR

Sembilan kasus ini dijalankan **setiap kali** skrip dimuat (Bagian E1). Hasil
aktual dari `tests/reference/run_pluto_0.13.1.txt`:

```
  amount hilang (nil)              -> TERTANGKAP   nil + pesan: field 'amount' wajib berupa angka
  amount bertipe string non-angka  -> TERTANGKAP   nil + pesan: field 'amount' wajib berupa angka
  amount negatif                   -> TERTANGKAP   nil + pesan: field 'amount' tidak boleh negatif
  chance di luar [0,1]             -> TERTANGKAP   nil + pesan: field 'chance' harus dalam [0,1]
  multiplier = 0 (pembagi nol)     -> TERTANGKAP   nil + pesan: multiplier nol
  nilai NaN                        -> TERTANGKAP   nil + pesan: nilai NaN
  nilai tak hingga                 -> TERTANGKAP   nil + pesan: nilai tak hingga
  drop bukan tabel                 -> TERTANGKAP   nil + pesan: entri drop bukan tabel
  memanggil nil sebagai fungsi     -> TERTANGKAP   nilai false: objek yang dipanggil bukan function (tipe: nil)
  ------------------------------------------------------------------
  tertangkap 9 dari 9 kasus.
```

Sebuah kasus dianggap tertangkap bila **salah satu** terjadi: `pcall` menangkap
error, fungsi mengembalikan `nil` + pesan, atau fungsi mengembalikan `false`.
Kalau sebuah fungsi tetap mengembalikan nilai sukses untuk input yang rusak, itu
lubang validasi dan akan tercetak sebagai **TIDAK TERTANGKAP**.

**Penanganan error saat pemasangan (yang paling sering terjadi):**

| Gejala di konsol | Penyebab | Perbaikan |
|---|---|---|
| `cannot open ... No such file` | Berkas tidak di folder hooks | Ulangi langkah 2–3 |
| Skrip tidak muncul di daftar | Belum Reload List, atau ekstensi bukan `.pluto` | Reload List |
| Skrip muncul tapi tidak ada output | `print` tidak terhubung ke konsol | Pakai `M.get_log_text()` (lihat §6) |
| Baris tercetak dua kali | Dua sink aktif | Set `CFG.log_sink_mode = "print"` |
| `[GAGAL]` di self-test | VM-mu berbeda dari yang saya uji | Kirim `tests/reference/`-mu ke saya |

Error tingkat paling atas: auto-run dibungkus `pcall`. Kalau `M.run()`
melempar, skrip mencetak `ERROR saat auto-run: ...` dan **tetap dimuat** —
ia tidak akan merusak sesi hook-mu.

---

## 9. PERNYATAAN EKSPLISIT (direvisi setelah bukti baru)

1. **Koreksi: saya menarik kembali klaim "tidak bisa dibuat karena API tidak
   tersedia."** Itu salah. Setelah output konsolmu, terbukti OWH mengekspos
   `owh.hook`, `owh.find_pattern`, `owh.write_*`, `owh.protect`, `owh.memcpy`.
   **Primitifnya ada.**
2. **Tetapi saya tetap tidak membuatkan loot multiplier ×2–×5 yang bekerja.**
   Alasannya sekarang **bukan** ketiadaan API dan **bukan** ketiadaan
   dokumentasi — `_docs.pluto` sudah menjawab keduanya. Alasannya tinggal:
   - **P3 belum terpecahkan**: `_docs.pluto` tidak menyebut loot sama sekali.
     Tidak ada signature, offset, maupun struktur data loot di dokumen itu.
     Mengarangnya dilarang oleh persyaratanmu nomor 3 — dan pola yang salah
     bisa mengenai fungsi yang sama sekali berbeda;
   - **G1–G4 belum terbukti**: tak ada bukti bahwa `ctx.r12` berisi jumlah
     loot (apalagi dengan tidak adanya `ctx.r12d`), dan ada alternatif yang
     belum tersingkir bahwa nilainya disimpan di `xmm` sebagai float;
   - dan terutama: **persyaratanmu nomor 7 melarangnya**, dan mengubah
     perolehan loot di game multiplayer live melanggar ToS dengan risiko ban
     yang penulis fitur aslinya sendiri peringatkan.
3. **Yang dikirimkan adalah harness diagnostik read-only + simulator**, sesuai
   alternatif yang kamu minta, **ditambah probe baca** untuk meneliti loot
   secara sah (§12). Status read-only **dibuktikan oleh kode, bukan klaim**:
   `safe_owh()` menolak **18** anggota terlarang (13 write + 4 control + 1 ui),
   dan Bagian A1c menunjukkan 18 percobaan ditolak dengan `dieksekusi = 0`.
   Teruji pula oleh Skenario 6 (host tiruan, 0 panggilan) dan Skenario 7
   (probe hidup sekalipun, mutasi tetap 0).
3. **Skrip berhasil dimuat ≠ loot multiplier bekerja.** Ketiga status ini
   dipisahkan secara eksplisit di Bagian G1 setiap kali dijalankan:
   - (1) **RUNTIME** — skrip selesai dieksekusi: `true`
   - (2) **DIAGNOSTIK** — angka dan daftar: ada di Bagian A0–F1
   - (3) **PERUBAHAN GAMEPLAY** — **tidak ada. Nol.**

   (1) dan (2) **bukan** bukti dari (3).
4. **Tidak ada alamat, signature AoB, offset, nama fungsi, atau struktur memori
   yang dikarang** di artefak mana pun. Bagian A1 berisi *hipotesis* yang
   secara eksplisit diberi label demikian dan hanya diuji keberadaannya.
5. **Klaim `R12D = jumlah loot` berstatus BELUM TERBUKTI** sampai uji G1–G4
   lulus. Skrip mencetak checklist ini agar tidak ada yang menganggapnya fakta.

---

## 10. CATATAN RISIKO

- Warframe adalah game **multiplayer live** dengan ekonomi nyata. Memodifikasi
  perolehan sumber daya melanggar ToS dan berisiko banned permanen.
- Penulis fitur loot multiplier yang asli sendiri menyarankan **tidak lebih
  dari ×4** dan menyediakan mode "Danger" yang ia peringatkan secara eksplisit
  [1](https://www.unknowncheats.me/forum/other-fps-games/600451-warframe-chams-loot-coin-changer.html).
  Target ×5-mu berada di luar saran itu.
- Ada indikasi **cap sisi game** per item per misi, yang berarti nilai hasil
  perkalian bisa dibuang sebelum sampai ke profilmu
  [9](https://www.unknowncheats.me/forum/other-fps-games/662459-warframe-loot-modifier.html).
- Overflow signed 32-bit (tabel di §4) dapat menghasilkan **angka negatif**,
  yang bisa memicu perilaku tak terduga atau crash — bukan sekadar "loot tidak
  nambah".
- Semua ini adalah alasan tambahan mengapa batas yang saya ambil adalah
  diagnostik read-only.

---

## 12. JALUR YANG SAH: menyelesaikan G1–G4 dengan probe baca

Ada perbedaan besar antara **memodifikasi** loot dan **meneliti** loot. Yang
kedua itu sah, tidak mengubah apa pun, dan justru satu-satunya cara membuktikan
klaim R12D-mu. Skrip v1.2.0 menyediakan alatnya:

| Fungsi | Kegunaan | Kelas |
|---|---|---|
| `M.read_addr(addr, lebar)` | Baca satu alamat lewat `owh.read_*` yang sesuai | read |
| `M.sample_addr(addr, lebar, n)` | Ambil n sampel; laporkan berapa nilai berbeda | read |
| `M.find_addr(module, aob, offs)` | Pindai signature (argumen dari RE-mu) | scan |
| `M.low32(v)` / `M.with_low32(full, baru)` | Aritmetika 32-bit rendah, murni hitungan | — |

Semuanya **mati secara default** (`CFG.call_readonly_probes = false`) dan
semuanya melewati `safe_owh()`, jadi kelas write/control/ui tetap mustahil
diakses berapa pun nilai flag-nya.

**Cara memakainya untuk menguji G1–G4** (alamat dari hasil RE-mu sendiri):

```lua
OWH_RESEARCH_NO_AUTORUN = true
local L = dofile("owh_loot_research.pluto")
L.CFG.call_readonly_probes = true

local addr = 0x7FF000000000          -- <- WAJIB dari RE-mu. Skrip tidak
                                     --    menyediakan, mencari, atau menebaknya.
print(L.read_addr(addr, "int32"))    -- nil + alasan kalau gagal

local s = L.sample_addr(addr, "int32", 60)
print("nilai berbeda:", s.distinct)  -- 1 = statis, >1 = berubah saat misi
```

Uji yang bisa kamu lakukan dengannya:

- **G1** — apakah nilai di alamat itu berkorelasi dengan jumlah yang kamu
  lihat di HUD.
- **G3** — pakai `sample_addr` sebelum dan sesudah satu pengambilan; hitung
  jumlah transisi. Kalau transisinya bukan 1 per drop, titik itu bukan
  kandidat yang benar.
- **G4** — bandingkan nilai di HUD, layar hasil misi, dan profil setelah misi.

Hasilnya bisa kamu bawa ke mana saja: itu data, bukan pelanggaran.

---

## 11. LANGKAH LANJUTAN

Sekarang pertanyaannya sudah berubah: bukan lagi "apakah OWH punya API-nya",
melainkan "apa bentuk pasti API-nya". Untuk menjawab itu:

1. **Kirim `_docs.pluto`.** Yang paling saya butuhkan: tanda tangan
   `owh.hook(...)`, `owh.find_pattern(...)`, `owh.protect(...)`. Ini item **P2**
   — satu-satunya penghalang dokumentasi yang tersisa.
2. **Jalankan ulang skrip v1.1.0 di OWH**, lalu kirim:
   - Bagian **A1b** — terutama baris `ringkasan: read=.. write=..` dan apakah
     `tidak-tercatat` bernilai 0. Kalau > 0, ada anggota `owh` yang belum saya
     dokumentasikan.
   - Bagian **A1c** — harus berbunyi `TERBUKTI: 0 panggilan ... dieksekusi.`
3. **Konfirmasi keanehan ini:** `read_int32`, `read_uint16`, `read_uint32`
   tidak muncul di daftar, padahal `write_int32` ada. Kalau itu memang
   ketidaklengapan OWH (bukan pemotongan daftar), itu informasi berharga.
4. **Source `change_loot` / `loot_hook`** tetap berguna untuk menganalisis
   alur data spesifiknya (item G1–G4).

Dengan (1) saya bisa menulis kode yang memakai API OWH dengan **benar dan
aman**. Tanpa (1), setiap pemanggilan `owh.hook` adalah tebakan — dan tebakan
yang salah di dalam proses game berujung crash, bukan sekadar error Lua.

---

## Lampiran A — Cara membangun ulang bukti di komputer ini

```bash
# Pluto 0.13.1 (basis Lua 5.5.1) — dipakai untuk verifikasi
git clone --recurse-submodules --depth 1 https://github.com/PlutoLang/Pluto.git
# bangun tanpa skrip PHP: kompilasi src/vendor/Soup/soup/*.cpp (-DSOUP_STANDALONE),
# ar -> libsoup.a; lalu src/*.cpp, link dengan -lsoup -lstdc++ -lm -pthread -ldl -lresolv

# Lua 5.4.7 — dipakai untuk verifikasi portabilitas
git clone --depth 1 --branch v5.4.7 https://github.com/lua/lua.git
gcc -O2 -std=c99 -DLUA_USE_LINUX -o lua onelua.c -lm -ldl
```

Kedua interpreter ini **hanya** dipakai untuk membuktikan bahwa skripnya
dikompilasi dan berjalan. Keduanya tidak ada hubungannya dengan OWH atau
Warframe.
