-- ==============================================================================
-- [1] SERVICES, VARIABLES & CONNECTION MANAGER
-- ==============================================================================

local VIM = game:GetService("VirtualInputManager")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local FileName = "Velox_Mobile_Config.json"

-- CONNECTION MANAGER (Untuk mencegah memory leak saat Exit)
local GlobalConnections = {}
local function TrackConn(conn)
    table.insert(GlobalConnections, conn)
    return conn
end

-- TARGET GUI (Aman untuk Executor Pihak Ketiga)
local TargetGui = (gethui and gethui()) or game:GetService("CoreGui")

-- CONFIGURATION
local Theme = {
    Bg      = Color3.fromRGB(18, 18, 22),
    Sidebar = Color3.fromRGB(26, 26, 32),
    Element = Color3.fromRGB(35, 35, 42),
    Accent  = Color3.fromRGB(255, 180, 0), -- Deep Gold
    Text    = Color3.fromRGB(245, 245, 245),
    SubText = Color3.fromRGB(160, 160, 160),
    Red     = Color3.fromRGB(255, 65, 65),
    Green   = Color3.fromRGB(45, 225, 110),
    Blue    = Color3.fromRGB(0, 150, 255),
    Stroke  = Color3.fromRGB(60, 60, 70),
    Popup   = Color3.fromRGB(25, 25, 30)
}

-- GLOBAL VARIABLES
local JOYSTICK_SIZE = 140
local KNOB_SIZE = 60
local DEADZONE = 0.15 

local isRunning = false 
local IsLayoutLocked = false 
local GlobalTransparency = 0 
local IsAutoLoad = true
local Settings_Mode_M1 = "HOLD" 
local Settings_Mode_Dash = "HOLD" 
local Settings_Mode_Jump = "HOLD" 
local Jump_Offset = Vector2.new(0, 0) 
local JumpCrosshairUI = nil
local IsAutoM1_Active = false 
local M1_Offset = Vector2.new(0, 0) 
local ShowCrosshair = false 
local IsAutoDashing = false 
local CrosshairUI = nil 
local IsJoystickEnabled = false 

local Combos = {} 
local CurrentComboIndex = 0 
local ActiveVirtualKeys = {} 
local CurrentConfigName = nil 
local VirtualKeySelectors = {}

-- SYSTEM VARS
local SkillMode = "INSTANT" 
local CurrentSmartKeyData = nil 
local SelectedComboID = nil 

-- EDITOR & RESIZER VARS
local ResizerList = {}
local CurrentSelectedElement = nil
local ResizerUpdateFunc = nil 
local UpdateTransparencyFunc = nil 
local RefreshEditorUI = nil 
local CreateComboButtonFunc = nil 
local ModeBtn = nil 

-- Tambahkan variable ini di Section [1] agar Load Function bisa membacanya
local SetM1Btn = nil
local SetDashBtn = nil
local SetJumpBtn = nil
local AutoLoadBtn = nil

local WeaponData = {
    {name = "Melee", slot = 1, color = Color3.fromRGB(255, 140, 0), tooltip = "Melee", keys = {"Z", "X", "C"}},
    {name = "Fruit", slot = 2, color = Color3.fromRGB(170, 50, 255), tooltip = "Blox Fruit", keys = {"Z", "X", "C", "V", "F"}},
    {name = "Sword", slot = 3, color = Color3.fromRGB(0, 160, 255), tooltip = "Sword", keys = {"Z", "X"}},
    {name = "Gun",   slot = 4, color = Color3.fromRGB(255, 220, 0),   tooltip = "Gun", keys = {"Z", "X"}}
}

-- ==============================================================================
-- [2] UTILITY FUNCTIONS
-- ==============================================================================

local function createCorner(p, r) 
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = p 
end

local function GetJumpButton()
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PGui then return nil end
    
    -- Coba cari di lokasi standar Roblox Mobile
    local touchGui = PGui:FindFirstChild("TouchGui")
    if touchGui and touchGui:FindFirstChild("TouchControlFrame") then
        local btn = touchGui.TouchControlFrame:FindFirstChild("JumpButton")
        if btn and btn.Visible then return btn end
    end
    
    -- Jika tidak ketemu, cari recursive (untuk game custom)
    local function findJump(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA("GuiObject") and child.Visible and (child.Name == "JumpButton" or child.Name == "Jump") then
                return child
            end
            local res = findJump(child)
            if res then return res end
        end
    end
    
    return findJump(PGui)
end

local function createStroke(p, c) 
    local s = Instance.new("UIStroke")
    s.Color = c or Theme.Stroke
    s.Thickness = 1.5
    s.ApplyStrokeMode = "Border"
    s.Parent = p
    return s 
end

local function mkTool(t,c,f,p) 
    local b = Instance.new("TextButton")
    b.Text = t
    b.BackgroundColor3 = Theme.Sidebar
    b.TextColor3 = Theme.Text
    b.Font = Enum.Font.Gotham
    b.TextSize = 10
    b.Parent = p
    b.Selectable = false
    createCorner(b, 6)
    createStroke(b, c)
    if f then b.MouseButton1Click:Connect(f) end
    return b 
end

local function FireUI(btn)
    if not btn then return end
    for _, c in pairs(getconnections(btn.Activated)) do c:Fire() end
    for _, c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
    for _, c in pairs(getconnections(btn.InputBegan)) do 
        c:Fire({UserInputType=Enum.UserInputType.MouseButton1, UserInputState=Enum.UserInputState.Begin})
    end
end

local function MakeDraggable(guiObject, clickCallback)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if not IsLayoutLocked then 
                dragging = true
                dragStart = input.Position
                startPos = guiObject.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
            end
        end
    end)
    guiObject.InputChanged:Connect(function(input) 
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then 
            dragInput = input 
        end 
    end)
    TrackConn(UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
    guiObject.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if clickCallback and (IsLayoutLocked or (not dragging or (input.Position - dragStart).Magnitude < 15)) then clickCallback() end
            dragging = false
        end
    end)
end

local function isChatting()
    local focused = UserInputService:GetFocusedTextBox()
    return focused ~= nil
end

-- ==============================================================================
-- [3] CORE LOGIC & MANAGERS
-- ==============================================================================

local JoyOuter, JoyKnob, JoyDrag, ToggleBtn, JoyContainer, LockBtn, ScreenGui

UpdateTransparencyFunc = function()
    local t = GlobalTransparency
    if ToggleBtn then 
        ToggleBtn.BackgroundTransparency = math.clamp(0.2 + t, 0.2, 1)
        ToggleBtn.ImageTransparency = t 
        if ToggleBtn:FindFirstChild("UIStroke") then ToggleBtn.UIStroke.Transparency = t end
    end
    for _, c in pairs(Combos) do 
        if c.Button then 
            c.Button.BackgroundTransparency = t
            c.Button.TextTransparency = t
            if c.Button:FindFirstChild("UIStroke") then c.Button.UIStroke.Transparency = t end
        end 
    end
    for _, item in pairs(ActiveVirtualKeys) do 
        local btn = item.Button
        btn.BackgroundTransparency = t
        btn.TextTransparency = t
        if btn:FindFirstChild("UIStroke") then btn.UIStroke.Transparency = t end
    end
    if JoyOuter and JoyKnob then
        JoyOuter.BackgroundTransparency = math.clamp(0.3 + t, 0.3, 1)
        JoyKnob.BackgroundTransparency = math.clamp(0.2 + t, 0.2, 1)
        JoyDrag.BackgroundTransparency = t
        JoyDrag.TextTransparency = t
        if JoyOuter:FindFirstChild("UIStroke") then JoyOuter.UIStroke.Transparency = math.clamp(0.1 + t, 0.1, 1) end
    end
end

local function updateLockState()
    if JoyDrag then JoyDrag.Visible = (not IsLayoutLocked) and IsJoystickEnabled end
    if LockBtn then
        if IsLayoutLocked then 
            LockBtn.Text = "POS: LOCKED"
            LockBtn.BackgroundColor3 = Theme.Red
        else 
            LockBtn.Text = "POS: UNLOCKED"
            LockBtn.BackgroundColor3 = Theme.Green 
        end
    end
    if ResizerUpdateFunc then ResizerUpdateFunc() end
end

local function TapM1()
    local vp = Camera.ViewportSize
    local x = (vp.X / 2) + M1_Offset.X
    local y = (vp.Y / 2) + M1_Offset.Y
    VIM:SendTouchEvent(5, 0, x, y) 
    task.wait(0.02)
    VIM:SendTouchEvent(5, 2, x, y)
end

local CachedDodgeBtn = nil
local function TriggerDodge()
    if CachedDodgeBtn and CachedDodgeBtn.Parent then 
        FireUI(CachedDodgeBtn) 
        return 
    end
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local Ctx = PGui and PGui:FindFirstChild("MobileContextButtons") and PGui.MobileContextButtons:FindFirstChild("ContextButtonFrame")
    if Ctx then
        for _, f in pairs(Ctx:GetChildren()) do
            if f.Name:find("Dodge") then
                CachedDodgeBtn = f:FindFirstChild("Button")
                if CachedDodgeBtn then FireUI(CachedDodgeBtn) return end
            end
        end
    end
end

local function GetMobileButtonObj(keyName)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local Skills = PGui and PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    if Skills then
        for _, f in pairs(Skills:GetChildren()) do
            if f:IsA("Frame") and f.Visible and f:FindFirstChild(keyName) then
                local mobileBtn = f[keyName]:FindFirstChild("Mobile")
                if mobileBtn then return mobileBtn end
            end
        end
    end
    return nil
end

local NotifContainer = nil 
local function ShowNotification(text, color)
    if not NotifContainer then return end
    local NotifFrame = Instance.new("Frame")
    NotifFrame.Size = UDim2.new(0, 200, 0, 40)
    NotifFrame.Position = UDim2.new(0.5, -100, 0.1, 0)
    NotifFrame.BackgroundColor3 = Theme.Sidebar
    NotifFrame.BackgroundTransparency = 0.1
    NotifFrame.Parent = NotifContainer
    NotifFrame.ZIndex = 6000
    createCorner(NotifFrame, 8)
    createStroke(NotifFrame, color or Theme.Accent)
    
    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, 0, 1, 0)
    Lbl.Text = text
    Lbl.TextColor3 = Theme.Text
    Lbl.Font = Enum.Font.GothamBold
    Lbl.TextSize = 12
    Lbl.BackgroundTransparency = 1
    Lbl.Parent = NotifFrame
    Lbl.ZIndex = 6001
    
    task.delay(1.5, function() NotifFrame:Destroy() end)
end

local function pressKey(keyName)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local Skills = PGui and PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    if Skills then
        for _, f in pairs(Skills:GetChildren()) do
            if f:IsA("Frame") and f.Visible and f:FindFirstChild(keyName) then
                FireUI(f[keyName]:FindFirstChild("Mobile") or f[keyName])
                return
            end
        end
    end
end

local function isWeaponReady(targetSlotIdx)
    local char = LocalPlayer.Character
    if not char then return false end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return false end 
    local expectedTip = WeaponData[targetSlotIdx].tooltip
    if tool.ToolTip == expectedTip then return true end
    return false
end

local function equipWeapon(slotIdx, isToggle)
    if not slotIdx or not WeaponData[slotIdx] then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum then return end
    local targetTooltip = WeaponData[slotIdx].tooltip
    
    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool and currentTool.ToolTip == targetTooltip then
        if isToggle then hum:UnequipTools() end
        return 
    end
    
    local toolToEquip = nil
    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.ToolTip == targetTooltip then
            toolToEquip = tool
            break
        end
    end
    
    if toolToEquip then hum:EquipTool(toolToEquip) end
    task.wait(0.1)
end

-- ==============================================================================
-- [4] INPUT HANDLERS (AUTO FINISH & SMART TAP SYNC)
-- ==============================================================================

local IsSmartHolding = false 


