local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Configuration
local HERB_NAME = "Medicinal Herb"
local COLLECT_KEY = Enum.KeyCode.E
local COLLECT_DURATION = 2
local SEARCH_INTERVAL = 3
local REACH_DISTANCE = 5
local PATHFINDING_TIMEOUT = 7

-- Initialize character
local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Herb detection with proximity check
local function findNearestHerb()
    local closestHerb, closestDistance = nil, math.huge
    
    for _, item in ipairs(workspace:GetDescendants()) do
        if item.Name == HERB_NAME and item:IsA("BasePart") then
            local distance = (humanoidRootPart.Position - item.Position).Magnitude
            if distance < closestDistance then
                closestHerb = item
                closestDistance = distance
            end
        end
    end
    
    return closestHerb
end

-- Smooth pathfinding with obstacle avoidance
local function navigateTo(target)
    local path = PathfindingService:CreatePath({
        AgentRadius = 1.5,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true
    })
    
    path:ComputeAsync(humanoidRootPart.Position, target.Position)
    
    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        
        for i = 2, #waypoints do -- Skip first waypoint
            humanoid:MoveTo(waypoints[i].Position)
            
            local startTime = os.clock()
            while (humanoidRootPart.Position - waypoints[i].Position).Magnitude > 2.5 do
                if os.clock() - startTime > PATHFINDING_TIMEOUT then
                    humanoid:MoveTo(humanoidRootPart.Position) -- Cancel movement
                    return false
                end
                RunService.Heartbeat:Wait()
            end
        end
        return true
    end
    return false
end

-- Realistic collection interaction
local function collectHerb(herb)
    -- Face the herb naturally
    local targetPosition = Vector3.new(herb.Position.X, humanoidRootPart.Position.Y, herb.Position.Z)
    humanoidRootPart.CFrame = CFrame.lookAt(humanoidRootPart.Position, targetPosition)
    
    -- Simulate key press with human-like delay
    wait(math.random(0.1, 0.3))
    
    -- Hold E with slight randomness
    local actualDuration = COLLECT_DURATION * (0.9 + math.random() * 0.2) -- 90-110% of duration
    UserInputService:SetKeysDown({COLLECT_KEY})
    
    local startTime = os.clock()
    while os.clock() - startTime < actualDuration do
        if (humanoidRootPart.Position - herb.Position).Magnitude > REACH_DISTANCE + 2 then
            UserInputService:SetKeysUp({COLLECT_KEY})
            return false -- Moved too far away
        end
        RunService.Heartbeat:Wait()
    end
    
    UserInputService:SetKeysUp({COLLECT_KEY})
    return true
end

-- Main collection loop with cooldown
local lastCollectionTime = 0
local COLLECTION_COOLDOWN = 10

while true do
    local currentTime = os.clock()
    
    if currentTime - lastCollectionTime >= COLLECTION_COOLDOWN then
        local herb = findNearestHerb()
        
        if herb then
            local distance = (humanoidRootPart.Position - herb.Position).Magnitude
            
            if distance > REACH_DISTANCE then
                if navigateTo(herb) then
                    if collectHerb(herb) then
                        lastCollectionTime = os.clock()
                        print("Successfully collected:", HERB_NAME)
                        wait(math.random(2, 4)) -- Random pause between actions
                    end
                end
            else
                if collectHerb(herb) then
                    lastCollectionTime = os.clock()
                    print("Collected nearby herb")
                end
            end
        else
            print("No herbs found. Searching again in", SEARCH_INTERVAL, "seconds")
        end
    else
        local remainingCooldown = math.floor(COLLECTION_COOLDOWN - (currentTime - lastCollectionTime))
        print("On cooldown. Ready in", remainingCooldown, "seconds")
    end
    
    wait(SEARCH_INTERVAL)
end
