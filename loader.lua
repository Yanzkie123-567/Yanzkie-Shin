-- Load Rayfield UI Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

----------------------------------------------------
-- CONFIGURATION
----------------------------------------------------
local FALLBACK_PLOT = Vector3.new(0, 5, 0) -- Used only if plot/character is missing

local TWEEN_SPEED = 300  -- Speed in studs per second (Updated Default)
local WAIT_AT_EGG = 3    -- Total seconds to stay at each egg location
local PICKUP_DELAY = 0.5 -- Delay between pick-up attempts

local selectedRarity = "Ethereal"
local runCount = 5
local isRunning = false

local noClipEnabled = true
local removeShakeEnabled = true
local autoServerHopEnabled = false

-- List of specific Ethereal egg names in RenderedEggs
local ETHEREAL_EGG_NAMES = {
	"blackhole egg", "blackhole",
	"solaris egg", "solaris",
	"cherub egg", "cherub",
	"volcanic egg", "volcanic"
}
----------------------------------------------------

-- 1. NO CLIP MECHANISM
local noClipConnection
local function setNoClip(enable)
	if enable then
		if not noClipConnection then
			noClipConnection = RunService.Stepped:Connect(function()
				if localPlayer.Character then
					for _, part in ipairs(localPlayer.Character:GetDescendants()) do
						if part:IsA("BasePart") and part.CanCollide then
							part.CanCollide = false
						end
					end
				end
			end)
		end
	else
		if noClipConnection then
			noClipConnection:Disconnect()
			noClipConnection = nil
		end
	end
end

-- 2. SCREEN SHAKE REMOVER
local shakeConnection
local function disableScreenShake(enable)
	if enable then
		if not shakeConnection then
			shakeConnection = RunService.RenderStepped:Connect(function()
				if Camera then
					Camera.CFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Camera.CFrame.LookVector)
				end
				
				local char = localPlayer.Character
				if char then
					local humanoid = char:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.CameraOffset = Vector3.new(0, 0, 0)
					end
				end
			end)
		end
	else
		if shakeConnection then
			shakeConnection:Disconnect()
			shakeConnection = nil
		end
	end
end

-- 3. SERVER HOP FUNCTION
local function serverHop()
	Rayfield:Notify({
		Title = "Auto Server Hop",
		Content = "Finding a new server...",
		Duration = 3,
		Image = 4483362458
	})

	local placeId = game.PlaceId
	local currentJobId = game.JobId
	local serversUrl = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"

	local success, result = pcall(function()
		return HttpService:JSONDecode(game:HttpGet(serversUrl))
	end)

	if success and result and result.data then
		for _, server in ipairs(result.data) do
			if server.playing < server.maxPlayers and server.id ~= currentJobId then
				TeleportService:TeleportToPlaceInstance(placeId, server.id, localPlayer)
				return
			end
		end
	end

	-- Fallback to standard server teleport if no explicit server ID was matched
	TeleportService:Teleport(placeId, localPlayer)
end

-- Dynamic function to scan workspace.RenderedEggs for matching Egg positions
local function getActiveEggPositions()
	local eggPositions = {}
	
	local renderedFolder = workspace:FindFirstChild("RenderedEggs")
	if not renderedFolder then
		return eggPositions
	end

	for _, object in ipairs(renderedFolder:GetDescendants()) do
		local objectName = string.lower(object.Name)
		local rarityMatch = false

		if selectedRarity == "Ethereal" then
			for _, etherealName in ipairs(ETHEREAL_EGG_NAMES) do
				if string.find(objectName, etherealName) then
					rarityMatch = true
					break
				end
			end
		elseif selectedRarity == "All" then
			rarityMatch = true
		else
			if string.find(objectName, string.lower(selectedRarity)) then
				rarityMatch = true
			end
		end

		if not rarityMatch then
			local rarityValue = object:FindFirstChild("Rarity") or object:FindFirstChild("EggRarity")
			if rarityValue and rarityValue:IsA("StringValue") then
				if string.find(string.lower(rarityValue.Value), string.lower(selectedRarity)) then
					rarityMatch = true
				end
			end
		end

		if rarityMatch then
			if object:IsA("Model") then
				local primaryPart = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
				if primaryPart then
					table.insert(eggPositions, primaryPart.Position)
				else
					local pivotPos = object:GetPivot().Position
					table.insert(eggPositions, pivotPos)
				end
			elseif object:IsA("BasePart") and not object.Parent:IsA("Model") then
				table.insert(eggPositions, object.Position)
			end
		end
	end

	return eggPositions
