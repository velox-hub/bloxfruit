local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- 1. SETUP UI (DRAGGABLE & MINIMIZE)
if CoreGui:FindFirstChild("SkillDebugger") then CoreGui.SkillDebugger:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SkillDebugger"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main Container
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 280, 0, 320)
MainFrame.Position = UDim2.new(0.6, 0, 0.1, 0) -- Posisi awal di agak atas kanan
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BackgroundTransparency = 0.2 -- Agar tembus pandang dikit
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(255, 170, 0)
MainFrame.Parent = ScreenGui

-- Header (BAGIAN UNTUK MENGGESER)
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 30)
Header.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
Header.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.8, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "  SKILL INSPECTOR (DRAG HERE)"
Title.TextColor3 = Color3.fromRGB(0, 0, 0)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Minimize Button
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -30, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
MinBtn.Text = "-"
MinBtn.TextSize = 20
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Parent = Header

-- Content Container
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -30)
Content.Position = UDim2.new(0, 0, 0, 30)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local KeyInput = Instance.new("TextBox")
KeyInput.Size = UDim2.new(0.4, 0, 0, 30)
KeyInput.Position = UDim2.new(0.05, 0, 0.05, 0)
KeyInput.Text = "Z" 
KeyInput.PlaceholderText = "Key"
KeyInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyInput.Parent = Content

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0.9, 0, 0.8, 0)
StatusLabel.Position = UDim2.new(0.05, 0, 0.2, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.Font = Enum.Font.Code
StatusLabel.TextSize = 12
StatusLabel.Text = "Waiting..."
StatusLabel.TextWrapped = true
StatusLabel.Parent = Content

-- [[ LOGIKA DRAG / GESER ]]
local dragging, dragInput, dragStart, startPos

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- [[ LOGIKA MINIMIZE ]]
local isMin = false
MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    if isMin then
        Content.Visible = false
        MainFrame.Size = UDim2.new(0, 280, 0, 30) -- Jadi kecil
        MinBtn.Text = "+"
    else
        Content.Visible = true
        MainFrame.Size = UDim2.new(0, 280, 0, 320) -- Kembali besar
        MinBtn.Text = "-"
    end
end)

-- 2. LOGIKA PENCARIAN & MONITORING
local function GetTargetButton(key)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local Skills = PGui and PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    
    if Skills then
        for _, f in pairs(Skills:GetChildren()) do
            if f:IsA("Frame") and f.Visible and f:FindFirstChild(key) then
                local mobileBtn = f[key]:FindFirstChild("Mobile")
                if mobileBtn then return mobileBtn end
            end
        end
    end
    return nil
end

local function FormatColor(c3)
    return string.format("%d,%d,%d", math.floor(c3.R*255), math.floor(c3.G*255), math.floor(c3.B*255))
end

RunService.RenderStepped:Connect(function()
    if isMin then return end -- Hemat resource saat diminimize
    
    local targetKey = KeyInput.Text:upper()
    local btn = GetTargetButton(targetKey)
    
    if btn then
        local info = "TARGET: " .. targetKey .. "\n"
        
        -- Cek Properti Utama
        info = info .. "----------------------\n"
        info = info .. "Active: " .. tostring(btn.Active) .. "\n"
        info = info .. "Visible: " .. tostring(btn.Visible) .. "\n"
        info = info .. "Color: " .. FormatColor(btn.BackgroundColor3) .. "\n"
        info = info .. "Trans: " .. string.format("%.2f", btn.BackgroundTransparency) .. "\n"
        
        if btn:IsA("ImageButton") then
            info = info .. "ImgColor: " .. FormatColor(btn.ImageColor3) .. "\n"
        end
        
        -- Cek Anak-anaknya (Cooldown)
        info = info .. "----------------------\n"
        info = info .. "[CHILDREN/ISI]:\n"
        
        local children = btn:GetChildren()
        if #children == 0 then
            info = info .. " (Kosong)\n"
        else
            for _, c in pairs(children) do
                if c:IsA("Frame") or c:IsA("TextLabel") or c:IsA("ImageLabel") then
                    info = info .. "> " .. c.Name .. " (Vis: " .. tostring(c.Visible) .. ")\n"
                    if c:IsA("Frame") then
                         info = info .. "  Size: " .. tostring(c.Size) .. "\n"
                    end
                end
            end
        end
        
        StatusLabel.Text = info
        StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0) 
    else
        StatusLabel.Text = "Searching Skill [" .. targetKey .. "]..."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)
