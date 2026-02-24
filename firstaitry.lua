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
local Ball = BallsFolder:FindFirstChild("CBM")
if not Ball then
    warn("CBM ball not found in Balls folder!")
    return
end

--// SETTINGS
local DANGER_RADIUS = 35
local AUTO_DEFENSE_DISTANCE = 8.4      -- distance to rush the ball
local DEFENSIVE_BEHIND = 7.5         -- stay behind attacker toward own goal
local ANGLE_OFFSET = 0.3             -- slight lateral offset
local SPEED_BOOST = 24
local NORMAL_SPEED = 16
local HALF_LINE_Z = 0
local STOP_SCRIPT = false

--// GOAL POSITIONS
local AWAY_GOAL_POS = Vector3.new(2,5.32,349)
local HOME_GOAL_POS = Vector3.new(2,5,-349)
local myGoalPos, opponentGoalPos
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

-- HELPER FUNCTIONS
local function moveTo(pos) humanoid:MoveTo(pos) end
local function jump() humanoid.Jump = true end

local function getBestForward()
    local bestPlayer, bestScore = nil, -math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Team == player.Team and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local pos = plr.Character.HumanoidRootPart.Position
            local closestOpp = math.huge
            for _, opp in ipairs(Players:GetPlayers()) do
                if opp.Team ~= player.Team and opp.Character and opp.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (opp.Character.HumanoidRootPart.Position - pos).Magnitude
                    if d < closestOpp then closestOpp = d end
                end
            end
            local score = closestOpp*1.5 - (opponentGoalPos - pos).Magnitude
            if score > bestScore then bestScore = score bestPlayer = plr end
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
    Debris:AddItem(bv, 0.4)
end

-- Defensive shadowing: stay behind attacker toward own goal
local function defensivePosition(attackerHRP)
    local dirToGoal = (myGoalPos - attackerHRP.Position).Unit
    local targetPos = attackerHRP.Position + dirToGoal * DEFENSIVE_BEHIND
    local right = Vector3.new(-dirToGoal.Z, 0, dirToGoal.X)
    targetPos = targetPos + right * ANGLE_OFFSET

    if player.Team.Name == "Home" and targetPos.Z > HALF_LINE_Z then
        targetPos = Vector3.new(targetPos.X, targetPos.Y, HALF_LINE_Z - 1)
    elseif player.Team.Name == "Away" and targetPos.Z < HALF_LINE_Z then
        targetPos = Vector3.new(targetPos.X, targetPos.Y, HALF_LINE_Z + 1)
    end
    return targetPos
end

local function defensiveMidpoint(att1HRP, att2HRP)
    local mid = (att1HRP.Position + att2HRP.Position)/2
    local dirToGoal = (myGoalPos - mid).Unit
    local targetPos = mid + dirToGoal * DEFENSIVE_BEHIND
    local right = Vector3.new(-dirToGoal.Z,0,dirToGoal.X)
    targetPos = targetPos + right * ANGLE_OFFSET

    if player.Team.Name == "Home" and targetPos.Z > HALF_LINE_Z then
        targetPos = Vector3.new(targetPos.X, targetPos.Y, HALF_LINE_Z - 1)
    elseif player.Team.Name == "Away" and targetPos.Z < HALF_LINE_Z then
        targetPos = Vector3.new(targetPos.X, targetPos.Y, HALF_LINE_Z + 1)
    end
    return targetPos
end

local function playersNearBall(radius)
    local attackers, defenders = {},{}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local d = (plr.Character.HumanoidRootPart.Position - Ball.Position).Magnitude
            if d <= radius then
                if plr.Team ~= player.Team then
                    table.insert(attackers, plr)
                else
                    table.insert(defenders, plr)
                end
            end
        end
    end
    return attackers, defenders
end

-- Track ball ownership for 1 second follow
local ballOwnedAt = 0
local followingBall = false

-- MAIN LOOP
RunService.Heartbeat:Connect(function()
    if STOP_SCRIPT then return end
    if not Ball then return end

    local ballHeight = Ball.Position.Y - PitchPart.Position.Y
    local shouldJump = ballHeight >= 2

    local attackers, defenders = playersNearBall(DANGER_RADIUS)
    for i,v in ipairs(defenders) do if v==player then table.remove(defenders,i) break end end
    local numAttackers = #attackers
    local numDefenders = #defenders + 1

    humanoid.WalkSpeed = SPEED_BOOST

    local hasBall = Ball:FindFirstChild("Owner") and Ball.Owner.Value == player

    -- Find nearest attacker
    local closestAttacker, closestDist = nil, math.huge
    for _, att in ipairs(attackers) do
        local d = (att.Character.HumanoidRootPart.Position - Ball.Position).Magnitude
        if d < closestDist then
            closestDist = d
            closestAttacker = att
        end
    end

    local distToBall = (Ball.Position - hrp.Position).Magnitude
    local closerThanAttacker = closestAttacker and distToBall < closestDist

    -- RUSH the ball if within 7 studs OR closer than nearest attacker
    local shouldRush = distToBall <= AUTO_DEFENSE_DISTANCE or closerThanAttacker

    if shouldRush then
        if shouldJump then jump() end
        moveTo(Ball.Position)

        if hasBall then
            if not followingBall then
                followingBall = true
                ballOwnedAt = tick()
            end
            if tick() - ballOwnedAt >= 1 then
                autoPass()
                followingBall = false
            end
        else
            followingBall = false
        end
        return
    end

    -- DEFENSIVE SHADOWING
    if numAttackers == 1 and numDefenders == 1 then
        local targetPos = defensivePosition(attackers[1].Character.HumanoidRootPart)
        moveTo(targetPos)
    elseif numAttackers == 2 and numDefenders == 1 then
        local targetPos = defensiveMidpoint(attackers[1].Character.HumanoidRootPart, attackers[2].Character.HumanoidRootPart)
        moveTo(targetPos)
    elseif numAttackers == 2 and numDefenders >= 2 then
        if closestAttacker then
            local targetPos = defensivePosition(closestAttacker.Character.HumanoidRootPart)
            moveTo(targetPos)
        end
    end
end)
