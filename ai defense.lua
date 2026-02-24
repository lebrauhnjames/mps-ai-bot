--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// PLAYER REFERENCES
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

--// WORLD REFERENCES
local PitchPart = workspace:WaitForChild("Pitch"):WaitForChild("Grass")
local BallsFolder = workspace:WaitForChild("Balls")
local Ball = BallsFolder:WaitForChild("CBM")

--// REMOTE PASS
local RS = ReplicatedStorage
local MainFunction = RS:WaitForChild("Event").MainFunction
local MainEvent = RS:WaitForChild("Event").MainEvent

--// SETTINGS
local DANGER_RADIUS = 35
local AUTO_DEFENSE_DISTANCE = 12 -- rush distance
local DEFENSIVE_BEHIND = 5      -- shadow behind attacker
local ANGLE_OFFSET = 0.3        -- lateral angle
local SPEED_BOOST = 24
local NORMAL_SPEED = 16
local HALF_LINE_Z = 0
local STOP_SCRIPT = false

--// GOAL POSITIONS
local AWAY_GOAL_POS = Vector3.new(2,5.32,349)
local HOME_GOAL_POS = Vector3.new(2,5,-349)
local myGoalPos, opponentGoalPos = nil,nil
if player.Team.Name == "Home" then
    myGoalPos = HOME_GOAL_POS
    opponentGoalPos = AWAY_GOAL_POS
else
    myGoalPos = AWAY_GOAL_POS
    opponentGoalPos = HOME_GOAL_POS
end

-- Stop script
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.F4 then
        STOP_SCRIPT = true
    end
end)

-- Helpers
local function moveTo(pos) humanoid:MoveTo(pos) end
local function jump() humanoid.Jump = true end

-- Defensive positions
local function defensivePosition(attHRP)
    local dirToGoal = (myGoalPos - attHRP.Position).Unit
    local right = Vector3.new(-dirToGoal.Z,0,dirToGoal.X)
    local pos = attHRP.Position + dirToGoal*DEFENSIVE_BEHIND + right*ANGLE_OFFSET
    if player.Team.Name=="Home" and pos.Z>HALF_LINE_Z then pos=Vector3.new(pos.X,pos.Y,HALF_LINE_Z-1) end
    if player.Team.Name=="Away" and pos.Z<HALF_LINE_Z then pos=Vector3.new(pos.X,pos.Y,HALF_LINE_Z+1) end
    return pos
end

local function defensiveMidpoint(att1HRP, att2HRP)
    local mid=(att1HRP.Position + att2HRP.Position)/2
    local dirToGoal=(myGoalPos-mid).Unit
    local right=Vector3.new(-dirToGoal.Z,0,dirToGoal.X)
    local pos = mid + dirToGoal*DEFENSIVE_BEHIND + right*ANGLE_OFFSET
    if player.Team.Name=="Home" and pos.Z>HALF_LINE_Z then pos=Vector3.new(pos.X,pos.Y,HALF_LINE_Z-1) end
    if player.Team.Name=="Away" and pos.Z<HALF_LINE_Z then pos=Vector3.new(pos.X,pos.Y,HALF_LINE_Z+1) end
    return pos
end

-- Players near ball
local function playersNearBall(radius)
    local attackers, defenders = {},{}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local d = (plr.Character.HumanoidRootPart.Position - Ball.Position).Magnitude
            if d<=radius then
                if plr.Team ~= player.Team then table.insert(attackers,plr) else table.insert(defenders,plr) end
            end
        end
    end
    return attackers, defenders
end

-- Single-pass using MainFunction as in your snippet
local function passToPlayer(targetPlayer)
    if not Ball:FindFirstChild("Owner") then return end
    local owner = Ball.Owner.Value
    if owner ~= player then
        MainFunction:InvokeServer("Ownership", Ball, Ball.Position, 100, 10, nil)
    end

    local targetHRP = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    local duration = 1.7
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5,1e5,1e5)
    bv.Velocity = (targetHRP.Position - Ball.Position) / duration
    bv.Parent = Ball
    Debris:AddItem(bv,0.4)

    -- Sound logic
    local Kick = Ball:WaitForChild("Kick")
    local power = (bv.Velocity.Magnitude / 200) ^ 1.1 - 0.075
    if power < 0.15 then power = 0.15 end
    local pitch = bv.Velocity.Magnitude / 150 + 1
    Kick.Volume = power
    Kick.PlaybackSpeed = pitch
    Kick:Play()
    MainEvent:FireServer("Sound", Ball, Kick, power, pitch, false)
end

-- Main AI
RunService.Heartbeat:Connect(function()
    if STOP_SCRIPT then return end
    if not Ball then return end

    local ballHeight = Ball.Position.Y - PitchPart.Position.Y
    local shouldJump = ballHeight >= 2

    local attackers, defenders = playersNearBall(DANGER_RADIUS)
    for i,v in ipairs(defenders) do if v==player then table.remove(defenders,i) break end end
    local numAttackers=#attackers
    local numDefenders=#defenders+1

    humanoid.WalkSpeed=SPEED_BOOST

    -- Determine nearest player to ball
    local closestDist = (hrp.Position - Ball.Position).Magnitude
    local nearestPlayer = player
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (plr.Character.HumanoidRootPart.Position - Ball.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                nearestPlayer = plr
            end
        end
    end

    local hasBall = Ball:FindFirstChild("Owner") and Ball.Owner.Value==player
    local distToBall = (Ball.Position - hrp.Position).Magnitude

    -- Rush only if bot is closest OR within AUTO_DEFENSE_DISTANCE
    if hasBall or (nearestPlayer==player and distToBall <= AUTO_DEFENSE_DISTANCE) then
        if shouldJump then jump() end
        moveTo(Ball.Position)

        -- Wait a short moment before passing if we just gained the ball
        if hasBall then
            local bestForward = nil
            local bestScore = -math.huge
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= player and plr.Team == player.Team and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    local pos = plr.Character.HumanoidRootPart.Position
                    local score = (opponentGoalPos - pos).Magnitude * -1 -- simple heuristic
                    if score > bestScore then
                        bestScore = score
                        bestForward = plr
                    end
                end
            end
            if bestForward then
                passToPlayer(bestForward)
            end
        end
        return
    end

    -- 1v1
    if numAttackers==1 and numDefenders==1 then
        local attHRP=attackers[1].Character.HumanoidRootPart
        moveTo(defensivePosition(attHRP))
    end

    -- 2v1
    if numAttackers==2 and numDefenders==1 then
        local att1=attackers[1].Character.HumanoidRootPart
        local att2=attackers[2].Character.HumanoidRootPart
        moveTo(defensiveMidpoint(att1,att2))
    end

    -- 2v2
    if numAttackers==2 and numDefenders>=2 then
        local closestAtt,closestDist=nil,math.huge
        for _,att in ipairs(attackers) do
            local d=(att.Character.HumanoidRootPart.Position-hrp.Position).Magnitude
            if d<closestDist then closestDist=d closestAtt=att end
        end
        if closestAtt then
            moveTo(defensivePosition(closestAtt.Character.HumanoidRootPart))
        end
    end
end)
