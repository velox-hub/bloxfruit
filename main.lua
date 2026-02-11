-- ==============================================================================
-- [ VELOX LITE V4 - COMBO BUILDER PRO ]
-- Updated: Smart Cycling, Dynamic Sliders, Auto M1
-- ==============================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- THEME & DATA
local Theme = {
    Bg = Color3.fromRGB(25, 25, 30),
    Element = Color3.fromRGB(35, 35, 40),
    Accent = Color3.fromRGB(0, 255, 170),
    Text = Color3.fromRGB(240, 240, 240),
    SubText = Color3.fromRGB(180, 180, 180),
    Red = Color3.fromRGB(255, 80, 80),
    Green = Color3.fromRGB(50, 200, 100),
    Stroke = Color3.fromRGB(60, 60, 70)
}

-- Definisi Senjata & Batasan Skill
local WeaponData = {
    [1] = {name = "Melee", color = Color3.fromRGB(255, 100, 100), keys = {"Z", "X", "C"}},
    [2] = {name = "Blox Fruit", color = Color3.fromRGB(180, 100, 255), keys = {"Z", "X", "C", "V", "F"}},
    [3] = {name = "Sword", color = Color3.fromRGB(100, 200, 255), keys = {"Z", "X"}},
    [4] = {name = "Gun", color = Color3.fromRGB(255, 255, 100), keys = {"Z", "X"}}
}

local Combos = { {Name = "Combo Utama", Steps = {}} }
local CurrentComboIndex = 1