local function executeComboSequence(idx)
    if isChatting() then return end 

    local data = Combos[idx]
    if not data or not data.Button then return end
    
    -- [TOGGLE ON/OFF]
    if isRunning then 
        isRunning = false; return 
    end
    
    isRunning = true
    
    local btn = data.Button
    -- [1] SIMPAN TEKS ASLI
    local originalText = btn.Text 
    
    btn.Text = "STOP"
    btn.BackgroundColor3 = Theme.Red
    if btn:FindFirstChild("UIStroke") then btn.UIStroke.Color = Theme.Red end
    
    task.spawn(function()
        -- Definisi Warna Ready (Cyan)
        local READY_COLOR = Color3.fromRGB(0, 255, 255) 
        local fixedTouchID = 6 -- ID TETAP 6

        for i, step in ipairs(data.Steps) do
            -- Cek Stop
            if not isRunning then break end

            CurrentActiveKey = step.Key

            -- Cek Karakter
            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then 
                isRunning = false; break 
            end
            
            -- Cek & Equip Senjata
            if not isWeaponReady(step.Slot) then 
                equipWeapon(step.Slot, false) 
                task.wait(0.05) 
            end
            
            -- [1] VISUAL DULU (PressKey)
            pressKey(step.Key) 

            -- [2] LOGIKA SMART MODE & DELAY (Sebelum VIM Ditekan)
            if SkillMode == "SMART" and i == 1 then 
                -- Tunggu user menekan layar (Hold Start)
                while not IsSmartHolding and isRunning do task.wait() end
                -- Tunggu user melepas layar (Hold Release)
                while IsSmartHolding and isRunning do task.wait() end
            else 
                -- START DELAY (User defined) - Terjadi SETELAH pressKey
                if step.Delay and step.Delay > 0 then 
                    task.wait(step.Delay)
                end
            end

            -- Hitung Posisi VIM
            local vp = Camera.ViewportSize
            local x = (vp.X / 2) + M1_Offset.X
            local y = (vp.Y / 2) + M1_Offset.Y

            -- Ambil Tombol UI (Pasti Ketemu Sesuai Request)
            local targetBtn = GetMobileButtonObj(step.Key)

            if targetBtn then
                -- Cek Mode: Hold vs Tap
                if step.IsHold and step.HoldTime and step.HoldTime > 0 then
                    -- [MODE HOLD / TAHAN LAMA]
                    -- Langsung tekan dan tahan (Tanpa spam Tap, karena akan membatalkan charge)
                    
                    -- 1. Tekan (Down)
                    VIM:SendTouchEvent(fixedTouchID, 0, x, y)
                    
                    -- 2. Tahan Sesuai Durasi
                    local holdTimer = tick()
                    while (tick() - holdTimer) < step.HoldTime do
                        if not isRunning then break end
                        task.wait()
                    end
                    
                    -- 3. Lepas (Up) -> Skill Keluar
                    VIM:SendTouchEvent(fixedTouchID, 2, x, y)
                    
                else
                    -- [MODE TAP / SPAM]
                    -- ====================================================
                    while isRunning and targetBtn.BackgroundColor3 == READY_COLOR do
                        
                        -- A. TEKAN (Down)
                        VIM:SendTouchEvent(fixedTouchID, 0, x, y)
                        
                        -- B. HOLD SEBENTAR (PENTING: Agar input terbaca server)
                        task.wait(0.1) 
                        
                        -- C. LEPAS (Up) -> Memicu Skill
                        VIM:SendTouchEvent(fixedTouchID, 2, x, y)
                        
                        -- D. CEK WARNA
                        -- Beri waktu sedikit untuk UI update warna
                        task.wait(0.05) 
                        if targetBtn.BackgroundColor3 ~= READY_COLOR then 
                            break -- Skill Keluar!
                        end
                    end
                end
            end -- <--- INI ADALAH 'END' YANG ANDA LUPAKAN UNTUK 'if targetBtn then'
            
            CurrentSmartKeyData = nil 
            
            -- Jeda kecil antar skill (Default, jika tidak ada delay)
            if i < #data.Steps then task.wait(0.05) end
        end

        -- [3] SELESAI -> KEMBALIKAN KE TEKS ASLI
        isRunning = false
        btn.Text = data.Name
        btn.BackgroundColor3 = Theme.Sidebar
        if btn:FindFirstChild("UIStroke") then btn.UIStroke.Color = Theme.Accent end
    end)
end


local SmartTouchObject = nil 

TrackConn(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if isChatting() or gameProcessed then return end 
    if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
        if SelectedComboID ~= nil and not isRunning then
            IsSmartHolding = true
            executeComboSequence(SelectedComboID)
        end
    end
end))

TrackConn(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        IsSmartHolding = false 
    end
    if input == SmartTouchObject and SkillMode == "SMART" and CurrentSmartKeyData ~= nil then
        if ActiveVirtualKeys[CurrentSmartKeyData.ID] then
            local btn = ActiveVirtualKeys[CurrentSmartKeyData.ID].Button
            btn.BackgroundColor3 = Color3.fromRGB(0,0,0); btn.TextColor3 = Theme.Accent
        end
        CurrentSmartKeyData = nil; SmartTouchObject = nil
    end
end))

-- ==============================================================================
-- [5] UI CONSTRUCTION & TAB SYSTEM
-- ==============================================================================

if TargetGui:FindFirstChild("VeloxUI") then TargetGui.VeloxUI:Destroy() end
ScreenGui = Instance.new("ScreenGui") 
ScreenGui.Name = "VeloxUI"
ScreenGui.Parent = TargetGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

NotifContainer = Instance.new("Frame")
NotifContainer.Size = UDim2.new(1, 0, 1, 0)
NotifContainer.BackgroundTransparency = 1
NotifContainer.Parent = ScreenGui
NotifContainer.ZIndex = 6000

ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0.02, 0, 0.3, 0)
ToggleBtn.BackgroundColor3 = Theme.Sidebar
ToggleBtn.BackgroundTransparency = 0.2
ToggleBtn.Image = "rbxassetid://73551285041476" 
ToggleBtn.ImageColor3 = Color3.fromRGB(255, 255, 255) 
ToggleBtn.Parent = ScreenGui
ToggleBtn.ZIndex = 501
ToggleBtn.Selectable = false
createCorner(ToggleBtn, 12)
createStroke(ToggleBtn, Theme.Accent)
MakeDraggable(ToggleBtn, nil)

local Window = Instance.new("Frame")
Window.Size = UDim2.new(0, 600, 0, 340)
Window.Position = UDim2.new(0.5, -300, 0.5, -170)
Window.BackgroundColor3 = Theme.Bg
Window.Visible = true
Window.Parent = ScreenGui
Window.ZIndex = 100
Window.Active = true
createCorner(Window, 10)
createStroke(Window, Theme.Accent)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundTransparency = 1
TopBar.Parent = Window
TopBar.ZIndex = 110
MakeDraggable(TopBar, function() end)

ToggleBtn.MouseButton1Click:Connect(function() Window.Visible = not Window.Visible end)

local PopupOverlay = Instance.new("Frame")
PopupOverlay.Size = UDim2.new(1, 0, 1, 0)
PopupOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
PopupOverlay.BackgroundTransparency = 0.5
PopupOverlay.Parent = Window
PopupOverlay.Visible = false
PopupOverlay.ZIndex = 2000 

local function ClosePopup() 
    PopupOverlay.Visible = false 
    for _, c in pairs(PopupOverlay:GetChildren()) do c:Destroy() end 
end

local function ShowPopup(title, contentFunc)
    for _, c in pairs(PopupOverlay:GetChildren()) do c:Destroy() end
    PopupOverlay.Visible = true
    
    local MainP = Instance.new("Frame")
    MainP.Size = UDim2.new(0, 300, 0, 0) 
    MainP.AnchorPoint = Vector2.new(0.5, 0.5)
    MainP.Position = UDim2.new(0.5, 0, 0.5, 0)
    MainP.BackgroundColor3 = Theme.Popup
    MainP.Parent = PopupOverlay
    MainP.ZIndex = 2001 
    createCorner(MainP, 10)
    createStroke(MainP, Theme.Accent)
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.Text = title
    Title.Font = Enum.Font.GothamBlack
    Title.TextColor3 = Theme.Accent
    Title.TextSize = 16
    Title.BackgroundTransparency = 1
    Title.Parent = MainP
    Title.ZIndex = 2002
    
    local Close = Instance.new("TextButton")
    Close.Size = UDim2.new(0, 30, 0, 30)
    Close.Position = UDim2.new(1, -35, 0, 5)
    Close.Text = "X"
    Close.TextColor3 = Theme.Red
    Close.BackgroundTransparency = 1
    Close.Parent = MainP
    Close.Font = Enum.Font.GothamBold
    Close.ZIndex = 2003
    Close.MouseButton1Click:Connect(ClosePopup)
    
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(0.9, 0, 0, 0)
    Container.Position = UDim2.new(0.05, 0, 0, 45)
    Container.BackgroundTransparency = 1
    Container.Parent = MainP
    Container.ZIndex = 2002
    
    local contentHeight = contentFunc(Container)
    MainP.Size = UDim2.new(0, 300, 0, contentHeight + 55) 
end

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 140, 1, 0)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.Parent = Window
Sidebar.Active = true
createCorner(Sidebar, 10)

local BrandFrame = Instance.new("Frame")
BrandFrame.Size = UDim2.new(1, 0, 0, 55)
BrandFrame.BackgroundTransparency = 1
BrandFrame.Parent = Sidebar

local BrandText = Instance.new("TextLabel")
BrandText.Size = UDim2.new(1, 0, 0, 30)
BrandText.Position = UDim2.new(0, 0, 0, 5)
BrandText.Text = "VELOX"
BrandText.TextColor3 = Theme.Accent
BrandText.Font = Enum.Font.GothamBlack
BrandText.TextSize = 18
BrandText.BackgroundTransparency = 1
BrandText.Parent = BrandFrame

local TaglineText = Instance.new("TextLabel")
TaglineText.Size = UDim2.new(1, 0, 0, 15)
TaglineText.Position = UDim2.new(0, 0, 0.6, 0)
TaglineText.Text = "Total Control. Instant Combo."
TaglineText.TextColor3 = Theme.SubText
TaglineText.Font = Enum.Font.Gotham
TaglineText.TextSize = 9
TaglineText.BackgroundTransparency = 1
TaglineText.Parent = BrandFrame

local NavContainer = Instance.new("Frame")
NavContainer.Size = UDim2.new(1, 0, 1, -60)
NavContainer.Position = UDim2.new(0, 0, 0, 60)
NavContainer.BackgroundTransparency = 1
NavContainer.Parent = Sidebar
local SideLayout = Instance.new("UIListLayout")
SideLayout.Parent = NavContainer
SideLayout.HorizontalAlignment = "Center"
SideLayout.Padding = UDim.new(0, 5)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -150, 1, -20)
Content.Position = UDim2.new(0, 150, 0, 10)
Content.BackgroundTransparency = 1
Content.Parent = Window

local PageTitle = Instance.new("TextLabel")
PageTitle.Size = UDim2.new(1, 0, 0, 30)
PageTitle.Text = "GUIDE & INFO"
PageTitle.Font = Enum.Font.GothamBlack
PageTitle.TextSize = 22
PageTitle.TextColor3 = Theme.Text
PageTitle.TextXAlignment = "Left"
PageTitle.BackgroundTransparency = 1
PageTitle.Parent = Content

local Pages = {}
local function nav(pName, title) 
    for n, p in pairs(Pages) do p.Visible = (n == pName) end 
    PageTitle.Text = title 
end

local function mkNav(icon, text, target, title)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 40)
    btn.BackgroundColor3 = Theme.Bg
    btn.BackgroundTransparency = 1
    btn.Text = "  " .. icon .. "  " .. text
    btn.TextColor3 = Theme.SubText
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextXAlignment = "Left"
    btn.Parent = NavContainer
    btn.Selectable = false
    createCorner(btn, 6)
    
    btn.MouseButton1Click:Connect(function() 
        nav(target, title)
        for _, c in pairs(NavContainer:GetChildren()) do 
            if c:IsA("TextButton") then 
                c.TextColor3 = Theme.SubText
                c.BackgroundColor3 = Theme.Bg
                c.BackgroundTransparency = 1 
            end 
        end
        btn.TextColor3 = Theme.Accent
        btn.BackgroundColor3 = Theme.Element
        btn.BackgroundTransparency = 0 
    end)
    return btn
end

local P_Guide = Instance.new("Frame"); P_Guide.Size=UDim2.new(1,0,0.85,0); P_Guide.Position=UDim2.new(0,0,0.15,0); P_Guide.BackgroundTransparency=1; P_Guide.Visible=true; P_Guide.Parent=Content; Pages["Guide"]=P_Guide
local P_Edit = Instance.new("Frame"); P_Edit.Size=UDim2.new(1,0,0.85,0); P_Edit.Position=UDim2.new(0,0,0.15,0); P_Edit.BackgroundTransparency=1; P_Edit.Visible=false; P_Edit.Parent=Content; Pages["Editor"]=P_Edit
local P_Lay = Instance.new("ScrollingFrame"); P_Lay.Size=UDim2.new(1,0,0.85,0); P_Lay.Position=UDim2.new(0,0,0.15,0); P_Lay.BackgroundTransparency=1; P_Lay.Visible=false; P_Lay.ScrollBarThickness=4; P_Lay.Parent=Content; Pages["Layout"]=P_Lay
P_Lay.ScrollingDirection = Enum.ScrollingDirection.Y 
local P_Set = Instance.new("Frame"); P_Set.Size=UDim2.new(1,0,0.85,0); P_Set.Position=UDim2.new(0,0,0.15,0); P_Set.BackgroundTransparency=1; P_Set.Visible=false; P_Set.Parent=Content; Pages["Settings"]=P_Set
local P_Sys = Instance.new("Frame"); P_Sys.Size=UDim2.new(1,0,0.85,0); P_Sys.Position=UDim2.new(0,0,0.15,0); P_Sys.BackgroundTransparency=1; P_Sys.Visible=false; P_Sys.Parent=Content; Pages["System"]=P_Sys

local NavGuide = mkNav("ℹ️", "GUIDE", "Guide", "GUIDE & INFO")
NavGuide.TextColor3 = Theme.Accent
NavGuide.BackgroundColor3 = Theme.Element
NavGuide.BackgroundTransparency = 0
mkNav("⚔️", "COMBO", "Editor", "COMBO EDITOR")
mkNav("🛠️", "LAYOUT", "Layout", "LAYOUT SETTINGS")
mkNav("🔧", "SETTINGS", "Settings", "CALIBRATION & SETTINGS")
mkNav("⚙️", "SYSTEM", "System", "SYSTEM MANAGER")

