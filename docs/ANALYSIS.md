# OWH / LuaVM — Loot Multiplier Research

**Tanggal:** 2026-10-12 · **Branch:** `arena/77b9773e-editor`
**Artefak:** `hooks/owh_loot_research.pluto` (v1.0.0) · `tests/compat_driver.lua` · `tests/reference/`

---

## 0. STATUS LAMPIRAN — BACA INI DULU

Ketiga referensi yang kamu sebutkan **tidak ikut terlampir** pada pesanmu. Yang
ada di repositori saat saya mulai hanyalah `README.md` berisi `# editor` (9 byte).

| Referensi | Status | Akibatnya |
|---|---|---|
| 1. `_docs.pluto` dari OWH | **Tidak diterima** | Saya tidak tahu nama API OWH yang sesungguhnya |
| 2. Source DX11Hook (`change_loot`, `loot_hook`) | **Tidak diterima** | Saya tidak bisa membaca baris kodenya |
| 3. Screenshot hasil uji `.pluto` | **Tidak diterima** | Saya tidak bisa memverifikasi konsol OWH-mu |

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

**Jawaban: tidak ada padanan yang bisa dibuktikan valid. Ada dua alasan, satu
bersifat teknis dan satu bersifat bukti.**

### 2.1 Alasan teknis: beda level eksekusi

| | Hook C++ (`loot_hook`) | Skrip `.pluto` di LuaVM |
|---|---|---|
| Berjalan di | Dalam proses game, di alamat instruksi | Di dalam VM yang disematkan host |
| Bisa menyisipkan instruksi? | Ya (`jmp` ke trampoline) | **Tidak** |
| Bisa membaca/menulis register CPU? | Ya (inline asm / context struct) | **Tidak** |
| Bisa memanggil fungsi game di alamat mentah? | Ya (cast pointer) | **Tidak** |
| Bisa mengubah nilai saat fungsi game berjalan? | Ya | **Tidak** |
| Yang bisa dilakukan | Apa pun dalam proses | **Hanya apa yang di-*export* host ke skrip** |

Sebuah VM Lua tidak punya primitif untuk memasang detour di tengah fungsi.
Satu-satunya cara skrip bisa memengaruhi loot adalah **jika host OWH
mengekspos sebuah fungsi native** (misalnya `setLootMultiplier(n)`) yang
diimplementasikan di dalam DLL OWH dalam bahasa C++. Kalau OWH tidak
mengeksposnya, tidak ada jumlah kode Lua yang bisa menciptakannya.

Jadi pertanyaannya bergeser dari *"bagaimana menulis `imul` di Lua"* menjadi
*"apakah OWH mengekspos API loot?"* — dan pertanyaan kedua ini **tidak bisa
dijawab tanpa `_docs.pluto`**.

### 2.2 Alasan bukti: saya tidak punya `_docs.pluto`

Saya tidak akan menulis `owh.setLootMultiplier(3)` atau variasi serupa karena
saya tidak punya bukti bahwa nama itu ada. Menuliskannya akan melanggar
persyaratanmu nomor 3 (*jangan mengarang nama fungsi*).

Skrip yang saya kirim menjawab ini secara empiris: Bagian **A2** mendaftar
setiap global di `_G`, dan Bagian **A1** mengetes sebelas nama kandidat dan
mencetak `[ADA]` atau `[TIDAK ADA]`. Jalankan di OWH-mu, dan kamu punya
jawabannya — dari komputermu sendiri, bukan dari tebakan saya.

### 2.3 Bahkan kalau API-nya ada

Persyaratanmu nomor 7 melarang mengubah hasil drop aktual. Selain itu, ini game
multiplayer live dengan ekonomi nyata; memodifikasi perolehan sumber daya
melanggar ToS Warframe dan — menurut penulis fitur aslinya sendiri —
berisiko [1](https://www.unknowncheats.me/forum/other-fps-games/600451-warframe-chams-loot-coin-changer.html).
Jadi saya menghentikan batas di **diagnostik read-only + simulator**, persis
seperti yang kamu minta sebagai alternatif.

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

### 3.2 TERBUKTI (direproduksi di komputer ini, lihat `tests/reference/`)

| Klaim | Bukti |
|---|---|
| Skrip `.pluto` ini dimuat dan dieksekusi tanpa error | `run_pluto_0.13.1.txt`, `run_lua_5.4.7.txt` (exit 0) |
| Self-test 18/18 lulus | Bagian F1 pada kedua berkas referensi |
| 9/9 kasus error tertangkap | Bagian E1 |
| Tetap tidak crash saat `print`, `io`, `os`, `debug`, `string.format` dicabut | `compat_*.txt` — 27/27 lulus di Pluto **dan** Lua 5.4.7 |
| Aritmetika model ×2–×5 benar | Diverifikasi terhadap nilai yang dihitung manual, Bagian B1/C1/C2/C3 |

### 3.3 BELUM TERBUKTI (butuh source-mu atau eksperimen RE)

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
| `collect_globals(limit)` | Mengumpulkan dan mengurutkan kunci `_G`. `pairs` dibungkus `pcall` — kalau `__pairs` host error, ia melapor, bukan crash. |
| `describe_table(name, tbl, limit)` | Mendaftar member tabel sedalam 1 level. **Hanya membaca** — tanpa pemanggilan, tanpa sentuhan metatable. |
| `probe_hypotheses()` | Mengetes 11 nama kandidat dan mencetak `[ADA]`/`[TIDAK ADA]`. Daftar ini **hipotesis, bukan klaim API**; ganti dengan nama asli dari `_docs.pluto`. |

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
   - Bagian **A2** — **ini yang paling penting**, salin dan kirim ke saya
   - `self-test: 18 lulus, 0 gagal`
   - `tertangkap 9 dari 9 kasus.`

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

## 9. PERNYATAAN EKSPLISIT

1. **Loot multiplier ×2–×5 yang bekerja TIDAK bisa dibuat dari skrip `.pluto`
   dengan API yang terbukti tersedia saat ini.** Alasannya di §2: VM Lua tidak
   bisa memasang detour ×86-64, dan saya tidak punya bukti bahwa OWH
   mengekspos API loot native.
2. **Yang dikirimkan adalah harness diagnostik read-only + simulator**, sesuai
   alternatif yang kamu minta di persyaratan nomor 7. Tidak ada satu baris pun
   yang menulis memori, memasang hook, mem-patch instruksi, mengubah register,
   atau mengubah hasil drop.
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

## 11. LANGKAH LANJUTAN

Supaya saya bisa menulis kode yang cocok dengan API OWH yang **nyata**:

1. Kirim `_docs.pluto` (lampirkan berkasnya atau tempel isinya).
2. Jalankan skrip di OWH, lalu kirim bagian **A2 — Inventaris Global `_G`**.
   Kalau mau lebih lengkap, naikkan `CFG.dump_limit` jadi 1000 dulu.
3. Kirim source `change_loot` / `loot_hook` bila kamu masih ingin saya menganalisis
   alur datanya secara spesifik.

Dengan dua yang pertama, saya bisa mengganti daftar hipotesis di `HYPOTHESES`
dengan nama API yang sesungguhnya dan menambahkan pemeriksaan kemampuan yang
presisi. Tanpa itu, saya hanya akan mengulangi "BELUM TERBUKTI".

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
