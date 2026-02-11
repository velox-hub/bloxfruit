-- ==============================================================================

-- [ VELOX V1.4 - MOBILE NATIVE INPUT ]

-- Input Engine: FireUI + Virtual Input Manager (Touch)

-- ==============================================================================



local VIM = game:GetService("VirtualInputManager")

local Players = game:GetService("Players")

local CoreGui = game:GetService("CoreGui")

local UserInputService = game:GetService("UserInputService")

local HttpService = game:GetService("HttpService")

local RunService = game:GetService("RunService")

local Workspace = game:GetService("Workspace")



local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer

local FileName = "Velox_Config_Mobile.json"



-- CONFIGURATION

local Theme = {

    Bg      = Color3.fromRGB(18, 18, 22),

    Sidebar = Color3.fromRGB(26, 26, 32),

    Element = Color3.fromRGB(35, 35, 42),

    Accent  = Color3.fromRGB(0, 255, 170), -- Ganti jadi Cyan agar lebih segar

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

local IsJoystickEnabled = false 

local JoyConnection = nil 



local Combos = {} 

local CurrentComboIndex = 0 

local ActiveVirtualKeys = {} 

local CurrentConfigName = nil 

local Keybinds = {} 

local VirtualKeySelectors = {}



-- SYSTEM VARS

local SkillMode = "INSTANT" 

local CurrentSmartKeyData = nil 

local SelectedComboID = nil 



-- UI VARIABLES

local ResizerList = {}

local CurrentSelectedElement = nil

local ScreenGui = nil

local ResizerUpdateFunc, UpdateTransparencyFunc, RefreshEditorUI, RefreshControlUI, CreateComboButtonFunc



local WeaponData = {

    {name = "Melee", slot = 1, color = Color3.fromRGB(255, 140, 0), tooltip = "Melee", keys = {"Z", "X", "C"}},

    {name = "Fruit", slot = 2, color = Color3.fromRGB(170, 50, 255), tooltip = "Blox Fruit", keys = {"Z", "X", "C", "V", "F"}},

    {name = "Sword", slot = 3, color = Color3.fromRGB(0, 160, 255), tooltip = "Sword", keys = {"Z", "X"}},

    {name = "Gun",   slot = 4, color = Color3.fromRGB(255, 220, 0),   tooltip = "Gun", keys = {"Z", "X"}}

}



-- ==============================================================================

-- [1] ENGINE INPUT BARU (CORE PERUBAHAN)

-- ==============================================================================



-- Fungsi 1: Paksa Klik Tombol UI Blox Fruit (FireUI)

local function FireUI(btn)

    if not btn then return end

    for _, c in pairs(getconnections(btn.Activated)) do c:Fire() end

    for _, c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire() end

    for _, c in pairs(getconnections(btn.InputBegan)) do 

        c:Fire({UserInputType=Enum.UserInputType.MouseButton1, UserInputState=Enum.UserInputState.Begin})

    end

end



-- Fungsi 2: Tap Tengah Layar (M1) untuk Konfirmasi Skill

local function TapM1()

    local vp = Camera.ViewportSize

    local x, y = vp.X / 2, vp.Y / 2 * 0.8 -- Agak ke atas sedikit

    

    VIM:SendTouchEvent(5, 0, x, y) -- Sentuh

    task.wait() -- 1 frame delay

    VIM:SendTouchEvent(5, 2, x, y) -- Lepas

end



-- Fungsi 3: Eksekusi Skill (Cari Tombol -> FireUI -> TapM1)

local function CastSkill(key)

    -- Cari Folder Skill di PlayerGui

    local PGui = LocalPlayer:FindFirstChild("PlayerGui")

    local MainGui = PGui and PGui:FindFirstChild("Main")

    local SkillsFrame = MainGui and MainGui:FindFirstChild("Skills")



    if SkillsFrame then

        -- Loop cari tombol skill (Z, X, C, V, F)

        for _, frame in pairs(SkillsFrame:GetChildren()) do

            if frame:IsA("Frame") and frame.Visible then

                -- Blox Fruits punya tombol bernama KeyCode di dalam frame skill

                if frame.Name == key or frame:FindFirstChild(key) then

                    local btn = frame:FindFirstChild("Mobile") or frame:FindFirstChild("Button") or frame:FindFirstChild(key)

                    

                    if btn then

                        FireUI(btn) -- 1. Pilih Skill

                        TapM1()     -- 2. Tembak (Auto Aim)

                        return true

                    end

                end

            end

        end

    end

    return false

end



-- Fungsi 4: Ganti Senjata (Langsung Humanoid)

local function EquipWeaponDirect(slotIdx)

    local char = LocalPlayer.Character

    if not char then return end

    local hum = char:FindFirstChild("Humanoid")

    if not hum then return end

    

    local targetTip = WeaponData[slotIdx].tooltip

    local current = char:FindFirstChildOfClass("Tool")

    

    -- Cek jika sudah equip

    if current and current.ToolTip == targetTip then return end



    -- Cari di Backpack

    for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do

        if t:IsA("Tool") and t.ToolTip == targetTip then

            hum:EquipTool(t)

            return

        end

    end

end



-- ==============================================================================

-- [2] UTILITY FUNCTIONS

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



local function isChatting()

    return UserInputService:GetFocusedTextBox() ~= nil

end



-- ==============================================================================

-- [3] UI HELPERS & NOTIF

-- ==============================================================================



local JoyOuter, JoyKnob, JoyDrag, ToggleBtn, JoyContainer, LockBtn



UpdateTransparencyFunc = function()

    local t = GlobalTransparency

    if ToggleBtn then ToggleBtn.BackgroundTransparency = t; ToggleBtn.TextTransparency = t; if ToggleBtn:FindFirstChild("UIStroke") then ToggleBtn.UIStroke.Transparency = t end end

    for _, c in pairs(Combos) do if c.Button then c.Button.BackgroundTransparency = t; c.Button.TextTransparency = t; if c.Button:FindFirstChild("UIStroke") then c.Button.UIStroke.Transparency = t end end end

    for _, item in pairs(ActiveVirtualKeys) do local btn = item.Button; btn.BackgroundTransparency = t; btn.TextTransparency = t; if btn:FindFirstChild("UIStroke") then btn.UIStroke.Transparency = t end end

    if JoyOuter and JoyKnob then JoyOuter.BackgroundTransparency = math.clamp(0.3 + t, 0.3, 1); JoyKnob.BackgroundTransparency = math.clamp(0.2 + t, 0.2, 1); JoyDrag.BackgroundTransparency = t; JoyDrag.TextTransparency = t end

end



local function updateLockState()

    if JoyDrag then JoyDrag.Visible = (not IsLayoutLocked) and IsJoystickEnabled end

    if LockBtn then LockBtn.Text = IsLayoutLocked and "POS: LOCKED" or "POS: UNLOCKED"; LockBtn.BackgroundColor3 = IsLayoutLocked and Theme.Red or Theme.Green end

    if ResizerUpdateFunc then ResizerUpdateFunc() end

end



local NotifContainer = nil 

local function ShowNotification(text, color)

    if not NotifContainer then return end

    local f = Instance.new("Frame"); f.Size=UDim2.new(0,200,0,40); f.Position=UDim2.new(0.5,-100,0.1,0); f.BackgroundColor3=Theme.Sidebar; f.BackgroundTransparency=0.1; f.Parent=NotifContainer; f.ZIndex=6000; createCorner(f,8); createStroke(f,color or Theme.Accent)

    local l = Instance.new("TextLabel"); l.Size=UDim2.new(1,0,1,0); l.Text=text; l.TextColor3=Theme.Text; l.Font=Enum.Font.GothamBold; l.TextSize=12; l.BackgroundTransparency=1; l.Parent=f; l.ZIndex=6001

    task.delay(1.5, function() f:Destroy() end)

end



-- ==============================================================================

-- [4] COMBO EXECUTOR (UPDATED)

-- ==============================================================================



local function executeComboSequence(idx)

    if isChatting() then return end 



    local data = Combos[idx]

    if not data or not data.Button then return end

    

    if isRunning then return end -- Prevent Spam



    isRunning = true

    local btn = data.Button

    btn.Text = "STOP"

    btn.BackgroundColor3 = Theme.Red

    btn.UIStroke.Color = Theme.Red

    

    task.spawn(function()

        for i, step in ipairs(data.Steps) do

            if not isRunning then break end

            

            -- 1. Equip Senjata (Metode Humanoid)

            EquipWeaponDirect(step.Slot)

            

            -- 2. Delay sebelum skill

            if step.Delay and step.Delay > 0 then task.wait(step.Delay) end

            

            -- 3. Cast Skill (Metode FireUI + TapM1)

            CastSkill(step.Key)

            

            -- 4. Delay agar skill tidak tumpang tindih

            local waitTime = step.HoldTime or 0.1

            if waitTime < 0.15 then waitTime = 0.15 end -- Minimal delay agar register

            task.wait(waitTime)

        end

        

        isRunning = false

        if btn then btn.Text = data.Name; btn.BackgroundColor3 = Theme.Sidebar; btn.UIStroke.Color = Theme.Accent end

        if SelectedComboID == idx then btn.BackgroundColor3 = Theme.Green; btn.UIStroke.Color = Theme.Green end

    end)

end



local SmartTouchObject = nil 



-- ==============================================================================

-- [5] INPUT HANDLER (TOUCH & MOUSE)

-- ==============================================================================



UserInputService.InputBegan:Connect(function(input, gameProcessed)

    if isChatting() then return end 



    -- [INPUT MOBILE / CLICK]

    if not gameProcessed and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then

        

        -- Logic Smart Tap

        if SkillMode == "SMART" and CurrentSmartKeyData ~= nil then

            SmartTouchObject = input 

            task.spawn(function()

                if CurrentSmartKeyData.Slot then EquipWeaponDirect(CurrentSmartKeyData.Slot) end

                task.wait(0.05) -- Delay equip

                CastSkill(CurrentSmartKeyData.Key.Name) -- Paksa Cast

            end)

        end

        

        -- Logic Pilih Combo (Mode Smart)

        if SelectedComboID ~= nil and not isRunning then

            executeComboSequence(SelectedComboID)

        end

    end

end)



UserInputService.InputEnded:Connect(function(input)

    -- Reset Smart Tap

    if input == SmartTouchObject and SkillMode == "SMART" and CurrentSmartKeyData ~= nil then

        if ActiveVirtualKeys[CurrentSmartKeyData.ID] then

            local btn = ActiveVirtualKeys[CurrentSmartKeyData.ID].Button

            btn.BackgroundColor3 = Color3.fromRGB(0,0,0)

            btn.TextColor3 = Theme.Accent

        end

        CurrentSmartKeyData = nil

        SmartTouchObject = nil

    end

end)



-- ==============================================================================

-- [6] UI BUILDER

-- ==============================================================================



if CoreGui:FindFirstChild("VeloxUI") then CoreGui.VeloxUI:Destroy() end

ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "VeloxUI"; ScreenGui.Parent = CoreGui; ScreenGui.ResetOnSpawn = false



NotifContainer = Instance.new("Frame"); NotifContainer.Size = UDim2.new(1,0,1,0); NotifContainer.BackgroundTransparency = 1; NotifContainer.Parent = ScreenGui; NotifContainer.ZIndex = 6000



ToggleBtn = Instance.new("TextButton")

ToggleBtn.Size = UDim2.new(0, 45, 0, 45); ToggleBtn.Position = UDim2.new(0.02, 0, 0.3, 0); ToggleBtn.BackgroundColor3 = Theme.Sidebar; ToggleBtn.Text = "V"; ToggleBtn.TextColor3 = Theme.Accent; ToggleBtn.Font = Enum.Font.GothamBlack; ToggleBtn.TextSize = 24; ToggleBtn.Parent = ScreenGui; ToggleBtn.ZIndex = 200; createCorner(ToggleBtn, 12); createStroke(ToggleBtn, Theme.Accent)

MakeDraggable(ToggleBtn, nil)



local Window = Instance.new("Frame"); Window.Size = UDim2.new(0, 600, 0, 340); Window.Position = UDim2.new(0.5, -300, 0.5, -170); Window.BackgroundColor3 = Theme.Bg; Window.Visible = true; Window.Parent = ScreenGui; Window.ZIndex = 100; createCorner(Window, 10); createStroke(Window, Theme.Accent)

MakeDraggable(Window, nil)

ToggleBtn.MouseButton1Click:Connect(function() Window.Visible = not Window.Visible end)



-- Popup & Tabs (Condensed for Space)

local PopupOverlay = Instance.new("Frame"); PopupOverlay.Size=UDim2.new(1,0,1,0); PopupOverlay.BackgroundColor3=Color3.new(0,0,0); PopupOverlay.BackgroundTransparency=0.5; PopupOverlay.Parent=Window; PopupOverlay.Visible=false; PopupOverlay.ZIndex=2000

local function ClosePopup() PopupOverlay.Visible=false; for _,c in pairs(PopupOverlay:GetChildren()) do c:Destroy() end end

local function ShowPopup(title, contentFunc) for _,c in pairs(PopupOverlay:GetChildren()) do c:Destroy() end; PopupOverlay.Visible=true; local M=Instance.new("Frame"); M.Size=UDim2.new(0,300,0,0); M.AnchorPoint=Vector2.new(0.5,0.5); M.Position=UDim2.new(0.5,0,0.5,0); M.BackgroundColor3=Theme.Popup; M.Parent=PopupOverlay; M.ZIndex=2001; createCorner(M,10); createStroke(M,Theme.Accent); local T=Instance.new("TextLabel"); T.Size=UDim2.new(1,0,0,40); T.Text=title; T.Font=Enum.Font.GothamBlack; T.TextColor3=Theme.Accent; T.BackgroundTransparency=1; T.Parent=M; T.ZIndex=2002; local C=Instance.new("TextButton"); C.Size=UDim2.new(0,30,0,30); C.Position=UDim2.new(1,-35,0,5); C.Text="X"; C.TextColor3=Theme.Red; C.BackgroundTransparency=1; C.Parent=M; C.ZIndex=2003; C.MouseButton1Click:Connect(ClosePopup); local Cont=Instance.new("Frame"); Cont.Size=UDim2.new(0.9,0,0,0); Cont.Position=UDim2.new(0.05,0,0,45); Cont.BackgroundTransparency=1; Cont.Parent=M; Cont.ZIndex=2002; local h=contentFunc(Cont); M.Size=UDim2.new(0,300,0,h+55) end



local Sidebar = Instance.new("Frame"); Sidebar.Size=UDim2.new(0,140,1,0); Sidebar.BackgroundColor3=Theme.Sidebar; Sidebar.Parent=Window; createCorner(Sidebar,10)

local NavContainer = Instance.new("Frame"); NavContainer.Size=UDim2.new(1,0,1,-60); NavContainer.Position=UDim2.new(0,0,0,60); NavContainer.BackgroundTransparency=1; NavContainer.Parent=Sidebar

local SideLayout = Instance.new("UIListLayout"); SideLayout.Parent=NavContainer; SideLayout.HorizontalAlignment="Center"; SideLayout.Padding=UDim.new(0,5)

local Content = Instance.new("Frame"); Content.Size=UDim2.new(1,-150,1,-20); Content.Position=UDim2.new(0,150,0,10); Content.BackgroundTransparency=1; Content.Parent=Window

local Pages={}; local function nav(n) for k,p in pairs(Pages) do p.Visible=(k==n) end end

local function mkNav(txt,tgt) local b=Instance.new("TextButton"); b.Size=UDim2.new(0.9,0,0,40); b.BackgroundColor3=Theme.Bg; b.BackgroundTransparency=1; b.Text=txt; b.TextColor3=Theme.SubText; b.Font=Enum.Font.GothamBold; b.Parent=NavContainer; createCorner(b,6); b.MouseButton1Click:Connect(function() nav(tgt); for _,c in pairs(NavContainer:GetChildren()) do if c:IsA("TextButton") then c.TextColor3=Theme.SubText; c.BackgroundTransparency=1 end end; b.TextColor3=Theme.Accent; b.BackgroundTransparency=0; b.BackgroundColor3=Theme.Element end) return b end



local P_Edit = Instance.new("Frame"); P_Edit.Size=UDim2.new(1,0,1,0); P_Edit.BackgroundTransparency=1; P_Edit.Visible=false; P_Edit.Parent=Content; Pages["Editor"]=P_Edit

local P_Lay = Instance.new("ScrollingFrame"); P_Lay.Size=UDim2.new(1,0,1,0); P_Lay.BackgroundTransparency=1; P_Lay.Visible=true; P_Lay.Parent=Content; Pages["Layout"]=P_Lay; P_Lay.ScrollBarThickness=4

local P_Sys = Instance.new("Frame"); P_Sys.Size=UDim2.new(1,0,1,0); P_Sys.BackgroundTransparency=1; P_Sys.Visible=false; P_Sys.Parent=Content; Pages["System"]=P_Sys



local N1=mkNav("LAYOUT", "Layout"); N1.TextColor3=Theme.Accent; N1.BackgroundTransparency=0; N1.BackgroundColor3=Theme.Element

mkNav("COMBO", "Editor"); mkNav("SYSTEM", "System")



-- ==============================================================================

-- [7] JOYSTICK (UPDATED LOOP)

-- ==============================================================================

JoyContainer = Instance.new("Frame"); JoyContainer.Size=UDim2.new(0,JOYSTICK_SIZE,0,JOYSTICK_SIZE+30); JoyContainer.Position=UDim2.new(0.1,0,0.6,0); JoyContainer.BackgroundTransparency=1; JoyContainer.Parent=ScreenGui; JoyContainer.Visible=false; JoyContainer.ZIndex=50

JoyDrag=Instance.new("TextButton"); JoyDrag.Size=UDim2.new(0,60,0,25); JoyDrag.Position=UDim2.new(0.5,-30,0,-10); JoyDrag.Text="DRAG"; JoyDrag.BackgroundColor3=Color3.fromRGB(30,30,30); JoyDrag.TextColor3=Theme.Accent; JoyDrag.Parent=JoyContainer; JoyDrag.Visible=false; createCorner(JoyDrag,6)

JoyOuter=Instance.new("ImageButton"); JoyOuter.Size=UDim2.new(0,JOYSTICK_SIZE,0,JOYSTICK_SIZE); JoyOuter.Position=UDim2.new(0,0,0,20); JoyOuter.BackgroundColor3=Color3.new(0,0,0); JoyOuter.BackgroundTransparency=0.3; JoyOuter.Parent=JoyContainer; createCorner(JoyOuter,JOYSTICK_SIZE); createStroke(JoyOuter,Theme.Text).Transparency=0.1

JoyKnob=Instance.new("Frame"); JoyKnob.Size=UDim2.new(0,KNOB_SIZE,0,KNOB_SIZE); JoyKnob.Position=UDim2.new(0.5,-KNOB_SIZE/2,0.5,-KNOB_SIZE/2); JoyKnob.BackgroundColor3=Theme.Accent; JoyKnob.BackgroundTransparency=0.2; JoyKnob.Parent=JoyOuter; createCorner(JoyKnob,KNOB_SIZE)



local function EnableJoyDrag()

    local d,o; JoyDrag.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then d=true; o=Vector2.new(i.Position.X-JoyContainer.AbsolutePosition.X, i.Position.Y-JoyContainer.AbsolutePosition.Y) end end)

    UserInputService.InputChanged:Connect(function(i) if d and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then JoyContainer.Position=UDim2.new(0,math.clamp(i.Position.X-o.X,0,Camera.ViewportSize.X-JoyOuter.AbsoluteSize.X),0,math.clamp(i.Position.Y-o.Y,0,Camera.ViewportSize.Y-(JoyOuter.AbsoluteSize.Y+30))) end end)

    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then d=false end end)

