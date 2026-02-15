local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- [[ KONFIGURASI ]]
local TARGET_KEY = "Z" -- Ganti dengan tombol skill yang mau dicek

-- Fungsi Cari Tombol (Sesuaikan jika perlu)
local function GetButton()
    local PGui = LocalPlayer:WaitForChild("PlayerGui")
    local Skills = PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    if Skills then
        for _, f in pairs(Skills:GetChildren()) do
            if f:IsA("Frame") and f.Visible and f:FindFirstChild(TARGET_KEY) then
                return f[TARGET_KEY]:FindFirstChild("Mobile") or f[TARGET_KEY]
            end
        end
    end
    return nil
end

-- Fungsi Mengambil Semua Data Properti UI secara Rekursif
local function SnapshotUI(instance)
    local data = {}
    
    -- 1. Ambil Properti Utama
    data.Name = instance.Name
    data.Class = instance.ClassName
    pcall(function() data.Visible = instance.Visible end)
    pcall(function() data.Size = instance.Size end)
    pcall(function() data.Position = instance.Position end)
    pcall(function() data.Trans = instance.BackgroundTransparency end)
    pcall(function() data.Color = instance.BackgroundColor3 end)
    pcall(function() data.ZIndex = instance.ZIndex end)
    pcall(function() data.Text = instance.Text end) -- Jika TextLabel/Button
    pcall(function() data.Image = instance.Image end) -- Jika ImageLabel/Button
    
    -- 2. Ambil Data Anak-anaknya (Children)
    data.Children = {}
    for _, child in pairs(instance:GetChildren()) do
        if child:IsA("GuiObject") then
            data.Children[child.Name] = SnapshotUI(child)
        end
    end
    
    return data
end

-- Fungsi Membandingkan 2 Snapshot
local function CompareSnapshots(stateA, stateB, path)
    path = path or "Button"
    
    -- Bandingkan Properti Langsung
    for prop, valA in pairs(stateA) do
        if prop ~= "Children" then
            local valB = stateB[prop]
            if valB ~= nil and tostring(valA) ~= tostring(valB) then
                warn("PERUBAHAN DITEMUKAN PADA: " .. path)
                print("   > Properti: " .. prop)
                print("   > Awal    : " .. tostring(valA))
                print("   > Akhir   : " .. tostring(valB))
            end
        end
    end
    
    -- Bandingkan Anak-anak (Children)
    -- Cek Anak Baru atau Anak Hilang
    for name, childDataB in pairs(stateB.Children) do
        if not stateA.Children[name] then
            warn("OBJEK BARU MUNCUL (New Child): " .. path .. "." .. name)
        else
            -- Jika anak sudah ada, bandingkan propertinya
            CompareSnapshots(stateA.Children[name], childDataB, path .. "." .. name)
        end
    end
    
    for name, _ in pairs(stateA.Children) do
        if not stateB.Children[name] then
            warn("OBJEK HILANG (Destroyed/Removed): " .. path .. "." .. name)
        end
    end
end

-- [[ EKSEKUSI UTAMA ]]
local btn = GetButton()

if not btn then
    warn("❌ Tombol tidak ditemukan! Pastikan UI sudah load.")
else
    print("========================================")
    print("📸 MENGAMBIL SNAPSHOT 1 (READY STATE)...")
    local StateReady = SnapshotUI(btn)
    print("✅ Snapshot 1 Selesai.")
    
    print("----------------------------------------")
    print("⏳ ANDA PUNYA 3 DETIK UNTUK MENEKAN SKILL " .. TARGET_KEY .. " !!!")
    print("   TEKAN SKILL SEKARANG AGAR MASUK COOLDOWN!")
    print("----------------------------------------")
    
    task.wait(3) -- Waktu untuk Anda menekan skill
    
    print("📸 MENGAMBIL SNAPSHOT 2 (COOLDOWN STATE)...")
    local StateCooldown = SnapshotUI(btn)
    
    print("========================================")
    print("🔍 HASIL ANALISIS PERUBAHAN:")
    print("========================================")
    
    CompareSnapshots(StateReady, StateCooldown)
    
    print("========================================")
    print("✅ Analisis Selesai. Cek Console (F9)!")
end
