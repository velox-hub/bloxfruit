local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- 1. SETUP UI DEBUGGER
if CoreGui:FindFirstChild("SkillDebugger") then CoreGui.SkillDebugger:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SkillDebugger"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 300, 0, 350)
MainFrame.Position = UDim2.new(0.7, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(255, 170, 0)
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
Title.Text = "SKILL BUTTON INSPECTOR"
Title.TextColor3 = Color3.fromRGB(0, 0, 0)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.Parent = MainFrame

-- Input Key (Z, X, C...)
local KeyInput = Instance.new("TextBox")
KeyInput.Size = UDim2.new(0.3, 0, 0, 30)
KeyInput.Position = UDim2.new(0.05, 0, 0.1, 0)
KeyInput.Text = "Z" -- Default
KeyInput.PlaceholderText = "Key (Z/X)"
KeyInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyInput.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0.9, 0, 0.75, 0)
StatusLabel.Position = UDim2.new(0.05, 0, 0.2, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.Font = Enum.Font.Code
StatusLabel.TextSize = 13
StatusLabel.Text = "Waiting..."
StatusLabel.Parent = MainFrame

-- Drag Function
local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
MainFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
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
    return string.format("R:%d G:%d B:%d", math.floor(c3.R*255), math.floor(c3.G*255), math.floor(c3.B*255))
end

-- LOOP UPDATE UI
RunService.RenderStepped:Connect(function()
    local targetKey = KeyInput.Text:upper()
    local btn = GetTargetButton(targetKey)
    
    if btn then
        local info = "TARGET: " .. btn:GetFullName() .. "\n\n"
        
        -- Cek Properti Utama
        info = info .. "[PROPERTIES]\n"
        info = info .. "Visible: " .. tostring(btn.Visible) .. "\n"
        info = info .. "Active: " .. tostring(btn.Active) .. "\n"
        info = info .. "BgColor: " .. FormatColor(btn.BackgroundColor3) .. "\n"
        info = info .. "BgTrans: " .. string.format("%.2f", btn.BackgroundTransparency) .. "\n"
        
        if btn:IsA("ImageButton") then
            info = info .. "ImgColor: " .. FormatColor(btn.ImageColor3) .. "\n"
            info = info .. "ImgTrans: " .. string.format("%.2f", btn.ImageTransparency) .. "\n"
        end
        
        -- Cek Anak-anaknya (Cooldown Frame/Text)
        info = info .. "\n[CHILDREN / ISI TOMBOL]\n"
        local children = btn:GetChildren()
        if #children == 0 then
            info = info .. "No Children (Kosong)\n"
        else
            for _, c in pairs(children) do
                if c:IsA("Frame") or c:IsA("TextLabel") or c:IsA("ImageLabel") then
                    info = info .. "> " .. c.Name .. " (" .. c.ClassName .. ")\n"
                    info = info .. "   - Visible: " .. tostring(c.Visible) .. "\n"
                    if c:IsA("Frame") then
                        info = info .. "   - Trans: " .. string.format("%.2f", c.BackgroundTransparency) .. "\n"
                        info = info .. "   - Size: " .. tostring(c.Size) .. "\n"
                    end
                    if c:IsA("TextLabel") then
                        info = info .. "   - Text: " .. c.Text .. "\n"
                    end
                end
            end
        end
        
        StatusLabel.Text = info
        StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0) -- Hijau = Ketemu
    else
        StatusLabel.Text = "Searching for Skill [" .. targetKey .. "]...\n\nPastikan Anda memegang senjata/skill\ndan tombol Mobile UI terlihat."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Merah = Hilang
    end
end)
