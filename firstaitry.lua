--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

--// WORLD REFERENCES
local PitchPart = workspace:WaitForChild("Pitch"):WaitForChild("Grass")
local BallsFolder = workspace:WaitForChild("Balls")
local Ball = BallsFolder:WaitForChild("VEF")

--// SETTINGS
local DANGER_RADIUS = 35
local RUSH_GOAL_DISTANCE = 45
local DECISION_RATE = 0.25

--// PASS FUNCTION (AUTO SELECT BEST ATTACKER)
local function getBestForward()
    local bestPlayer = nil
    local bestScore = -math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Team == player.Team then
            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                
                local teammatePos = plr.Character.HumanoidRootPart.Position
                
                -- Distance from nearest opponent
                local closestOpp = math.huge
                for _, opp in ipairs(Players:GetPlayers()) do
                    if opp.Team ~= player.Team and opp.Character and opp.Character:FindFirstChild("HumanoidRootPart") then
                        local dist = (opp.Character.HumanoidRootPart.Position - teammatePos).Magnitude
                        if dist < closestOpp then
                            closestOpp = dist
                        end
                    end
                end

                -- Closer to opponent goal = better
                local goalZ = PitchPart.Position.Z + PitchPart.Size.Z/2
                local attackScore = math.abs(goalZ - teammatePos.Z)

                local score = closestOpp * 1.5 - attackScore

                if score > bestScore then
                    bestScore = score
                    bestPlayer = plr
                end
            end
        end
    end

    return bestPlayer
end

local function autoPass()
    local target = getBestForward()
    if not target then return end

    local targetHRP = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    local part = Ball

    if part:FindFirstChild("Owner") and part.Owner.Value ~= player then
        return
    end

    local duration = 1.6

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5,1e5,1e5)
    bv.Velocity = (targetHRP.Position - part.Position) / duration
    bv.Parent = part
    game.Debris:AddItem(bv, 0.4)
end

--// HELPER: GET PLAYERS NEAR BALL
local function getPlayersNearBall(radius)
    local attackers = {}
    local defenders = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (plr.Character.HumanoidRootPart.Position - Ball.Position).Magnitude
            
            if dist <= radius then
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

--// MOVEMENT CONTROLLER
local function moveTo(position)
    char.Humanoid:MoveTo(position)
end

--// AI LOOP
local lastDecision = 0

RunService.RenderStepped:Connect(function()

    if tick() - lastDecision < DECISION_RATE then return end
    lastDecision = tick()

    if not Ball then return end

    local attackers, defenders = getPlayersNearBall(DANGER_RADIUS)
    local numAttackers = #attackers
    local numDefenders = #defenders

    -- Remove self from defenders count
    for i,v in ipairs(defenders) do
        if v == player then
            table.remove(defenders, i)
            break
        end
    end

    numDefenders = #defenders + 1 -- include self logically

    -- Determine goal side
    local pitchCenterZ = PitchPart.Position.Z
    local defendingRight = Ball.Position.Z > pitchCenterZ

    local myGoalZ
    if defendingRight then
        myGoalZ = PitchPart.Position.Z - PitchPart.Size.Z/2
    else
        myGoalZ = PitchPart.Position.Z + PitchPart.Size.Z/2
    end

    local ballDistToGoal = math.abs(Ball.Position.Z - myGoalZ)

    -------------------------------------------------
    -- 1v1 → RUSH
    -------------------------------------------------
    if numAttackers == 1 and numDefenders == 1 then
        moveTo(Ball.Position)
    end

    -------------------------------------------------
    -- 2v1 → HOLD MIDDLE
    -------------------------------------------------
    if numAttackers == 2 and numDefenders == 1 then
        
        local pos1 = attackers[1].Character.HumanoidRootPart.Position
        local pos2 = attackers[2].Character.HumanoidRootPart.Position
        local midpoint = (pos1 + pos2) / 2

        if ballDistToGoal < RUSH_GOAL_DISTANCE then
            moveTo(Ball.Position) -- rush near goal
        else
            moveTo(midpoint)
        end
    end

    -------------------------------------------------
    -- 2v2 → MARK CLOSEST
    -------------------------------------------------
    if numAttackers == 2 and numDefenders >= 2 then
        
        local closestAttacker = nil
        local closestDist = math.huge

        for _, attacker in ipairs(attackers) do
            local dist = (attacker.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestAttacker = attacker
            end
        end

        if closestAttacker then
            moveTo(closestAttacker.Character.HumanoidRootPart.Position)
        end
    end

    -------------------------------------------------
    -- IF WE WIN BALL → AUTO PASS
    -------------------------------------------------
    if Ball:FindFirstChild("Owner") and Ball.Owner.Value == player then
        autoPass()
    end

end)