-- ==============================================================================
-- [ VELOX LITE V4 - DYNAMIC COMBO BUILDER ]
-- Features: In-Game Editor, Auto M1 on Skills, Add/Delete Steps.
-- ==============================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- CONFIG & THEME
local Theme = {
    Bg = Color3.fromRGB(20, 20, 25),
    Main = Color3.fromRGB(35, 35, 40),
    Accent = Color3.fromRGB(0, 255, 170),
    Text = Color3.fromRGB(240, 240, 240),
    Red = Color3.fromRGB(255, 80, 80),
    Yellow = Color3.fromRGB(255, 200, 0)
}

local WeaponData = {
    ["1"] = "Melee", ["2"] = "Blox Fruit", ["3"] = "Sword", ["4"] = "Gun"
}

-- DATA COMBO (DYNAMIC)
local MyCombo = {}

-- CLEANUP & UI BASE
if CoreGui:FindFirstChild("VeloxBuilder") then CoreGui.VeloxBuilder:Destroy() end
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "VeloxBuilder"; ScreenGui.Parent = CoreGui

-- ==============================================================================
-- [ FUNGSI LOGIC ]
-- ==============================================================================

local function TapM1()
    local vp = Camera.ViewportSize
    VirtualInputManager:SendTouchEvent(5, 0, vp.X/2, vp.Y/2)
    task.wait(0.01)
    VirtualInputManager:SendTouchEvent(5, 2, vp.X/2, vp.Y/2)
end

local function ForceEquip(slotStr)
    local target = WeaponData[slotStr]
    local char = LocalPlayer.Character
    if char and target then
        local hum = char:FindFirstChild("Humanoid")
        for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do
            if t:IsA("Tool") and t.ToolTip == target then 
                hum:EquipTool(t)
                break 
            end
        end
    end
end

local function TriggerSkill(key)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local Skills = PGui and PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    if Skills then
        for _, f in pairs(Skills:GetChildren()) do
            if f:IsA("Frame") and f.Visible and f:FindFirstChild(key) then
                local btn = f[key]:FindFirstChild("Mobile") or f[key]
                for _, c in pairs(getconnections(btn.Activated)) do c:Fire() end
                task.wait(0.05)
                TapM1() -- TRIGGER M1 OTOMATIS SETELAH SKILL
                return
            end
        end
    end
end

-- ==============================================================================
-- [ UI COMPONENTS ]
-- ==============================================================================

-- Panel Utama
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 350)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -175)
MainFrame.BackgroundColor3 = Theme.Bg
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
MainFrame.Parent = ScreenGui

local Corner = Instance.new("UICorner"); Corner.Parent = MainFrame
local Stroke = Instance.new("UIStroke"); Stroke.Color = Theme.Accent; Stroke.Thickness = 2; Stroke.Parent = MainFrame

-- Judul
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Text = "COMBO BUILDER V4"
Title.TextColor3 = Theme.Accent
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = MainFrame

-- List Tampilan Combo
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(0.9, 0, 0, 150)
Scroll.Position = UDim2.new(0.05, 0, 0, 50)
Scroll.BackgroundColor3 = Theme.Main
Scroll.BorderSizePixel = 0
Scroll.CanvasSize = UDim2.new(0, 0, 2, 0)
Scroll.Parent = MainFrame
local ListLayout = Instance.new("UIListLayout"); ListLayout.Parent = Scroll; ListLayout.Padding = UDim.new(0, 5)

-- Fungsi Update List UI
local function RefreshComboList()
    for _, child in pairs(Scroll:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
    for i, step in ipairs(MyCombo) do
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -10, 0, 25)
        label.BackgroundColor3 = Color3.new(1,1,1)
        label.BackgroundTransparency = 0.9
        label.Text = i..". ["..step.type.."] : "..step.val
        label.TextColor3 = Theme.Text
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.Parent = Scroll
    end
