local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Auto-detection configuration
local TARGET_NAME = "Medicinal Herb"
local SEARCH_RADIUS = 200
local INTERACTION_TYPES = {
    HOLD_E = {
        key = Enum.KeyCode.E,
        duration = 2
    },
    CLICK = {
        detector_class = "ClickDetector"
    },
    PROXIMITY = {
        range = 10
    }
}

-- Initialize character
local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Debug visualization
local function createMarker(target, color)
    if target:FindFirstChild("HERB_DEBUG_MARKER") then return end
    
    local marker = Instance.new("BoxHandleAdornment")
    marker.Name = "HERB_DEBUG_MARKER"
    marker.Adornee = target
    marker.AlwaysOnTop = true
    marker.Size = target:IsA("BasePart") and target.Size or target.PrimaryPart.Size
    marker.Color3 = color or Color3.fromRGB(0, 255, 0)
    marker.Transparency = 0.7
    marker.ZIndex = 10
    marker.Parent = target
    return marker
end

-- Advanced target finding
local function findTarget()
    local candidates = {}
    
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant.Name:find(TARGET_NAME) then
            if descendant:IsA("BasePart") or descendant:IsA("Model") then
                local validTarget = false
                local primaryPart = nil
                local position = nil
                
                if descendant:IsA("Model") then
                    primaryPart = descendant.PrimaryPart or descendant:FindFirstChildWhichIsA("BasePart")
                    if primaryPart then
                        position = primaryPart.Position
                        validTarget = true
                    end
                else
                    position = descendant.Position
                    validTarget = true
                end
                
                if validTarget and (humanoidRootPart.Position - position).Magnitude <= SEARCH_RADIUS then
                    table.insert(candidates, {
                        object = descendant,
                        primaryPart = primaryPart,
                        position = position
                    })
                end
            end
        end
    end
    
    -- Find nearest candidate
    local nearest = nil
    local minDistance = math.huge
    
    for _, candidate in ipairs(candidates) do
        local distance = (humanoidRootPart.Position - candidate.position).Magnitude
        if distance < minDistance then
            minDistance = distance
            nearest = candidate
        end
    end
    
    return nearest
end

-- Smart interaction detection
local function determineInteractionMethod(target)
    -- Method 1: Check for ClickDetector
    local clickDetector = target.object:FindFirstChildOfClass("ClickDetector") 
                    or (target.primaryPart and target.primaryPart:FindFirstChildOfClass("ClickDetector"))
    
    if clickDetector then
        createMarker(target.object, Color3.fromRGB(255, 0, 0))
        return "CLICK", clickDetector
    end
    
    -- Method 2: Check for ProximityPrompt
    local proximityPrompt = target.object:FindFirstChildOfClass("ProximityPrompt")
                    or (target.primaryPart and target.primaryPart:FindFirstChildOfClass("ProximityPrompt"))
    
    if proximityPrompt then
        createMarker(target.object, Color3.fromRGB(0, 0, 255))
        return "PROMPT", proximityPrompt
    end
    
    -- Method 3: Default to Hold E
    createMarker(target.object, Color3.fromRGB(0, 255, 0))
    return "HOLD_E"
end

-- Pathfinding with obstacle avoidance
local function navigateTo(position)
    local path = PathfindingService:CreatePath({
        AgentRadius = 1,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true
    })
    
    path:ComputeAsync(humanoidRootPart.Position, position)
    
    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        
        for i = 2, #waypoints do
            humanoid:MoveTo(waypoints[i].Position)
            
            local startTime = os.clock()
            while (humanoidRootPart.Position - waypoints[i].Position).Magnitude > 3 do
                if os.clock() - startTime > 5 then
                    humanoid:MoveTo(humanoidRootPart.Position)
                    return false
                end
                RunService.Heartbeat:Wait()
            end
        end
        return true
    end
    return false
end

-- Interaction handlers
local interactionHandlers = {
    CLICK = function(target, detector)
        fireclickdetector(detector)
        print("Collected via ClickDetector")
        return true
    end,
    
    PROMPT = function(target, prompt)
        prompt:InputHoldBegin()
        wait(prompt.HoldDuration)
        prompt:InputHoldEnd()
        print("Collected via ProximityPrompt")
        return true
    end,
    
    HOLD_E = function(target)
        -- Face the target
        humanoidRootPart.CFrame = CFrame.lookAt(
            humanoidRootPart.Position,
            Vector3.new(target.position.X, humanoidRootPart.Position.Y, target.position.Z)
        )
        
        -- Hold E
        local startTime = os.clock()
        UserInputService:SetKeysDown({INTERACTION_TYPES.HOLD_E.key})
        
        while os.clock() - startTime < INTERACTION_TYPES.HOLD_E.duration do
            if (humanoidRootPart.Position - target.position).Magnitude > 10 then
                UserInputService:SetKeysUp({INTERACTION_TYPES.HOLD_E.key})
                return false
            end
            RunService.Heartbeat:Wait()
        end
        
        UserInputService:SetKeysUp({INTERACTION_TYPES.HOLD_E.key})
        print("Collected via Hold E")
        return true
    end
}

-- Main collection system
local function attemptCollection()
    local target = findTarget()
    
    if not target then
        print("No target found within range")
        return false
    end
    
    local interactionType, interactionTarget = determineInteractionMethod(target)
    
    -- Navigate to target if not in range
    if (humanoidRootPart.Position - target.position).Magnitude > 10 then
        if not navigateTo(target.position) then
            print("Pathfinding failed")
            return false
        end
    end
    
    -- Attempt interaction
    if interactionHandlers[interactionType] then
        return interactionHandlers[interactionType](target, interactionTarget)
    end
    
    return false
end

-- Main loop with cooldown
while true do
    local success, err = pcall(attemptCollection)
    
    if not success then
        warn("Error during collection:", err)
    end
    
    wait(3) -- Search cooldown
end