-- ==============================================================================
-- [6] GUIDE TAB CONTENT
-- ==============================================================================
local GFrame = Instance.new("ScrollingFrame")
GFrame.Size = UDim2.new(1, 0, 1, 0)
GFrame.BackgroundTransparency = 1
GFrame.ScrollBarThickness = 4
GFrame.ScrollingDirection = Enum.ScrollingDirection.Y
GFrame.Parent = P_Guide
local GText = [[WELCOME TO VELOX ! (PvP EDITION)

[ OPTIMIZED FOR BLOX FRUITS ]
• Anti-AFK Removed for better FPS
• Connection Leaks Fixed
• Executor Secure GUI Implementation

[ FEATURES ]
• Custom Layout: Resize & Move ANY button.
• Smart Cast: Tap skill -> Tap screen to fire.
• Weapon Bind: Assign weapons to virtual keys.
• Save System: Fully Working.]]
local GLabel = Instance.new("TextLabel")
GLabel.Size = UDim2.new(0.95, 0, 0, 300) 
GLabel.Position = UDim2.new(0.025, 0, 0, 0)
GLabel.Text = GText
GLabel.TextColor3 = Theme.Text
GLabel.Font = Enum.Font.Gotham
GLabel.TextSize = 14
GLabel.TextXAlignment = "Left"
GLabel.TextYAlignment = "Top"
GLabel.BackgroundTransparency = 1
GLabel.TextWrapped = true
GLabel.Parent = GFrame
GFrame.CanvasSize = UDim2.new(0, 0, 0, 350)

-- ==============================================================================
-- [7] JOYSTICK LOGIC
-- ==============================================================================
JoyContainer = Instance.new("Frame")
JoyContainer.Size = UDim2.new(0, JOYSTICK_SIZE, 0, JOYSTICK_SIZE + 30)
JoyContainer.Position = UDim2.new(0.1, 0, 0.6, 0)
JoyContainer.BackgroundTransparency = 1
JoyContainer.Active = false
JoyContainer.Parent = ScreenGui
JoyContainer.Visible = false
JoyContainer.ZIndex = 50

JoyDrag = Instance.new("TextButton")
JoyDrag.Size = UDim2.new(0, 60, 0, 25)
JoyDrag.Position = UDim2.new(0.5, -30, 0, -10)
JoyDrag.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
JoyDrag.Text = "DRAG"
JoyDrag.TextColor3 = Theme.Accent
JoyDrag.Font = Enum.Font.GothamBold
JoyDrag.TextSize = 11
JoyDrag.Parent = JoyContainer
JoyDrag.Selectable = false
JoyDrag.Visible = false
createCorner(JoyDrag, 6)
JoyDrag.ZIndex = 52

JoyOuter = Instance.new("ImageButton")
JoyOuter.Size = UDim2.new(0, JOYSTICK_SIZE, 0, JOYSTICK_SIZE)
JoyOuter.Position = UDim2.new(0, 0, 0, 20)
JoyOuter.BackgroundColor3 = Color3.new(0, 0, 0)
JoyOuter.BackgroundTransparency = 0.3
JoyOuter.ImageTransparency = 1
JoyOuter.AutoButtonColor = false
JoyOuter.Parent = JoyContainer
JoyOuter.Selectable = true
JoyOuter.Active = true
createCorner(JoyOuter, JOYSTICK_SIZE)
local JO_Str = createStroke(JoyOuter, Theme.Text)
JO_Str.Transparency = 0.1
JO_Str.Thickness = 2
JoyOuter.ZIndex = 51

JoyKnob = Instance.new("Frame")
JoyKnob.Size = UDim2.new(0, KNOB_SIZE, 0, KNOB_SIZE)
JoyKnob.Position = UDim2.new(0.5, -KNOB_SIZE/2, 0.5, -KNOB_SIZE/2)
JoyKnob.BackgroundColor3 = Theme.Accent
JoyKnob.BackgroundTransparency = 0.2
JoyKnob.Parent = JoyOuter
createCorner(JoyKnob, KNOB_SIZE)
JoyKnob.ZIndex = 52

local function EnableJoyDrag()
    local d, offset
    JoyDrag.InputBegan:Connect(function(i) 
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then 
            d = true; offset = Vector2.new(i.Position.X - JoyContainer.AbsolutePosition.X, i.Position.Y - JoyContainer.AbsolutePosition.Y) 
        end 
    end)
    TrackConn(UserInputService.InputChanged:Connect(function(i) 
        if d and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then 
            local newX = i.Position.X - offset.X
            local newY = i.Position.Y - offset.Y
            JoyContainer.Position = UDim2.new(0, math.clamp(newX, 0, Camera.ViewportSize.X - JoyOuter.AbsoluteSize.X), 0, math.clamp(newY, 0, Camera.ViewportSize.Y - (JoyOuter.AbsoluteSize.Y + 30))) 
        end 
    end))
    TrackConn(UserInputService.InputEnded:Connect(function(i) 
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then 
            d = false 
        end 
    end))
end
EnableJoyDrag()

local moveTouch, moveDir = nil, Vector2.new(0,0)
JoyOuter.InputBegan:Connect(function(i) 
    if (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1) and not moveTouch then 
        moveTouch = i 
    end 
end)

TrackConn(UserInputService.InputChanged:Connect(function(i) 
    if i == moveTouch then 
        local center = JoyOuter.AbsolutePosition + (JoyOuter.AbsoluteSize/2)
        local vec = Vector2.new(i.Position.X, i.Position.Y) - center
        if vec.Magnitude > JoyOuter.AbsoluteSize.X/2 then 
            vec = vec.Unit * (JoyOuter.AbsoluteSize.X/2) 
        end
        JoyKnob.Position = UDim2.new(0.5, vec.X - KNOB_SIZE/2, 0.5, vec.Y - KNOB_SIZE/2)
        moveDir = Vector2.new(vec.X/(JoyOuter.AbsoluteSize.X/2), vec.Y/(JoyOuter.AbsoluteSize.X/2)) 
    end 
end))

TrackConn(UserInputService.InputEnded:Connect(function(i) 
    if i == moveTouch then 
        moveTouch = nil
        moveDir = Vector2.new(0,0)
        JoyKnob.Position = UDim2.new(0.5, -KNOB_SIZE/2, 0.5, -KNOB_SIZE/2) 
    end 
end))

TrackConn(RunService.RenderStepped:Connect(function()
    if not IsJoystickEnabled or not LocalPlayer.Character then return end
    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
    if not hum then return end
    if moveDir.Magnitude < DEADZONE then hum:Move(Vector3.new(0,0,0), true) return end
    if moveDir.Magnitude > 0 then
        local cam = workspace.CurrentCamera
        local flatLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
        local flatRight = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z).Unit
        local moveVec = (flatLook * -moveDir.Y) + (flatRight * moveDir.X)
        hum:Move(moveVec, false)
    end
end))

-- ==============================================================================
-- [8] MANAGER (ADD/REMOVE BUTTONS)
-- ==============================================================================
local function toggleVirtualKey(keyName, slotIdx, customName)
    local id = customName or keyName
    local kn = tostring(keyName)
    
    -- [1] PERBAIKAN FATAL: KEMBALIKAN LOGIKA SLOT ID
    -- Tanpa ini, tombol 1-4 tidak akan punya slotIdx (nil)
    if not slotIdx then
        if kn == "1" then slotIdx = 1 
        elseif kn == "2" then slotIdx = 2 
        elseif kn == "3" then slotIdx = 3 
        elseif kn == "4" then slotIdx = 4 
        end
    end

    -- [2] ID UNIK (Agar tidak bentrok)
    local myTouchID = 0
    if id == "Jump" then myTouchID = 50
    elseif id == "Dodge" then myTouchID = 51
    elseif slotIdx then myTouchID = 10 + slotIdx 
    else myTouchID = (string.byte(kn) % 20) + 20 end 

    -- Bersihkan tombol lama
    if ActiveVirtualKeys[id] then 
        if ActiveVirtualKeys[id].Button then ActiveVirtualKeys[id].Button:Destroy() end
        ActiveVirtualKeys[id]=nil
        if VirtualKeySelectors[id] then VirtualKeySelectors[id].BackgroundColor3=Theme.Element; VirtualKeySelectors[id].TextColor3=Theme.Text end
        if SkillMode == "SMART" and CurrentSmartKeyData and CurrentSmartKeyData.ID == id then CurrentSmartKeyData = nil end
        UpdateTransparencyFunc(); if ResizerUpdateFunc then ResizerUpdateFunc() end
    else
        -- [3] SETUP VISUAL TOMBOL
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 50, 0, 50); btn.Position = UDim2.new(0.5, 0, 0.5, 0); 
        btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0); 
        btn.Text = id; btn.TextColor3 = Theme.Accent; btn.Font = Enum.Font.GothamBold; btn.TextSize = 20; btn.TextScaled = true; btn.Parent = ScreenGui; btn.Selectable = false; btn.ZIndex = 60
        createCorner(btn, 12); createStroke(btn, Theme.Accent); MakeDraggable(btn, nil)
        
        local vData = {ID=id, Slot=slotIdx, Button=btn, KeyName=kn}
        local isWeaponKey = (kn == "1" or kn == "2" or kn == "3" or kn == "4")
        local isSkillKey  = table.find({"Z","X","C","V","F"}, kn)
        
        -- VARIABEL STATUS
        local isSpamming = false -- Untuk Jump/Dodge
        local isFingerDown = false -- Untuk validasi jari nempel

        -- [HELPER] Fungsi Spam Sederhana (Jump/Dodge)
        local function StartSpamLogic(actionFunc)
            isSpamming = true
            btn.BackgroundColor3 = Theme.Green; btn.TextColor3 = Theme.Bg
            
            task.spawn(function()
                while isSpamming and ActiveVirtualKeys[id] do
                    actionFunc()
                    task.wait(0.15) -- Delay Spam
                    -- Jika mode HOLD dan jari lepas, stop loop
                    if not isFingerDown and (Settings_Mode_Jump == "HOLD" or Settings_Mode_Dash == "HOLD") then break end
                end
                -- Reset Warna
                btn.BackgroundColor3 = Color3.new(0,0,0); btn.TextColor3 = Theme.Accent
            end)
        end

        -- [HELPER] Eksekusi Jump VIM
        local function DoJump()
            local jb = GetJumpButton()
            if jb then
                local fx = jb.AbsolutePosition.X + (jb.AbsoluteSize.X/2) + Jump_Offset.X
                local fy = jb.AbsolutePosition.Y + (jb.AbsoluteSize.Y/2) + Jump_Offset.Y
                VIM:SendTouchEvent(myTouchID, 0, fx, fy)
                task.wait(0.05)
                VIM:SendTouchEvent(myTouchID, 2, fx, fy)
            end
        end

        -- [4] SAAT TOMBOL DITEKAN
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                isFingerDown = true

                -- A. WEAPON KEY (1-4) [FIXED]
                if isWeaponKey then
                    -- Langsung ganti senjata menggunakan slotIdx yang sudah diperbaiki di atas
                    if slotIdx then equipWeapon(slotIdx, true) end
                    
                    -- Efek Visual Kedip (Biar tahu tombol ditekan)
                    task.spawn(function()
                        btn.BackgroundColor3 = Theme.Green; btn.TextColor3 = Theme.Bg
                        task.wait(0.1)
                        btn.BackgroundColor3 = Color3.new(0,0,0); btn.TextColor3 = Theme.Accent
                    end)
                    return
                end

                -- B. JUMP / DODGE / M1
                if id == "Jump" or id == "Dodge" or id == "M1" then
                    local mode = "HOLD"
                    if id == "Jump" then mode = Settings_Mode_Jump
                    elseif id == "Dodge" then mode = Settings_Mode_Dash
                    elseif id == "M1" then mode = Settings_Mode_M1 end

                    local action = nil
                    if id == "Jump" then action = DoJump
                    elseif id == "Dodge" then action = TriggerDodge
                    elseif id == "M1" then action = TapM1 end

                    if mode == "TOGGLE" then
                        if isSpamming then isSpamming = false else StartSpamLogic(action) end
                    else
                        -- Mode HOLD
                        StartSpamLogic(action)
                    end
                    return
                end

                -- C. SKILL LOGIC (Z-F)
                if isSkillKey then
                    -- Cek senjata dulu sebelum skill (Esensial)
                    if slotIdx and not isWeaponReady(slotIdx) then
                        equipWeapon(slotIdx, false)
                        task.wait(0.03)
                    end

                    if SkillMode == "INSTANT" then
                        local vp = Camera.ViewportSize
                        local x = (vp.X / 2) + M1_Offset.X
                        local y = (vp.Y / 2) + M1_Offset.Y
                        
                        pressKey(kn) -- Visual Game
                        task.wait(0.03)
                        VIM:SendTouchEvent(myTouchID, 0, x, y) -- Tekan VIM
                        task.wait(0.03)
                        
                        -- Warna Tetap Hitam
                        btn.BackgroundColor3 = Color3.new(0,0,0); btn.TextColor3 = Theme.Accent
                    else 
                        -- SMART MODE
                        pressKey(kn); CurrentSmartKeyData = vData; SmartTouchObject = input 
                        btn.BackgroundColor3 = Theme.Accent; btn.TextColor3 = Color3.new(0,0,0)
                    end
                end
            end
        end)

        -- [5] SAAT TOMBOL DILEPAS
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                isFingerDown = false
                
                -- Matikan Spam Jump/Dodge (Mode HOLD)
                if (id == "Jump" and Settings_Mode_Jump == "HOLD") or 
                   (id == "Dodge" and Settings_Mode_Dash == "HOLD") or 
                   (id == "M1" and Settings_Mode_M1 == "HOLD") then
                    isSpamming = false
                end
                
                -- Release Skill Instant
                if isSkillKey and SkillMode == "INSTANT" then
                    local vp = Camera.ViewportSize
                    local x = (vp.X / 2) + M1_Offset.X
                    local y = (vp.Y / 2) + M1_Offset.Y
                    
                    VIM:SendTouchEvent(myTouchID, 2, x, y) -- Lepas VIM
                    
                elseif SkillMode == "SMART" then
                    btn.BackgroundColor3 = Color3.new(0,0,0); btn.TextColor3 = Theme.Accent
                    if CurrentSmartKeyData and CurrentSmartKeyData.ID == id then CurrentSmartKeyData = nil end
                end
            end
        end)
        
        -- [6] SAFETY (Jari Tergelincir)
        btn.MouseLeave:Connect(function()
            isFingerDown = false
            if (id == "Jump" and Settings_Mode_Jump == "HOLD") then isSpamming = false end
            
            if isSkillKey and SkillMode == "INSTANT" then
                local vp = Camera.ViewportSize
                local x = (vp.X / 2) + M1_Offset.X
                local y = (vp.Y / 2) + M1_Offset.Y
                VIM:SendTouchEvent(myTouchID, 2, x, y)
            end
        end)
        
        ActiveVirtualKeys[id] = vData
        if VirtualKeySelectors[id] then VirtualKeySelectors[id].BackgroundColor3=Theme.Green; VirtualKeySelectors[id].TextColor3=Theme.Bg end
        UpdateTransparencyFunc(); if ResizerUpdateFunc then ResizerUpdateFunc() end
    end
