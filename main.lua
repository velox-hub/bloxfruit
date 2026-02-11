-- ==============================================================================
-- [ VELOX V135 X LITE V4 - HYBRID FULL COMPLETE ]
-- Features: Direct UI Trigger, Manual Equip, M1/Dodge, Save/Load, Combo Editor.
-- ==============================================================================

local VIM = game:GetService("VirtualInputManager")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local FileName = "Velox_Hybrid_Config.json"

-- [ CONFIGURATION & THEME ]
local Theme = {
    Bg      = Color3.fromRGB(18, 18, 22),
    Sidebar = Color3.fromRGB(26, 26, 32),
    Element = Color3.fromRGB(35, 35, 42),
    Accent  = Color3.fromRGB(0, 255, 170), -- Neon Lite V4
    Text    = Color3.fromRGB(245, 245, 245),
    SubText = Color3.fromRGB(160, 160, 160),
    Red     = Color3.fromRGB(255, 65, 65),
    Green   = Color3.fromRGB(45, 225, 110),
    Blue    = Color3.fromRGB(0, 150, 255),
    Stroke  = Color3.fromRGB(60, 60, 70),
    Popup   = Color3.fromRGB(25, 25, 30)
}

-- [ GLOBAL VARS ]
local JOYSTICK_SIZE = 140
local KNOB_SIZE = 60
local DEADZONE = 0.15 
local isRunning = false 
local IsLayoutLocked = false 
local GlobalTransparency = 0 
local IsJoystickEnabled = false 
local Combos = {} 
local CurrentComboIndex = 0 
local ActiveVirtualKeys = {} 
local CurrentConfigName = nil 
local Keybinds = {} 
local VirtualKeySelectors = {}
local SkillMode = "INSTANT" 
local CurrentSmartKeyData = nil 
local SelectedComboID = nil 

local WeaponData = {
    {name = "Melee", slot = 1, color = Color3.fromRGB(255, 140, 0), tooltip = "Melee", keys = {"Z", "X", "C"}},
    {name = "Fruit", slot = 2, color = Color3.fromRGB(170, 50, 255), tooltip = "Blox Fruit", keys = {"Z", "X", "C", "V", "F"}},
    {name = "Sword", slot = 3, color = Color3.fromRGB(0, 160, 255), tooltip = "Sword", keys = {"Z", "X"}},
    {name = "Gun",   slot = 4, color = Color3.fromRGB(255, 220, 0),   tooltip = "Gun", keys = {"Z", "X"}}
}

-- ==============================================================================
-- [1] LITE INPUT ENGINE (DIRECT UI)
-- ==============================================================================

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

local function TapM1()
    local vp = Camera.ViewportSize
    VIM:SendTouchEvent(5, 0, vp.X / 2, vp.Y / 2)
    task.wait(0.01)
    VIM:SendTouchEvent(5, 2, vp.X / 2, vp.Y / 2)
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

local function equipWeapon(slotIdx)
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChild("Humanoid"); if not hum then return end
    local target = WeaponData[slotIdx].tooltip
    local current = char:FindFirstChildOfClass("Tool")
    if current and current.ToolTip == target then return end
    for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do
        if t:IsA("Tool") and t.ToolTip == target then hum:EquipTool(t); break end
    end
end

-- ==============================================================================
-- [2] UTILITIES & UI TOOLS
-- ==============================================================================

local function createCorner(p, r) 
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p 
end

local function createStroke(p, c) 
    local s = Instance.new("UIStroke"); s.Color = c or Theme.Stroke; s.Thickness = 1.5; s.ApplyStrokeMode = "Border"; s.Parent = p; return s 
end

local function MakeDraggable(guiObject, clickCallback)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if not IsLayoutLocked then 
                dragging = true; dragStart = input.Position; startPos = guiObject.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
            end
        end
    end)
    guiObject.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    guiObject.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if clickCallback and (IsLayoutLocked or (not dragging or (input.Position - dragStart).Magnitude < 15)) then clickCallback() end
            dragging = false
        end
    end)
end

-- ==============================================================================
-- [3] CORE UI SETUP
-- ==============================================================================

if CoreGui:FindFirstChild("VeloxHybrid") then CoreGui.VeloxHybrid:Destroy() end
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "VeloxHybrid"; ScreenGui.Parent = CoreGui; ScreenGui.ResetOnSpawn = false

local Window = Instance.new("Frame")
Window.Size = UDim2.new(0, 580, 0, 340)
Window.Position = UDim2.new(0.5, -290, 0.5, -170)
Window.BackgroundColor3 = Theme.Bg
Window.Parent = ScreenGui
createCorner(Window, 10); createStroke(Window, Theme.Accent)
MakeDraggable(Window)

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 45, 0, 45)
ToggleBtn.Position = UDim2.new(0.02, 0, 0.3, 0)
ToggleBtn.BackgroundColor3 = Theme.Sidebar
ToggleBtn.Text = "V"; ToggleBtn.TextColor3 = Theme.Accent; ToggleBtn.Font = Enum.Font.GothamBlack; ToggleBtn.TextSize = 22; ToggleBtn.Parent = ScreenGui
createCorner(ToggleBtn, 12); createStroke(ToggleBtn, Theme.Accent)
ToggleBtn.MouseButton1Click:Connect(function() Window.Visible = not Window.Visible end)
MakeDraggable(ToggleBtn)