end; EnableJoyDrag()



local moveTouch, moveDir = nil, Vector2.new(0,0)

JoyOuter.InputBegan:Connect(function(i) if (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1) and not moveTouch then moveTouch=i end end)

UserInputService.InputChanged:Connect(function(i) if i==moveTouch then local c=JoyOuter.AbsolutePosition+(JoyOuter.AbsoluteSize/2); local v=Vector2.new(i.Position.X,i.Position.Y)-c; if v.Magnitude>JoyOuter.AbsoluteSize.X/2 then v=v.Unit*(JoyOuter.AbsoluteSize.X/2) end; JoyKnob.Position=UDim2.new(0.5,v.X-KNOB_SIZE/2,0.5,v.Y-KNOB_SIZE/2); moveDir=Vector2.new(v.X/(JoyOuter.AbsoluteSize.X/2),v.Y/(JoyOuter.AbsoluteSize.X/2)) end end)

UserInputService.InputEnded:Connect(function(i) if i==moveTouch then moveTouch=nil; moveDir=Vector2.new(0,0); JoyKnob.Position=UDim2.new(0.5,-KNOB_SIZE/2,0.5,-KNOB_SIZE/2) end end)



RunService.RenderStepped:Connect(function()

    if not IsJoystickEnabled or not LocalPlayer.Character then return end

    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")

    if not hum then return end

    if moveDir.Magnitude < DEADZONE then hum:Move(Vector3.new(0,0,0), true); return end

    local cam = workspace.CurrentCamera

    local mv = (Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z).Unit * -moveDir.Y) + (Vector3.new(cam.CFrame.RightVector.X,0,cam.CFrame.RightVector.Z).Unit * moveDir.X)

    hum:Move(mv, false)

