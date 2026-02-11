-- ==============================================================================
-- [ VELOX LITE V5 - CROSSHAIR SYNC ]
-- Fix: Menggunakan "IgnoreGuiInset" agar koordinat UI & Sentuhan 100% Akurat.
-- Fitur: M1 mengetuk tepat di tengah Crosshair yang bisa digeser.
-- ==============================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

-- UI CONFIG
local Theme = {
    Bg = Color3.fromRGB(20, 20, 25),
    Accent = Color3.fromRGB(0, 255, 180),
    Text = Color3.fromRGB(240, 240, 240),
    Red = Color3.fromRGB(255, 80, 80),
    Aim = Color3.fromRGB(255, 255, 0) -- Warna Kuning untuk Crosshair
}

local WeaponData = {
    [1] = {tooltip = "Melee"}, [2] = {tooltip = "Blox Fruit"},
    [3] = {tooltip = "Sword"}, [4] = {tooltip = "Gun"}
}

-- SETUP GUI (CRITICAL FIX)
if CoreGui:FindFirstChild("VeloxLite") then CoreGui.VeloxLite:Destroy() end
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "VeloxLite"; ScreenGui.Parent = CoreGui

-- [PENTING] Ini membuat (0,0) UI = Pojok Kiri Atas Layar Fisik (Tanpa terpotong TopBar)
ScreenGui.IgnoreGuiInset = true 

-- VARIABLE AIM
local AimRef = nil

-- ==============================================================================
-- [1] LOGIC UTAMA
-- ==============================================================================

-- M1 (CLICK AT CROSSHAIR CENTER)
local function TapM1()
    if AimRef then
        -- 1. Ambil Posisi Pojok Kiri Atas Tombol Crosshair
        local pos = AimRef.AbsolutePosition
        
        -- 2. Ambil Ukuran Tombol
        local size = AimRef.AbsoluteSize
        
        -- 3. Hitung Titik Tengah (Posisi + Setengah Ukuran)
        local x = pos.X + (size.X / 2)
        local y = pos.Y + (size.Y / 2)
        
        -- 4. Kirim Sentuhan "Hantu" (Touch ID 5)
        VirtualInputManager:SendTouchEvent(5, 0, x, y) -- Tekan
        task.wait() -- Tunggu 1 frame
        VirtualInputManager:SendTouchEvent(5, 2, x, y) -- Lepas
    end
end

-- 1-4 TOGGLE
local function ToggleEquip(slot)
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChild("Humanoid"); if not hum then return end
    local target = WeaponData[slot].tooltip
    local current = char:FindFirstChildOfClass("Tool")
    
    if current and current.ToolTip == target then
        hum:UnequipTools()
    else
        for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do
            if t:IsA("Tool") and t.ToolTip == target then hum:EquipTool(t); break end
        end
    end
end

-- UTILS UI
local function FireUI(btn)
    if not btn then return end
    for _, c in pairs(getconnections(btn.Activated)) do c:Fire() end
    for _, c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
    for _, c in pairs(getconnections(btn.InputBegan)) do 
        c:Fire({UserInputType=Enum.UserInputType.MouseButton1, UserInputState=Enum.UserInputState.Begin})
    end
end

local function TriggerSkill(key)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local Skills = PGui and PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    if Skills then
        for _, f in pairs(Skills:GetChildren()) do
            if f:IsA("Frame") and f.Visible and f:FindFirstChild(key) then
                FireUI(f[key]:FindFirstChild("Mobile") or f[key])
                return
            end
        end
    end
end

local function TriggerDodge()
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local Ctx = PGui and PGui:FindFirstChild("MobileContextButtons") and PGui.MobileContextButtons:FindFirstChild("ContextButtonFrame")
    if Ctx then
        for _, f in pairs(Ctx:GetChildren()) do
            if f.Name:find("BoundAction") and f.Name:find("Dodge") then
                FireUI(f:FindFirstChild("Button"))
                return
            end
        end
    end
end

-- ==============================================================================
-- [2] UI BUILDER
-- ==============================================================================

local function MakeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = guiObject.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    guiObject.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function CreateBtn(text, func, size, color, pos, isCrosshair)
    local btn = Instance.new("TextButton")
    btn.Size = size
    btn.Position = pos
    
    if isCrosshair then
        -- Desain Crosshair (Target)
        btn.BackgroundColor3 = Theme.Aim
        btn.BackgroundTransparency = 0.6
        btn.Text = "⌖"
        btn.TextColor3 = Color3.new(0,0,0)
        btn.TextSize = 24
        
        -- Garis bidik visual
        local h = Instance.new("Frame"); h.Size=UDim2.new(1,0,0,1); h.Position=UDim2.new(0,0,0.5,0); h.BackgroundColor3=Color3.new(0,0,0); h.Parent=btn
        local v = Instance.new("Frame"); v.Size=UDim2.new(0,1,1,0); v.Position=UDim2.new(0.5,0,0,0); v.BackgroundColor3=Color3.new(0,0,0); v.Parent=btn
        
        AimRef = btn -- Simpan referensi tombol ini
    else
        btn.BackgroundColor3 = color
        btn.BackgroundTransparency = 0.2
        btn.Text = text
        btn.TextColor3 = Theme.Text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = btn
        local stroke = Instance.new("UIStroke"); stroke.Color = Theme.Accent; stroke.Thickness = 1.5; stroke.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            btn.BackgroundColor3 = Theme.Accent; btn.TextColor3 = Color3.new(0,0,0); func()
            task.delay(0.1, function() btn.BackgroundColor3 = color; btn.TextColor3 = Theme.Text end)
        end)
    end
    
    if isCrosshair then
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1,0); corner.Parent = btn
        local stroke = Instance.new("UIStroke"); stroke.Color = Theme.Aim; stroke.Thickness = 2; stroke.Parent = btn
    end

    btn.Parent = ScreenGui
    MakeDraggable(btn)
    return btn
end

-- ==============================================================================
-- [3] LAYOUT SETUP
-- ==============================================================================

-- CROSSHAIR (Patokan Aim)
CreateBtn("⌖", nil, UDim2.new(0,40,0,40), Theme.Aim, UDim2.new(0.5, -20, 0.4, -20), true)

-- Weapons
CreateBtn("1", function() ToggleEquip(1) end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.65,0,0.45,0))
CreateBtn("2", function() ToggleEquip(2) end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.73,0,0.45,0))
CreateBtn("3", function() ToggleEquip(3) end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.81,0,0.45,0))
CreateBtn("4", function() ToggleEquip(4) end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.89,0,0.45,0))

-- Skills
CreateBtn("Z", function() TriggerSkill("Z") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.65,0,0.55,0))
CreateBtn("X", function() TriggerSkill("X") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.73,0,0.55,0))
CreateBtn("C", function() TriggerSkill("C") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.81,0,0.55,0))
CreateBtn("V", function() TriggerSkill("V") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.69,0,0.65,0))
CreateBtn("F", function() TriggerSkill("F") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.77,0,0.65,0))

-- Actions
CreateBtn("M1", TapM1, UDim2.new(0,60,0,60), Theme.Red, UDim2.new(0.9,0,0.25,0))
CreateBtn("Dodge", TriggerDodge, UDim2.new(0,50,0,50), Theme.Bg, UDim2.new(0.89,0,0.55,0))

print("Velox Lite V5: Crosshair Synced")