-- [SIDEBAR]
local Sidebar = Instance.new("Frame"); Sidebar.Size = UDim2.new(0, 140, 1, 0); Sidebar.BackgroundColor3 = Theme.Sidebar; Sidebar.Parent = Window; createCorner(Sidebar, 10)
local NavContainer = Instance.new("Frame"); NavContainer.Size = UDim2.new(1, 0, 1, -60); NavContainer.Position = UDim2.new(0, 0, 0, 60); NavContainer.BackgroundTransparency = 1; NavContainer.Parent = Sidebar
local SideLayout = Instance.new("UIListLayout"); SideLayout.Parent = NavContainer; SideLayout.HorizontalAlignment = "Center"; SideLayout.Padding = UDim.new(0, 5)

-- [CONTENT AREA]
local Content = Instance.new("Frame"); Content.Size = UDim2.new(1, -150, 1, -20); Content.Position = UDim2.new(0, 150, 0, 10); Content.BackgroundTransparency = 1; Content.Parent = Window
local PageTitle = Instance.new("TextLabel"); PageTitle.Size = UDim2.new(1, 0, 0, 30); PageTitle.Text = "DASHBOARD"; PageTitle.Font = Enum.Font.GothamBlack; PageTitle.TextSize = 20; PageTitle.TextColor3 = Theme.Text; PageTitle.TextXAlignment = "Left"; PageTitle.BackgroundTransparency = 1; PageTitle.Parent = Content

local Pages = {}
local function nav(pName, title)
    for n, p in pairs(Pages) do p.Visible = (n == pName) end
    PageTitle.Text = title
end

local function mkNav(icon, text, target, title)
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(0.9, 0, 0, 38); btn.BackgroundColor3 = Theme.Bg; btn.BackgroundTransparency = 1; btn.Text = "  "..icon.."  "..text; btn.TextColor3 = Theme.SubText; btn.Font = Enum.Font.GothamBold; btn.TextSize = 12; btn.TextXAlignment = "Left"; btn.Parent = NavContainer
    createCorner(btn, 6)
    btn.MouseButton1Click:Connect(function() 
        nav(target, title)
        for _, c in pairs(NavContainer:GetChildren()) do if c:IsA("TextButton") then c.TextColor3 = Theme.SubText; c.BackgroundTransparency = 1 end end
        btn.TextColor3 = Theme.Accent; btn.BackgroundTransparency = 0; btn.BackgroundColor3 = Theme.Element
    end)
end

-- PAGE CONTAINERS
local P_Edit = Instance.new("Frame"); P_Edit.Size=UDim2.new(1,0,0.85,0); P_Edit.Position=UDim2.new(0,0,0.15,0); P_Edit.BackgroundTransparency=1; P_Edit.Visible=false; P_Edit.Parent=Content; Pages["Editor"]=P_Edit
local P_Lay = Instance.new("ScrollingFrame"); P_Lay.Size=UDim2.new(1,0,0.85,0); P_Lay.Position=UDim2.new(0,0,0.15,0); P_Lay.BackgroundTransparency=1; P_Lay.Visible=true; P_Lay.ScrollBarThickness=0; P_Lay.Parent=Content; Pages["Layout"]=P_Lay
local P_Sys = Instance.new("Frame"); P_Sys.Size=UDim2.new(1,0,0.85,0); P_Sys.Position=UDim2.new(0,0,0.15,0); P_Sys.BackgroundTransparency=1; P_Sys.Visible=false; P_Sys.Parent=Content; Pages["System"]=P_Sys

mkNav("🛠️", "LAYOUT", "Layout", "LAYOUT SETTINGS")
mkNav("⚔️", "COMBO", "Editor", "COMBO EDITOR")
mkNav("⚙️", "SYSTEM", "System", "SYSTEM MANAGER")

-- ==============================================================================
-- [4] VIRTUAL KEY & COMBO LOGIC (HYBRID ENGINE)
-- ==============================================================================

local function toggleVirtualKey(keyName, slotIdx, customName)
    local id = customName or keyName
    if ActiveVirtualKeys[id] then 
        ActiveVirtualKeys[id].Button:Destroy(); ActiveVirtualKeys[id] = nil
        if VirtualKeySelectors[id] then VirtualKeySelectors[id].BackgroundColor3 = Theme.Element end
    else
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 55, 0, 55)
        btn.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        btn.Text = id; btn.TextColor3 = Theme.Accent; btn.Font = Enum.Font.GothamBold; btn.TextSize = 16; btn.Parent = ScreenGui
        createCorner(btn, 14); createStroke(btn, Theme.Accent)
        btn.ZIndex = 50
        
        btn.MouseButton1Click:Connect(function()
            if id == "M1" then TapM1() return end
            if id == "Dodge" then TriggerDodge() return end
            
            local weaponKeys = {"1", "2", "3", "4"}
            if table.find(weaponKeys, keyName) then
                equipWeapon(tonumber(keyName))
            else
                if slotIdx then equipWeapon(slotIdx) end
                TriggerSkill(keyName)
            end
        end)
        MakeDraggable(btn)
        ActiveVirtualKeys[id] = {ID = id, Button = btn, Key = keyName, Slot = slotIdx}
        if VirtualKeySelectors[id] then VirtualKeySelectors[id].BackgroundColor3 = Theme.Green end
    end
