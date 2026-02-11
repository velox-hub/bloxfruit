-- Hapus GUI lama jika ada (supaya tidak menumpuk saat di-execute ulang)
local oldGui = game.CoreGui:FindFirstChild("AutoJumpGUI") or game.Players.LocalPlayer.PlayerGui:FindFirstChild("AutoJumpGUI")
if oldGui then oldGui:Destroy() end

-- --- SETUP GUI ---
local ScreenGui = Instance.new("ScreenGui")
local ToggleButton = Instance.new("TextButton")
local UICorner = Instance.new("UICorner")

-- Nama GUI agar mudah dicari/dihapus
ScreenGui.Name = "AutoJumpGUI"
-- Coba pasang di CoreGui (lebih aman), jika gagal pasang di PlayerGui
if pcall(function() ScreenGui.Parent = game.CoreGui end) then
else
    ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- --- DESAIN TOMBOL ---
ToggleButton.Name = "JumpToggle"
ToggleButton.Parent = ScreenGui
ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60) -- Warna Awal Merah (OFF)
ToggleButton.Position = UDim2.new(0.8, 0, 0.4, 0) -- Posisi awal (bisa digeser)
ToggleButton.Size = UDim2.new(0, 120, 0, 50) -- Ukuran tombol
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "AUTO JUMP: OFF"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 14

-- Membuat sudut tombol tumpul (Rounded)
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = ToggleButton

-- --- FUNGSI AGAR TOMBOL BISA DIGESER (DRAGGABLE) ---
local UserInputService = game:GetService("UserInputService")
local dragging, dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    ToggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = ToggleButton.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

ToggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

-- --- LOGIKA AUTO JUMP ---
local active = false
local runService = game:GetService("RunService")

ToggleButton.MouseButton1Click:Connect(function()
    active = not active -- Tukar status (Nyala <-> Mati)
    
    if active then
        -- KONDISI NYALA
        ToggleButton.Text = "AUTO JUMP: ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(60, 255, 60) -- Warna Hijau
        
        -- Loop lompat
        spawn(function()
            while active do
                local char = game.Players.LocalPlayer.Character
                if char and char:FindFirstChild("Humanoid") then
                    -- Metode paling stabil untuk mobile
                    char.Humanoid.Jump = true 
                    
                    -- Opsional: Jika ingin memaksa state lompat (lebih agresif)
                    -- char.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
                task.wait() -- Lompat secepat mungkin (spam jump)
                -- Jika ingin lompat pelan ganti jadi task.wait(1)
            end
        end)
        
    else
        -- KONDISI MATI
        ToggleButton.Text = "AUTO JUMP: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60) -- Warna Merah
    end
end)