end

CreateComboButtonFunc = function(idx, loadedSteps)
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(0, 60, 0, 60); btn.Position = UDim2.new(0.5, -30, 0.5, 0); btn.BackgroundColor3 = Theme.Sidebar; btn.Text = "C"..idx; btn.TextColor3 = Theme.Accent; btn.Font = Enum.Font.GothamBold; btn.TextSize = 18; btn.Parent = ScreenGui; btn.Selectable = false; btn.ZIndex = 70; createCorner(btn, 30); local st = createStroke(btn, Theme.Accent)
    MakeDraggable(btn, function() 
        if SkillMode == "INSTANT" then executeComboSequence(idx) 
        else 
            if SelectedComboID==idx then SelectedComboID=nil; btn.BackgroundColor3=Theme.Sidebar; btn.UIStroke.Color=Theme.Accent; isRunning=false 
            else 
                if SelectedComboID and Combos[SelectedComboID] then Combos[SelectedComboID].Button.BackgroundColor3=Theme.Sidebar; Combos[SelectedComboID].Button.UIStroke.Color=Theme.Accent end
                SelectedComboID=idx; btn.BackgroundColor3=Theme.Green; btn.UIStroke.Color=Theme.Green
                if CurrentSmartKeyData then local old=ActiveVirtualKeys[CurrentSmartKeyData.ID]; if old then old.Button.BackgroundColor3=Color3.fromRGB(0,0,0); old.Button.TextColor3=Theme.Accent end; CurrentSmartKeyData=nil end 
            end 
        end 
    end)
    local steps = loadedSteps or {}
    table.insert(Combos, {ID=idx, Name="C"..idx, Button=btn, Steps=steps})
    CurrentComboIndex = idx
    UpdateTransparencyFunc(); if ResizerUpdateFunc then ResizerUpdateFunc() end; RefreshEditorUI()
    if not loadedSteps then ShowNotification("Combo Added", Theme.Green) end
end

-- ==============================================================================
-- [9] LAYOUT SETTINGS TAB (CLEAN & COMPACT)
-- ==============================================================================
local LayPad = Instance.new("UIPadding"); LayPad.Parent=P_Lay; LayPad.PaddingLeft=UDim.new(0,10); LayPad.PaddingRight=UDim.new(0,10); LayPad.PaddingTop=UDim.new(0,10); LayPad.PaddingBottom=UDim.new(0,20)
local LayList = Instance.new("UIListLayout"); LayList.Parent=P_Lay; LayList.Padding=UDim.new(0, 8); LayList.SortOrder="LayoutOrder"; LayList.HorizontalAlignment="Center" -- Padding diperkecil jadi 8
LayList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() P_Lay.CanvasSize = UDim2.new(0, 0, 0, LayList.AbsoluteContentSize.Y + 30) end)

local function mkSection(title, order)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(1, 0, 0, 18); l.Text = title; l.TextColor3 = Theme.SubText; l.Font = Enum.Font.GothamBold; l.TextSize = 10; l.TextXAlignment = "Left"; l.BackgroundTransparency = 1; l.LayoutOrder = order; l.Parent = P_Lay; return l
end

-- [[ 1. GENERAL TOOLS ]]
mkSection("GENERAL TOOLS", 1)
local SetBox = Instance.new("Frame"); SetBox.Size = UDim2.new(1, 0, 0, 0); SetBox.AutomaticSize = Enum.AutomaticSize.Y; SetBox.BackgroundTransparency = 1; SetBox.LayoutOrder = 2; SetBox.Parent = P_Lay
local Grid1 = Instance.new("UIGridLayout"); Grid1.Parent=SetBox; Grid1.CellSize = UDim2.new(0.48, 0, 0, 32); Grid1.CellPadding = UDim2.new(0.04, 0, 0.04, 0) -- Tinggi tombol diperkecil jadi 32

LockBtn = mkTool("POS: UNLOCKED", Theme.Green, function() IsLayoutLocked=not IsLayoutLocked; updateLockState() end, SetBox)
local JoyToggle = mkTool("JOYSTICK: OFF", Theme.Red, nil, SetBox)
JoyToggle.MouseButton1Click:Connect(function() IsJoystickEnabled = not IsJoystickEnabled; JoyContainer.Visible = IsJoystickEnabled; if IsJoystickEnabled then JoyContainer.Position = UDim2.new(0.1, 0, 0.6, 0) end; JoyToggle.Text = IsJoystickEnabled and "JOYSTICK: ON" or "JOYSTICK: OFF"; JoyToggle.BackgroundColor3 = IsJoystickEnabled and Theme.Green or Theme.Red; updateLockState();  ResizerUpdateFunc()end)
mkTool("ADD COMBO", Theme.Accent, function() local idx = #Combos + 1; CreateComboButtonFunc(idx, nil) end, SetBox)
mkTool("DEL COMBO", Theme.Red, function() if #Combos<1 then return end; Combos[CurrentComboIndex].Button:Destroy(); table.remove(Combos, CurrentComboIndex); if #Combos > 0 then CurrentComboIndex=math.min(CurrentComboIndex, #Combos) else CurrentComboIndex=0 end; if ResizerUpdateFunc then ResizerUpdateFunc() end; RefreshEditorUI(); ShowNotification("Combo Deleted", Theme.Red); end, SetBox)

-- [[ 2. TRANSPARENCY ]]
local TransContainer = Instance.new("Frame"); TransContainer.Size = UDim2.new(1, 0, 0, 25); TransContainer.BackgroundTransparency = 1; TransContainer.LayoutOrder = 3; TransContainer.Parent = P_Lay
local TLbl = Instance.new("TextLabel"); TLbl.Size=UDim2.new(0.4,0,1,0); TLbl.Text="UI TRANSPARENCY"; TLbl.TextColor3=Theme.SubText; TLbl.Font=Enum.Font.GothamBold; TLbl.TextSize=10; TLbl.TextXAlignment="Left"; TLbl.BackgroundTransparency=1; TLbl.Parent=TransContainer
local TBg = Instance.new("Frame"); TBg.Size=UDim2.new(0.55,0,0,4); TBg.Position=UDim2.new(0.42,0,0.5,-2); TBg.BackgroundColor3=Theme.Stroke; TBg.Parent=TransContainer; createCorner(TBg,2)
local TKnob = Instance.new("TextButton"); TKnob.Size=UDim2.new(0,10,0,10); TKnob.Position=UDim2.new(0,0,0.5,-5); TKnob.BackgroundColor3=Theme.Accent; TKnob.Text=""; TKnob.Parent=TBg; TKnob.Selectable=false; createCorner(TKnob,6)
local dragT=false; TKnob.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragT=true end end); TrackConn(UserInputService.InputChanged:Connect(function(i) if dragT and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local p=math.clamp((i.Position.X-TBg.AbsolutePosition.X)/TBg.AbsoluteSize.X,0,1); TKnob.Position=UDim2.new(p,-5,0.5,-5); GlobalTransparency=p*0.9; UpdateTransparencyFunc() end end)); TrackConn(UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragT=false end end))

-- [[ 3. QUICK KEYS ]]
mkSection("QUICK KEYS (Tap to Show/Hide)", 4)
local VKBox = Instance.new("Frame"); VKBox.Size = UDim2.new(1, 0, 0, 0); VKBox.AutomaticSize = Enum.AutomaticSize.Y; VKBox.BackgroundTransparency = 1; VKBox.LayoutOrder = 5; VKBox.Parent = P_Lay
local Grid2 = Instance.new("UIGridLayout"); Grid2.Parent=VKBox; Grid2.CellSize = UDim2.new(0.18, 0, 0, 30); Grid2.CellPadding = UDim2.new(0.02, 0, 0.02, 0)
local keysList = {"1", "2", "3", "4", "Z", "X", "C", "V", "F", "M1", "Dodge", "Jump"}
for _, k in ipairs(keysList) do
    local btn = Instance.new("TextButton"); btn.Text=k; btn.BackgroundColor3=Theme.Element; btn.TextColor3=Theme.Text; btn.Font=Enum.Font.GothamBold; btn.TextSize=11; btn.Parent=VKBox; btn.Selectable=false; createCorner(btn,4)
    btn.MouseButton1Click:Connect(function() toggleVirtualKey(k, nil, k) end); VirtualKeySelectors[k] = btn
end

-- [[ 4. WEAPON BIND ]]
mkSection("CUSTOM WEAPON BIND", 6)
local VKeyAddBox = Instance.new("Frame"); VKeyAddBox.Size = UDim2.new(1, 0, 0, 75); VKeyAddBox.BackgroundColor3 = Theme.Sidebar; VKeyAddBox.LayoutOrder = 7; VKeyAddBox.Parent = P_Lay; createCorner(VKeyAddBox, 6); local VKeyPad = Instance.new("UIPadding"); VKeyPad.Parent=VKeyAddBox; VKeyPad.PaddingTop=UDim.new(0,8); VKeyPad.PaddingLeft=UDim.new(0,8); VKeyPad.PaddingRight=UDim.new(0,8)
local TypeBtn = Instance.new("TextButton"); TypeBtn.Size=UDim2.new(0.48,0,0,28); TypeBtn.Position=UDim2.new(0,0,0,0); TypeBtn.BackgroundColor3=Theme.Element; TypeBtn.Text="Melee"; TypeBtn.TextColor3=Theme.Text; TypeBtn.Parent=VKeyAddBox; createCorner(TypeBtn,6); TypeBtn.Font=Enum.Font.GothamBold; TypeBtn.TextSize=10
local KeyBtn = Instance.new("TextButton"); KeyBtn.Size=UDim2.new(0.48,0,0,28); KeyBtn.Position=UDim2.new(0.52,0,0,0); KeyBtn.BackgroundColor3=Theme.Element; KeyBtn.Text="Z"; KeyBtn.TextColor3=Theme.Text; KeyBtn.Parent=VKeyAddBox; createCorner(KeyBtn,6); KeyBtn.Font=Enum.Font.GothamBold; KeyBtn.TextSize=10
local AddVKeyBtn = Instance.new("TextButton"); AddVKeyBtn.Size=UDim2.new(1,0,0,28); AddVKeyBtn.Position=UDim2.new(0,0,0,35); AddVKeyBtn.BackgroundColor3=Theme.Green; AddVKeyBtn.Text="ADD BOUND KEY"; AddVKeyBtn.TextColor3=Theme.Bg; AddVKeyBtn.Font=Enum.Font.GothamBold; AddVKeyBtn.Parent=VKeyAddBox; createCorner(AddVKeyBtn,6); AddVKeyBtn.TextSize=11
local selW, selK = "Melee", "Z"
local SkillLimits = { ["Melee"] = {"Z", "X", "C"}, ["Fruit"] = {"Z", "X", "C", "V", "F"}, ["Sword"] = {"Z", "X"}, ["Gun"] = {"Z", "X"} }

local function UpdateAddButtonState()
    local id = selW .. " " .. selK
    if ActiveVirtualKeys[id] then AddVKeyBtn.Text = "DELETE (" .. id .. ")"; AddVKeyBtn.BackgroundColor3 = Theme.Red else AddVKeyBtn.Text = "ADD KEY (" .. id .. ")"; AddVKeyBtn.BackgroundColor3 = Theme.Green end
