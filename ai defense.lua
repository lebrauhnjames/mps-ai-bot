--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

--// PLAYER REFERENCES
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

--// WORLD REFERENCES
local PitchPart = workspace:WaitForChild("Pitch"):WaitForChild("Grass")
local BallsFolder = workspace:WaitForChild("Balls")
local Ball = BallsFolder:WaitForChild("CBM")

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

local function getBestForward()
    local bestPlayer, bestScore = nil,-math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Team==player.Team and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local pos = plr.Character.HumanoidRootPart.Position
            local closestOpp = math.huge
            for _, opp in ipairs(Players:GetPlayers()) do
                if opp.Team ~= player.Team and opp.Character and opp.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (opp.Character.HumanoidRootPart.Position - pos).Magnitude
                    if d < closestOpp then closestOpp = d end
                end
            end
            local score = closestOpp*1.5 - (opponentGoalPos - pos).Magnitude
            if score > bestScore then bestScore = score bestPlayer=plr end
        end
    end
    return bestPlayer
end

local function autoPass()
    local target = getBestForward()
    if not target then return end
    local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end
    if Ball:FindFirstChild("Owner") and Ball.Owner.Value ~= player then return end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5,1e5,1e5)
    bv.Velocity = (targetHRP.Position - Ball.Position)/1.6
    bv.Parent = Ball
    Debris:AddItem(bv,0.4)
end

local function defensivePosition(attackerHRP)
    local dirToGoal = (myGoalPos - attackerHRP.Position).Unit
    local right = Vector3.new(-dirToGoal.Z,0,dirToGoal.X)
    local pos = attackerHRP.Position + dirToGoal*DEFENSIVE_BEHIND + right*ANGLE_OFFSET
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

    -- 1v1
    if numAttackers==1 and numDefenders==1 then
        local attHRP=attackers[1].Character.HumanoidRootPart
        local dist=(attHRP.Position-hrp.Position).Magnitude
        if dist<=AUTO_DEFENSE_DISTANCE then
            if shouldJump then jump() end
            moveTo(Ball.Position)
            jump()
            autoPass()
            jump()
        else
            if shouldJump then jump() end
            moveTo(defensivePosition(attHRP))
        end
    end

    -- 2v1
    if numAttackers==2 and numDefenders==1 then
        local att1=attackers[1].Character.HumanoidRootPart
        local att2=attackers[2].Character.HumanoidRootPart
        local distToBall=(Ball.Position-hrp.Position).Magnitude
        if distToBall<=AUTO_DEFENSE_DISTANCE then
            if shouldJump then jump() end
            moveTo(Ball.Position)
            jump()
            autoPass()
            jump()
        else
            if shouldJump then jump() end
            moveTo(defensiveMidpoint(att1,att2))
        end
    end

    -- 2v2
    if numAttackers==2 and numDefenders>=2 then
        local closestAtt,closestDist=nil,math.huge
        for _,att in ipairs(attackers) do
            local d=(att.Character.HumanoidRootPart.Position-hrp.Position).Magnitude
            if d<closestDist then closestDist=d closestAtt=att end
        end
        if closestAtt then
            if shouldJump then jump() end
            moveTo(defensivePosition(closestAtt.Character.HumanoidRootPart))
        end
    end

    -- Auto-pass if we own ball
    if Ball:FindFirstChild("Owner") and Ball.Owner.Value==player then
        autoPass()
    end
end)