end

-- Dynamic Plot Detection
local function getMyPlotPosition()
	local possibleFolders = {
		workspace:FindFirstChild("Plots"),
		workspace:FindFirstChild("PlotsFolder"),
		workspace:FindFirstChild("Tycoons"),
		workspace:FindFirstChild("Bases"),
		workspace
	}

	for _, folder in ipairs(possibleFolders) do
		if folder then
			for _, plot in ipairs(folder:GetChildren()) do
				local ownerVal = plot:FindFirstChild("Owner") 
					or plot:FindFirstChild("OwnerName") 
					or plot:FindFirstChild("Player") 
					or plot:FindFirstChild("ClaimedBy")
					or plot:FindFirstChild("UserId")

				if ownerVal then
					local valStr = tostring(ownerVal.Value)
					if valStr == localPlayer.Name or ownerVal.Value == localPlayer or valStr == tostring(localPlayer.UserId) then
						return plot:GetPivot().Position
					end
				end

				if string.find(string.lower(plot.Name), string.lower(localPlayer.Name)) or string.find(plot.Name, tostring(localPlayer.UserId)) then
					return plot:GetPivot().Position
				end
			end
		end
	end

	if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
		return localPlayer.Character.HumanoidRootPart.Position
	end

	return FALLBACK_PLOT
end

-- Tween movement function
local function tweenToPosition(targetPosition)
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart")
	
	local startPosition = rootPart.Position
	local distance = (targetPosition - startPosition).Magnitude
	local tweenTime = math.max(distance / TWEEN_SPEED, 0.02)

	local tweenInfo = TweenInfo.new(
		tweenTime,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out
	)

	local targetCFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0)) 
	local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
	tween:Play()
	
	return tween
end

-- Auto Pick-Up function
local function autoPickUp(duration)
	local startTime = os.clock()
	
	while os.clock() - startTime < duration do
		local character = localPlayer.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local rootPos = character.HumanoidRootPart.Position
			
			for _, prompt in ipairs(workspace:GetDescendants()) do
				if prompt:IsA("ProximityPrompt") and prompt.Enabled then
					local parentObj = prompt.Parent
					if parentObj and parentObj:IsA("BasePart") then
						if (parentObj.Position - rootPos).Magnitude <= prompt.MaxActivationDistance then
							fireproximityprompt(prompt)
						end
					end
				end
			end
			
			for _, part in ipairs(workspace:GetDescendants()) do
				if part:IsA("BasePart") and part:FindFirstChildOfClass("TouchTransmitter") then
					if (part.Position - rootPos).Magnitude <= 10 then
						firetouchinterest(character.HumanoidRootPart, part, 0)
						task.wait(0.05)
						firetouchinterest(character.HumanoidRootPart, part, 1)
					end
				end
			end
		end
		
		task.wait(PICKUP_DELAY)
	end
end

----------------------------------------------------
-- RAYFIELD UI INTERFACE
----------------------------------------------------
local Window = Rayfield:CreateWindow({
	Name = "Auto Steal Egg Hub",
	LoadingTitle = "Loading Script...",
	LoadingSubtitle = "by Assistant",
	ConfigurationSaving = { Enabled = false },
	KeySystem = false
})

local MainTab = Window:CreateTab("Main", 4483362458)