end

-- ==============================================================================
-- [5] LAYOUT & SYSTEM INTERFACE
-- ==============================================================================

local LayList = Instance.new("UIListLayout"); LayList.Parent = P_Lay; LayList.Padding = UDim.new(0, 10)
local function mkSection(txt, p)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(0.95,0,0,25); l.Text = txt; l.TextColor3 = Theme.Accent; l.Font = Enum.Font.GothamBold; l.TextSize = 13; l.BackgroundTransparency = 1; l.Parent = p; return l
end

mkSection("QUICK CONTROLS", P_Lay)
local Grid = Instance.new("Frame"); Grid.Size = UDim2.new(0.95,0,0,100); Grid.BackgroundTransparency = 1; Grid.Parent = P_Lay
local UIGrid = Instance.new("UIGridLayout"); UIGrid.Parent = Grid; UIGrid.CellSize = UDim2.new(0, 60, 0, 35)

local qKeys = {"1", "2", "3", "4", "Z", "X", "C", "V", "F", "M1", "Dodge"}
for _, k in ipairs(qKeys) do
    local b = Instance.new("TextButton"); b.Text = k; b.BackgroundColor3 = Theme.Element; b.TextColor3 = Theme.Text; b.Font = Enum.Font.GothamBold; b.Parent = Grid; createCorner(b, 4)
    b.MouseButton1Click:Connect(function() toggleVirtualKey(k, nil, k) end)
    VirtualKeySelectors[k] = b
end

mkSection("LOCK & VISUAL", P_Lay)
local LockBtn = Instance.new("TextButton"); LockBtn.Size = UDim2.new(0.95,0,0,40); LockBtn.BackgroundColor3 = Theme.Red; LockBtn.Text = "LAYOUT: UNLOCKED"; LockBtn.TextColor3 = Theme.Text; LockBtn.Font = Enum.Font.GothamBold; LockBtn.Parent = P_Lay; createCorner(LockBtn, 6)
LockBtn.MouseButton1Click:Connect(function()
    IsLayoutLocked = not IsLayoutLocked
    LockBtn.Text = IsLayoutLocked and "LAYOUT: LOCKED" or "LAYOUT: UNLOCKED"
    LockBtn.BackgroundColor3 = IsLayoutLocked and Theme.Green or Theme.Red
end)

-- ==============================================================================
-- [6] SAVE & LOAD SYSTEM
-- ==============================================================================

local function GetState()
    local data = {VirtualKeys = {}}
    for id, v in pairs(ActiveVirtualKeys) do
        table.insert(data.VirtualKeys, {
            id = id, key = v.Key, slot = v.Slot,
            pos = {v.Button.Position.X.Offset, v.Button.Position.Y.Offset}
        })
    end
    return data
end

local function Save(name)
    local full = {}
    if isfile(FileName) then full = HttpService:JSONDecode(readfile(FileName)) end
    full[name] = GetState()
    writefile(FileName, HttpService:JSONEncode(full))
end

local function Load(name)
    if not isfile(FileName) then return end
    local full = HttpService:JSONDecode(readfile(FileName))
    local data = full[name]
    if not data then return end
    
    for _, v in pairs(ActiveVirtualKeys) do v.Button:Destroy() end
    ActiveVirtualKeys = {}
    
    for _, vk in ipairs(data.VirtualKeys) do
        toggleVirtualKey(vk.key, vk.slot, vk.id)
        if ActiveVirtualKeys[vk.id] then
            ActiveVirtualKeys[vk.id].Button.Position = UDim2.new(0, vk.pos[1], 0, vk.pos[2])
        end
    end
end

mkSection("CONFIGURATION", P_Sys)
local SBtn = Instance.new("TextButton"); SBtn.Size = UDim2.new(0.9,0,0,40); SBtn.BackgroundColor3 = Theme.Blue; SBtn.Text = "SAVE AUTO_CONFIG"; SBtn.TextColor3 = Theme.Text; SBtn.Parent = P_Sys; createCorner(SBtn, 6)
SBtn.MouseButton1Click:Connect(function() Save("Auto") end)

local LBtn = Instance.new("TextButton"); LBtn.Size = UDim2.new(0.9,0,0,40); LBtn.BackgroundColor3 = Theme.Green; LBtn.Text = "LOAD AUTO_CONFIG"; LBtn.Position = UDim2.new(0,0,0,50); LBtn.TextColor3 = Theme.Text; LBtn.Parent = P_Sys; createCorner(LBtn, 6)
LBtn.MouseButton1Click:Connect(function() Load("Auto") end)

-- [FINALIZE]
print("Velox Hybrid V135: Engine Online")
if isfile(FileName) then pcall(function() Load("Auto") end) end