end

-- ==============================================================================
-- [ TOMBOL INPUT ]
-- ==============================================================================

local function AddStep(t, v)
    table.insert(MyCombo, {type = t, val = v})
    RefreshComboList()
end

-- Container Tombol Tambah
local BtnGrid = Instance.new("Frame")
BtnGrid.Size = UDim2.new(0.9, 0, 0, 80)
BtnGrid.Position = UDim2.new(0.05, 0, 0, 210)
BtnGrid.BackgroundTransparency = 1
BtnGrid.Parent = MainFrame

local function CreateAddBtn(text, t, v, color, pos)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 40, 0, 35)
    b.Position = pos
    b.Text = text
    b.BackgroundColor3 = color
    b.Font = Enum.Font.GothamBold
    b.TextColor3 = Color3.new(1,1,1)
    b.Parent = BtnGrid
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,5); c.Parent = b
    b.MouseButton1Click:Connect(function() AddStep(t, v) end)
end

-- Row 1: Weapon (1-4)
for i=1, 4 do CreateAddBtn(tostring(i), "Equip", tostring(i), Theme.Accent, UDim2.new(0, (i-1)*45, 0, 0)) end
-- Row 2: Skills (Z-F)
local skills = {"Z", "X", "C", "V", "F"}
for i, s in ipairs(skills) do CreateAddBtn(s, "Skill", s, Theme.Yellow, UDim2.new(0, (i-1)*45, 0, 40)) end

-- Action Buttons (Execute & Clear)
local RunBtn = Instance.new("TextButton")
RunBtn.Size = UDim2.new(0, 130, 0, 40)
RunBtn.Position = UDim2.new(0.05, 0, 0, 300)
RunBtn.Text = "EXECUTE"
RunBtn.BackgroundColor3 = Theme.Accent
RunBtn.Font = Enum.Font.GothamBold
RunBtn.Parent = MainFrame

local ClearBtn = Instance.new("TextButton")
ClearBtn.Size = UDim2.new(0, 130, 0, 40)
ClearBtn.Position = UDim2.new(0.52, 0, 0, 300)
ClearBtn.Text = "CLEAR / DELETE"
ClearBtn.BackgroundColor3 = Theme.Red
ClearBtn.Font = Enum.Font.GothamBold
ClearBtn.Parent = MainFrame

-- Logic Eksekusi Combo
RunBtn.MouseButton1Click:Connect(function()
    for _, step in ipairs(MyCombo) do
        if step.type == "Equip" then
            ForceEquip(step.val)
            task.wait(0.3)
        elseif step.type == "Skill" then
            TriggerSkill(step.val)
            task.wait(0.7) -- Delay antar skill
        end
    end
end)

ClearBtn.MouseButton1Click:Connect(function()
    MyCombo = {}
    RefreshComboList()
end)

-- Tombol Buka/Tutup UI
local Toggle = Instance.new("TextButton")
Toggle.Size = UDim2.new(0, 100, 0, 40)
Toggle.Position = UDim2.new(0, 10, 0.5, 0)
Toggle.Text = "EDIT COMBO"
Toggle.BackgroundColor3 = Theme.Bg
Toggle.TextColor3 = Theme.Accent
Toggle.Parent = ScreenGui
local TC = Instance.new("UICorner"); TC.Parent = Toggle
Toggle.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)

-- Fitur Draggable untuk MainFrame
local d = false; local start; local pos
MainFrame.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then d = true; start = i.Position; pos = MainFrame.Position end end)
UserInputService.InputChanged:Connect(function(i) if d and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then 
    local delta = i.Position - start
    MainFrame.Position = UDim2.new(pos.X.Scale, pos.X.Offset + delta.X, pos.Y.Scale, pos.Y.Offset + delta.Y)
end end)
MainFrame.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end end)

print("Velox Builder V4 Loaded. Press 'EDIT COMBO' to start.")