end
TypeBtn.MouseButton1Click:Connect(function() local tList={"Melee", "Fruit", "Sword", "Gun"}; local idx=table.find(tList, selW) or 0; selW=tList[(idx%#tList)+1]; TypeBtn.Text=selW; local validKeys = SkillLimits[selW] or {"Z", "X"}; if not table.find(validKeys, selK) then selK = validKeys[1] end; KeyBtn.Text = selK; UpdateAddButtonState() end)
KeyBtn.MouseButton1Click:Connect(function() local kList = SkillLimits[selW] or {"Z", "X"}; local idx = table.find(kList, selK) or 0; selK = kList[(idx % #kList) + 1]; KeyBtn.Text = selK; UpdateAddButtonState() end)
AddVKeyBtn.MouseButton1Click:Connect(function() local slot = 1; for i,v in ipairs(WeaponData) do if v.name == selW then slot = i break end end; local id = selW .. " " .. selK; toggleVirtualKey(selK, slot, id); UpdateAddButtonState() end)
UpdateAddButtonState()

-- [[ 5. RESIZER ]]
mkSection("RESIZER & VISIBILITY", 8)
local AdvBox = Instance.new("Frame"); AdvBox.Size = UDim2.new(1, 0, 0, 100); AdvBox.BackgroundColor3 = Theme.Sidebar; AdvBox.LayoutOrder = 9; AdvBox.Parent = P_Lay; createCorner(AdvBox,6); local AdvPad = Instance.new("UIPadding"); AdvPad.Parent=AdvBox; AdvPad.PaddingTop=UDim.new(0,8); AdvPad.PaddingLeft=UDim.new(0,8); AdvPad.PaddingRight=UDim.new(0,8)
local SelectBtn = Instance.new("TextButton"); SelectBtn.Size=UDim2.new(1,0,0,28); SelectBtn.Position=UDim2.new(0,0,0,0); SelectBtn.BackgroundColor3=Theme.Element; SelectBtn.Text="SELECT: NONE"; SelectBtn.TextColor3=Theme.Text; SelectBtn.Font=Enum.Font.GothamBold; SelectBtn.TextSize=10; SelectBtn.Parent=AdvBox; createCorner(SelectBtn,6)
local SizeSlider = Instance.new("Frame"); SizeSlider.Size=UDim2.new(1,0,0,4); SizeSlider.Position=UDim2.new(0,0,0,45); SizeSlider.BackgroundColor3=Theme.Stroke; SizeSlider.Parent=AdvBox; createCorner(SizeSlider,2)
local SizeKnob = Instance.new("TextButton"); SizeKnob.Size=UDim2.new(0,10,0,10); SizeKnob.Position=UDim2.new(0,-5,0.5,-5); SizeKnob.BackgroundColor3=Theme.Accent; SizeKnob.Text=""; SizeKnob.Parent=SizeSlider; SizeKnob.Selectable=false; createCorner(SizeKnob,6)
local SizeLabel = Instance.new("TextLabel"); SizeLabel.Size=UDim2.new(1,0,0,15); SizeLabel.Position=UDim2.new(0,0,-4,0); SizeLabel.Text="SIZE: 0%"; SizeLabel.TextColor3=Theme.SubText; SizeLabel.Font=Enum.Font.Gotham; SizeLabel.TextSize=9; SizeLabel.BackgroundTransparency=1; SizeLabel.Parent=SizeSlider
local VisBtn = Instance.new("TextButton"); VisBtn.Size=UDim2.new(1,0,0,28); VisBtn.Position=UDim2.new(0,0,0,55); VisBtn.BackgroundColor3=Theme.Green; VisBtn.Text="VISIBLE: ON"; VisBtn.TextColor3=Theme.Bg; VisBtn.Font=Enum.Font.GothamBold; VisBtn.TextSize=10; VisBtn.Parent=AdvBox; createCorner(VisBtn,6); VisBtn.Visible=false 

local ResizerIndex = 1
ResizerUpdateFunc = function() 
    ResizerList = {}
    if IsJoystickEnabled then
        table.insert(ResizerList, {Name="JOYSTICK", Obj=JoyOuter, Type="Joy"})
    end
    table.insert(ResizerList, {Name="TOGGLE BTN", Obj=ToggleBtn, Type="Btn"})
    for i, c in ipairs(Combos) do table.insert(ResizerList, {Name=c.Name, Obj=c.Button, Type="Btn"}) end
    for id, vData in pairs(ActiveVirtualKeys) do table.insert(ResizerList, {Name=id, Obj=vData.Button, Type="Btn"}) end
    if ResizerIndex > #ResizerList then ResizerIndex = 1 end
    if #ResizerList == 0 then SelectBtn.Text = "SELECT: NONE"; CurrentSelectedElement = nil; VisBtn.Visible=false return end
    local item = ResizerList[ResizerIndex]; SelectBtn.Text = "SELECT: " .. item.Name; CurrentSelectedElement = item 
    if item.Name == "TOGGLE BTN" then VisBtn.Visible = false else VisBtn.Visible = true; if item.Obj.Visible then VisBtn.Text="VISIBLE: ON"; VisBtn.BackgroundColor3=Theme.Green else VisBtn.Text="VISIBLE: OFF"; VisBtn.BackgroundColor3=Theme.Red end end
end

SelectBtn.MouseButton1Click:Connect(function() 
    if #ResizerList == 0 then return end
    ResizerIndex = ResizerIndex + 1; if ResizerIndex > #ResizerList then ResizerIndex = 1 end
    ResizerUpdateFunc()
    local item = CurrentSelectedElement; local currentSize = item.Obj.Size.X.Offset; local p = 0.5
    if item.Type == "Joy" then p = (currentSize - 100) / 150 else p = (currentSize - 30) / 70 end
    p = math.clamp(p, 0, 1); SizeKnob.Position = UDim2.new(p, -5, 0.5, -5); SizeLabel.Text = "SIZE: " .. math.floor(currentSize) .. "px" 
end)

VisBtn.MouseButton1Click:Connect(function() if CurrentSelectedElement then CurrentSelectedElement.Obj.Visible = not CurrentSelectedElement.Obj.Visible; ResizerUpdateFunc() end end)

local dragS = false
SizeKnob.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragS=true end end)
TrackConn(UserInputService.InputChanged:Connect(function(i) 
    if dragS and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) and CurrentSelectedElement then 
        local p = math.clamp((i.Position.X - SizeSlider.AbsolutePosition.X) / SizeSlider.AbsoluteSize.X, 0, 1); SizeKnob.Position = UDim2.new(p, -5, 0.5, -5); local newSize = 0
        if CurrentSelectedElement.Type == "Joy" then newSize = 100 + (p * 150); CurrentSelectedElement.Obj.Size = UDim2.new(0, newSize, 0, newSize); JoyContainer.Size = UDim2.new(0, newSize, 0, newSize + 30); createCorner(CurrentSelectedElement.Obj, newSize) 
        else newSize = 30 + (p * 70); CurrentSelectedElement.Obj.Size = UDim2.new(0, newSize, 0, newSize); if CurrentSelectedElement.Name:find("C") then createCorner(CurrentSelectedElement.Obj, newSize/2) end end
        SizeLabel.Text = "SIZE: " .. math.floor(newSize) .. "px" 
    end 
end))
TrackConn(UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragS=false end end))

-- ==============================================================================
-- [10] COMBO EDITOR TAB
-- ==============================================================================
local EmptyMsg = Instance.new("TextLabel"); EmptyMsg.Size=UDim2.new(1,0,1,0); EmptyMsg.Text="Go to LAYOUT tab to Add Combo first."; EmptyMsg.TextColor3=Theme.SubText; EmptyMsg.BackgroundTransparency=1; EmptyMsg.Font=Enum.Font.GothamBold; EmptyMsg.TextSize=14; EmptyMsg.Parent=P_Edit
local TopNav = Instance.new("Frame"); TopNav.Size=UDim2.new(1,0,0,35); TopNav.BackgroundTransparency=1; TopNav.Parent=P_Edit
local NavPrev = Instance.new("TextButton"); NavPrev.Size=UDim2.new(0,30,0,30); NavPrev.Position=UDim2.new(0,5,0,0); NavPrev.BackgroundColor3=Theme.Element; NavPrev.Text="<"; NavPrev.TextColor3=Theme.Accent; NavPrev.Font=Enum.Font.GothamBold; NavPrev.Parent=TopNav; createCorner(NavPrev,6)
local NavNext = Instance.new("TextButton"); NavNext.Size=UDim2.new(0,30,0,30); NavNext.Position=UDim2.new(1,-35,0,0); NavNext.BackgroundColor3=Theme.Element; NavNext.Text=">"; NavNext.TextColor3=Theme.Accent; NavNext.Font=Enum.Font.GothamBold; NavNext.Parent=TopNav; createCorner(NavNext,6)
local NavLbl = Instance.new("TextLabel"); NavLbl.Size=UDim2.new(0.6,0,1,0); NavLbl.Position=UDim2.new(0.2,0,0,0); NavLbl.Text="No Combo Selected"; NavLbl.TextColor3=Theme.Text; NavLbl.BackgroundTransparency=1; NavLbl.Font=Enum.Font.GothamBold; NavLbl.TextSize=14; NavLbl.Parent=TopNav
local EditScroll=Instance.new("ScrollingFrame"); EditScroll.Size=UDim2.new(1,0,0.75,0); EditScroll.Position=UDim2.new(0,0,0.12,0); EditScroll.BackgroundTransparency=1; EditScroll.ScrollBarThickness=3; EditScroll.Parent=P_Edit; local EditList=Instance.new("UIListLayout"); EditList.Parent=EditScroll; EditList.Padding=UDim.new(0,8)
local BottomBar = Instance.new("Frame"); BottomBar.Size=UDim2.new(1,0,0,40); BottomBar.Position=UDim2.new(0,0,1,0); BottomBar.AnchorPoint=Vector2.new(0,1); BottomBar.BackgroundTransparency=1; BottomBar.Parent=P_Edit
local AddAction=Instance.new("TextButton"); AddAction.Size=UDim2.new(1,0,1,-5); AddAction.Text="+ ADD ACTION"; AddAction.BackgroundColor3=Theme.Green; AddAction.TextColor3=Theme.Bg; AddAction.Font=Enum.Font.GothamBold; AddAction.Parent=BottomBar; AddAction.Selectable=false; createCorner(AddAction,6)

RefreshEditorUI = function()
    if CurrentComboIndex == 0 or not Combos[CurrentComboIndex] then NavLbl.Text="No Combo Selected"; EmptyMsg.Visible=true; EditScroll.Visible=false; BottomBar.Visible=false; TopNav.Visible=false return end
    EmptyMsg.Visible=false; EditScroll.Visible=true; BottomBar.Visible=true; TopNav.Visible=true; local d = Combos[CurrentComboIndex]; NavLbl.Text = d.Name
    for _,c in pairs(EditScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    EditScroll.CanvasSize = UDim2.new(0,0,0, (#d.Steps * 65) + 50)
    for i,s in ipairs(d.Steps) do
        local h = (s.IsHold) and 85 or 60; local r = Instance.new("Frame"); r.Size=UDim2.new(1,0,0,h); r.BackgroundColor3=Theme.Element; r.Parent=EditScroll; createCorner(r,6)
        local top = Instance.new("Frame"); top.Size=UDim2.new(1,0,0,30); top.BackgroundTransparency=1; top.Parent=r
        local w = Instance.new("TextButton"); w.Size=UDim2.new(0.25,0,1,0); w.Position=UDim2.new(0.02,0,0,0); w.Text=WeaponData[s.Slot].name; w.TextColor3=WeaponData[s.Slot].color; w.BackgroundTransparency=1; w.Parent=top; w.Font=Enum.Font.GothamBold; w.TextSize=11; w.TextXAlignment="Left"; w.Selectable=false; w.MouseButton1Click:Connect(function() s.Slot=(s.Slot%4)+1; s.Key=WeaponData[s.Slot].keys[1]; RefreshEditorUI() end)
        local k = Instance.new("TextButton"); k.Size=UDim2.new(0.15,0,1,0); k.Position=UDim2.new(0.3,0,0,0); k.Text="["..s.Key.."]"; k.TextColor3=Theme.Text; k.BackgroundTransparency=1; k.Parent=top; k.Font=Enum.Font.GothamBold; k.TextSize=11; k.Selectable=false; k.MouseButton1Click:Connect(function() local l=WeaponData[s.Slot].keys; local idx=1; for j,v in ipairs(l) do if v==s.Key then idx=j end end; s.Key=l[(idx%#l)+1]; RefreshEditorUI() end)
        local m = Instance.new("TextButton"); m.Size=UDim2.new(0.25,0,0.7,0); m.Position=UDim2.new(0.5,0,0.15,0); m.Text=s.IsHold and "HOLD" or "TAP"; m.BackgroundColor3=s.IsHold and Theme.Accent or Theme.Green; m.TextColor3=Theme.Bg; m.Parent=top; m.Font=Enum.Font.GothamBold; m.TextSize=10; m.Selectable=false; createCorner(m,4); m.MouseButton1Click:Connect(function() s.IsHold = not s.IsHold; RefreshEditorUI() end)
        local x = Instance.new("TextButton"); x.Size=UDim2.new(0.1,0,1,0); x.Position=UDim2.new(0.9,0,0,0); x.Text="X"; x.TextColor3=Theme.Red; x.BackgroundTransparency=1; x.Parent=top; x.TextSize=11; x.Font=Enum.Font.GothamBold; x.Selectable=false; x.MouseButton1Click:Connect(function() table.remove(d.Steps, i); RefreshEditorUI() end)
        
        local function mkSlid(y, t, v, mx, cb, c) 
            local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,25); f.Position=UDim2.new(0,0,0,y); f.BackgroundTransparency=1; f.Parent=r; 
            local txt=Instance.new("TextLabel"); txt.Size=UDim2.new(0.3,0,1,0); txt.Position=UDim2.new(0.02,0,0,0); txt.Text=string.format(t,v); txt.TextColor3=c; txt.BackgroundTransparency=1; txt.TextSize=9; txt.TextXAlignment="Left"; txt.Parent=f; 
            local bg=Instance.new("Frame"); bg.Size=UDim2.new(0.6,0,0,4); bg.Position=UDim2.new(0.35,0,0.5,-2); bg.BackgroundColor3=Theme.Stroke; bg.Parent=f; createCorner(bg,2); 
            local kn=Instance.new("TextButton"); kn.Size=UDim2.new(0,10,0,10); kn.BackgroundColor3=Theme.Text; kn.Text=""; kn.Parent=bg; kn.Selectable=false; createCorner(kn,5); kn.Position=UDim2.new(math.clamp(v/mx,0,1),-5,0.5,-5); 
            local sl=false; kn.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseButton1 then sl=true end end); 
            TrackConn(UserInputService.InputChanged:Connect(function(inp) if sl and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then local p=math.clamp((inp.Position.X-bg.AbsolutePosition.X)/bg.AbsoluteSize.X,0,1); kn.Position=UDim2.new(p,-5,0.5,-5); cb(p); txt.Text=string.format(t, (p*mx)) end end)); 
            TrackConn(UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseButton1 then sl=false end end)) 
        end
        mkSlid(30, "Wait: +%.1fs", s.Delay or 0, 2.0, function(p) s.Delay=math.floor(p*2*10)/10 end, Theme.SubText)
        if s.IsHold then mkSlid(55, "Hold: %.1fs", s.HoldTime or 0.1, 3.0, function(p) s.HoldTime=math.floor(p*3*10)/10 end, Theme.Accent) end
    end
end
AddAction.MouseButton1Click:Connect(function() table.insert(Combos[CurrentComboIndex].Steps, {Slot=1, Key="Z", Delay=0, IsHold=false, HoldTime=0.5}); RefreshEditorUI() end)
NavPrev.MouseButton1Click:Connect(function() if #Combos>1 then CurrentComboIndex=CurrentComboIndex-1; if CurrentComboIndex<1 then CurrentComboIndex=#Combos end; RefreshEditorUI() end end)
NavNext.MouseButton1Click:Connect(function() if #Combos>1 then CurrentComboIndex=CurrentComboIndex+1; if CurrentComboIndex>#Combos then CurrentComboIndex=1 end; RefreshEditorUI() end end)

-- ==============================================================================
-- [11] SAVE & LOAD IMPLEMENTATION
-- ==============================================================================
local function UpdateCrosshairToVIM()
    if not CrosshairUI then return end
    local vp = Camera.ViewportSize
    local vimX = (vp.X / 2) + M1_Offset.X
    local vimY = (vp.Y / 2) + M1_Offset.Y
    CrosshairUI.Position = UDim2.new(0, vimX, 0, vimY)
    pcall(function()
        for _, c in pairs(P_Set:GetChildren()) do
            if c:IsA("TextButton") and c.Text:find("X:") then
                c.Text = "X: " .. math.floor(vimX) .. " | Y: " .. math.floor(vimY)
            end
        end
    end)
end

local function GetCurrentState()
    local function getLayout(obj)
        if not obj then return {px=0, po=0, py=0, poy=0, sx=0, so=0, sy=0, soy=0} end
        return {px=obj.Position.X.Scale, po=obj.Position.X.Offset, py=obj.Position.Y.Scale, poy=obj.Position.Y.Offset, sx=obj.Size.X.Scale, so=obj.Size.X.Offset, sy=obj.Size.Y.Scale, soy=obj.Size.Y.Offset}
    end
    local data = { Transparency = GlobalTransparency, JoystickEnabled = IsJoystickEnabled, SkillMode = SkillMode, LayoutLocked = IsLayoutLocked, Pos_Window = getLayout(Window), Pos_Toggle = getLayout(ToggleBtn), Pos_Joy = getLayout(JoyContainer), Pos_JoyOuter = getLayout(JoyOuter), Combos = {}, VirtualKeys = {}, M1_OffsetX = M1_Offset.X, M1_OffsetY = M1_Offset.Y, Settings_Mode_M1 = Settings_Mode_M1, Settings_Mode_Dash = Settings_Mode_Dash, Settings_Mode_Jump = Settings_Mode_Jump, Jump_OffsetX = Jump_Offset.X, Jump_OffsetY = Jump_Offset.Y, AutoLoad = IsAutoLoad}
    for _, combo in ipairs(Combos) do if combo.Button then table.insert(data.Combos, {ID = combo.ID, Name = combo.Name, Steps = combo.Steps, Layout = getLayout(combo.Button)}) end end
    for id, vData in pairs(ActiveVirtualKeys) do if vData.Button then table.insert(data.VirtualKeys, {ID = id, KeyName = vData.KeyName, Slot = vData.Slot, Layout = getLayout(vData.Button)}) end end
    return data
end

local function SaveToFile(configName, data)
    local fullData = {}
    if isfile(FileName) then
        local success, result = pcall(function() local content = readfile(FileName); if content == "" then return {} end; return HttpService:JSONDecode(content) end)
        if success and type(result) == "table" then fullData = result end
    end
    fullData[configName] = data; fullData["LastUsed"] = configName
    writefile(FileName, HttpService:JSONEncode(fullData))
    ShowNotification("Saved: " .. configName, Theme.Green)
end

-- ==============================================================================
-- TAB SETTINGS & CALIBRATION
-- ==============================================================================

-- [[ 1. SETUP SCROLLING FRAME (Agar Rapi & Tidak Tembus) ]]
-- Membersihkan isi lama jika ada reload
for _, c in pairs(P_Set:GetChildren()) do c:Destroy() end

local SettingsScroll = Instance.new("ScrollingFrame")
SettingsScroll.Name = "SettingsScroll"
SettingsScroll.Size = UDim2.new(1, 0, 1, 0)
SettingsScroll.BackgroundTransparency = 1
SettingsScroll.BorderSizePixel = 0
SettingsScroll.ScrollBarThickness = 4
SettingsScroll.ScrollBarImageColor3 = Theme.Accent
SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 0) -- Akan otomatis membesar
SettingsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y -- Fitur otomatis Roblox
SettingsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
SettingsScroll.ClipsDescendants = true -- Mencegah konten tembus keluar
SettingsScroll.Parent = P_Set

local SetPad = Instance.new("UIPadding")
SetPad.PaddingLeft = UDim.new(0, 10)
SetPad.PaddingRight = UDim.new(0, 10)
SetPad.PaddingTop = UDim.new(0, 10)
SetPad.PaddingBottom = UDim.new(0, 20)
SetPad.Parent = SettingsScroll

local SetList = Instance.new("UIListLayout")
SetList.Padding = UDim.new(0, 12)
SetList.HorizontalAlignment = Enum.HorizontalAlignment.Center
SetList.SortOrder = Enum.SortOrder.LayoutOrder
SetList.Parent = SettingsScroll

-- [HELPER] Section Title Function
local function mkSetSection(title, order)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 18)
    l.Text = title
    l.TextColor3 = Theme.SubText
    l.Font = Enum.Font.GothamBold
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.BackgroundTransparency = 1
    l.LayoutOrder = order
    l.Parent = SettingsScroll -- Masuk ke Scroll
    return l
end

-- [[ 2. LOGIC CROSSHAIR M1 (RED) ]]
if CrosshairUI then CrosshairUI:Destroy() end 
CrosshairUI = Instance.new("ImageButton")
CrosshairUI.Name = "M1_Crosshair"
CrosshairUI.Size = UDim2.new(0, 50, 0, 50)
CrosshairUI.AnchorPoint = Vector2.new(0.5, 0.5)
CrosshairUI.BackgroundTransparency = 1
-- Menggunakan asset ID blank atau crosshair transparan agar kita bisa pakai Frame custom
CrosshairUI.Image = "" 
CrosshairUI.Parent = ScreenGui
CrosshairUI.Visible = false
CrosshairUI.ZIndex = 9999

-- Garis Visual M1
local CH_V = Instance.new("Frame"); CH_V.Size=UDim2.new(0,2,1,0); CH_V.Position=UDim2.new(0.5,-1,0,0); CH_V.BackgroundColor3=Theme.Red; CH_V.Parent=CrosshairUI; CH_V.BorderSizePixel=0
local CH_H = Instance.new("Frame"); CH_H.Size=UDim2.new(1,0,0,2); CH_H.Position=UDim2.new(0,0,0.5,-1); CH_H.BackgroundColor3=Theme.Red; CH_H.Parent=CrosshairUI; CH_H.BorderSizePixel=0

local draggingCH, dragInputCH
CrosshairUI.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingCH = true; CH_V.BackgroundColor3 = Theme.Green; CH_H.BackgroundColor3 = Theme.Green
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                draggingCH = false; CH_V.BackgroundColor3 = Theme.Red; CH_H.BackgroundColor3 = Theme.Red
                pcall(function() if CalibBtn then CalibBtn.Text = "FINISH" end end)
            end
        end)
    end
end)
CrosshairUI.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInputCH = input end end)
TrackConn(UserInputService.InputChanged:Connect(function(input)
    if input == dragInputCH and draggingCH then
        local vp = Camera.ViewportSize; M1_Offset = Vector2.new(input.Position.X - (vp.X / 2), input.Position.Y - (vp.Y / 2)); UpdateCrosshairToVIM()
    end
end))
TrackConn(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() UpdateCrosshairToVIM() end))

-- [[ 3. LOGIC CROSSHAIR JUMP (BLUE) - PURE CALIBRATION ]]
if JumpCrosshairUI then JumpCrosshairUI:Destroy() end 

JumpCrosshairUI = Instance.new("ImageButton")
JumpCrosshairUI.Name = "Jump_Crosshair"
JumpCrosshairUI.Size = UDim2.new(0, 60, 0, 60)
JumpCrosshairUI.AnchorPoint = Vector2.new(0.5, 0.5) -- Memastikan pusat UI sebagai titik acuan
JumpCrosshairUI.BackgroundTransparency = 1
JumpCrosshairUI.Image = "" 
JumpCrosshairUI.Parent = ScreenGui
JumpCrosshairUI.Visible = false
JumpCrosshairUI.ZIndex = 9999

-- Garis Crosshair Biru (Simetris Sempurna)
local JCH_V = Instance.new("Frame"); JCH_V.Size=UDim2.new(0,2,1,0); JCH_V.Position=UDim2.new(0.5,-1,0,0); JCH_V.BackgroundColor3=Theme.Blue; JCH_V.Parent=JumpCrosshairUI; JCH_V.BorderSizePixel=0
local JCH_H = Instance.new("Frame"); JCH_H.Size=UDim2.new(1,0,0,2); JCH_H.Position=UDim2.new(0,0,0.5,-1); JCH_H.BackgroundColor3=Theme.Blue; JCH_H.Parent=JumpCrosshairUI; JCH_H.BorderSizePixel=0

local function UpdateJumpVisual()
    if not JumpCrosshairUI.Visible then return end
    local jBtn = GetJumpButton()
    
    -- Ambil posisi tengah tombol asli
    local absPos = jBtn.AbsolutePosition
    local absSize = jBtn.AbsoluteSize
    local baseX = absPos.X + (absSize.X / 2)
    local baseY = absPos.Y + (absSize.Y / 2)

    -- Tempatkan UI Target Biru tepat di atas tombol + Offset user
    JumpCrosshairUI.Position = UDim2.new(0, baseX + Jump_Offset.X, 0, baseY + Jump_Offset.Y)
end

-- Update posisi setiap frame agar nempel terus ke tombol
TrackConn(RunService.RenderStepped:Connect(UpdateJumpVisual))

local draggingJump, dragInputJump
JumpCrosshairUI.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingJump = true
        -- Feedback Visual saat digeser (Warna Hijau)
        JCH_V.BackgroundColor3 = Theme.Green; JCH_H.BackgroundColor3 = Theme.Green
        input.Changed:Connect(function() 
            if input.UserInputState == Enum.UserInputState.End then 
                draggingJump = false 
                JCH_V.BackgroundColor3 = Theme.Blue; JCH_H.BackgroundColor3 = Theme.Blue
            end 
        end)
    end
end)

JumpCrosshairUI.InputChanged:Connect(function(input) 
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then 
        dragInputJump = input 
    end 
end)

TrackConn(UserInputService.InputChanged:Connect(function(input)
    if input == dragInputJump and draggingJump then
        local jBtn = GetJumpButton()
        
        -- Hitung Pusat Referensi
        local absPos = jBtn.AbsolutePosition
        local absSize = jBtn.AbsoluteSize
        local centerX = absPos.X + (absSize.X / 2)
        local centerY = absPos.Y + (absSize.Y / 2)
        
        -- Selisih antara jari user dengan pusat tombol adalah Offset-nya
        Jump_Offset = Vector2.new(input.Position.X - centerX, input.Position.Y - centerY)
    end
end))

-- [[ 4. CALIBRATION UI (GRID LAYOUT) ]]
mkSetSection("TOUCH CALIBRATION", 1)

local CalibBox = Instance.new("Frame")
CalibBox.Size = UDim2.new(1, 0, 0, 40)
CalibBox.BackgroundTransparency = 1
CalibBox.LayoutOrder = 2
CalibBox.Parent = SettingsScroll -- Masuk ke Scroll

local CalibGrid = Instance.new("UIGridLayout")
CalibGrid.Parent = CalibBox
CalibGrid.CellSize = UDim2.new(0.48, 0, 1, 0)
CalibGrid.CellPadding = UDim2.new(0.04, 0, 0, 0)

-- M1 Calibration Button
local CalibBtn = mkTool("CALIBRATE M1", Theme.Element, nil, CalibBox)
CalibBtn.MouseButton1Click:Connect(function()
    local isVisible = not CrosshairUI.Visible; CrosshairUI.Visible = isVisible
    if isVisible then 
        UpdateCrosshairToVIM(); CalibBtn.BackgroundColor3 = Theme.Red; CalibBtn.TextColor3 = Theme.Bg; CalibBtn.Text = "FINISH"
        ShowNotification("Drag RED Crosshair to Aim Point", Theme.Accent)
    else 
        CalibBtn.Text = "CALIBRATE M1"; CalibBtn.BackgroundColor3 = Theme.Element; CalibBtn.TextColor3 = Theme.Text; ShowNotification("M1 Position Saved!", Theme.Green) 
    end
end)

-- Jump Calibration Button
local CalibJumpBtn = mkTool("CALIBRATE JUMP", Theme.Element, nil, CalibBox)
CalibJumpBtn.MouseButton1Click:Connect(function()
    local isVisible = not JumpCrosshairUI.Visible; JumpCrosshairUI.Visible = isVisible
    if isVisible then 
        CalibJumpBtn.BackgroundColor3 = Theme.Blue; CalibJumpBtn.TextColor3 = Theme.Bg; CalibJumpBtn.Text = "FINISH"
        ShowNotification("Drag BLUE Target to Adjust Jump", Theme.Blue)
        UpdateJumpVisual()
    else 
        CalibJumpBtn.Text = "CALIBRATE JUMP"; CalibJumpBtn.BackgroundColor3 = Theme.Element; CalibJumpBtn.TextColor3 = Theme.Text; ShowNotification("Jump Position Saved!", Theme.Green) 
    end
end)

local InfoLbl = Instance.new("TextLabel"); InfoLbl.Size = UDim2.new(1, 0, 0, 15); InfoLbl.Text = "RED = M1 Aim  |  BLUE = Jump Position"; InfoLbl.TextColor3 = Theme.SubText; InfoLbl.BackgroundTransparency = 1; InfoLbl.Font = Enum.Font.Gotham; InfoLbl.TextSize = 10; InfoLbl.LayoutOrder = 3; InfoLbl.Parent = SettingsScroll

-- [[ 5. SKILL EXECUTION MODE ]]
mkSetSection("SKILL EXECUTION MODE", 4)
local ModeContainer = Instance.new("Frame"); ModeContainer.Size = UDim2.new(1, 0, 0, 35); ModeContainer.BackgroundTransparency = 1; ModeContainer.LayoutOrder = 5; ModeContainer.Parent = SettingsScroll
ModeBtn = mkTool("MODE: INSTANT", Theme.Green, function() 
    if SkillMode == "INSTANT" then 
        SkillMode = "SMART"; ModeBtn.Text = "MODE: SMART TAP"; ModeBtn.BackgroundColor3 = Theme.Blue 
    else 
        SkillMode = "INSTANT"; ModeBtn.Text = "MODE: INSTANT"; ModeBtn.BackgroundColor3 = Theme.Green; CurrentSmartKeyData=nil; SelectedComboID=nil 
    end 
end, ModeContainer)
ModeBtn.Size = UDim2.new(1, 0, 1, 0)

-- [[ 6. AUTO BUTTON SETTINGS ]]
mkSetSection("AUTO BUTTON SETTINGS", 6)
local AutoBox = Instance.new("Frame"); AutoBox.Size = UDim2.new(1, 0, 0, 115); AutoBox.BackgroundColor3 = Theme.Sidebar; AutoBox.LayoutOrder = 7; AutoBox.Parent = SettingsScroll; createCorner(AutoBox,6)
local AutoPad = Instance.new("UIPadding"); AutoPad.Parent=AutoBox; AutoPad.PaddingTop=UDim.new(0,10); AutoPad.PaddingLeft=UDim.new(0,10); AutoPad.PaddingRight=UDim.new(0,10); AutoPad.PaddingBottom=UDim.new(0,10)
local AutoList = Instance.new("UIListLayout"); AutoList.Parent=AutoBox; AutoList.Padding=UDim.new(0,8); AutoList.SortOrder="LayoutOrder"

SetM1Btn = mkTool("AUTO M1: HOLD MODE", Theme.Element, function()
    if Settings_Mode_M1 == "HOLD" then Settings_Mode_M1 = "TOGGLE"; SetM1Btn.Text = "AUTO M1: TOGGLE MODE (ON/OFF)"; SetM1Btn.BackgroundColor3 = Theme.Blue; SetM1Btn.TextColor3 = Theme.Bg
    else Settings_Mode_M1 = "HOLD"; SetM1Btn.Text = "AUTO M1: HOLD MODE"; SetM1Btn.BackgroundColor3 = Theme.Element; SetM1Btn.TextColor3 = Theme.SubText; IsAutoM1_Active = false end
end, AutoBox)
SetM1Btn.Size = UDim2.new(1, 0, 0, 28)

SetDashBtn = mkTool("AUTO DASH: HOLD MODE", Theme.Element, function()
    if Settings_Mode_Dash == "HOLD" then Settings_Mode_Dash = "TOGGLE"; SetDashBtn.Text = "AUTO DASH: TOGGLE MODE (ON/OFF)"; SetDashBtn.BackgroundColor3 = Theme.Blue; SetDashBtn.TextColor3 = Theme.Bg
    else Settings_Mode_Dash = "HOLD"; SetDashBtn.Text = "AUTO DASH: HOLD MODE"; SetDashBtn.BackgroundColor3 = Theme.Element; SetDashBtn.TextColor3 = Theme.SubText; IsAutoDashing = false end
end, AutoBox)
SetDashBtn.Size = UDim2.new(1, 0, 0, 28)

SetJumpBtn = mkTool("AUTO JUMP: HOLD MODE", Theme.Element, function()
    if Settings_Mode_Jump == "HOLD" then Settings_Mode_Jump = "TOGGLE"; SetJumpBtn.Text = "AUTO JUMP: TOGGLE MODE (ON/OFF)"; SetJumpBtn.BackgroundColor3 = Theme.Blue; SetJumpBtn.TextColor3 = Theme.Bg
    else Settings_Mode_Jump = "HOLD"; SetJumpBtn.Text = "AUTO JUMP: HOLD MODE"; SetJumpBtn.BackgroundColor3 = Theme.Element; SetJumpBtn.TextColor3 = Theme.SubText end
end, AutoBox)
SetJumpBtn.Size = UDim2.new(1, 0, 0, 28)

-- Spacer agar scroll tidak mentok bawah
local Spacer = Instance.new("Frame")
Spacer.Size = UDim2.new(1,0,0,20)
Spacer.BackgroundTransparency = 1
Spacer.LayoutOrder = 100
Spacer.Parent = SettingsScroll

UpdateCrosshairToVIM()

-- === SYSTEM TAB ===
local SysList = Instance.new("UIListLayout"); SysList.Parent=P_Sys; SysList.Padding=UDim.new(0,10); SysList.HorizontalAlignment="Center"
AutoLoadBtn = mkTool("AUTO LOAD: ON", Theme.Green, nil, P_Sys)
AutoLoadBtn.Size = UDim2.new(0.9, 0, 0, 45)

AutoLoadBtn.MouseButton1Click:Connect(function()
    IsAutoLoad = not IsAutoLoad
    if IsAutoLoad then
        AutoLoadBtn.Text = "AUTO LOAD: ON"
        AutoLoadBtn.BackgroundColor3 = Theme.Green
        AutoLoadBtn.TextColor3 = Theme.Bg
    else
        AutoLoadBtn.Text = "AUTO LOAD: OFF"
        AutoLoadBtn.BackgroundColor3 = Theme.Red
        AutoLoadBtn.TextColor3 = Theme.Text
    end
end)
local SaveBtn = mkTool("SAVE CONFIG", Theme.Blue, function() 
    if CurrentConfigName then 
        ShowPopup("SAVE OPTIONS", function(c) 
            local b1 = Instance.new("TextButton"); b1.Size=UDim2.new(0.9,0,0,35); b1.Position=UDim2.new(0.05,0,0,0); b1.BackgroundColor3=Theme.Bg; b1.Text="Overwrite '"..CurrentConfigName.."'"; b1.TextColor3=Theme.Accent; b1.Parent=c; createCorner(b1,6); b1.ZIndex=2004; b1.MouseButton1Click:Connect(function() SaveToFile(CurrentConfigName, GetCurrentState()); ClosePopup() end); 
            local b2 = Instance.new("TextButton"); b2.Size=UDim2.new(0.9,0,0,35); b2.Position=UDim2.new(0.05,0,0,40); b2.BackgroundColor3=Theme.Bg; b2.Text="Save as New"; b2.TextColor3=Theme.Text; b2.Parent=c; createCorner(b2,6); b2.ZIndex=2004; b2.MouseButton1Click:Connect(function() ClosePopup(); ShowPopup("NEW CONFIG", function(c2) local box = Instance.new("TextBox"); box.Size=UDim2.new(0.9,0,0,35); box.Position=UDim2.new(0.05,0,0,0); box.BackgroundColor3=Theme.Element; box.Text=""; box.PlaceholderText="Enter Name..."; box.TextColor3=Theme.Text; box.Parent=c2; createCorner(box,6); box.ZIndex=2004; local confirm = Instance.new("TextButton"); confirm.Size=UDim2.new(0.9,0,0,35); confirm.Position=UDim2.new(0.05,0,0,40); confirm.BackgroundColor3=Theme.Green; confirm.Text="CREATE"; confirm.TextColor3=Theme.Bg; confirm.Parent=c2; createCorner(confirm,6); confirm.ZIndex=2004; confirm.MouseButton1Click:Connect(function() if box.Text~="" then SaveToFile(box.Text, GetCurrentState()); CurrentConfigName=box.Text; ClosePopup() end end); return 100 end) end); return 100 
        end) 
    else 
        ShowPopup("NEW CONFIG", function(c) local box = Instance.new("TextBox"); box.Size=UDim2.new(0.9,0,0,35); box.Position=UDim2.new(0.05,0,0,0); box.BackgroundColor3=Theme.Element; box.Text=""; box.PlaceholderText="Enter Name..."; box.TextColor3=Theme.Text; box.Parent=c; createCorner(box,6); box.ZIndex=2004; local confirm = Instance.new("TextButton"); confirm.Size=UDim2.new(0.9,0,0,35); confirm.Position=UDim2.new(0.05,0,0,40); confirm.BackgroundColor3=Theme.Green; confirm.Text="CREATE"; confirm.TextColor3=Theme.Bg; confirm.Parent=c; createCorner(confirm,6); confirm.ZIndex=2004; confirm.MouseButton1Click:Connect(function() if box.Text~="" then SaveToFile(box.Text, GetCurrentState()); CurrentConfigName=box.Text; ClosePopup() end end); return 100 end) 
    end 
end, P_Sys); SaveBtn.Size=UDim2.new(0.9,0,0,45)

function LoadSpecific(configName)
    if not isfile(FileName) then return end
    
    -- 1. Baca File
    local successRead, fileContent = pcall(function() return readfile(FileName) end)
    if not successRead or fileContent == "" then return end
    
    -- 2. Decode JSON
    local successDecode, fileData = pcall(function() return HttpService:JSONDecode(fileContent) end)
    if not successDecode or type(fileData) ~= "table" or not fileData[configName] then return end
    
    -- 3. Terapkan Data (Pcall)
    local applySuccess, err = pcall(function()
        -- [!] DEFINISI VARIABEL DATA ADA DI SINI
        local data = fileData[configName]
        
        -- ====================================================
        -- [PERBAIKAN] LOGIKA SETTINGS DIPINDAHKAN KE SINI
        -- ====================================================
        if data.AutoLoad ~= nil then
            IsAutoLoad = data.AutoLoad
            if AutoLoadBtn then
                if IsAutoLoad then
                    AutoLoadBtn.Text = "AUTO LOAD: ON"
                    AutoLoadBtn.BackgroundColor3 = Theme.Green
                    AutoLoadBtn.TextColor3 = Theme.Bg
                else
                    AutoLoadBtn.Text = "AUTO LOAD: OFF"
                    AutoLoadBtn.BackgroundColor3 = Theme.Red
                    AutoLoadBtn.TextColor3 = Theme.Text
                end
            end
        end
        -- Load Settings Mode M1
        if data.Settings_Mode_M1 then
            Settings_Mode_M1 = data.Settings_Mode_M1
            if SetM1Btn then
                if Settings_Mode_M1 == "TOGGLE" then
                    SetM1Btn.Text = "AUTO M1: TOGGLE MODE (ON/OFF)"
                    SetM1Btn.BackgroundColor3 = Theme.Blue
                    SetM1Btn.TextColor3 = Theme.Bg
                else
                    SetM1Btn.Text = "AUTO M1: HOLD MODE"
                    SetM1Btn.BackgroundColor3 = Theme.Element
                    SetM1Btn.TextColor3 = Theme.SubText
                end
            end
        end

        -- Load Settings Mode Dash
        if data.Settings_Mode_Dash then
            Settings_Mode_Dash = data.Settings_Mode_Dash
            if SetDashBtn then
                if Settings_Mode_Dash == "TOGGLE" then
                    SetDashBtn.Text = "AUTO DASH: TOGGLE MODE (ON/OFF)"
                    SetDashBtn.BackgroundColor3 = Theme.Blue
                    SetDashBtn.TextColor3 = Theme.Bg
                else
                    SetDashBtn.Text = "AUTO DASH: HOLD MODE"
                    SetDashBtn.BackgroundColor3 = Theme.Element
                    SetDashBtn.TextColor3 = Theme.SubText
                end
            end
        end

        if data.Settings_Mode_Jump then
            Settings_Mode_Jump = data.Settings_Mode_Jump
            if SetJumpBtn then
                if Settings_Mode_Jump == "TOGGLE" then
                    SetJumpBtn.Text = "AUTO JUMP: TOGGLE MODE (ON/OFF)"
                    SetJumpBtn.BackgroundColor3 = Theme.Blue
                    SetJumpBtn.TextColor3 = Theme.Bg
                else
                    SetJumpBtn.Text = "AUTO JUMP: HOLD MODE"
                    SetJumpBtn.BackgroundColor3 = Theme.Element
                    SetJumpBtn.TextColor3 = Theme.SubText
                end
            end
        end

        -- ====================================================
        -- LANJUTAN LOGIKA LAINNYA
        -- ====================================================

        local function applyLayout(obj, layoutData)
            if not obj or not layoutData then return end
            obj.Position = UDim2.new(layoutData.px, layoutData.po, layoutData.py, layoutData.poy)
            obj.Size = UDim2.new(layoutData.sx, layoutData.so, layoutData.sy, layoutData.soy)
        end

        if data.M1_OffsetX and data.M1_OffsetY then 
            M1_Offset = Vector2.new(data.M1_OffsetX, data.M1_OffsetY)
            UpdateCrosshairToVIM() 
        end

        if data.Jump_OffsetX and data.Jump_OffsetY then
            Jump_Offset = Vector2.new(data.Jump_OffsetX, data.Jump_OffsetY)
        end

        GlobalTransparency = data.Transparency or 0
        if TKnob then TKnob.Position = UDim2.new(math.clamp(GlobalTransparency/0.9, 0, 1), -6, 0.5, -6) end
        UpdateTransparencyFunc()
        
        IsLayoutLocked = data.LayoutLocked or false
        updateLockState()

        IsJoystickEnabled = data.JoystickEnabled or false
        if JoyContainer then JoyContainer.Visible = IsJoystickEnabled end
        if JoyToggle then 
            if IsJoystickEnabled then 
                JoyToggle.Text = "JOYSTICK: ON"
                JoyToggle.BackgroundColor3 = Theme.Green 
            else 
                JoyToggle.Text = "JOYSTICK: OFF"
                JoyToggle.BackgroundColor3 = Theme.Red 
            end 
        end

        SkillMode = data.SkillMode or "INSTANT"
        if ModeBtn then 
            if SkillMode == "SMART" then 
                ModeBtn.Text = "MODE: SMART TAP"
                ModeBtn.BackgroundColor3 = Theme.Blue 
            else 
                ModeBtn.Text = "MODE: INSTANT"
                ModeBtn.BackgroundColor3 = Theme.Green 
            end 
        end

        if data.Pos_Window then applyLayout(Window, data.Pos_Window) end
        if data.Pos_Toggle then applyLayout(ToggleBtn, data.Pos_Toggle) end
        if data.Pos_Joy then applyLayout(JoyContainer, data.Pos_Joy) end
        if data.Pos_JoyOuter then 
            applyLayout(JoyOuter, data.Pos_JoyOuter)
            if data.Pos_JoyOuter.so then createCorner(JoyOuter, data.Pos_JoyOuter.so) end 
        end

        -- Bersihkan tombol lama
        for _, c in pairs(Combos) do if c.Button then c.Button:Destroy() end end; Combos = {}
        for _, vData in pairs(ActiveVirtualKeys) do if vData.Button then vData.Button:Destroy() end end; ActiveVirtualKeys = {}
        
        -- Load Combos
        if data.Combos and type(data.Combos) == "table" then 
            for _, cData in ipairs(data.Combos) do 
                CreateComboButtonFunc(cData.ID, cData.Steps)
                local createdCombo = Combos[#Combos]
                if createdCombo and cData.Layout then applyLayout(createdCombo.Button, cData.Layout) end 
            end 
        end
        
        -- Load Virtual Keys
        if data.VirtualKeys and type(data.VirtualKeys) == "table" then 
            for _, vData in ipairs(data.VirtualKeys) do 
                if vData.KeyName then 
                    toggleVirtualKey(vData.KeyName, vData.Slot, vData.ID)
                    local createdKey = ActiveVirtualKeys[vData.ID]
                    if createdKey and vData.Layout then 
                        applyLayout(createdKey.Button, vData.Layout)
                        if vData.Layout.so then createCorner(createdKey.Button, 12) end 
                    end 
                end 
            end 
        end
        
        if ResizerUpdateFunc then ResizerUpdateFunc() end
    end)

    if applySuccess then 
        ShowNotification("Loaded: " .. configName, Theme.Blue) 
    else 
        warn("Velox Load Error: " .. tostring(err))
        ShowNotification("Load Partial/Error", Theme.Red) 
    end
end

local LoadBtn = mkTool("LOAD CONFIG", Theme.Blue, function() ShowPopup("SELECT CONFIG", function(container) local scroll = Instance.new("ScrollingFrame"); scroll.Size=UDim2.new(1,0,0,150); scroll.BackgroundTransparency=1; scroll.Parent=container; scroll.ScrollBarThickness=3; scroll.ZIndex=2004; local layout = Instance.new("UIListLayout"); layout.Parent=scroll; layout.Padding=UDim.new(0,2); local count = 0; if isfile(FileName) then local s, r = pcall(function() return readfile(FileName) end); if s then local successDecode, all = pcall(function() return HttpService:JSONDecode(r) end); if successDecode and type(all) == "table" then for name, _ in pairs(all) do if name ~= "LastUsed" then count = count + 1; local b = Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,30); b.BackgroundColor3=Theme.Bg; b.Text=name; b.TextColor3=Theme.SubText; b.Parent=scroll; createCorner(b,6); b.ZIndex=2004; b.MouseButton1Click:Connect(function() ClosePopup(); ShowPopup("MANAGE: "..name, function(c2) local l = Instance.new("TextButton"); l.Size=UDim2.new(1,0,0,30); l.BackgroundColor3=Theme.Green; l.Text="LOAD"; l.TextColor3=Theme.Bg; l.Parent=c2; createCorner(l,6); l.ZIndex=2004; l.MouseButton1Click:Connect(function() LoadSpecific(name); CurrentConfigName=name; ClosePopup() end); local r = Instance.new("TextButton"); r.Size=UDim2.new(1,0,0,30); r.Position=UDim2.new(0,0,0,35); r.BackgroundColor3=Theme.Blue; r.Text="RENAME"; r.TextColor3=Theme.Bg; r.Parent=c2; createCorner(r,6); r.ZIndex=2004; r.MouseButton1Click:Connect(function() ClosePopup(); ShowPopup("RENAME TO...", function(c3) local box = Instance.new("TextBox"); box.Size=UDim2.new(1,0,0,35); box.BackgroundColor3=Theme.Element; box.Text=""; box.PlaceholderText="New Name..."; box.TextColor3=Theme.Text; box.Parent=c3; createCorner(box,6); box.ZIndex=2004; local confirm = Instance.new("TextButton"); confirm.Size=UDim2.new(1,0,0,35); confirm.Position=UDim2.new(0,0,0,40); confirm.BackgroundColor3=Theme.Blue; confirm.Text="UPDATE"; confirm.TextColor3=Theme.Bg; confirm.Parent=c3; createCorner(confirm,6); confirm.ZIndex=2004; confirm.MouseButton1Click:Connect(function() if box.Text ~= "" and box.Text ~= name then local f = readfile(FileName); local d = HttpService:JSONDecode(f); d[box.Text] = d[name]; d[name] = nil; if d["LastUsed"] == name then d["LastUsed"] = box.Text end; writefile(FileName, HttpService:JSONEncode(d)); ClosePopup(); ShowNotification("Renamed!", Theme.Blue) end end); return 80 end) end); local del = Instance.new("TextButton"); del.Size=UDim2.new(1,0,0,30); del.Position=UDim2.new(0,0,0,70); del.BackgroundColor3=Theme.Red; del.Text="DELETE"; del.TextColor3=Theme.Bg; del.Parent=c2; createCorner(del,6); del.ZIndex=2004; del.MouseButton1Click:Connect(function() local f = readfile(FileName); local d = HttpService:JSONDecode(f); d[name] = nil; if d["LastUsed"]==name then d["LastUsed"]=nil end; writefile(FileName, HttpService:JSONEncode(d)); ClosePopup(); ShowNotification("Deleted", Theme.Red) end); return 105 end) end) end end end end end; scroll.CanvasSize = UDim2.new(0,0,0, count * 32); return 150 end) end, P_Sys); LoadBtn.Size=UDim2.new(0.9,0,0,45)

local ResetBtn = mkTool("RESET CONFIG", Theme.Red, function() 
    ShowPopup("CONFIRM RESET?", function(c)
        local yes = Instance.new("TextButton"); yes.Size=UDim2.new(0.45,0,0,40); yes.BackgroundColor3=Theme.Green; yes.Text="YES"; yes.TextColor3=Theme.Bg; yes.Parent=c; createCorner(yes,6); yes.ZIndex=2004
        local no = Instance.new("TextButton"); no.Size=UDim2.new(0.45,0,0,40); no.Position=UDim2.new(0.55,0,0,0); no.BackgroundColor3=Theme.Red; no.Text="NO"; no.TextColor3=Theme.Bg; no.Parent=c; createCorner(no,6); no.ZIndex=2004
        
        yes.MouseButton1Click:Connect(function()
            -- 1. HAPUS SEMUA TOMBOL VIRTUAL
            for _, vData in pairs(ActiveVirtualKeys) do
                if vData.Button then vData.Button:Destroy() end
            end
            ActiveVirtualKeys = {}
            
            -- 2. HAPUS SEMUA COMBO
            for _, c in pairs(Combos) do 
                if c.Button then c.Button:Destroy() end 
            end
            Combos = {}
            CurrentComboIndex = 0 
            
            -- 3. RESET VARIABLE SYSTEM
            CurrentConfigName = nil
            SkillMode = "INSTANT"
            ModeBtn.Text = "MODE: INSTANT"
            ModeBtn.BackgroundColor3 = Theme.Green
            CurrentSmartKeyData = nil
            SelectedComboID = nil
            IsLayoutLocked = false
            
            -- 4. RESET VISUAL (Default Settings)
            GlobalTransparency = 0
            if TKnob then TKnob.Position = UDim2.new(0, -6, 0.5, -6) end
            IsJoystickEnabled = false
            JoyContainer.Visible = false
            if JoyToggle then
                JoyToggle.Text = "JOYSTICK: OFF"
                JoyToggle.BackgroundColor3 = Theme.Red
            end
            
            -- 5. RESET POSISI UI (Factory Default)
            Window.Position = UDim2.new(0.5, -300, 0.5, -170)
            ToggleBtn.Position = UDim2.new(0.02, 0, 0.3, 0)
            JoyContainer.Position = UDim2.new(0.1, 0, 0.6, 0)
            
            local defJoySize = 140
            JoyOuter.Size = UDim2.new(0, defJoySize, 0, defJoySize)
            JoyContainer.Size = UDim2.new(0, defJoySize, 0, defJoySize + 30)
            createCorner(JoyOuter, defJoySize)

            -- 6. RESET PILIHAN WARNA TOMBOL
            for k, btn in pairs(VirtualKeySelectors) do
                btn.BackgroundColor3 = Theme.Element
                btn.TextColor3 = Theme.Text
            end

            -- 7. REFRESH SEMUA
            UpdateTransparencyFunc()
            updateLockState()
            if ResizerUpdateFunc then ResizerUpdateFunc() end
            RefreshEditorUI() 

            ShowNotification("Factory Reset Complete!", Theme.Accent)
            ClosePopup()
        end)
        
        no.MouseButton1Click:Connect(ClosePopup)
        return 50
    end)
end, P_Sys); ResetBtn.Size=UDim2.new(0.9,0,0,45)

local ExitBtn = mkTool("EXIT SCRIPT", Theme.Red, function() 
    ShowPopup("CONFIRM EXIT?", function(c)
        local yes = Instance.new("TextButton"); yes.Size=UDim2.new(0.45,0,0,40); yes.BackgroundColor3=Theme.Green; yes.Text="YES"; yes.TextColor3=Theme.Bg; yes.Parent=c; createCorner(yes,6); yes.ZIndex=2004
        local no = Instance.new("TextButton"); no.Size=UDim2.new(0.45,0,0,40); no.Position=UDim2.new(0.55,0,0,0); no.BackgroundColor3=Theme.Red; no.Text="NO"; no.TextColor3=Theme.Bg; no.Parent=c; createCorner(no,6); no.ZIndex=2004
        
        yes.MouseButton1Click:Connect(function() 
            isRunning = false 
            IsAutoDashing = false 
            -- MEMBERSIHKAN EVENT AGAR TIDAK LAG
            for _, conn in pairs(GlobalConnections) do
                if conn.Connected then conn:Disconnect() end
            end
            table.clear(GlobalConnections)
            if ScreenGui then ScreenGui:Destroy() end 
        end)
        
        no.MouseButton1Click:Connect(ClosePopup)
        return 50
    end)
end, P_Sys); ExitBtn.Size=UDim2.new(0.9,0,0,45)



-- === STARTUP ===
ShowNotification("VELOX Mobile Loaded.", Theme.Accent)
task.wait(1)
ShowNotification("Custom Layout: READY", Theme.Green)
task.wait(1)
ShowNotification("Mobile Engine: ONLINE", Theme.Blue)

-- === STARTUP LOGIC (REVISED) ===
task.spawn(function()
    task.wait(1.5) 
    if isfile(FileName) then 
        local success, content = pcall(function() return readfile(FileName) end)
        if success and content ~= "" then 
            local decodeSuccess, data = pcall(function() return HttpService:JSONDecode(content) end)
            
            if decodeSuccess and data and data["LastUsed"] then
                local lastConfigName = data["LastUsed"]
                local lastData = data[lastConfigName]
                
                -- CEK 1: Apakah di data permanen LastUsed ada flag AutoLoad?
                -- CEK 2: Jika data AutoLoad tidak ditemukan (config lama), kita default ke TRUE
                local shouldLoad = true
                if lastData and lastData.AutoLoad ~= nil then
                    shouldLoad = lastData.AutoLoad
                end

                if shouldLoad then
                    LoadSpecific(lastConfigName) 
                    CurrentConfigName = lastConfigName
                    -- Pastikan tombol UI sinkron dengan data yang di-load
                    IsAutoLoad = true 
                    if AutoLoadBtn then
                        AutoLoadBtn.Text = "AUTO LOAD: ON"
                        AutoLoadBtn.BackgroundColor3 = Theme.Green
                    end
                else
                    ShowNotification("Auto-Load is Disabled", Theme.Red)
                end
            end 
        end 
    end
end)