end)



-- ==============================================================================

-- [8] VIRTUAL KEY MANAGER (UPDATED)

-- ==============================================================================



local function toggleVirtualKey(keyName, slotIdx, customName)

    local id = customName or keyName

    if ActiveVirtualKeys[id] then 

        ActiveVirtualKeys[id].Button:Destroy(); ActiveVirtualKeys[id]=nil

        if VirtualKeySelectors[id] then VirtualKeySelectors[id].BackgroundColor3=Theme.Element; VirtualKeySelectors[id].TextColor3=Theme.Text end

        UpdateTransparencyFunc(); if ResizerUpdateFunc then ResizerUpdateFunc() end

    else

        local btn = Instance.new("TextButton")

        btn.Size = UDim2.new(0, 50, 0, 50); btn.Position = UDim2.new(0.5, 0, 0.5, 0); btn.BackgroundColor3 = Color3.fromRGB(0,0,0); btn.Text = id; btn.TextColor3 = Theme.Accent; btn.Font = Enum.Font.GothamBold; btn.TextSize = 20; btn.Parent = ScreenGui; btn.ZIndex = 60; createCorner(btn, 12); createStroke(btn, Theme.Accent)

        MakeDraggable(btn, nil)

        

        local kCode = Enum.KeyCode[keyName] or Enum.KeyCode.One

        local vData = {ID=id, Key=kCode, Slot=slotIdx, Button=btn}

        local isWeaponKey = table.find({"1","2","3","4"}, keyName)

        

        btn.InputBegan:Connect(function(input)

            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then

                

                -- LOGIKA SENJATA (1-4)

                if isWeaponKey then

                    if vData.Slot then EquipWeaponDirect(vData.Slot) end

                    btn.BackgroundColor3 = Theme.Accent; btn.TextColor3 = Color3.new(0,0,0)

                    task.delay(0.1, function() btn.BackgroundColor3 = Color3.fromRGB(0,0,0); btn.TextColor3 = Theme.Accent end)

                    return

                end

                

                -- LOGIKA SKILL (Z-F)

                if SkillMode == "INSTANT" then

                    -- Instant: Pilih & Tembak langsung

                    if vData.Slot then EquipWeaponDirect(vData.Slot) end

                    CastSkill(keyName)

                    

                    -- Visual Effect

                    btn.BackgroundColor3 = Theme.Accent; btn.TextColor3 = Color3.new(0,0,0)

                    task.delay(0.1, function() btn.BackgroundColor3 = Color3.fromRGB(0,0,0); btn.TextColor3 = Theme.Accent end)

                    

                elseif SkillMode == "SMART" then

                    -- Smart: Pilih dulu (Hijau), tap lagi layar buat tembak

                    if CurrentSmartKeyData and CurrentSmartKeyData.ID ~= id then

                        local old = ActiveVirtualKeys[CurrentSmartKeyData.ID]

                        if old then old.Button.BackgroundColor3=Color3.fromRGB(0,0,0); old.Button.TextColor3=Theme.Accent end

                    end

                    if CurrentSmartKeyData and CurrentSmartKeyData.ID == id then

                        CurrentSmartKeyData = nil; btn.BackgroundColor3 = Color3.fromRGB(0,0,0); btn.TextColor3 = Theme.Accent

                    else

                        CurrentSmartKeyData = vData; btn.BackgroundColor3 = Theme.Green; btn.TextColor3 = Theme.Bg

                    end

                end

            end

        end)



        ActiveVirtualKeys[id] = vData

        if VirtualKeySelectors[id] then VirtualKeySelectors[id].BackgroundColor3=Theme.Green; VirtualKeySelectors[id].TextColor3=Theme.Bg end

        UpdateTransparencyFunc(); if ResizerUpdateFunc then ResizerUpdateFunc() end

    end