-- UTILS
local function createCorner(obj, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = obj
end

-- LOGIC ACTION
local function TapM1()
    local vp = Camera.ViewportSize
    VirtualInputManager:SendTouchEvent(5, 0, vp.X/2, vp.Y/2)
    task.wait(0.01)
    VirtualInputManager:SendTouchEvent(5, 2, vp.X/2, vp.Y/2)
end

local function ForceEquip(slot)
    local target = WeaponData[slot].name
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do
            if t:IsA("Tool") and t.ToolTip == target then hum:EquipTool(t); break end
        end
    end
end

local function TriggerSkill(key, isHold, holdTime)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local Skills = PGui and PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    if Skills then
        for _, f in pairs(Skills:GetChildren()) do
            if f:IsA("Frame") and f.Visible and f:FindFirstChild(key) then
                local btn = f[key]:FindFirstChild("Mobile") or f[key]
                if isHold then
                    VirtualInputManager:SendKeyEvent(true, key, false, game)
                    task.wait(holdTime)
                    VirtualInputManager:SendKeyEvent(false, key, false, game)
                else
                    for _, c in pairs(getconnections(btn.Activated)) do c:Fire() end
                    for _, c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                end
                task.wait(0.05)
                TapM1() -- Trigger M1 otomatis setelah skill
                return
            end
        end
    end
end

-- ==============================================================================
-- [ UI SETUP ]
-- ==============================================================================

if CoreGui:FindFirstChild("VeloxEditor") then CoreGui.VeloxEditor:Destroy() end
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "VeloxEditor"; ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame"); MainFrame.Size = UDim2.new(0, 320, 0, 420); MainFrame.Position = UDim2.new(0.5, -160, 0.5, -210); MainFrame.BackgroundColor3 = Theme.Bg; MainFrame.Parent = ScreenGui; createCorner(MainFrame, 10)
local P_Edit = Instance.new("Frame"); P_Edit.Size = UDim2.new(1, -20, 1, -20); P_Edit.Position = UDim2.new(0, 10, 0, 10); P_Edit.BackgroundTransparency = 1; P_Edit.Parent = MainFrame

local TopNav = Instance.new("Frame"); TopNav.Size=UDim2.new(1,0,0,35); TopNav.BackgroundTransparency=1; TopNav.Parent=P_Edit
local NavLbl = Instance.new("TextLabel"); NavLbl.Size=UDim2.new(1,0,1,0); NavLbl.Text="COMBO EDITOR"; NavLbl.TextColor3=Theme.Accent; NavLbl.BackgroundTransparency=1; NavLbl.Font=Enum.Font.GothamBold; NavLbl.TextSize=14; NavLbl.Parent=TopNav

local EditScroll=Instance.new("ScrollingFrame"); EditScroll.Size=UDim2.new(1,0,0.72,0); EditScroll.Position=UDim2.new(0,0,0.12,0); EditScroll.BackgroundTransparency=1; EditScroll.ScrollBarThickness=3; EditScroll.Parent=P_Edit; 
local EditList=Instance.new("UIListLayout"); EditList.Parent=EditScroll; EditList.Padding=UDim.new(0,8)

local BottomBar = Instance.new("Frame"); BottomBar.Size=UDim2.new(1,0,0,40); BottomBar.Position=UDim2.new(0,0,0.95,0); BottomBar.BackgroundTransparency=1; BottomBar.Parent=P_Edit
local AddAction=Instance.new("TextButton"); AddAction.Size=UDim2.new(0.48,0,1,0); AddAction.Text="+ ADD ACTION"; AddAction.BackgroundColor3=Theme.Green; AddAction.TextColor3=Theme.Bg; AddAction.Font=Enum.Font.GothamBold; AddAction.Parent=BottomBar; createCorner(AddAction,6)
local PlayCombo=Instance.new("TextButton"); PlayCombo.Size=UDim2.new(0.48,0,1,0); PlayCombo.Position=UDim2.new(0.52,0,0,0); PlayCombo.Text="RUN COMBO"; PlayCombo.BackgroundColor3=Theme.Accent; PlayCombo.TextColor3=Theme.Bg; PlayCombo.Font=Enum.Font.GothamBold; PlayCombo.Parent=BottomBar; createCorner(PlayCombo,6)

-- REFRESH UI FUNCTION
local RefreshEditorUI = function()
    local d = Combos[CurrentComboIndex]
    for _,c in pairs(EditScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    
    EditScroll.CanvasSize = UDim2.new(0,0,0, (#d.Steps * 95))
    
    for i, s in ipairs(d.Steps) do
        local h = (s.IsHold) and 85 or 60; 
        local r = Instance.new("Frame"); r.Size=UDim2.new(1,-10,0,h); r.BackgroundColor3=Theme.Element; r.Parent=EditScroll; createCorner(r,6)
        local top = Instance.new("Frame"); top.Size=UDim2.new(1,0,0,30); top.BackgroundTransparency=1; top.Parent=r
        
        -- Tombol Ganti Senjata (Cycle: Melee > Fruit > Sword > Gun)
        local w = Instance.new("TextButton"); w.Size=UDim2.new(0.32,0,1,0); w.Position=UDim2.new(0.02,0,0,0); w.Text=WeaponData[s.Slot].name; w.TextColor3=WeaponData[s.Slot].color; w.BackgroundTransparency=1; w.Parent=top; w.Font=Enum.Font.GothamBold; w.TextSize=10; w.TextXAlignment="Left"
        w.MouseButton1Click:Connect(function() 
            s.Slot = (s.Slot % 4) + 1
            -- Reset key jika key lama tidak ada di senjata baru
            local keys = WeaponData[s.Slot].keys
            s.Key = keys[1]
            RefreshEditorUI() 
        end)
        
        -- Tombol Ganti Skill (Cycle sesuai batasan senjata)
        local k = Instance.new("TextButton"); k.Size=UDim2.new(0.15,0,1,0); k.Position=UDim2.new(0.35,0,0,0); k.Text="["..s.Key.."]"; k.TextColor3=Theme.Text; k.BackgroundTransparency=1; k.Parent=top; k.Font=Enum.Font.GothamBold; k.TextSize=11
        k.MouseButton1Click:Connect(function() 
            local keys = WeaponData[s.Slot].keys
            local currentIdx = 1
            for idx, val in ipairs(keys) do if val == s.Key then currentIdx = idx end end
            s.Key = keys[(currentIdx % #keys) + 1]
            RefreshEditorUI()
        end)
        
        -- Tombol Toggle TAP / HOLD
        local m = Instance.new("TextButton"); m.Size=UDim2.new(0.2,0,0.7,0); m.Position=UDim2.new(0.55,0,0.15,0); m.Text=s.IsHold and "HOLD" or "TAP"; m.BackgroundColor3=s.IsHold and Theme.Accent or Theme.Green; m.TextColor3=Theme.Bg; m.Parent=top; m.Font=Enum.Font.GothamBold; m.TextSize=10; createCorner(m,4); 
        m.MouseButton1Click:Connect(function() s.IsHold = not s.IsHold; RefreshEditorUI() end)
        
        -- Tombol Hapus (Pojok Kanan)
        local x = Instance.new("TextButton"); x.Size=UDim2.new(0.1,0,1,0); x.Position=UDim2.new(0.88,0,0,0); x.Text="X"; x.TextColor3=Theme.Red; x.BackgroundTransparency=1; x.Parent=top; x.TextSize=12; x.Font=Enum.Font.GothamBold
        x.MouseButton1Click:Connect(function() table.remove(d.Steps, i); RefreshEditorUI() end)
        
        -- Slider Maker
        local function mkSlid(y, t, v, mx, cb, c) 
            local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,25); f.Position=UDim2.new(0,0,0,y); f.BackgroundTransparency=1; f.Parent=r; 
            local txt=Instance.new("TextLabel"); txt.Size=UDim2.new(0.3,0,1,0); txt.Position=UDim2.new(0.02,0,0,0); txt.Text=string.format(t,v); txt.TextColor3=c; txt.BackgroundTransparency=1; txt.TextSize=9; txt.TextXAlignment="Left"; txt.Parent=f; 
            local bg=Instance.new("Frame"); bg.Size=UDim2.new(0.55,0,0,4); bg.Position=UDim2.new(0.35,0,0.5,-2); bg.BackgroundColor3=Theme.Stroke; bg.Parent=f; createCorner(bg,2); 
            local kn=Instance.new("TextButton"); kn.Size=UDim2.new(0,10,0,10); kn.BackgroundColor3=Theme.Text; kn.Text=""; kn.Parent=bg; createCorner(kn,5); kn.Position=UDim2.new(math.clamp(v/mx,0,1),-5,0.5,-5); 
            local sl=false; kn.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseButton1 then sl=true end end); 
            UserInputService.InputChanged:Connect(function(inp) if sl and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then 
                local p=math.clamp((inp.Position.X-bg.AbsolutePosition.X)/bg.AbsoluteSize.X,0,1); 
                kn.Position=UDim2.new(p,-5,0.5,-5); 
                cb(p); 
                txt.Text=string.format(t, (p*mx)) 
            end end); 
            UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseButton1 then sl=false end end) 
        end
        
        mkSlid(30, "Wait: +%.1fs", s.Delay or 0, 2.0, function(p) s.Delay=math.floor(p*2*10)/10 end, Theme.SubText)
        if s.IsHold then 
            mkSlid(55, "Hold: %.1fs", s.HoldTime or 0.1, 3.0, function(p) s.HoldTime=math.floor(p*3*10)/10 end, Theme.Accent) 
        end
    end
end

-- EVENTS
AddAction.MouseButton1Click:Connect(function() 
    table.insert(Combos[CurrentComboIndex].Steps, {Slot=1, Key="Z", Delay=0.5, IsHold=false, HoldTime=0.5})
    RefreshEditorUI() 
end)

PlayCombo.MouseButton1Click:Connect(function()
    local d = Combos[CurrentComboIndex]
    for _, s in ipairs(d.Steps) do
        ForceEquip(s.Slot)
        task.wait(0.2) -- Jeda ganti senjata
        TriggerSkill(s.Key, s.IsHold, s.HoldTime)
        task.wait(s.Delay)
    end
end)

-- DRAGGABLE SYSTEM
local d = false; local start; local pos
MainFrame.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then d = true; start = i.Position; pos = MainFrame.Position end end)
UserInputService.InputChanged:Connect(function(i) if d and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then 
    local delta = i.Position - start; MainFrame.Position = UDim2.new(pos.X.Scale, pos.X.Offset + delta.X, pos.Y.Scale, pos.Y.Offset + delta.Y)
end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end end)

RefreshEditorUI()
print("Velox Builder: Smart Dynamic UI Loaded")
