--[[
    VELOX MACRO CONTROLLER (AUTO SLOT & SKILL)
    Fitur:
    - Slot 1-4: Auto Detect & Equip (Melee/Fruit/Sword/Gun)
    - Skill Z-F: Auto Fire skill senjata yang sedang aktif.
    - Anti-Freeze: Menggunakan Signal Fire, bukan sentuh layar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- 1. BERSIHKAN UI LAMA
if CoreGui:FindFirstChild("VeloxMacro") then
    CoreGui.VeloxMacro:Destroy()
end

-- 2. GUI SETUP
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VeloxMacro"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

-- FRAME UTAMA (Kecil & Rapi)
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 150)
MainFrame.Position = UDim2.new(0.5, -150, 0.25, 0) -- Posisi agak ke atas
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- Hiasan UI
local UC = Instance.new("UICorner"); UC.CornerRadius=UDim.new(0,10); UC.Parent=MainFrame
local US = Instance.new("UIStroke"); US.Color=Color3.fromRGB(255, 180, 0); US.Thickness=2; US.Parent=MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Text = "VELOX MACRO"
Title.TextColor3 = Color3.fromRGB(255, 180, 0)
Title.Font = Enum.Font.GothamBlack
Title.BackgroundTransparency = 1
Title.Parent = MainFrame

-- WADAH TOMBOL SLOT (1-4)
local SlotContainer = Instance.new("Frame")
SlotContainer.Size = UDim2.new(0.9, 0, 0.35, 0)
SlotContainer.Position = UDim2.new(0.05, 0, 0.2, 0)
SlotContainer.BackgroundTransparency = 1
SlotContainer.Parent = MainFrame
local GridSlot = Instance.new("UIGridLayout")
GridSlot.CellSize = UDim2.new(0.22, 0, 1, 0); GridSlot.Parent=SlotContainer

-- WADAH TOMBOL SKILL (Z-F)
local SkillContainer = Instance.new("Frame")
SkillContainer.Size = UDim2.new(0.9, 0, 0.35, 0)
SkillContainer.Position = UDim2.new(0.05, 0, 0.6, 0)
SkillContainer.BackgroundTransparency = 1
SkillContainer.Parent = MainFrame
local GridSkill = Instance.new("UIGridLayout")
GridSkill.CellSize = UDim2.new(0.18, 0, 1, 0); GridSkill.Parent=SkillContainer

-- ==============================================================================
-- [LOGIKA INTI]
-- ==============================================================================

-- 1. FUNGSI EQUIP OTOMATIS BERDASARKAN TIPE
local function EquipByType(targetType)
    local foundName = nil
    
    -- Cek Senjata yang sedang dipegang (Character)
    for _, t in pairs(LP.Character:GetChildren()) do
        if t:IsA("Tool") and t.ToolTip == targetType then foundName = t.Name break end
    end
    
    -- Cek Tas (Backpack) jika belum ketemu
    if not foundName then
        for _, t in pairs(LP.Backpack:GetChildren()) do
            if t:IsA("Tool") and t.ToolTip == targetType then foundName = t.Name break end
        end
    end
    
    -- Eksekusi Equip
    if foundName then
        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadItem", foundName)
        return true -- Berhasil
    else
        return false -- Gagal (Tidak punya item)
    end
end

-- 2. FUNGSI FIRE TOMBOL (SIGNAL)
local function FireSignal(btn)
    if not btn or not btn.Visible then return end
    
    -- Coba nyalakan semua sinyal tombol (Brute Force aman)
    local cons = getconnections(btn.Activated)
    if #cons == 0 then cons = getconnections(btn.MouseButton1Click) end
    if #cons == 0 then cons = getconnections(btn.InputBegan) end
    
    for _, c in pairs(cons) do c:Fire() end
end

-- 3. FUNGSI SKILL PINTAR
local function SmartSkill(key)
    local Main = PlayerGui:FindFirstChild("Main")
    local Skills = Main and Main:FindFirstChild("Skills")
    
    if Skills then
        for _, w in pairs(Skills:GetChildren()) do
            -- Cari folder senjata yang sedang VISIBLE (Aktif)
            -- Logikanya: Kalau kamu tekan tombol 1, folder Melee jadi visible.
            if w:IsA("Frame") and w.Visible then
                local btn = w:FindFirstChild(key) and w[key]:FindFirstChild("Mobile")
                if btn then
                    FireSignal(btn)
                    return
                end
            end
        end
    end
end

-- ==============================================================================
-- [PEMBUATAN TOMBOL]
-- ==============================================================================

local function CreateBtn(text, color, parent, callback)
    local b = Instance.new("TextButton")
    b.Text = text
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    b.TextColor3 = color
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    
    b.MouseButton1Click:Connect(function()
        local success = callback()
        
        -- Efek Visual Klik
        local oldColor = b.BackgroundColor3
        if success == false then
            b.BackgroundColor3 = Color3.fromRGB(150, 50, 50) -- Merah (Gagal)
        else
            b.BackgroundColor3 = color -- Warna Tombol (Sukses)
            b.TextColor3 = Color3.fromRGB(20, 20, 20)
        end
        
        task.delay(0.1, function()
            b.BackgroundColor3 = oldColor
            b.TextColor3 = color
        end)
    end)
end

-- TOMBOL SLOT 1-4
-- Warna: Kuning Emas
CreateBtn("1", Color3.fromRGB(255, 200, 0), SlotContainer, function() return EquipByType("Melee") end)
CreateBtn("2", Color3.fromRGB(255, 200, 0), SlotContainer, function() return EquipByType("Blox Fruit") end)
CreateBtn("3", Color3.fromRGB(255, 200, 0), SlotContainer, function() return EquipByType("Sword") end)
CreateBtn("4", Color3.fromRGB(255, 200, 0), SlotContainer, function() return EquipByType("Gun") end)

-- TOMBOL SKILL Z-F
-- Warna: Biru Cyan
CreateBtn("Z", Color3.fromRGB(0, 200, 255), SkillContainer, function() SmartSkill("Z") end)
CreateBtn("X", Color3.fromRGB(0, 200, 255), SkillContainer, function() SmartSkill("X") end)
CreateBtn("C", Color3.fromRGB(0, 200, 255), SkillContainer, function() SmartSkill("C") end)
CreateBtn("V", Color3.fromRGB(0, 200, 255), SkillContainer, function() SmartSkill("V") end)
CreateBtn("F", Color3.fromRGB(0, 200, 255), SkillContainer, function() SmartSkill("F") end)

-- CLOSE BUTTON
local Close = Instance.new("TextButton")
Close.Text = "X"; Close.Size = UDim2.new(0, 25, 0, 25); Close.Position = UDim2.new(1, -30, 0, 0)
Close.BackgroundTransparency = 1; Close.TextColor3 = Color3.fromRGB(255, 50, 50)
Close.Font = Enum.Font.GothamBlack; Close.Parent = MainFrame
Close.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