end



CreateComboButtonFunc = function(idx, loadedSteps)

    local btn = Instance.new("TextButton"); btn.Size=UDim2.new(0,60,0,60); btn.Position=UDim2.new(0.5,-30,0.5,0); btn.BackgroundColor3=Theme.Sidebar; btn.Text="C"..idx; btn.TextColor3=Theme.Accent; btn.Font=Enum.Font.GothamBold; btn.TextSize=18; btn.Parent=ScreenGui; btn.ZIndex=70; createCorner(btn,30); createStroke(btn,Theme.Accent)

    MakeDraggable(btn, function() 

        if SkillMode == "INSTANT" then executeComboSequence(idx) 

        else 

            if SelectedComboID==idx then SelectedComboID=nil; btn.BackgroundColor3=Theme.Sidebar; btn.UIStroke.Color=Theme.Accent; isRunning=false 

            else SelectedComboID=idx; btn.BackgroundColor3=Theme.Green; btn.UIStroke.Color=Theme.Green end 

        end 

    end)

    table.insert(Combos, {ID=idx, Name="C"..idx, Button=btn, Steps=loadedSteps or {}})

    CurrentComboIndex = idx; UpdateTransparencyFunc(); RefreshEditorUI(); if ResizerUpdateFunc then ResizerUpdateFunc() end

