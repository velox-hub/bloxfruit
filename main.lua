--[[
    VELOX V128 (ULTIMATE FIXED & ENHANCED)
    - FIXED: Combo Editor & Guide Tabs (UI rewritten for visibility).
    - ADDED: Confirmation Popups for Reset & Exit.
    - FEATURE: Per-Button Hide/Show integrated into Resizer.
    - CORE: Preserved all V127 features (Joystick Pause, Smart Cast, etc).
]]

-- === SERVICES ===
local VIM = game:GetService("VirtualInputManager")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local FileName = "Velox_Config.json"

-- === CONFIGURATION ===
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

-- === VARIABLES ===
local JOYSTICK_SIZE = 140
local KNOB_SIZE = 60

local isRunning = false 
local IsLayoutLocked = false 
local GlobalTransparency = 0 
local IsJoystickEnabled = false 
local IsMovementPaused = false 

local Combos = {} 
local CurrentComboIndex = 0 
local ActiveVirtualKeys = {} 
local CurrentConfigName = nil 
local Keybinds = {} 
local VirtualKeySelectors = {}

-- SYSTEM VARS
local SkillMode = "INSTANT" -- "INSTANT" or "SMART"
local CurrentSmartKeyData = nil 
local SelectedComboID = nil 

-- EDITOR VARS
local ResizerList = {}
local CurrentSelectedElement = nil
local ResizerUpdateFunc = nil 
local UpdateTransparencyFunc = nil 
local RefreshEditorUI = nil 
local RefreshControlUI = nil

local WeaponData = {
    {name = "Melee", slot = 1, color = Color3.fromRGB(255, 140, 0), tooltip = "Melee", keys = {"Z", "X", "C"}},
    {name = "Fruit", slot = 2, color = Color3.fromRGB(170, 50, 255), tooltip = "Blox Fruit", keys = {"Z", "X", "C", "V", "F"}},
    {name = "Sword", slot = 3, color = Color3.fromRGB(0, 160, 255), tooltip = "Sword", keys = {"Z", "X"}},
    {name = "Gun",   slot = 4, color = Color3.fromRGB(255, 220, 0),   tooltip = "Gun", keys = {"Z", "X"}}
}

-- === UTILITIES ===
local function createCorner(p, r) local c = Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); c.Parent=p end
local function createStroke(p, c) local s = Instance.new("UIStroke"); s.Color=c or Theme.Stroke; s.Thickness=1.5; s.ApplyStrokeMode="Border"; s.Parent=p; return s end

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

-- === PRE-DECLARATION ===
local JoyOuter, JoyKnob, JoyDrag, ToggleBtn, JoyContainer, LockBtn

-- === MANAGER FUNCTIONS ===
UpdateTransparencyFunc = function()
    local t = GlobalTransparency
    
    if ToggleBtn then 
        ToggleBtn.BackgroundTransparency = t; ToggleBtn.TextTransparency = t 
        if ToggleBtn:FindFirstChild("UIStroke") then ToggleBtn.UIStroke.Transparency = t end
    end
    for _, c in pairs(Combos) do 
        if c.Button then 
            c.Button.BackgroundTransparency = t; c.Button.TextTransparency = t
            if c.Button:FindFirstChild("UIStroke") then c.Button.UIStroke.Transparency = t end
        end 
    end
    for _, item in pairs(ActiveVirtualKeys) do 
        local btn = item.Button
        btn.BackgroundTransparency = t; btn.TextTransparency = t
        if btn:FindFirstChild("UIStroke") then btn.UIStroke.Transparency = t end
    end
    if JoyOuter and JoyKnob then
        JoyOuter.BackgroundTransparency = math.clamp(0.3 + t, 0.3, 1)
        JoyKnob.BackgroundTransparency = math.clamp(0.2 + t, 0.2, 1)
        JoyDrag.BackgroundTransparency = t; JoyDrag.TextTransparency = t
        if JoyOuter:FindFirstChild("UIStroke") then JoyOuter.UIStroke.Transparency = math.clamp(0.1 + t, 0.1, 1) end
    end
end

local function updateLockState()
    if JoyDrag then JoyDrag.Visible = (not IsLayoutLocked) and IsJoystickEnabled end
    if LockBtn then
        if IsLayoutLocked then LockBtn.Text = "POS: LOCKED"; LockBtn.BackgroundColor3 = Theme.Red
        else LockBtn.Text = "POS: UNLOCKED"; LockBtn.BackgroundColor3 = Theme.Green end
    end
    if ResizerUpdateFunc then ResizerUpdateFunc() end
end

-- === NOTIFICATION ===
local NotifContainer = nil 
local function ShowNotification(text, color)
    if not NotifContainer then return end
    local NotifFrame = Instance.new("Frame"); NotifFrame.Size=UDim2.new(0,200,0,40); NotifFrame.Position=UDim2.new(0.5,-100,0.1,0); NotifFrame.BackgroundColor3=Theme.Sidebar; NotifFrame.BackgroundTransparency=0.1; NotifFrame.Parent=NotifContainer; createCorner(NotifFrame,8); local s=createStroke(NotifFrame, color or Theme.Accent)
    local Lbl = Instance.new("TextLabel"); Lbl.Size=UDim2.new(1,0,1,0); Lbl.Text=text; Lbl.TextColor3=Theme.Text; Lbl.Font=Enum.Font.GothamBold; Lbl.TextSize=12; Lbl.BackgroundTransparency=1; Lbl.Parent=NotifFrame
    task.delay(1.5, function() NotifFrame:Destroy() end)
end

-- === CORE LOGIC ===
local function PauseJoystickForAim()
    -- JOYSTICK PAUSE 0.3s
    IsMovementPaused = true
    task.delay(0.3, function() IsMovementPaused = false end)
end

local function pressKey(k, isHold, holdDur)
    if isHold then
        VIM:SendKeyEvent(true, k, false, game); task.wait(holdDur); VIM:SendKeyEvent(false, k, false, game)
    else
        for i=1,3 do VIM:SendKeyEvent(true, k, false, game); task.wait(0.05); VIM:SendKeyEvent(false, k, false, game); if i < 3 then task.wait(0.03) end end
    end
end

local function isWeaponReady(targetSlotIdx)
    local char = LocalPlayer.Character; if not char then return false end
    local tool = char:FindFirstChildOfClass("Tool"); if not tool then return false end 
    local expectedTip = WeaponData[targetSlotIdx].tooltip; if tool.ToolTip == expectedTip then return true end
    return false
end

local function equipWeapon(slotIdx)
    if not slotIdx then return end
    local s = WeaponData[slotIdx].slot
    local key = s==1 and Enum.KeyCode.One or s==2 and Enum.KeyCode.Two or s==3 and Enum.KeyCode.Three or Enum.KeyCode.Four
    VIM:SendKeyEvent(true, key, false, game); task.wait(); VIM:SendKeyEvent(false, key, false, game); task.wait(0.05)
end

-- === COMBO RUNNER ===
local CurrentRunningBtn = nil
local executeComboSequence_Ref = nil 

local function executeComboSequence(idx)
    local data = Combos[idx]; if not data or not data.Button then return end
    isRunning = true
    local btn = data.Button
    btn:SetAttribute("OrigText", btn.Text); btn.Text = "STOP"; btn.BackgroundColor3 = Theme.Red; btn.UIStroke.Color = Theme.Red
    
    task.spawn(function()
        for i, step in ipairs(data.Steps) do
            if not isRunning then break end
            if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Humanoid") or LocalPlayer.Character.Humanoid.Health <= 0 then isRunning = false; break end
            if not isWeaponReady(step.Slot) then equipWeapon(step.Slot) end
            if step.Delay and step.Delay > 0 then task.wait(step.Delay) end
            local map={Z=Enum.KeyCode.Z,X=Enum.KeyCode.X,C=Enum.KeyCode.C,V=Enum.KeyCode.V,F=Enum.KeyCode.F}
            pressKey(map[step.Key], step.IsHold, step.HoldTime or 0.1)
            task.wait(0.3)
        end
        isRunning = false; if btn then btn.Text = data.Name; btn.BackgroundColor3 = Theme.Sidebar; btn.UIStroke.Color = Theme.Accent end; CurrentRunningBtn = nil
        if SelectedComboID == idx then btn.BackgroundColor3 = Theme.Green; btn.UIStroke.Color = Theme.Green end
    end)
end
executeComboSequence_Ref = executeComboSequence

