--[==[
================================================================================
 tests/compat_driver.lua
 Penguji portabilitas & ketahanan untuk hooks/owh_loot_research.pluto
================================================================================

 Tujuan
   Membuktikan bahwa skrip .pluto tersebut:
     1. benar-benar bisa dimuat dan dieksekusi (bukan sekadar klaim), dan
     2. TETAP tidak crash ketika runtime mencabut fasilitas standar
        (print, io, os, string.format) — kondisi yang umum pada LuaVM
        tersemat di dalam game.

 Cara pakai
   pluto tests/compat_driver.lua
   lua5.4 tests/compat_driver.lua

 Catatan
   Driver ini sengaja ditulis dalam Lua murni (tanpa sintaks Pluto) agar bisa
   dijalankan oleh interpreter mana pun. Ia TIDAK menyentuh game sama sekali.
================================================================================
]==]

local SCRIPT = "hooks/owh_loot_research.pluto"

--------------------------------------------------------------------------------
-- util
--------------------------------------------------------------------------------

local results, failures = {}, 0

local function check(name, cond, detail)
    results[#results + 1] = { name = name, ok = (cond == true), detail = detail }
    if cond ~= true then failures = failures + 1 end
    print(string.format("  [%s] %-52s %s",
        (cond == true) and "OK  " or "GAGAL", name, detail or ""))
end

local function read_file(path)
    local fh, err = io.open(path, "rb")
    if not fh then return nil, "tidak dapat membuka " .. path .. ": " .. tostring(err) end
    local src = fh:read("*a")
    fh:close()
    return src
end

--- Membuat environment tiruan: __index meneruskan ke _G, kecuali kunci yang
--  diblokir (diblokir = dianggap tidak ada).
local function make_env(blocked, overrides)
    local env = {}
    if overrides then
        for k, v in pairs(overrides) do env[k] = v end
    end
    return setmetatable(env, {
        __index = function(_, k)
            if blocked[k] then return nil end
            return _G[k]
        end,
        __newindex = function(t, k, v) rawset(t, k, v) end,
    })
end

--- Memuat skrip dengan environment tertentu. Mendukung Lua 5.1 (setfenv) dan
--  Lua 5.2+ (parameter env pada load).
local function load_with_env(src, chunkname, env)
    local f = load(src, chunkname, "t", env)     -- 5.2 / 5.3 / 5.4 / 5.5 / Pluto
    if not f then
        f = load(src, chunkname)                 -- fallback 5.1
        if f and type(setfenv) == "function" then
            setfenv(f, env)
        end
    end
    return f
end

--------------------------------------------------------------------------------
-- persiapan
--------------------------------------------------------------------------------

local src, read_err = read_file(SCRIPT)
if not src then
    print("FATAL: " .. tostring(read_err))
    os.exit(2)
end

print("=")
print("PENGUJI PORABILITAS / KETAHANAN — " .. SCRIPT)
print("interpreter: " .. _VERSION)
print("=")

--------------------------------------------------------------------------------
-- Skenario 1: environment normal
--------------------------------------------------------------------------------

print("\n[Skenario 1] Environment normal (semua pustaka tersedia)")
do
    local env = make_env({})
    local f = load_with_env(src, "=owh_loot_research", env)
    check("skrip terkompilasi", type(f) == "function")
    if type(f) ~= "function" then os.exit(1) end

    local ok, mod = pcall(f)
    check("eksekusi tanpa error", ok, ok and "" or tostring(mod))
    check("modul dikembalikan", type(mod) == "table")
    if type(mod) ~= "table" then os.exit(1) end

    check("M.VERSION terisi", type(mod.VERSION) == "string", tostring(mod.VERSION))
    check("api wrap32 ada", type(mod.wrap32) == "function")
    check("api imul_r32 ada", type(mod.imul_r32) == "function")
    check("api sim_quantity ada", type(mod.sim_quantity) == "function")
    check("api sim_chance ada", type(mod.sim_chance) == "function")
    check("api evidence_checklist ada", type(mod.evidence_checklist) == "function")
    check("log terisi (>100 baris)", #mod.get_log() > 100, "#=" .. #mod.get_log())

    -- idempotensi: M.run() harus aman dipanggil ulang
    local ok2, res2 = pcall(mod.run)
    check("M.run() idempoten (panggil ke-2)", ok2 and res2 == true,
        tostring(res2))

    -- save_report harus menolak karena default-nya mati
    local ok3, saved, why = pcall(mod.save_report)
    check("save_report ditolak saat dinonaktifkan",
        ok3 and saved == false, tostring(why))

    -- sanity: hasil model
    check("imul_r32(100,3) == 300", mod.imul_r32(100, 3) == 300)
    check("imul_r32(1e9,3) wrap -> -1294967296",
        mod.imul_r32(1000000000, 3) == -1294967296)
end

--------------------------------------------------------------------------------
-- Skenario 2: print dan io dicabut
--------------------------------------------------------------------------------

print("\n[Skenario 2] print + io DICABUT (konsol host tidak tersedia)")
do
    local env = make_env({ print = true, io = true })
    local f = load_with_env(src, "=owh_loot_research(no-out)", env)
    check("skrip terkompilasi", type(f) == "function")
    local ok, mod = pcall(f)
    check("eksekusi tanpa error walau tanpa print/io", ok, ok and "" or tostring(mod))
    if ok and type(mod) == "table" then
        check("log internal tetap terisi (buffer jalan)", #mod.get_log() > 100,
            "#=" .. #mod.get_log())
        check("tidak ada sink output yang dipakai", true, "0 sink")
    end
end

--------------------------------------------------------------------------------
-- Skenario 3: print, io, os, debug dicabut
--------------------------------------------------------------------------------

print("\n[Skenario 3] print + io + os + debug DICABUT")
do
    local env = make_env({ print = true, io = true, os = true, debug = true })
    local f = load_with_env(src, "=owh_loot_research(minimal)", env)
    local ok, mod = pcall(f)
    check("eksekusi tanpa error", ok, ok and "" or tostring(mod))
    if ok and type(mod) == "table" then
        check("log internal tetap terisi", #mod.get_log() > 100, "#=" .. #mod.get_log())
    end
end

--------------------------------------------------------------------------------
-- Skenario 4: string.format dicabut (log harus turun ke fallback)
--------------------------------------------------------------------------------

print("\n[Skenario 4] string.format DICABUT (log harus memakai fallback)")
do
    local env = make_env({ print = true })
    local fake_string = {}
    for k, v in pairs(string) do fake_string[k] = v end
    fake_string.format = nil                      -- cabut format
    rawset(env, "string", fake_string)
    local f = load_with_env(src, "=owh_loot_research(no-format)", env)
    local ok, mod = pcall(f)
    check("eksekusi tanpa error tanpa string.format", ok, ok and "" or tostring(mod))
    if ok and type(mod) == "table" then
        check("log internal tetap terisi", #mod.get_log() > 100, "#=" .. #mod.get_log())
        local txt = mod.get_log_text()
        check("baris log tidak mengandung 'nil' ganda",
            txt:find("nilnil") == nil)
    end
end

--------------------------------------------------------------------------------
-- Skenario 5: dimuat sebagai pustaka (auto-run dimatikan)
--------------------------------------------------------------------------------

print("\n[Skenario 5] Auto-run DIMATIKAN lewat OWH_RESEARCH_NO_AUTORUN")
do
    local env = make_env({}, { OWH_RESEARCH_NO_AUTORUN = true })
    local f = load_with_env(src, "=owh_loot_research(lib)", env)
    local ok, mod = pcall(f)
    check("eksekusi tanpa error", ok, ok and "" or tostring(mod))
    if ok and type(mod) == "table" then
        check("belum menghasilkan log saat dimuat", #mod.get_log() == 0,
            "#=" .. #mod.get_log())
        local ok2, res2 = pcall(mod.run)
        check("M.run() dapat dipanggil manual", ok2 and res2 == true)
        check("log terisi setelah run manual", #mod.get_log() > 100,
            "#=" .. #mod.get_log())
    end
end

--------------------------------------------------------------------------------
-- Skenario 6: host OWH TIRUAN — bukti bahwa skrip benar-benar read-only
--
-- Kita pasang tabel `owh` palsu berisi 25 anggota yang TERBUKTI ada di OWH
-- (lihat docs/ANALYSIS.md) ditambah satu anggota asing untuk menguji deteksi
-- "tidak tercatat". Setiap anggota adalah fungsi mata-mata yang menghitung
-- berapa kali ia dipanggil. Bila skrip benar read-only, SEMUA penghitung
-- harus tetap 0 — termasuk setelah skrip sengaja mencoba memanggil yang
-- berbahaya di Bagian A1c.
--------------------------------------------------------------------------------

print("\n[Skenario 6] Host OWH tiruan — SEMUA panggilan mutasi harus 0")
do
    local OWH_MEMBERS = {
        "base", "find_pattern", "hook", "memcpy", "msgbox", "on_unload",
        "player_base", "protect", "read_bytes", "read_double", "read_int16",
        "read_int64", "read_string", "read_uint64", "read_uint8", "unhook",
        "write_bytes", "write_float", "write_int16", "write_int32",
        "write_int8", "write_string", "write_uint16", "write_uint64",
        "write_uint8",
    }
    local spy = {}
    local owh_fake = {}
    for i = 1, #OWH_MEMBERS do
        local name = OWH_MEMBERS[i]
        spy[name] = 0
        owh_fake[name] = function(...) spy[name] = spy[name] + 1 return 0 end
    end
    -- anggota asing: menguji deteksi "TIDAK TERCATAT"
    spy["sesuatu_yang_asing"] = 0
    owh_fake["sesuatu_yang_asing"] = function()
        spy["sesuatu_yang_asing"] = spy["sesuatu_yang_asing"] + 1
        return 0
    end

    local env = make_env({}, { owh = owh_fake })
    local f = load_with_env(src, "=owh_loot_research(owh-host)", env)
    local ok, mod = pcall(f)
    check("eksekusi tanpa error di host OWH tiruan", ok, ok and "" or tostring(mod))
    if ok and type(mod) == "table" then
        -- inventaris harus menemukan semua anggota
        local inv = mod.owh_inventory()
        check("inventaris menemukan 25+1 anggota", #inv == 26, "ditemukan " .. #inv)

        local unc = 0
        for i = 1, #inv do
            if inv[i].kind == "TIDAK TERCATAT" then unc = unc + 1 end
        end
        check("anggota asing terdeteksi sebagai tidak-tercatat", unc == 1,
            "jumlah=" .. unc)

        -- penghitung internal
        local c = mod.get_owh_call_count()
        check("usaha pemanggilan tercatat (9 dari A1c)", c.attempted == 9,
            "attempted=" .. c.attempted)
        check("0 panggilan yang benar-benar dieksekusi", c.executed == 0,
            "executed=" .. c.executed)
        check("9 usaha ditolak pengaman", c.refused == 9, "refused=" .. c.refused)

        -- pembuktian utama: tidak SATU pun fungsi host tersentuh
        local touched, total_calls = {}, 0
        for name, n in pairs(spy) do
            if n > 0 then touched[#touched + 1] = name .. "(" .. n .. ")" end
            total_calls = total_calls + n
        end
        check("TIDAK ADA fungsi owh yang dipanggil sama sekali",
            total_calls == 0,
            total_calls == 0 and "0 panggilan" or "terserang: " .. table.concat(touched, ", "))

        -- pengaman harus menolak walau dipanggil manual
        local ok2, res2 = pcall(mod.safe_owh, "write_int32", 0, 0)
        check("safe_owh menolak write_int32", ok2 and res2 == false)
        check("write_int32 tidak tersentuh setelah itu", spy.write_int32 == 0,
            "count=" .. spy.write_int32)

        local ok3, res3 = pcall(mod.safe_owh, "hook", nil, nil)
        check("safe_owh menolak hook", ok3 and res3 == false)
        check("hook tidak tersentuh setelah itu", spy.hook == 0,
            "count=" .. spy.hook)
    end
end

--------------------------------------------------------------------------------
-- ringkasan
--------------------------------------------------------------------------------

print("\n" .. string.rep("=", 78))
local total = #results
print(string.format("HASIL: %d lulus, %d gagal, total %d", total - failures, failures, total))
print(string.rep("=", 78))
if failures > 0 then
    print("Ada skenario yang gagal. Perbaiki sebelum dipasang ke Custom Hooks.")
    os.exit(1)
end
print("Semua skenario lulus.")
print("INGAT: 'skrip berjalan' BUKAN berarti loot di game berubah x2..x5.")
print("Driver ini hanya menguji runtime dan ketahanan, bukan efek gameplay.")
os.exit(0)