end



-- ==============================================================================

-- [9] LAYOUT TAB SETUP

-- ==============================================================================

local LayList = Instance.new("UIListLayout"); LayList.Parent=P_Lay; LayList.Padding=UDim.new(0,10)

local SetBox = Instance.new("Frame"); SetBox.Size=UDim2.new(0.95,0,0,80); SetBox.BackgroundTransparency=1; SetBox.Parent=P_Lay

local Grid1 = Instance.new("UIGridLayout"); Grid1.Parent=SetBox; Grid1.CellSize=UDim2.new(0.47,0,0,30); Grid1.CellPadding=UDim2.new(0.04,0,0.1,0)

local function mkTool(t,c,f,p) local b=Instance.new("TextButton"); b.Text=t; b.BackgroundColor3=Theme.Sidebar; b.TextColor3=Theme.Text; b.Font=Enum.Font.Gotham; b.TextSize=10; b.Parent=p; createCorner(b,6); createStroke(b,c); b.MouseButton1Click:Connect(f); return b end



LockBtn = mkTool("POS: UNLOCKED", Theme.Green, function() IsLayoutLocked=not IsLayoutLocked; updateLockState() end, SetBox)

local JoyToggle = mkTool("JOYSTICK: OFF", Theme.Red, function() IsJoystickEnabled=not IsJoystickEnabled; JoyContainer.Visible=IsJoystickEnabled; updateLockState(); JoyToggle.Text=IsJoystickEnabled and "JOYSTICK: ON" or "JOYSTICK: OFF"; JoyToggle.BackgroundColor3=IsJoystickEnabled and Theme.Green or Theme.Red end, SetBox)