-- === GLOBAL INPUT HANDLER ===
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.Keyboard and not gameProcessed then
        for action, bindKey in pairs(Keybinds) do
            if input.KeyCode == bindKey then
                if string.sub(action, 1, 1) == "C" then 
                    local id = tonumber(string.sub(action, 2))
                    if Combos[id] then
                        if SkillMode == "INSTANT" then PauseJoystickForAim(); executeComboSequence(id)
                        else SelectedComboID = id; ShowNotification("Combo "..id.." Selected", Theme.Green) end
                    end
                elseif ActiveVirtualKeys[action] then 
                    local vData = ActiveVirtualKeys[action]
                    if SkillMode == "INSTANT" then
                        PauseJoystickForAim(); if vData.Slot then equipWeapon(vData.Slot) end
                        VIM:SendKeyEvent(true, vData.Key, false, game); task.delay(0.1, function() VIM:SendKeyEvent(false, vData.Key, false, game) end)
                    else CurrentSmartKeyData = vData; ShowNotification("Skill "..action.." Ready", Theme.Green) end
                end
            end
        end
    end

    if not gameProcessed and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
        if SkillMode == "SMART" and CurrentSmartKeyData ~= nil then
            PauseJoystickForAim()
            task.spawn(function()
                if CurrentSmartKeyData.Slot and not isWeaponReady(CurrentSmartKeyData.Slot) then equipWeapon(CurrentSmartKeyData.Slot) end
                VIM:SendKeyEvent(true, CurrentSmartKeyData.Key, false, game); task.wait(0.05); VIM:SendKeyEvent(false, CurrentSmartKeyData.Key, false, game) 
            end)
        end
        if SelectedComboID ~= nil and not isRunning then
            PauseJoystickForAim(); executeComboSequence(SelectedComboID)
        end
    end
end)

-- === UI CONSTRUCTION ===
if CoreGui:FindFirstChild("VeloxUI") then CoreGui.VeloxUI:Destroy() end
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VeloxUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

NotifContainer = Instance.new("Frame"); NotifContainer.Size=UDim2.new(1,0,1,0); NotifContainer.BackgroundTransparency=1; NotifContainer.Parent=ScreenGui; NotifContainer.ZIndex=6000

-- TOGGLE & WINDOW
ToggleBtn = Instance.new("TextButton"); ToggleBtn.Size=UDim2.new(0,45,0,45); ToggleBtn.Position=UDim2.new(0.02,0,0.3,0); ToggleBtn.BackgroundColor3=Theme.Sidebar; ToggleBtn.Text="R"; ToggleBtn.TextColor3=Theme.Accent; ToggleBtn.Font=Enum.Font.GothamBlack; ToggleBtn.TextSize=24; ToggleBtn.Parent=ScreenGui; ToggleBtn.ZIndex=200; ToggleBtn.Selectable=false; createCorner(ToggleBtn,12); local ToggleStroke = createStroke(ToggleBtn,Theme.Accent); MakeDraggable(ToggleBtn, nil)
local Window = Instance.new("Frame"); Window.Size=UDim2.new(0,600,0,340); Window.Position=UDim2.new(0.5,-300,0.5,-170); Window.BackgroundColor3=Theme.Bg; Window.Visible=true; Window.Parent=ScreenGui; Window.ZIndex=100; createCorner(Window,10); createStroke(Window,Theme.Accent); MakeDraggable(Window, nil)
ToggleBtn.MouseButton1Click:Connect(function() Window.Visible=not Window.Visible end)

-- POPUP & NAVIGATION
local PopupOverlay = Instance.new("Frame"); PopupOverlay.Size=UDim2.new(1,0,1,0); PopupOverlay.BackgroundColor3=Color3.new(0,0,0); PopupOverlay.BackgroundTransparency=1; PopupOverlay.Parent=Window; PopupOverlay.Visible=false; PopupOverlay.ZIndex=500
local function ClosePopup() PopupOverlay.Visible=false; for _,c in pairs(PopupOverlay:GetChildren()) do c:Destroy() end end
local function ShowPopup(title, contentFunc)
    for _,c in pairs(PopupOverlay:GetChildren()) do c:Destroy() end
    PopupOverlay.Visible=true
    local MainP = Instance.new("Frame"); MainP.Size=UDim2.new(0,300,0,0); MainP.AnchorPoint=Vector2.new(0.5,0.5); MainP.Position=UDim2.new(0.5,0,0.5,0); MainP.BackgroundColor3=Theme.Popup; MainP.Parent=PopupOverlay; createCorner(MainP,10); createStroke(MainP,Theme.Accent)
    local Title = Instance.new("TextLabel"); Title.Size=UDim2.new(1,0,0,40); Title.Text=title; Title.Font=Enum.Font.GothamBlack; Title.TextColor3=Theme.Accent; Title.TextSize=16; Title.BackgroundTransparency=1; Title.Parent=MainP
    local Close = Instance.new("TextButton"); Close.Size=UDim2.new(0,30,0,30); Close.Position=UDim2.new(1,-35,0,5); Close.Text="X"; Close.TextColor3=Theme.Red; Close.BackgroundTransparency=1; Close.Parent=MainP; Close.Font=Enum.Font.GothamBold; Close.MouseButton1Click:Connect(ClosePopup)
    local Container = Instance.new("Frame"); Container.Size=UDim2.new(0.9,0,0,0); Container.Position=UDim2.new(0.05,0,0,45); Container.BackgroundTransparency=1; Container.Parent=MainP
    local contentHeight = contentFunc(Container)
    MainP.Size = UDim2.new(0,300,0,contentHeight+55) 
end

local Sidebar = Instance.new("Frame"); Sidebar.Size = UDim2.new(0, 140, 1, 0); Sidebar.BackgroundColor3 = Theme.Sidebar; Sidebar.Parent = Window; Sidebar.Active=true; createCorner(Sidebar, 10)
local BrandFrame = Instance.new("Frame"); BrandFrame.Size=UDim2.new(1,0,0,55); BrandFrame.BackgroundTransparency=1; BrandFrame.Parent=Sidebar
local BrandText = Instance.new("TextLabel"); BrandText.Size=UDim2.new(1,0,0,30); BrandText.Position=UDim2.new(0,0,0,5); BrandText.Text="VELOX"; BrandText.TextColor3=Theme.Accent; BrandText.Font=Enum.Font.GothamBlack; BrandText.TextSize=18; BrandText.BackgroundTransparency=1; BrandText.Parent=BrandFrame
local NavContainer = Instance.new("Frame"); NavContainer.Size=UDim2.new(1,0,1,-60); NavContainer.Position=UDim2.new(0,0,0,60); NavContainer.BackgroundTransparency=1; NavContainer.Parent=Sidebar
local SideLayout = Instance.new("UIListLayout"); SideLayout.Parent=NavContainer; SideLayout.HorizontalAlignment="Center"; SideLayout.Padding=UDim.new(0,5);

local Content = Instance.new("Frame"); Content.Size=UDim2.new(1,-150,1,-20); Content.Position=UDim2.new(0,150,0,10); Content.BackgroundTransparency=1; Content.Parent=Window
local Pages={}; local function nav(pName) for n, p in pairs(Pages) do p.Visible=(n==pName) end end
local function mkNav(icon, text, target)
    local btn = Instance.new("TextButton"); btn.Size=UDim2.new(0.9,0,0,40); btn.BackgroundColor3=Theme.Bg; btn.BackgroundTransparency=1; btn.Text="  "..icon.."  "..text; btn.TextColor3=Theme.SubText; btn.Font=Enum.Font.GothamBold; btn.TextSize=12; btn.TextXAlignment="Left"; btn.Parent=NavContainer; btn.Selectable=false; createCorner(btn,6)
    btn.MouseButton1Click:Connect(function() nav(target); for _, c in pairs(NavContainer:GetChildren()) do if c:IsA("TextButton") then c.TextColor3=Theme.SubText; c.BackgroundColor3=Theme.Bg; c.BackgroundTransparency=1 end end; btn.TextColor3=Theme.Accent; btn.BackgroundColor3=Theme.Element; btn.BackgroundTransparency=0 end)
    return btn
end

-- PAGE FRAMES (UI FIX: ENSURE VISIBILITY)
local P_Guide = Instance.new("Frame"); P_Guide.Size=UDim2.new(1,0,0.85,0); P_Guide.Position=UDim2.new(0,0,0.15,0); P_Guide.BackgroundTransparency=1; P_Guide.Visible=false; P_Guide.Parent=Content; Pages["Guide"]=P_Guide
local P_Edit = Instance.new("Frame"); P_Edit.Size=UDim2.new(1,0,0.85,0); P_Edit.Position=UDim2.new(0,0,0.15,0); P_Edit.BackgroundTransparency=1; P_Edit.Visible=true; P_Edit.Parent=Content; Pages["Editor"]=P_Edit
local P_Control = Instance.new("ScrollingFrame"); P_Control.Size=UDim2.new(1,0,0.85,0); P_Control.Position=UDim2.new(0,0,0.15,0); P_Control.BackgroundTransparency=1; P_Control.Visible=false; P_Control.ScrollBarThickness=2; P_Control.Parent=Content; Pages["Control"]=P_Control
local P_Lay = Instance.new("ScrollingFrame"); P_Lay.Size=UDim2.new(1,0,0.85,0); P_Lay.Position=UDim2.new(0,0,0.15,0); P_Lay.BackgroundTransparency=1; P_Lay.Visible=false; P_Lay.ScrollBarThickness=2; P_Lay.Parent=Content; Pages["Layout"]=P_Lay
local P_Sys = Instance.new("Frame"); P_Sys.Size=UDim2.new(1,0,0.85,0); P_Sys.Position=UDim2.new(0,0,0.15,0); P_Sys.BackgroundTransparency=1; P_Sys.Visible=false; P_Sys.Parent=Content; Pages["System"]=P_Sys

