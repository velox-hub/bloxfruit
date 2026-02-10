--[[
    VELOX NATIVE HOTBAR (REAL UI CLICK)
    Fitur:
    - Tidak memaksa equip (No Force Equip).
    - Melakukan "Tap Virtual" pada Hotbar Game Asli.
    - Dijamin Skill Muncul 100% (Karena game mengira kamu yang klik).
]]

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

if CoreGui:FindFirstChild("VeloxNative") then
    CoreGui.VeloxNative:Destroy()
end

-- GUI SETUP
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VeloxNative"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 160)
MainFrame.Position = UDim2.new(0.5, -150, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(0, 255, 0) -- Hijau (Correct Way)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Text = "VELOX: REAL HOTBAR TAP"
Title.TextColor3 = Color3.fromRGB(0, 255, 0)
Title.Font = Enum.Font.GothamBlack
Title.BackgroundTransparency = 1
Title.Parent = MainFrame

-- WADAH TOMBOL
local SlotC = Instance.new("Frame"); SlotC.Size=UDim2.new(0.9,0,0.35,0); SlotC.Position=UDim2.new(0.05,0,0.2,0); SlotC.BackgroundTransparency=1; SlotC.Parent=MainFrame
local SkillC = Instance.new("Frame"); SkillC.Size=UDim2.new(0.9,0,0.35,0); SkillC.Position=UDim2.new(0.05,0,0.6,0); SkillC.BackgroundTransparency=1; SkillC.Parent=MainFrame
local G1 = Instance.new("UIGridLayout"); G1.CellSize=UDim2.new(0.22,0,1,0); G1.Parent=SlotC
local G2 = Instance.new("UIGridLayout"); G2.CellSize=UDim2.new(0.18,0,1,0); G2.Parent=SkillC

-- ==============================================================================
-- [LOGIKA INTI: CLICK THE REAL GAME UI]
-- ==============================================================================

local function TapRealHotbar(slotIndex)
    -- Path ke Hotbar Blox Fruits (Biasanya di sini)
    -- Kita cari Container Hotbar
    local Main = PlayerGui:FindFirstChild("Main")
    local InCombat = Main and Main:FindFirstChild("InCombat")
    local Container = InCombat and InCombat:FindFirstChild("Container")
    local Hotbar = Container and Container:FindFirstChild("Hotbar")
    
    if Hotbar then
        -- Ambil semua slot yang ada di Hotbar
        local slots = {}
        for _, child in pairs(Hotbar:GetChildren()) do
            if child:IsA("Frame") or child:IsA("ImageButton") then
                table.insert(slots, child)
            end
        end
        
        -- Urutkan slot dari Kiri ke Kanan (Berdasarkan posisi X)
        -- Ini penting karena urutan di folder acak, tapi di layar berurutan.
        table.sort(slots, function(a, b)
            return a.AbsolutePosition.X < b.AbsolutePosition.X
        end)
        
        -- Ambil Slot sesuai Index (1, 2, 3, 4)
        local targetSlot = slots[slotIndex]
        
        if targetSlot and targetSlot.Visible then
            -- KETUK UI ASLI GAME MENGGUNAKAN VIRTUAL TOUCH
            local pos = targetSlot.AbsolutePosition
            local size = targetSlot.AbsoluteSize
            local centerX = pos.X + (size.X / 2)
            local centerY = pos.Y + (size.Y / 2)
            
            -- Kirim Sentuhan (Jari ke-10, biar gak ganggu analog)
            VirtualInputManager:SendTouchEvent(10, 0, centerX, centerY) -- Tekan
            task.wait(0.05)
            VirtualInputManager:SendTouchEvent(10, 1, centerX, centerY) -- Lepas
            
            return true
        end
    end
    return false
end

-- LOGIKA SKILL (UI BUTTON FIRE)
local function FireSkill(key)
    local Main = PlayerGui:FindFirstChild("Main")
    local Skills = Main and Main:FindFirstChild("Skills")
    if Skills then
        for _, w in pairs(Skills:GetChildren()) do
            if w:IsA("Frame") and w.Visible then
                local b = w:FindFirstChild(key) and w[key]:FindFirstChild("Mobile")
                if b then
                    local cons = getconnections(b.Activated)
                    if #cons == 0 then cons = getconnections(b.MouseButton1Click) end
                    for _, c in pairs(cons) do c:Fire() end
                    return
                end
            end
        end
    end
end

-- ==============================================================================
-- [UI BUILDER]
-- ==============================================================================

local function MakeBtn(text, color, parent, cb)
    local b = Instance.new("TextButton")
    b.Text = text
    b.BackgroundColor3 = Color3.fromRGB(30,30,35)
    b.TextColor3 = color
    b.Font = Enum.Font.GothamBold
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    
    b.MouseButton1Down:Connect(function()
        cb()
        -- Visual Flash
        task.spawn(function()
            b.BackgroundColor3 = color; b.TextColor3 = Color3.fromRGB(10,10,10)
            task.wait(0.05)
            b.BackgroundColor3 = Color3.fromRGB(30,30,35); b.TextColor3 = color
        end)
    end)
end

-- SLOT BUTTONS (Klik Hotbar Asli)
MakeBtn("1", Color3.fromRGB(255, 220, 0), SlotC, function() TapRealHotbar(1) end)
MakeBtn("2", Color3.fromRGB(255, 220, 0), SlotC, function() TapRealHotbar(2) end)
MakeBtn("3", Color3.fromRGB(255, 220, 0), SlotC, function() TapRealHotbar(3) end)
MakeBtn("4", Color3.fromRGB(255, 220, 0), SlotC, function() TapRealHotbar(4) end)

-- SKILL BUTTONS
local keys = {"Z", "X", "C", "V", "F"}
for _, k in ipairs(keys) do
    MakeBtn(k, Color3.fromRGB(0, 255, 255), SkillC, function() FireSkill(k) end)
end

-- CLOSE
local Close = Instance.new("TextButton")
Close.Text = "X"; Close.Size = UDim2.new(0, 25, 0, 25); Close.Position = UDim2.new(1, -30, 0, 0)
Close.BackgroundTransparency = 1; Close.TextColor3 = Color3.fromRGB(255, 50, 50)
Close.Parent = MainFrame
Close.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