mkTool("ADD COMBO", Theme.Accent, function() CreateComboButtonFunc(#Combos+1, nil) end, SetBox)

mkTool("DEL COMBO", Theme.Red, function() if #Combos>0 then Combos[#Combos].Button:Destroy(); table.remove(Combos, #Combos); RefreshEditorUI() end end, SetBox)



local VKBox = Instance.new("Frame"); VKBox.Size=UDim2.new(0.95,0,0,120); VKBox.BackgroundTransparency=1; VKBox.Parent=P_Lay

local Grid2 = Instance.new("UIGridLayout"); Grid2.Parent=VKBox; Grid2.CellSize=UDim2.new(0.3,0,0,32); Grid2.CellPadding=UDim2.new(0.03,0,0.03,0)

for _, k in ipairs({"1", "2", "3", "4", "Z", "X", "C", "V", "F"}) do

    local btn = Instance.new("TextButton"); btn.Text=k; btn.BackgroundColor3=Theme.Element; btn.TextColor3=Theme.Text; btn.Font=Enum.Font.GothamBold; btn.Parent=VKBox; createCorner(btn,4); btn.MouseButton1Click:Connect(function() toggleVirtualKey(k, nil, k) end) 

    VirtualKeySelectors[k] = btn

end



-- ==============================================================================

-- [10] COMBO EDITOR LOGIC

-- ==============================================================================

local EditScroll=Instance.new("ScrollingFrame"); EditScroll.Size=UDim2.new(1,0,0.7,0); EditScroll.Position=UDim2.new(0,0,0.15,0); EditScroll.BackgroundTransparency=1; EditScroll.Parent=P_Edit; local EditList=Instance.new("UIListLayout"); EditList.Parent=EditScroll

local AddAct = Instance.new("TextButton"); AddAct.Size=UDim2.new(1,0,0,40); AddAct.Position=UDim2.new(0,0,0.9,0); AddAct.Text="+ ADD ACTION"; AddAct.BackgroundColor3=Theme.Green; AddAct.Parent=P_Edit; createCorner(AddAct,6)



RefreshEditorUI = function()

    for _,c in pairs(EditScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end

    if not Combos[CurrentComboIndex] then return end

    local d = Combos[CurrentComboIndex]; EditScroll.CanvasSize = UDim2.new(0,0,0,#d.Steps*65+50)

    for i,s in ipairs(d.Steps) do

        local r = Instance.new("Frame"); r.Size=UDim2.new(1,0,0,60); r.BackgroundColor3=Theme.Element; r.Parent=EditScroll; createCorner(r,6)

        local btn = Instance.new("TextButton"); btn.Size=UDim2.new(0.3,0,1,0); btn.Text=WeaponData[s.Slot].name.." ["..s.Key.."]"; btn.TextColor3=WeaponData[s.Slot].color; btn.BackgroundTransparency=1; btn.Parent=r; btn.MouseButton1Click:Connect(function() s.Slot=(s.Slot%4)+1; s.Key=WeaponData[s.Slot].keys[1]; RefreshEditorUI() end)

        local del = Instance.new("TextButton"); del.Size=UDim2.new(0.1,0,1,0); del.Position=UDim2.new(0.9,0,0,0); del.Text="X"; del.TextColor3=Theme.Red; del.BackgroundTransparency=1; del.Parent=r; del.MouseButton1Click:Connect(function() table.remove(d.Steps,i); RefreshEditorUI() end)

    end

end

AddAct.MouseButton1Click:Connect(function() if Combos[CurrentComboIndex] then table.insert(Combos[CurrentComboIndex].Steps, {Slot=1, Key="Z", Delay=0}); RefreshEditorUI() end end)



ShowNotification("VELOX HYBRID V1.4 LOADED", Theme.Green)