mkNav("⚔️","COMBO","Editor").TextColor3=Theme.Accent; 
mkNav("ℹ️","GUIDE","Guide"); 
mkNav("🛠️","LAYOUT","Layout"); 
mkNav("🎮","CONTROLS","Control"); 
mkNav("⚙️","SYSTEM","System")

-- === GUIDE TAB (FIXED VISIBILITY) ===
local GFrame = Instance.new("ScrollingFrame"); GFrame.Size=UDim2.new(1,0,1,0); GFrame.BackgroundTransparency=1; GFrame.ScrollBarThickness=4; GFrame.Parent=P_Guide
local GText = [[WELCOME TO VELOX V127!

[ FEATURES ]
• Custom Layout: Resize & Move ANY button.
• Smart Cast: Tap skill -> Tap screen to fire.
• Weapon Bind: Assign weapons to virtual keys.
• PC Support: Keybinds for all functions.

[ CONTROLS ]
Use the 'Controls' tab to set PC Keybinds and change Skill Mode.

[ JOYSTICK FIX ]
Movement pauses briefly (0.3s) when firing skills to prevent aiming at feet.]]
local GLabel = Instance.new("TextLabel"); GLabel.Size=UDim2.new(0.95,0,0,300); GLabel.Position=UDim2.new(0.025,0,0,0); GLabel.Text=GText; GLabel.TextColor3=Theme.Text; GLabel.Font=Enum.Font.Gotham; GLabel.TextSize=14; GLabel.TextXAlignment="Left"; GLabel.TextYAlignment="Top"; GLabel.BackgroundTransparency=1; GLabel.TextWrapped=true; GLabel.Parent=GFrame
GFrame.CanvasSize = UDim2.new(0,0,0,350) -- Ensure scrolling if text is long

-- === JOYSTICK ===
JoyContainer = Instance.new("Frame"); JoyContainer.Size=UDim2.new(0, JOYSTICK_SIZE, 0, JOYSTICK_SIZE + 30); JoyContainer.Position=UDim2.new(0.1, 0, 0.6, 0); JoyContainer.BackgroundTransparency=1; JoyContainer.Active=false; JoyContainer.Parent=ScreenGui; JoyContainer.Visible=false; JoyContainer.ZIndex=50
JoyDrag = Instance.new("TextButton"); JoyDrag.Size=UDim2.new(0,60,0,25); JoyDrag.Position=UDim2.new(0.5,-30,0,-10); JoyDrag.BackgroundColor3=Color3.fromRGB(30,30,30); JoyDrag.Text="DRAG"; JoyDrag.TextColor3=Theme.Accent; JoyDrag.Font=Enum.Font.GothamBold; JoyDrag.TextSize=11; JoyDrag.Parent=JoyContainer; JoyDrag.Selectable=false; JoyDrag.Visible=false; createCorner(JoyDrag,6); JoyDrag.ZIndex=52
JoyOuter = Instance.new("ImageButton"); JoyOuter.Size=UDim2.new(0,JOYSTICK_SIZE,0,JOYSTICK_SIZE); JoyOuter.Position=UDim2.new(0,0,0,20); JoyOuter.BackgroundColor3=Color3.new(0,0,0); JoyOuter.BackgroundTransparency=0.3; JoyOuter.ImageTransparency=1; JoyOuter.AutoButtonColor=false; JoyOuter.Parent=JoyContainer; JoyOuter.Selectable=true; JoyOuter.Active=true; createCorner(JoyOuter, JOYSTICK_SIZE); 
local JO_Str=createStroke(JoyOuter, Theme.Text); JO_Str.Transparency=0.1; JO_Str.Thickness=2; JoyOuter.ZIndex=51
JoyKnob = Instance.new("Frame"); JoyKnob.Size=UDim2.new(0,KNOB_SIZE,0,KNOB_SIZE); JoyKnob.Position=UDim2.new(0.5,-KNOB_SIZE/2,0.5,-KNOB_SIZE/2); JoyKnob.BackgroundColor3=Theme.Accent; JoyKnob.BackgroundTransparency=0.2; JoyKnob.Parent=JoyOuter; createCorner(JoyKnob, KNOB_SIZE); JoyKnob.ZIndex=52

local function EnableJoyDrag()
    local d, offset
    JoyDrag.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then d=true; offset=Vector2.new(i.Position.X - JoyContainer.AbsolutePosition.X, i.Position.Y - JoyContainer.AbsolutePosition.Y) end end)
    UserInputService.InputChanged:Connect(function(i) if d and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then local newX = i.Position.X - offset.X; local newY = i.Position.Y - offset.Y; JoyContainer.Position = UDim2.new(0, math.clamp(newX, 0, Camera.ViewportSize.X - JoyOuter.AbsoluteSize.X), 0, math.clamp(newY, 0, Camera.ViewportSize.Y - (JoyOuter.AbsoluteSize.Y + 30))) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then d=false end end)
end
EnableJoyDrag()

local moveTouch, moveDir = nil, Vector2.new(0,0)
JoyOuter.InputBegan:Connect(function(i) if (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1) and not moveTouch then moveTouch=i end end)
UserInputService.InputChanged:Connect(function(i) if i==moveTouch then local center = JoyOuter.AbsolutePosition + (JoyOuter.AbsoluteSize/2); local vec = Vector2.new(i.Position.X, i.Position.Y) - center; if vec.Magnitude > JoyOuter.AbsoluteSize.X/2 then vec = vec.Unit * (JoyOuter.AbsoluteSize.X/2) end; JoyKnob.Position = UDim2.new(0.5, vec.X - KNOB_SIZE/2, 0.5, vec.Y - KNOB_SIZE/2); moveDir = Vector2.new(vec.X/(JoyOuter.AbsoluteSize.X/2), vec.Y/(JoyOuter.AbsoluteSize.X/2)) end end)
UserInputService.InputEnded:Connect(function(i) if i==moveTouch then moveTouch=nil; moveDir=Vector2.new(0,0); JoyKnob.Position=UDim2.new(0.5,-KNOB_SIZE/2,0.5,-KNOB_SIZE/2) end end)

RunService.RenderStepped:Connect(function()
    if not IsJoystickEnabled then return end
    if not LocalPlayer.Character then return end
    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
    if not hum then return end
    if IsMovementPaused then hum:Move(Vector3.new(0,0,0), true); return end 
    if hum.Sit then
        local seat = hum.SeatPart
        if seat and seat:IsA("VehicleSeat") then
            if moveDir.Y < -0.2 then seat.Throttle = 1 elseif moveDir.Y > 0.2 then seat.Throttle = -1 else seat.Throttle = 0 end
            if moveDir.X > 0.2 then seat.Steer = 1 elseif moveDir.X < -0.2 then seat.Steer = -1 else seat.Steer = 0 end
        else
            if moveDir.Magnitude > 0 then
                local cam = workspace.CurrentCamera
                local flatLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
                local flatRight = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z).Unit
                local moveVec = (flatLook * -moveDir.Y) + (flatRight * moveDir.X)
                hum:Move(moveVec, false)
            end
        end
    else
        if moveDir.Magnitude > 0 then
            local cam = workspace.CurrentCamera
            local flatLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
            local flatRight = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z).Unit
            local moveVec = (flatLook * -moveDir.Y) + (flatRight * moveDir.X)
            hum:Move(moveVec, false)
        end
    end
end)

