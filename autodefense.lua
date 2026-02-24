local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local MainEvent = ReplicatedStorage:WaitForChild("Event"):WaitForChild("MainEvent")
local MainFunction = ReplicatedStorage.Event.MainFunction
local Animation = Instance.new("Animation")
Animation.AnimationId = "rbxassetid://17824593324"
local any_LoadAnimation_result1_upvr = char.Humanoid:LoadAnimation(Animation)

-- Replace this with your limbs
local Limbs = {
    RA = char:WaitForChild("Right Arm"),
    LA = char:WaitForChild("Left Arm"),
    RL = char:WaitForChild("Right Leg"),
    LL = char:WaitForChild("Left Leg"),
    Torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"),
    Head = char:WaitForChild("Head")
}

local Player = player
local THRESHOLD = 5.3 -- Distance to trigger
local active = false -- F2 toggle
local connection = nil
local cd = false

local function startAutoGK()
    if connection then return end -- Already running
    connection = RunService.RenderStepped:Connect(function()
        local ballsFolder = workspace:WaitForChild("Balls")
        for _, b in ipairs(ballsFolder:GetChildren()) do
            if b:IsA("BasePart") then
                local dist = (b.Position - hrp.Position).Magnitude
				local heightDiff = b.Position.Y - hrp.Position.Y
                if dist <= THRESHOLD and not cd and b.Owner.Value ~= player and not b.ReactDecline.Value and heightDiff <= 0 then
                    cd = true
				print("Hit.")
                MainFunction:InvokeServer("Ownership", b, b.Position, 1, 10, 1)
    local v11 = nil
		any_LoadAnimation_result1_upvr:Play(0, 1, 1)
		any_LoadAnimation_result1_upvr:AdjustWeight(1, 0)
		local Motor6D_3 = Instance.new("Motor6D")
		Motor6D_3.Parent = Player.Character:WaitForChild("Right Leg")
		Motor6D_3.Part0 = Player.Character:WaitForChild("Right Leg")
		Motor6D_3.Part1 = Player.Character:WaitForChild("RL")
		game.Debris:AddItem(Motor6D_3, 0.5)
		local Motor6D_2 = Instance.new("Motor6D")
		Motor6D_2.Parent = Player.Character:WaitForChild("Left Leg")
		Motor6D_2.Part0 = Player.Character:WaitForChild("Left Leg")
		Motor6D_2.Part1 = Player.Character:WaitForChild("LL")
		game.Debris:AddItem(Motor6D_2, 0.5)
		local v11 = Instance.new("BodyVelocity")
		v11.Velocity = (char.HumanoidRootPart.CFrame * CFrame.fromEulerAnglesXYZ(0, 0.75, 0)).lookVector * 20.5
		v11.Velocity *= Vector3.new(1, 0, 1)
		v11.Velocity += Vector3.new(0, 22.5, 0)
		v11.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		v11.Parent = b
        Debris:AddItem(v11, 0.3)

    local kickSound = b:WaitForChild("Kick")
    local mag = (v11.Velocity.Magnitude / 200) ^ 1.1 - 0.075
    local vol = mag < 0.15 and 0.15 or mag
    local spd = v11.Velocity.Magnitude / 150 + 1
    kickSound.Volume = vol
    kickSound.PlaybackSpeed = spd
    kickSound:Play()

    ReplicatedStorage.Event.MainEvent:FireServer("Sound", b, kickSound, vol, spd, false)
    task.delay(2, function()
    cd = false
    end)
                end
            end
        end
    end)
end

local function stopAutoGK()
    if connection then
        connection:Disconnect()
        connection = nil
    end
end

-- Keybinds
inputConnection = UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F2 then
        active = not active
        if active then
            print("F2: Auto CB ON")
            startAutoGK()
        else
            print("F2: Auto CB OFF")
            stopAutoGK()
        end
    elseif input.KeyCode == Enum.KeyCode.F3 then
        -- Self destruct
        stopAutoGK()
        if inputConnection then
            inputConnection:Disconnect()
            inputConnection = nil
        end
        script:Destroy()
        print("F3: Script self destructed")
    end
end)