-- 1. RARITY SELECTOR
MainTab:CreateDropdown({
	Name = "Target Rarity",
	Options = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Ethereal", "All"},
	CurrentOption = {"Ethereal"},
	MultipleOptions = false,
	Flag = "RarityDropdown",
	Callback = function(Option)
		selectedRarity = Option[1]
	end,
})

-- 2. TWEEN SPEED SLIDER (Range 100 to 1000)
MainTab:CreateSlider({
	Name = "Tween Speed",
	Range = {100, 1000},
	Increment = 25,
	Suffix = " Studs/s",
	CurrentValue = TWEEN_SPEED,
	Flag = "TweenSpeedSlider",
	Callback = function(Value)
		TWEEN_SPEED = Value
	end,
})

-- 3. NO CLIP TOGGLE
MainTab:CreateToggle({
	Name = "No Clip",
	CurrentValue = true,
	Flag = "NoClipToggle",
	Callback = function(Value)
		noClipEnabled = Value
		if not isRunning then
			setNoClip(Value)
		end
	end,
})

-- 4. REMOVE SCREEN SHAKE TOGGLE
MainTab:CreateToggle({
	Name = "Remove Screen Shake",
	CurrentValue = true,
	Flag = "RemoveShakeToggle",
	Callback = function(Value)
		removeShakeEnabled = Value
		disableScreenShake(Value)
	end,
})

-- 5. AUTO SERVER HOP TOGGLE
MainTab:CreateToggle({
	Name = "Auto Server Hop",
	CurrentValue = false,
	Flag = "AutoServerHopToggle",
	Callback = function(Value)
		autoServerHopEnabled = Value
	end,
})

-- 6. TRIP REPEAT COUNT SLIDER
MainTab:CreateSlider({
	Name = "Loop Cycles",
	Range = {1, 50},
	Increment = 1,
	Suffix = " Cycles",
	CurrentValue = runCount,
	Flag = "TripCountSlider",
	Callback = function(Value)
		runCount = Value
	end,
})

-- 7. AUTO STEAL EGG TOGGLE
local StealToggle = MainTab:CreateToggle({
	Name = "Auto Steal Egg",
	CurrentValue = false,
	Flag = "AutoStealEggToggle",
	Callback = function(Value)
		isRunning = Value
		
		if noClipEnabled then setNoClip(isRunning) end
		if removeShakeEnabled then disableScreenShake(isRunning) end

		if isRunning then
			task.spawn(function()
				for cycle = 1, runCount do
					if not isRunning then break end

					local activeEggs = getActiveEggPositions()

					if #activeEggs == 0 then
						Rayfield:Notify({
							Title = "Auto Steal Egg",
							Content = "No " .. selectedRarity .. " eggs in RenderedEggs!",
							Duration = 2,
							Image = 4483362458
						})
						
						if autoServerHopEnabled then
							task.wait(1)
							serverHop()
							break
						else
							task.wait(2)
						end
					else
						for index, eggPos in ipairs(activeEggs) do
							if not isRunning then break end

							Rayfield:Notify({
								Title = "Auto Steal Egg (" .. selectedRarity .. ")",
								Content = "Cycle " .. cycle .. " | Egg " .. index .. "/" .. #activeEggs,
								Duration = 2,
								Image = 4483362458
							})

							-- 1. Tween to detected egg position
							local toEggTween = tweenToPosition(eggPos)
							toEggTween.Completed:Wait()

							if not isRunning then break end

							-- 2. Trigger pick-up mechanisms
							autoPickUp(WAIT_AT_EGG)

							if not isRunning then break end

							-- 3. Tween back to assigned plot
							local currentPlotPos = getMyPlotPosition()

							Rayfield:Notify({
								Title = "Auto Steal Egg",
								Content = "Returning to Plot...",
								Duration = 1.5,
								Image = 4483362458
							})

							local toPlotTween = tweenToPosition(currentPlotPos)
							toPlotTween.Completed:Wait()

							task.wait(0.5)
						end
					end
				end

				isRunning = false
				setNoClip(false)
				StealToggle:Set(false)
			end)
		end
	end,
})