-- === MANAGER ===
local function toggleVirtualKey(keyName, slotIdx, customName)
    local id = customName or keyName
    if ActiveVirtualKeys[id] then 
        ActiveVirtualKeys[id].Button:Destroy(); ActiveVirtualKeys[id]=nil
        if VirtualKeySelectors[id] then VirtualKeySelectors[id].BackgroundColor3=Theme.Element; VirtualKeySelectors[id].TextColor3=Theme.Text end
        if SkillMode == "SMART" and CurrentSmartKeyData and CurrentSmartKeyData.ID == id then CurrentSmartKeyData = nil end
        UpdateTransparencyFunc(); if ResizerUpdateFunc then ResizerUpdateFunc() end; if RefreshControlUI then RefreshControlUI() end
    else
        local btn = Instance.new("TextButton"); btn.Size=UDim2.new(0,50,0,50); btn.Position=UDim2.new(0.5,0,0.5,0); btn.BackgroundColor3=Color3.fromRGB(0,0,0); btn.Text=id; btn.TextColor3=Theme.Accent; btn.Font=Enum.Font.GothamBold; btn.TextSize=20; btn.Parent=ScreenGui; btn.Selectable=false; createCorner(btn,12); createStroke(btn,Theme.Accent); btn.ZIndex=60
        MakeDraggable(btn, nil)
        local kCode; if keyName=="1" then kCode=Enum.KeyCode.One elseif keyName=="2" then kCode=Enum.KeyCode.Two elseif keyName=="3" then kCode=Enum.KeyCode.Three elseif keyName=="4" then kCode=Enum.KeyCode.Four else kCode=Enum.KeyCode[keyName] end
        local vData = {ID=id, Key=kCode, Slot=slotIdx, Button=btn}
        btn.MouseButton1Click:Connect(function()
            if SkillMode == "INSTANT" then
                PauseJoystickForAim(); if vData.Slot then equipWeapon(vData.Slot) end
                VIM:SendKeyEvent(true, kCode, false, game); btn.BackgroundColor3=Theme.Accent; btn.TextColor3=Color3.new(0,0,0)
                task.delay(0.1, function() VIM:SendKeyEvent(false, kCode, false, game); btn.BackgroundColor3=Color3.fromRGB(0,0,0); btn.TextColor3=Theme.Accent end)
            elseif SkillMode == "SMART" then
                if CurrentSmartKeyData and CurrentSmartKeyData.ID == id then CurrentSmartKeyData = nil; btn.BackgroundColor3=Color3.fromRGB(0,0,0); btn.TextColor3=Theme.Accent
                else
                    if CurrentSmartKeyData then local old = ActiveVirtualKeys[CurrentSmartKeyData.ID]; if old then old.Button.BackgroundColor3=Color3.fromRGB(0,0,0); old.Button.TextColor3=Theme.Accent end end
                    CurrentSmartKeyData = vData; btn.BackgroundColor3=Theme.Green; btn.TextColor3=Theme.Bg
                    if SelectedComboID then local cBtn=Combos[SelectedComboID].Button; if cBtn then cBtn.BackgroundColor3=Theme.Sidebar; cBtn.UIStroke.Color=Theme.Accent end; SelectedComboID=nil end
                end
            end
        end)
        ActiveVirtualKeys[id] = vData; if VirtualKeySelectors[id] then VirtualKeySelectors[id].BackgroundColor3=Theme.Green; VirtualKeySelectors[id].TextColor3=Theme.Bg end; UpdateTransparencyFunc(); if ResizerUpdateFunc then ResizerUpdateFunc() end; if RefreshControlUI then RefreshControlUI() end
    end
end

-- === LAYOUT TAB ===
local LayPad = Instance.new("UIPadding"); LayPad.Parent=P_Lay; LayPad.PaddingLeft=UDim.new(0,10); LayPad.PaddingRight=UDim.new(0,10); LayPad.PaddingTop=UDim.new(0,10); LayPad.PaddingBottom=UDim.new(0,10)
local LayList = Instance.new("UIListLayout"); LayList.Parent=P_Lay; LayList.Padding=UDim.new(0,10); LayList.SortOrder="LayoutOrder"
LayList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() P_Lay.CanvasSize = UDim2.new(0, 0, 0, LayList.AbsoluteContentSize.Y + 20) end)

local SetBox = Instance.new("Frame"); SetBox.Size=UDim2.new(1,0,0,115); SetBox.BackgroundTransparency=1; SetBox.LayoutOrder=1; SetBox.Parent=P_Lay
local Grid1 = Instance.new("UIGridLayout"); Grid1.Parent=SetBox; Grid1.CellSize=UDim2.new(0.47,0,0,30); Grid1.CellPadding=UDim2.new(0.04,0,0.1,0)
local function mkTool(t,c,f,p) local b=Instance.new("TextButton"); b.Text=t; b.BackgroundColor3=Theme.Sidebar; b.TextColor3=Theme.Text; b.Font=Enum.Font.Gotham; b.TextSize=10; b.Parent=p; b.Selectable=false; createCorner(b,6); createStroke(b,c); b.MouseButton1Click:Connect(f); return b end

LockBtn = mkTool("POS: UNLOCKED", Theme.Green, function() IsLayoutLocked=not IsLayoutLocked; updateLockState() end, SetBox)
local JoyToggle = mkTool("JOYSTICK: OFF", Theme.Red, nil, SetBox)
JoyToggle.MouseButton1Click:Connect(function() IsJoystickEnabled = not IsJoystickEnabled; JoyContainer.Visible = IsJoystickEnabled; if IsJoystickEnabled then JoyContainer.Position = UDim2.new(0.1, 0, 0.6, 0) end; JoyToggle.Text = IsJoystickEnabled and "JOYSTICK: ON" or "JOYSTICK: OFF"; JoyToggle.BackgroundColor3 = IsJoystickEnabled and Theme.Green or Theme.Red; updateLockState() end)

mkTool("ADD COMBO", Theme.Accent, function() 
    local idx=#Combos+1; local btn=Instance.new("TextButton"); btn.Size=UDim2.new(0,60,0,60); btn.Position=UDim2.new(0.5,-30,0.5,0); btn.BackgroundColor3=Theme.Sidebar; btn.Text="C"..idx; btn.TextColor3=Theme.Accent; btn.Font=Enum.Font.GothamBold; btn.TextSize=18; btn.Parent=ScreenGui; btn.Selectable=false; createCorner(btn,30); local st=createStroke(btn,Theme.Accent); btn.ZIndex=70
    MakeDraggable(btn, function() if SkillMode == "INSTANT" then PauseJoystickForAim(); executeComboSequence(idx) else if SelectedComboID==idx then SelectedComboID=nil; btn.BackgroundColor3=Theme.Sidebar; btn.UIStroke.Color=Theme.Accent; isRunning=false else if SelectedComboID and Combos[SelectedComboID] then Combos[SelectedComboID].Button.BackgroundColor3=Theme.Sidebar; Combos[SelectedComboID].Button.UIStroke.Color=Theme.Accent end; SelectedComboID=idx; btn.BackgroundColor3=Theme.Green; btn.UIStroke.Color=Theme.Green; if CurrentSmartKeyData then local old=ActiveVirtualKeys[CurrentSmartKeyData.ID]; if old then old.Button.BackgroundColor3=Color3.fromRGB(0,0,0); old.Button.TextColor3=Theme.Accent end; CurrentSmartKeyData=nil end end end end)
    table.insert(Combos, {ID=idx, Name="C"..idx, Button=btn, Steps={}}); CurrentComboIndex=idx; UpdateTransparencyFunc(); if ResizerUpdateFunc then ResizerUpdateFunc() end; RefreshEditorUI(); ShowNotification("Combo Added", Theme.Green); if RefreshControlUI then RefreshControlUI() end
end, SetBox)
mkTool("DEL COMBO", Theme.Red, function() if #Combos<1 then return end; Combos[CurrentComboIndex].Button:Destroy(); table.remove(Combos, CurrentComboIndex); if #Combos > 0 then CurrentComboIndex=math.min(CurrentComboIndex, #Combos) else CurrentComboIndex=0 end; if ResizerUpdateFunc then ResizerUpdateFunc() end; RefreshEditorUI(); ShowNotification("Combo Deleted", Theme.Red); if RefreshControlUI then RefreshControlUI() end end, SetBox)

-- TRANSPARENCY
local TransBox = Instance.new("Frame"); TransBox.Size=UDim2.new(1,0,0,30); TransBox.BackgroundTransparency=1; TransBox.LayoutOrder=2; TransBox.Parent=P_Lay
local TLbl = Instance.new("TextLabel"); TLbl.Size=UDim2.new(0.4,0,1,0); TLbl.Text="Transparency:"; TLbl.TextColor3=Theme.SubText; TLbl.Font=Enum.Font.Gotham; TLbl.TextSize=11; TLbl.TextXAlignment="Left"; TLbl.BackgroundTransparency=1; TLbl.Parent=TransBox
local TBg = Instance.new("Frame"); TBg.Size=UDim2.new(0.55,0,0,4); TBg.Position=UDim2.new(0.42,0,0.5,-2); TBg.BackgroundColor3=Theme.Stroke; TBg.Parent=TransBox; createCorner(TBg,2)
local TKnob = Instance.new("TextButton"); TKnob.Size=UDim2.new(0,12,0,12); TKnob.Position=UDim2.new(0,0,0.5,-6); TKnob.BackgroundColor3=Theme.Accent; TKnob.Text=""; TKnob.Parent=TBg; TKnob.Selectable=false; createCorner(TKnob,6)
local dragT=false; TKnob.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragT=true end end); UserInputService.InputChanged:Connect(function(i) if dragT and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local p=math.clamp((i.Position.X-TBg.AbsolutePosition.X)/TBg.AbsoluteSize.X,0,1); TKnob.Position=UDim2.new(p,-6,0.5,-6); GlobalTransparency=p*0.9; UpdateTransparencyFunc() end end); UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragT=false end end)

