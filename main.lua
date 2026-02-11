-- ==============================================================================
-- [ VELOX LITE V4 - COMBO EDITION ]
-- Custom Combo: Bisa atur urutan Senjata & Skill sendiri
-- ==============================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- CONFIG UTAMA
local Theme = {
    Bg = Color3.fromRGB(25, 25, 30),
    Accent = Color3.fromRGB(0, 255, 170),
    Text = Color3.fromRGB(240, 240, 240),
    Red = Color3.fromRGB(255, 80, 80),
    Combo = Color3.fromRGB(255, 150, 0) -- Warna Tombol Combo
}

local WeaponData = {
    [1] = {tooltip = "Melee"}, [2] = {tooltip = "Blox Fruit"},
    [3] = {tooltip = "Sword"}, [4] = {tooltip = "Gun"}
}

-- ==============================================================================
-- [ PENGATURAN COMBO - EDIT DI SINI ]
-- ==============================================================================
-- Penjelasan:
-- type "E" = Equip (1: Melee, 2: Fruit, 3: Sword, 4: Gun)
-- type "S" = Skill (Z, X, C, V, F)
-- delay    = Waktu tunggu sebelum ke skill berikutnya (detik)

local ComboSettings = {
    {type = "E", val = 2, delay = 0.1}, -- Ambil Fruit (Slot 2)
    {type = "S", val = "Z", delay = 0.8}, -- Skill Z Fruit, tunggu 0.8 detik
    {type = "S", val = "X", delay = 0.5}, -- Skill X Fruit, tunggu 0.5 detik
    {type = "E", val = 3, delay = 0.1}, -- Ganti ke Sword (Slot 3)
    {type = "S", val = "Z", delay = 0.6}, -- Skill Z Sword
    {type = "S", val = "X", delay = 0.2}, -- Skill X Sword
}

-- ==============================================================================
-- [ LOGIC DASAR ]
-- ==============================================================================

if CoreGui:FindFirstChild("VeloxLite") then CoreGui.VeloxLite:Destroy() end
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "VeloxLite"; ScreenGui.Parent = CoreGui

local function TapM1()
    local vp = Camera.ViewportSize
    local x, y = vp.X / 2, vp.Y / 2
    VirtualInputManager:SendTouchEvent(5, 0, x, y)
    task.wait(0.01)
    VirtualInputManager:SendTouchEvent(5, 2, x, y)
end

-- ForceEquip: Memastikan senjata terpakai (tidak toggle lepas)
local function ForceEquip(slot)
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChild("Humanoid"); if not hum then return end
    local target = WeaponData[slot].tooltip
    
    local current = char:FindFirstChildOfClass("Tool")
    if current and current.ToolTip == target then return end -- Sudah dipakai
    
    for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do
        if t:IsA("Tool") and t.ToolTip == target then 
            hum:EquipTool(t)
            break 
        end
    end
end

-- Toggle Biasa (untuk tombol 1-4)
local function ToggleEquip(slot)
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChild("Humanoid"); if not hum then return end
    local target = WeaponData[slot].tooltip
    local current = char:FindFirstChildOfClass("Tool")
    if current and current.ToolTip == target then hum:UnequipTools() else ForceEquip(slot) end
end

local function FireUI(btn)
    if not btn then return end
    for _, c in pairs(getconnections(btn.Activated)) do c:Fire() end
    for _, c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
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
-- [ COMBO EXECUTION ]
-- ==============================================================================

local function ExecuteCombo()
    for _, step in ipairs(ComboSettings) do
        if step.type == "E" then
            ForceEquip(step.val)
        elseif step.type == "S" then
            TriggerSkill(step.val)
        end
        task.wait(step.delay or 0.1)
    end
end

-- ==============================================================================
-- [ UI BUILDER ]
-- ==============================================================================

local function MakeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = guiObject.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    guiObject.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local function CreateBtn(text, func, size, color, pos)
    local btn = Instance.new("TextButton")
    btn.Size = size; btn.Position = pos; btn.BackgroundColor3 = color; btn.BackgroundTransparency = 0.2
    btn.Text = text; btn.TextColor3 = Theme.Text; btn.Font = Enum.Font.GothamBold; btn.TextSize = 14; btn.Parent = ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = btn
    local stroke = Instance.new("UIStroke"); stroke.Color = Theme.Accent; stroke.Thickness = 1.5; stroke.Parent = btn
    btn.MouseButton1Click:Connect(func)
    MakeDraggable(btn)
    return btn
end

-- ==============================================================================
-- [ LAYOUT TOMBOL ]
-- ==============================================================================

-- Senjata
CreateBtn("1", function() ToggleEquip(1) end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.65,0,0.45,0))
CreateBtn("2", function() ToggleEquip(2) end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.73,0,0.45,0))
CreateBtn("3", function() ToggleEquip(3) end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.81,0,0.45,0))
CreateBtn("4", function() ToggleEquip(4) end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.89,0,0.45,0))

-- Skill
CreateBtn("Z", function() TriggerSkill("Z") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.65,0,0.55,0))
CreateBtn("X", function() TriggerSkill("X") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.73,0,0.55,0))
CreateBtn("C", function() TriggerSkill("C") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.81,0,0.55,0))
CreateBtn("V", function() TriggerSkill("V") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.69,0,0.65,0))
CreateBtn("F", function() TriggerSkill("F") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.77,0,0.65,0))

-- Special (M1 & Dodge)
CreateBtn("M1", TapM1, UDim2.new(0,60,0,60), Theme.Red, UDim2.new(0.9,0,0.25,0))
CreateBtn("Dodge", TriggerDodge, UDim2.new(0,50,0,50), Theme.Bg, UDim2.new(0.89,0,0.55,0))

-- TOMBOL COMBO UTAMA
CreateBtn("START COMBO", ExecuteCombo, UDim2.new(0,120,0,45), Theme.Combo, UDim2.new(0.4,0,0.8,0))

print("Velox Lite V4: Combo Master Loaded")
