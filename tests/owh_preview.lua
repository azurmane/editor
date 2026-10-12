--[==[
================================================================================
 tests/owh_preview.lua
 Pratinjau: seperti apa Bagian A1b & A1c di konsol OWH yang sebenarnya.
================================================================================

 Skrip ini MEMALSUKAN namespace `owh` dengan 25 anggota yang terbukti ada
 (lihat docs/ANALYSIS.md), lalu menjalankan hooks/owh_loot_research.pluto di
 atasnya dan mencetak hanya Bagian A1b (inventaris + klasifikasi) dan A1c
 (pembuktian pengaman read-only).

 Tujuannya: kamu bisa melihat bentuk laporannya SEBELUM memasangnya ke OWH.
 Angka yang muncul di sini berasal dari host tiruan, BUKAN dari OWH-mu.

 Pakai:  pluto tests/owh_preview.lua
         lua5.4 tests/owh_preview.lua
================================================================================
]==]

local OWH_MEMBERS = {
    "base", "find_pattern", "hook", "memcpy", "msgbox", "on_unload",
    "player_base", "protect", "read_bytes", "read_double", "read_int16",
    "read_int64", "read_string", "read_uint64", "read_uint8", "unhook",
    "write_bytes", "write_float", "write_int16", "write_int32",
    "write_int8", "write_string", "write_uint16", "write_uint64",
    "write_uint8",
}

-- Semua anggota adalah fungsi yang mengembalikan 0. Mereka TIDAK pernah
-- dipanggil oleh skrip yang diuji (lihat pembuktian di Bagian A1c).
local owh_fake = {}
for i = 1, #OWH_MEMBERS do
    owh_fake[OWH_MEMBERS[i]] = function() return 0 end
end

-- Muat sebagai pustaka, jangan auto-run, lalu jalankan dengan env khusus.
local src_path = "hooks/owh_loot_research.pluto"
local fh, err = io.open(src_path, "rb")
if not fh then
    print("FATAL: tidak dapat membuka " .. src_path .. ": " .. tostring(err))
    os.exit(2)
end
local src = fh:read("*a")
fh:close()

local env = setmetatable({ owh = owh_fake, OWH_RESEARCH_NO_AUTORUN = true },
                         { __index = _G })
local f = load(src, "=owh_loot_research", "t", env)
if not f then
    print("FATAL: gagal mengompilasi " .. src_path)
    os.exit(2)
end

local ok, mod = pcall(f)
if not ok or type(mod) ~= "table" then
    print("FATAL: gagal memuat modul: " .. tostring(mod))
    os.exit(2)
end

mod.run()

-- Cetak hanya bagian yang relevan.
local lines = mod.get_log()
local printing, printed = false, 0
for i = 1, #lines do
    local l = lines[i]
    if l:find("A1b%. API OWH") then printing = true end
    if printing then
        print(l)
        printed = printed + 1
        if l:find("A2%. INVENTARIS GLOBAL") then break end
    end
end

print("")
print(string.rep("=", 78))
print("CATATAN: ini host TIRUAN. Angka asli akan muncul saat dijalankan di OWH.")
print("Yang penting untuk diperiksa di OWH-mu:")
print("  1. baris 'ringkasan: read=.. write=.. control=..' ")
print("  2. baris 'tidak-tercatat' — kalau > 0, ada anggota owh yang belum")
print("     saya dokumentasikan. Kirim namanya ke saya.")
print("  3. baris 'TERBUKTI: 0 panggilan ke operasi mutasi dieksekusi.'")
print(string.rep("=", 78))