-- MANUAL V-KEYS 1-4 & Z-F
local VKTitle = Instance.new("TextLabel"); VKTitle.Size=UDim2.new(1,0,0,25); VKTitle.Text="QUICK VIRTUAL KEYS"; VKTitle.TextColor3=Theme.Accent; VKTitle.Font=Enum.Font.GothamBold; VKTitle.TextSize=12; VKTitle.BackgroundTransparency=1; VKTitle.LayoutOrder=3; VKTitle.Parent=P_Lay
local VKBox = Instance.new("Frame"); VKBox.Size=UDim2.new(1,0,0,120); VKBox.BackgroundTransparency=1; VKBox.LayoutOrder=4; VKBox.Parent=P_Lay
local Grid2 = Instance.new("UIGridLayout"); Grid2.Parent=VKBox; Grid2.CellSize=UDim2.new(0.3,0,0,32); Grid2.CellPadding=UDim2.new(0.03,0,0.03,0)
local keysList = {"1", "2", "3", "4", "Z", "X", "C", "V", "F"}
for _, k in ipairs(keysList) do
    local btn = Instance.new("TextButton"); btn.Text=k; btn.BackgroundColor3=Theme.Element; btn.TextColor3=Theme.Text; btn.Font=Enum.Font.GothamBold; btn.TextSize=11; btn.Parent=VKBox; btn.Selectable=false; createCorner(btn,4)
    btn.MouseButton1Click:Connect(function() toggleVirtualKey(k, nil, k) end) -- Add without auto-equip first
    VirtualKeySelectors[k] = btn
end

-- WEAPON V-KEY ADDER
local AddTitle = Instance.new("TextLabel"); AddTitle.Size=UDim2.new(1,0,0,20); AddTitle.Text="WEAPON BIND ADDER"; AddTitle.TextColor3=Theme.Accent; AddTitle.Font=Enum.Font.GothamBold; AddTitle.TextSize=11; AddTitle.BackgroundTransparency=1; AddTitle.LayoutOrder=5; AddTitle.Parent=P_Lay
local VKeyAddBox = Instance.new("Frame"); VKeyAddBox.Size=UDim2.new(1,0,0,80); VKeyAddBox.BackgroundColor3=Theme.Sidebar; VKeyAddBox.LayoutOrder=6; VKeyAddBox.Parent=P_Lay; createCorner(VKeyAddBox,6)
local TypeBtn = Instance.new("TextButton"); TypeBtn.Size=UDim2.new(0.45,0,0,30); TypeBtn.Position=UDim2.new(0.03,0,0.1,0); TypeBtn.BackgroundColor3=Theme.Element; TypeBtn.Text="Melee"; TypeBtn.TextColor3=Theme.Text; TypeBtn.Parent=VKeyAddBox; createCorner(TypeBtn,6)
local KeyBtn = Instance.new("TextButton"); KeyBtn.Size=UDim2.new(0.45,0,0,30); KeyBtn.Position=UDim2.new(0.52,0,0.1,0); KeyBtn.BackgroundColor3=Theme.Element; KeyBtn.Text="Z"; KeyBtn.TextColor3=Theme.Text; KeyBtn.Parent=VKeyAddBox; createCorner(KeyBtn,6)
local AddVKeyBtn = Instance.new("TextButton"); AddVKeyBtn.Size=UDim2.new(0.94,0,0,30); AddVKeyBtn.Position=UDim2.new(0.03,0,0.55,0); AddVKeyBtn.BackgroundColor3=Theme.Green; AddVKeyBtn.Text="ADD BOUND KEY"; AddVKeyBtn.TextColor3=Theme.Bg; AddVKeyBtn.Font=Enum.Font.GothamBold; AddVKeyBtn.Parent=VKeyAddBox; createCorner(AddVKeyBtn,6)
local selW, selK = "Melee", "Z"
TypeBtn.MouseButton1Click:Connect(function() local tList={"Melee", "Fruit", "Sword", "Gun"}; local idx=table.find(tList, selW) or 0; selW=tList[(idx%#tList)+1]; TypeBtn.Text=selW end)
KeyBtn.MouseButton1Click:Connect(function() local kList={"Z", "X", "C", "V", "F"}; local idx=table.find(kList, selK) or 0; selK=kList[(idx%#kList)+1]; KeyBtn.Text=selK end)
AddVKeyBtn.MouseButton1Click:Connect(function() local slot=1; for i,v in ipairs(WeaponData) do if v.name==selW then slot=i break end end; local id=selW.." "..selK; toggleVirtualKey(selK, slot, id) end)

-- RESIZER & HIDE
local AdvLabel = Instance.new("TextLabel"); AdvLabel.Size=UDim2.new(1,0,0,20); AdvLabel.Text="RESIZE BUTTON"; AdvLabel.TextColor3=Theme.Accent; AdvLabel.Font=Enum.Font.GothamBold; AdvLabel.TextSize=11; AdvLabel.BackgroundTransparency=1; AdvLabel.LayoutOrder=7; AdvLabel.Parent=P_Lay
local AdvBox = Instance.new("Frame"); AdvBox.Size=UDim2.new(1,0,0,120); AdvBox.BackgroundColor3=Theme.Sidebar; AdvBox.LayoutOrder=8; AdvBox.Parent=P_Lay; createCorner(AdvBox,6)
local SelectBtn = Instance.new("TextButton"); SelectBtn.Size=UDim2.new(0.9,0,0,30); SelectBtn.Position=UDim2.new(0.05,0,0.1,0); SelectBtn.BackgroundColor3=Theme.Element; SelectBtn.Text="SELECT: NONE"; SelectBtn.TextColor3=Theme.Text; SelectBtn.Font=Enum.Font.GothamBold; SelectBtn.TextSize=11; SelectBtn.Parent=AdvBox; createCorner(SelectBtn,6)
local SizeSlider = Instance.new("Frame"); SizeSlider.Size=UDim2.new(0.9,0,0,4); SizeSlider.Position=UDim2.new(0.05,0,0.5,0); SizeSlider.BackgroundColor3=Theme.Stroke; SizeSlider.Parent=AdvBox; createCorner(SizeSlider,2)
local SizeKnob = Instance.new("TextButton"); SizeKnob.Size=UDim2.new(0,12,0,12); SizeKnob.Position=UDim2.new(0,-6,0.5,-6); SizeKnob.BackgroundColor3=Theme.Accent; SizeKnob.Text=""; SizeKnob.Parent=SizeSlider; SizeKnob.Selectable=false; createCorner(SizeKnob,6)
local SizeLabel = Instance.new("TextLabel"); SizeLabel.Size=UDim2.new(1,0,0,15); SizeLabel.Position=UDim2.new(0,0,-4,0); SizeLabel.Text="SIZE: 0%"; SizeLabel.TextColor3=Theme.SubText; SizeLabel.Font=Enum.Font.Gotham; SizeLabel.TextSize=10; SizeLabel.BackgroundTransparency=1; SizeLabel.Parent=SizeSlider
local VisBtn = Instance.new("TextButton"); VisBtn.Size=UDim2.new(0.9,0,0,30); VisBtn.Position=UDim2.new(0.05,0,0.7,0); VisBtn.BackgroundColor3=Theme.Green; VisBtn.Text="VISIBLE: ON"; VisBtn.TextColor3=Theme.Bg; VisBtn.Font=Enum.Font.GothamBold; VisBtn.TextSize=11; VisBtn.Parent=AdvBox; createCorner(VisBtn,6)

local ResizerIndex = 1
ResizerUpdateFunc = function() 
    ResizerList = {}; table.insert(ResizerList, {Name="JOYSTICK", Obj=JoyOuter, Type="Joy"}); table.insert(ResizerList, {Name="TOGGLE BTN", Obj=ToggleBtn, Type="Btn"}); 
    for i, c in ipairs(Combos) do table.insert(ResizerList, {Name=c.Name, Obj=c.Button, Type="Btn"}) end; 
    for id, vData in pairs(ActiveVirtualKeys) do table.insert(ResizerList, {Name=id, Obj=vData.Button, Type="Btn"}) end; 
    if ResizerIndex > #ResizerList then ResizerIndex = 1 end; 
    if #ResizerList == 0 then SelectBtn.Text = "SELECT: NONE"; CurrentSelectedElement = nil; VisBtn.Text="VISIBLE: --"; VisBtn.BackgroundColor3=Theme.Element; return end; 
    local item = ResizerList[ResizerIndex]; SelectBtn.Text = "SELECT: " .. item.Name; CurrentSelectedElement = item 
    if item.Obj.Visible then VisBtn.Text="VISIBLE: ON"; VisBtn.BackgroundColor3=Theme.Green else VisBtn.Text="VISIBLE: OFF"; VisBtn.BackgroundColor3=Theme.Red end
end

SelectBtn.MouseButton1Click:Connect(function() 
    if #ResizerList == 0 then return end; ResizerIndex = ResizerIndex + 1; if ResizerIndex > #ResizerList then ResizerIndex = 1 end; 
    ResizerUpdateFunc();
    local item = CurrentSelectedElement; local currentSize = item.Obj.Size.X.Offset; local p = 0.5; 
    if item.Type == "Joy" then p = (currentSize - 100) / 150 else p = (currentSize - 30) / 70 end; 
    p = math.clamp(p, 0, 1); SizeKnob.Position = UDim2.new(p, -6, 0.5, -6); SizeLabel.Text = "SIZE: " .. math.floor(currentSize) .. "px" 
end)

VisBtn.MouseButton1Click:Connect(function()
    if CurrentSelectedElement then
        CurrentSelectedElement.Obj.Visible = not CurrentSelectedElement.Obj.Visible
        ResizerUpdateFunc()
    end
end)

local dragS = false; SizeKnob.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragS=true end end); UserInputService.InputChanged:Connect(function(i) if dragS and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) and CurrentSelectedElement then local p = math.clamp((i.Position.X - SizeSlider.AbsolutePosition.X) / SizeSlider.AbsoluteSize.X, 0, 1); SizeKnob.Position = UDim2.new(p, -6, 0.5, -6); local newSize = 0; if CurrentSelectedElement.Type == "Joy" then newSize = 100 + (p * 150); CurrentSelectedElement.Obj.Size = UDim2.new(0, newSize, 0, newSize); JoyContainer.Size = UDim2.new(0, newSize, 0, newSize + 30); createCorner(CurrentSelectedElement.Obj, newSize) else newSize = 30 + (p * 70); CurrentSelectedElement.Obj.Size = UDim2.new(0, newSize, 0, newSize); if CurrentSelectedElement.Name:find("C") then createCorner(CurrentSelectedElement.Obj, newSize/2) end end; SizeLabel.Text = "SIZE: " .. math.floor(newSize) .. "px" end end); UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragS=false end end)

-- === COMBO EDITOR (FIXED & RESTORED) ===
local TopNav = Instance.new("Frame"); TopNav.Size=UDim2.new(1,0,0,35); TopNav.BackgroundTransparency=1; TopNav.Parent=P_Edit
local NavPrev = Instance.new("TextButton"); NavPrev.Size=UDim2.new(0,30,0,30); NavPrev.Position=UDim2.new(0,5,0,0); NavPrev.BackgroundColor3=Theme.Element; NavPrev.Text="<"; NavPrev.TextColor3=Theme.Accent; NavPrev.Font=Enum.Font.GothamBold; NavPrev.Parent=TopNav; createCorner(NavPrev,6)
local NavNext = Instance.new("TextButton"); NavNext.Size=UDim2.new(0,30,0,30); NavNext.Position=UDim2.new(1,-35,0,0); NavNext.BackgroundColor3=Theme.Element; NavNext.Text=">"; NavNext.TextColor3=Theme.Accent; NavNext.Font=Enum.Font.GothamBold; NavNext.Parent=TopNav; createCorner(NavNext,6)
local NavLbl = Instance.new("TextLabel"); NavLbl.Size=UDim2.new(0.6,0,1,0); NavLbl.Position=UDim2.new(0.2,0,0,0); NavLbl.Text="No Combo Selected"; NavLbl.TextColor3=Theme.Text; NavLbl.BackgroundTransparency=1; NavLbl.Font=Enum.Font.GothamBold; NavLbl.TextSize=14; NavLbl.Parent=TopNav
local EditScroll=Instance.new("ScrollingFrame"); EditScroll.Size=UDim2.new(1,0,0.75,0); EditScroll.Position=UDim2.new(0,0,0.12,0); EditScroll.BackgroundTransparency=1; EditScroll.ScrollBarThickness=3; EditScroll.Parent=P_Edit; local EditList=Instance.new("UIListLayout"); EditList.Parent=EditScroll; EditList.Padding=UDim.new(0,8)
local BottomBar = Instance.new("Frame"); BottomBar.Size=UDim2.new(1,0,0,40); BottomBar.Position=UDim2.new(0,0,1,0); BottomBar.AnchorPoint=Vector2.new(0,1); BottomBar.BackgroundTransparency=1; BottomBar.Parent=P_Edit
local AddAction=Instance.new("TextButton"); AddAction.Size=UDim2.new(1,0,1,-5); AddAction.Text="+ ADD ACTION"; AddAction.BackgroundColor3=Theme.Green; AddAction.TextColor3=Theme.Bg; AddAction.Font=Enum.Font.GothamBold; AddAction.Parent=BottomBar; AddAction.Selectable=false; createCorner(AddAction,6)

RefreshEditorUI = function()
    if CurrentComboIndex == 0 or not Combos[CurrentComboIndex] then NavLbl.Text="No Combo Selected"; EditScroll.Visible=false; BottomBar.Visible=false; return end
    EditScroll.Visible=true; BottomBar.Visible=true; local d = Combos[CurrentComboIndex]; NavLbl.Text = d.Name
    for _,c in pairs(EditScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    EditScroll.CanvasSize = UDim2.new(0,0,0, (#d.Steps * 65) + 50)
    for i,s in ipairs(d.Steps) do
        local h = (s.IsHold) and 85 or 60; local r = Instance.new("Frame"); r.Size=UDim2.new(1,0,0,h); r.BackgroundColor3=Theme.Element; r.Parent=EditScroll; createCorner(r,6)
        local top = Instance.new("Frame"); top.Size=UDim2.new(1,0,0,30); top.BackgroundTransparency=1; top.Parent=r
        local w = Instance.new("TextButton"); w.Size=UDim2.new(0.25,0,1,0); w.Position=UDim2.new(0.02,0,0,0); w.Text=WeaponData[s.Slot].name; w.TextColor3=WeaponData[s.Slot].color; w.BackgroundTransparency=1; w.Parent=top; w.Font=Enum.Font.GothamBold; w.TextSize=11; w.TextXAlignment="Left"; w.Selectable=false; w.MouseButton1Click:Connect(function() s.Slot=(s.Slot%4)+1; s.Key=WeaponData[s.Slot].keys[1]; RefreshEditorUI() end)
        local k = Instance.new("TextButton"); k.Size=UDim2.new(0.15,0,1,0); k.Position=UDim2.new(0.3,0,0,0); k.Text="["..s.Key.."]"; k.TextColor3=Theme.Text; k.BackgroundTransparency=1; k.Parent=top; k.Font=Enum.Font.GothamBold; k.TextSize=11; k.Selectable=false; k.MouseButton1Click:Connect(function() local l=WeaponData[s.Slot].keys; local idx=1; for j,v in ipairs(l) do if v==s.Key then idx=j end end; s.Key=l[(idx%#l)+1]; RefreshEditorUI() end)
        local m = Instance.new("TextButton"); m.Size=UDim2.new(0.25,0,0.7,0); m.Position=UDim2.new(0.5,0,0.15,0); m.Text=s.IsHold and "HOLD" or "TAP"; m.BackgroundColor3=s.IsHold and Theme.Accent or Theme.Green; m.TextColor3=Theme.Bg; m.Parent=top; m.Font=Enum.Font.GothamBold; m.TextSize=10; m.Selectable=false; createCorner(m,4); m.MouseButton1Click:Connect(function() s.IsHold = not s.IsHold; RefreshEditorUI() end)
        local x = Instance.new("TextButton"); x.Size=UDim2.new(0.1,0,1,0); x.Position=UDim2.new(0.9,0,0,0); x.Text="X"; x.TextColor3=Theme.Red; x.BackgroundTransparency=1; x.Parent=top; x.TextSize=11; x.Font=Enum.Font.GothamBold; x.Selectable=false; x.MouseButton1Click:Connect(function() table.remove(d.Steps, i); RefreshEditorUI() end)
        local function mkSlid(y, t, v, mx, cb, c) local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,25); f.Position=UDim2.new(0,0,0,y); f.BackgroundTransparency=1; f.Parent=r; local txt=Instance.new("TextLabel"); txt.Size=UDim2.new(0.3,0,1,0); txt.Position=UDim2.new(0.02,0,0,0); txt.Text=string.format(t,v); txt.TextColor3=c; txt.BackgroundTransparency=1; txt.TextSize=9; txt.TextXAlignment="Left"; txt.Parent=f; local bg=Instance.new("Frame"); bg.Size=UDim2.new(0.6,0,0,4); bg.Position=UDim2.new(0.35,0,0.5,-2); bg.BackgroundColor3=Theme.Stroke; bg.Parent=f; createCorner(bg,2); local kn=Instance.new("TextButton"); kn.Size=UDim2.new(0,10,0,10); kn.BackgroundColor3=Theme.Text; kn.Text=""; kn.Parent=bg; kn.Selectable=false; createCorner(kn,5); kn.Position=UDim2.new(math.clamp(v/mx,0,1),-5,0.5,-5); local sl=false; kn.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseButton1 then sl=true end end); UserInputService.InputChanged:Connect(function(inp) if sl and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then local p=math.clamp((inp.Position.X-bg.AbsolutePosition.X)/bg.AbsoluteSize.X,0,1); kn.Position=UDim2.new(p,-5,0.5,-5); cb(p); txt.Text=string.format(t, (p*mx)) end end); UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseButton1 then sl=false end end) end
        mkSlid(30, "Wait: +%.1fs", s.Delay or 0, 2.0, function(p) s.Delay=math.floor(p*2*10)/10 end, Theme.SubText)
        if s.IsHold then mkSlid(55, "Hold: %.1fs", s.HoldTime or 0.1, 3.0, function(p) s.HoldTime=math.floor(p*3*10)/10 end, Theme.Accent) end
    end
end
AddAction.MouseButton1Click:Connect(function() table.insert(Combos[CurrentComboIndex].Steps, {Slot=1, Key="Z", Delay=0, IsHold=false, HoldTime=0.5}); RefreshEditorUI() end)
NavPrev.MouseButton1Click:Connect(function() if #Combos>1 then CurrentComboIndex=CurrentComboIndex-1; if CurrentComboIndex<1 then CurrentComboIndex=#Combos end; RefreshEditorUI() end end)
NavNext.MouseButton1Click:Connect(function() if #Combos>1 then CurrentComboIndex=CurrentComboIndex+1; if CurrentComboIndex>#Combos then CurrentComboIndex=1 end; RefreshEditorUI() end end)

-- === CONTROLS TAB ===
local CtrlList = Instance.new("UIListLayout"); CtrlList.Parent=P_Control; CtrlList.Padding=UDim.new(0,10); CtrlList.SortOrder="LayoutOrder"
local CtrlPad = Instance.new("UIPadding"); CtrlPad.Parent=P_Control; CtrlPad.PaddingTop=UDim.new(0,10); CtrlPad.PaddingLeft=UDim.new(0,10); CtrlPad.PaddingRight=UDim.new(0,10)
local ModeBox = Instance.new("Frame"); ModeBox.Size=UDim2.new(1,0,0,50); ModeBox.BackgroundColor3=Theme.Sidebar; ModeBox.LayoutOrder=1; ModeBox.Parent=P_Control; createCorner(ModeBox,6)
local ModeBtn = Instance.new("TextButton"); ModeBtn.Size=UDim2.new(0.9,0,0,30); ModeBtn.Position=UDim2.new(0.05,0,0.5,-15); ModeBtn.BackgroundColor3=Theme.Green; ModeBtn.Text="SKILL MODE: INSTANT"; ModeBtn.TextColor3=Theme.Bg; ModeBtn.Font=Enum.Font.GothamBold; ModeBtn.Parent=ModeBox; createCorner(ModeBtn,6)
ModeBtn.MouseButton1Click:Connect(function() if SkillMode == "INSTANT" then SkillMode = "SMART"; ModeBtn.Text = "SKILL MODE: SMART TAP"; ModeBtn.BackgroundColor3 = Theme.Blue else SkillMode = "INSTANT"; ModeBtn.Text = "SKILL MODE: INSTANT"; ModeBtn.BackgroundColor3 = Theme.Green; CurrentSmartKeyData=nil; SelectedComboID=nil end end)
local BindContainer = Instance.new("Frame"); BindContainer.AutomaticSize=Enum.AutomaticSize.Y; BindContainer.Size=UDim2.new(1,0,0,0); BindContainer.BackgroundTransparency=1; BindContainer.LayoutOrder=2; BindContainer.Parent=P_Control; local BindList = Instance.new("UIListLayout"); BindList.Parent=BindContainer; BindList.Padding=UDim.new(0,5)
RefreshControlUI = function() for _, c in pairs(BindContainer:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end; for _, c in ipairs(Combos) do local f = Instance.new("Frame"); f.Size=UDim2.new(1,0,0,35); f.BackgroundColor3=Theme.Element; f.Parent=BindContainer; createCorner(f,6); local l = Instance.new("TextLabel"); l.Size=UDim2.new(0.6,0,1,0); l.Position=UDim2.new(0.05,0,0,0); l.Text=c.Name; l.TextColor3=Theme.Text; l.Font=Enum.Font.Gotham; l.TextXAlignment="Left"; l.BackgroundTransparency=1; l.Parent=f; local b = Instance.new("TextButton"); b.Size=UDim2.new(0.3,0,0.8,0); b.Position=UDim2.new(0.65,0,0.1,0); b.BackgroundColor3=Theme.Sidebar; b.TextColor3=Theme.Accent; b.Font=Enum.Font.GothamBold; b.Parent=f; createCorner(b,4); local bindKey = nil; for k,v in pairs(Keybinds) do if k == "C"..c.ID then bindKey=v end end; b.Text = bindKey and bindKey.Name or "BIND"; b.MouseButton1Click:Connect(function() b.Text="..."; local conn; conn = UserInputService.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Keyboard then Keybinds["C"..c.ID] = input.KeyCode; b.Text=input.KeyCode.Name; conn:Disconnect() end end) end) end; for id, vData in pairs(ActiveVirtualKeys) do local f = Instance.new("Frame"); f.Size=UDim2.new(1,0,0,35); f.BackgroundColor3=Theme.Element; f.Parent=BindContainer; createCorner(f,6); local l = Instance.new("TextLabel"); l.Size=UDim2.new(0.6,0,1,0); l.Position=UDim2.new(0.05,0,0,0); l.Text=id; l.TextColor3=Theme.Text; l.Font=Enum.Font.Gotham; l.TextXAlignment="Left"; l.BackgroundTransparency=1; l.Parent=f; local b = Instance.new("TextButton"); b.Size=UDim2.new(0.3,0,0.8,0); b.Position=UDim2.new(0.65,0,0.1,0); b.BackgroundColor3=Theme.Sidebar; b.TextColor3=Theme.Accent; b.Font=Enum.Font.GothamBold; b.Parent=f; createCorner(b,4); local bindKey = Keybinds[id]; b.Text = bindKey and bindKey.Name or "BIND"; b.MouseButton1Click:Connect(function() b.Text="..."; local conn; conn = UserInputService.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Keyboard then Keybinds[id] = input.KeyCode; b.Text=input.KeyCode.Name; conn:Disconnect() end end) end) end end

-- === SYSTEM TAB (RESTORED FIXED WITH CONFIRM) ===
local SysList = Instance.new("UIListLayout"); SysList.Parent=P_Sys; SysList.Padding=UDim.new(0,10); SysList.HorizontalAlignment="Center"
local SaveBtn = mkTool("SAVE CONFIG", Theme.Blue, function() if CurrentConfigName then ShowPopup("SAVE OPTIONS", function(c) local b1 = Instance.new("TextButton"); b1.Size=UDim2.new(1,0,0,35); b1.BackgroundColor3=Theme.Bg; b1.Text="Overwrite '"..CurrentConfigName.."'"; b1.TextColor3=Theme.Accent; b1.Parent=c; createCorner(b1,6); b1.MouseButton1Click:Connect(function() SaveToFile(CurrentConfigName, GetCurrentState()); ClosePopup() end); local b2 = Instance.new("TextButton"); b2.Size=UDim2.new(1,0,0,35); b2.Position=UDim2.new(0,0,0,40); b2.BackgroundColor3=Theme.Bg; b2.Text="Save as New"; b2.TextColor3=Theme.Text; b2.Parent=c; createCorner(b2,6); b2.MouseButton1Click:Connect(function() ClosePopup(); ShowPopup("NEW CONFIG", function(c2) local box = Instance.new("TextBox"); box.Size=UDim2.new(1,0,0,35); box.BackgroundColor3=Theme.Element; box.Text=""; box.PlaceholderText="Enter Name..."; box.TextColor3=Theme.Text; box.Parent=c2; createCorner(box,6); local confirm = Instance.new("TextButton"); confirm.Size=UDim2.new(1,0,0,35); confirm.Position=UDim2.new(0,0,0,40); confirm.BackgroundColor3=Theme.Green; confirm.Text="CREATE"; confirm.TextColor3=Theme.Bg; confirm.Parent=c2; createCorner(confirm,6); confirm.MouseButton1Click:Connect(function() if box.Text~="" then SaveToFile(box.Text, GetCurrentState()); ClosePopup() end end); return 80 end) end); return 80 end) else ShowPopup("NEW CONFIG", function(c) local box = Instance.new("TextBox"); box.Size=UDim2.new(1,0,0,35); box.BackgroundColor3=Theme.Element; box.Text=""; box.PlaceholderText="Enter Name..."; box.TextColor3=Theme.Text; box.Parent=c; createCorner(box,6); local confirm = Instance.new("TextButton"); confirm.Size=UDim2.new(1,0,0,35); confirm.Position=UDim2.new(0,0,0,40); confirm.BackgroundColor3=Theme.Green; confirm.Text="CREATE"; confirm.TextColor3=Theme.Bg; confirm.Parent=c; createCorner(confirm,6); confirm.MouseButton1Click:Connect(function() if box.Text~="" then SaveToFile(box.Text, GetCurrentState()); ClosePopup() end end); return 80 end) end end, P_Sys); SaveBtn.Size=UDim2.new(0.9,0,0,45)
local LoadBtn = mkTool("LOAD CONFIG", Theme.Blue, function() ShowPopup("SELECT CONFIG", function(container) local scroll = Instance.new("ScrollingFrame"); scroll.Size=UDim2.new(1,0,0,150); scroll.BackgroundTransparency=1; scroll.Parent=container; scroll.ScrollBarThickness=3; local layout = Instance.new("UIListLayout"); layout.Parent=scroll; layout.Padding=UDim.new(0,2); local count = 0; if isfile(FileName) then local r = readfile(FileName); local all = HttpService:JSONDecode(r); for name, _ in pairs(all) do if name ~= "LastUsed" then count = count + 1; local b = Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,30); b.BackgroundColor3=Theme.Bg; b.Text=name; b.TextColor3=Theme.SubText; b.Parent=scroll; createCorner(b,6); b.MouseButton1Click:Connect(function() ClosePopup(); ShowPopup("MANAGE: "..name, function(c2) local l = Instance.new("TextButton"); l.Size=UDim2.new(1,0,0,30); l.BackgroundColor3=Theme.Green; l.Text="LOAD"; l.TextColor3=Theme.Bg; l.Parent=c2; createCorner(l,6); l.MouseButton1Click:Connect(function() LoadSpecific(name); ClosePopup() end); local r = Instance.new("TextButton"); r.Size=UDim2.new(1,0,0,30); r.Position=UDim2.new(0,0,0,35); r.BackgroundColor3=Theme.Blue; r.Text="RENAME"; r.TextColor3=Theme.Bg; r.Parent=c2; createCorner(r,6); r.MouseButton1Click:Connect(function() ClosePopup(); ShowPopup("RENAME TO...", function(c3) local box = Instance.new("TextBox"); box.Size=UDim2.new(1,0,0,35); box.BackgroundColor3=Theme.Element; box.Text=""; box.PlaceholderText="New Name..."; box.TextColor3=Theme.Text; box.Parent=c3; createCorner(box,6); local confirm = Instance.new("TextButton"); confirm.Size=UDim2.new(1,0,0,35); confirm.Position=UDim2.new(0,0,0,40); confirm.BackgroundColor3=Theme.Blue; confirm.Text="UPDATE"; confirm.TextColor3=Theme.Bg; confirm.Parent=c3; createCorner(confirm,6); confirm.MouseButton1Click:Connect(function() if box.Text ~= "" and box.Text ~= name then local f = readfile(FileName); local d = HttpService:JSONDecode(f); d[box.Text] = d[name]; d[name] = nil; if d["LastUsed"] == name then d["LastUsed"] = box.Text end; writefile(FileName, HttpService:JSONEncode(d)); ClosePopup(); ShowNotification("Renamed!", Theme.Blue) end end); return 80 end) end); local d = Instance.new("TextButton"); d.Size=UDim2.new(1,0,0,30); d.Position=UDim2.new(0,0,0,70); d.BackgroundColor3=Theme.Red; d.Text="DELETE"; d.TextColor3=Theme.Bg; d.Parent=c2; createCorner(d,6); d.MouseButton1Click:Connect(function() local f = readfile(FileName); local d = HttpService:JSONDecode(f); d[name] = nil; if d["LastUsed"]==name then d["LastUsed"]=nil end; writefile(FileName, HttpService:JSONEncode(d)); ClosePopup(); ShowNotification("Deleted", Theme.Red) end); return 105 end) end) end end end; scroll.CanvasSize = UDim2.new(0,0,0, count * 32); return 150 end) end, P_Sys); LoadBtn.Size=UDim2.new(0.9,0,0,45)
local ResetBtn = mkTool("RESET CONFIG", Theme.Red, function() 
    ShowPopup("CONFIRM RESET?", function(c)
        local yes = Instance.new("TextButton"); yes.Size=UDim2.new(0.45,0,0,40); yes.BackgroundColor3=Theme.Green; yes.Text="YES"; yes.TextColor3=Theme.Bg; yes.Parent=c; createCorner(yes,6)
        local no = Instance.new("TextButton"); no.Size=UDim2.new(0.45,0,0,40); no.Position=UDim2.new(0.55,0,0,0); no.BackgroundColor3=Theme.Red; no.Text="NO"; no.TextColor3=Theme.Bg; no.Parent=c; createCorner(no,6)
        yes.MouseButton1Click:Connect(function()
            for _, c in pairs(Combos) do if c.Button then c.Button:Destroy() end end; Combos = {}; 
            for _, vData in pairs(ActiveVirtualKeys) do vData.Button:Destroy() end; ActiveVirtualKeys = {}; 
            GlobalTransparency = 0; TKnob.Position=UDim2.new(0, -6, 0.5, -6); AreButtonsHidden = false; HideBtn.Text = "HIDE BUTTONS: OFF"; HideBtn.BackgroundColor3 = Theme.Red; 
            UpdateTransparencyFunc(); IsJoystickEnabled = false; JoyContainer.Visible = false; JoyToggle.Text="JOYSTICK: OFF"; JoyToggle.BackgroundColor3=Theme.Red; 
            IsLayoutLocked = false; JoyContainer.Position = UDim2.new(0.1, 0, 0.6, 0); CurrentComboIndex = 0; CurrentConfigName = nil; SkillMode = "INSTANT"; 
            if ResizerUpdateFunc then ResizerUpdateFunc() end; updateLockState(); RefreshControlUI(); ShowNotification("Config Reset!", Theme.Accent); ClosePopup()
        end)
        no.MouseButton1Click:Connect(ClosePopup)
        return 50
    end)
end, P_Sys); ResetBtn.Size=UDim2.new(0.9,0,0,45)
local ExitBtn = mkTool("EXIT SCRIPT", Theme.Red, function() 
    ShowPopup("CONFIRM EXIT?", function(c)
        local yes = Instance.new("TextButton"); yes.Size=UDim2.new(0.45,0,0,40); yes.BackgroundColor3=Theme.Green; yes.Text="YES"; yes.TextColor3=Theme.Bg; yes.Parent=c; createCorner(yes,6)
        local no = Instance.new("TextButton"); no.Size=UDim2.new(0.45,0,0,40); no.Position=UDim2.new(0.55,0,0,0); no.BackgroundColor3=Theme.Red; no.Text="NO"; no.TextColor3=Theme.Bg; no.Parent=c; createCorner(no,6)
        yes.MouseButton1Click:Connect(function() isRunning = false; ScreenGui:Destroy() end)
        no.MouseButton1Click:Connect(ClosePopup)
        return 50
    end)
end, P_Sys); ExitBtn.Size=UDim2.new(0.9,0,0,45)

-- === STARTUP ===
ShowNotification("VELOX Loaded.", Theme.Accent)
task.wait(1)
ShowNotification("Custom Layout: READY", Theme.Green)
task.wait(1)
ShowNotification("Macro Engine: ONLINE", Theme.Blue)
task.delay(0.5, function() if isfile(FileName) then local s, r = pcall(function() return readfile(FileName) end); if s then local data = HttpService:JSONDecode(r); if data["LastUsed"] and data[data["LastUsed"]] then LoadSpecific(data["LastUsed"]) end end end end)
