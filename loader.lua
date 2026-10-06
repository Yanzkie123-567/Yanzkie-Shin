----------------------------------------------------
-- SERVICES & LOCAL PLAYER
----------------------------------------------------
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

----------------------------------------------------
-- RAYFIELD UI LOADER (WITH SAFE FALLBACK)
----------------------------------------------------
local Rayfield = nil

local function loadRayfield()
	local success, result = pcall(function()
		return loadstring(game:HttpGet('https://sirius.menu/rayfield', true))()
	end)

	if success and result then
		return result
	end

	-- Fallback to GitHub raw if sirius.menu is down/blocked
	warn("[Rayfield] Primary menu link failed. Attempting GitHub fallback...")
	local fallbackSuccess, fallbackResult = pcall(function()
		return loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source', true))()
	end)

	if fallbackSuccess and fallbackResult then
		return fallbackResult
	end

	return nil
end

Rayfield = loadRayfield()

if not Rayfield then
	warn("[ERROR] Failed to load Rayfield UI library. Please check your internet or executor HttpGet support.")
	return
end

----------------------------------------------------
-- CONFIGURATION & STATE
----------------------------------------------------
local selectedRarity = "Ethereal"
local TWEEN_SPEED = 300
local WAIT_AT_EGG = 2.5
local PICKUP_DELAY = 0.2
local runCount = 5

local noClipEnabled = true
local removeShakeEnabled = true
local autoServerHopEnabled = false

local isRunning = false
local homePlotPosition = nil
local noClipConnection = nil
local shakeConnection = nil

local ETHEREAL_EGG_NAMES = {
	"blackhole egg", "blackhole",
	"solaris egg", "solaris",
	"cherub egg", "cherub",
	"volcanic egg", "volcanic"
}

----------------------------------------------------
-- CORE HELPER FUNCTIONS
----------------------------------------------------

-- 1. NO CLIP
local function setNoClip(enable)
	if enable then
		if not noClipConnection then
			noClipConnection = RunService.Stepped:Connect(function()
				local char = localPlayer.Character
				if char then
					for _, part in ipairs(char:GetDescendants()) do
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
local function disableScreenShake(enable)
	if enable then
		if not shakeConnection then
			local function disableShakeScripts(parent)
				if not parent then return end
				for _, scriptObj in ipairs(parent:GetDescendants()) do
					if scriptObj:IsA("LocalScript") or scriptObj:IsA("ModuleScript") then
						local name = string.lower(scriptObj.Name)
						if string.find(name, "shake") or string.find(name, "recoil") or string.find(name, "camoffset") then
							scriptObj.Disabled = true
						end
					end
				end
			end

			disableShakeScripts(localPlayer:FindFirstChild("PlayerScripts"))
			disableShakeScripts(localPlayer.Character)

			shakeConnection = RunService.RenderStepped:Connect(function()
				local char = localPlayer.Character
				if char then
					local humanoid = char:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.CameraOffset = Vector3.zero
					end
				end

				if Camera then
					local pos = Camera.CFrame.Position
					local look = Camera.CFrame.LookVector
					Camera.CFrame = CFrame.lookAt(pos, pos + look)
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

-- 3. SCANNER (WORKSPACE ROOT FIRST -> RENDEREDEGGs SECOND)
local function getActiveEggObjects()
	local targetEggs = {}

	local function processEggObject(obj)
		if not obj or not obj.Parent then return end
		local objectName = string.lower(obj.Name)
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
			local rarityValue = obj:FindFirstChild("Rarity") or obj:FindFirstChild("EggRarity")
			if rarityValue and rarityValue:IsA("StringValue") then
				if string.find(string.lower(rarityValue.Value), string.lower(selectedRarity)) then
					rarityMatch = true
				end
			end
		end

		if rarityMatch then
			table.insert(targetEggs, obj)
		end
	end

	-- Priority 1: Top-level Workspace
	for _, child in ipairs(workspace:GetChildren()) do
		if not child:IsA("Folder") and not Players:GetPlayerFromCharacter(child) then
			processEggObject(child)
		end
	end

	-- Priority 2: RenderedEggs Folder (if root scan yielded no matches)
	if #targetEggs == 0 then
		local renderedFolder = workspace:FindFirstChild("RenderedEggs")
		if renderedFolder then
			for _, child in ipairs(renderedFolder:GetChildren()) do
				processEggObject(child)
			end
		end
	end

	return targetEggs
end

-- 4. PLOT DETECTION
local function getMyPlotPosition()
	if homePlotPosition then
		return homePlotPosition
	end

	local myName = string.lower(localPlayer.Name)
	local myUserId = tostring(localPlayer.UserId)

	local possibleFolders = {
		workspace:FindFirstChild("Plots"),
		workspace:FindFirstChild("PlotsFolder"),
		workspace:FindFirstChild("Tycoons"),
		workspace:FindFirstChild("Bases")
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
					local valStr = string.lower(tostring(ownerVal.Value))
					if valStr == myName or ownerVal.Value == localPlayer or valStr == myUserId then
						return plot:GetPivot().Position
					end
				end

				local plotName = string.lower(plot.Name)
				if string.find(plotName, myName) or string.find(plotName, myUserId) then
					return plot:GetPivot().Position
				end
			end
		end
	end

	for _, object in ipairs(workspace:GetChildren()) do
		if object:IsA("Model") or object:IsA("Folder") then
			local objectName = string.lower(object.Name)
			if string.find(objectName, myName) or string.find(objectName, myUserId) then
				return object:GetPivot().Position
			end

			local ownerVal = object:FindFirstChild("Owner") 
				or object:FindFirstChild("OwnerName") 
				or object:FindFirstChild("Player") 
				or object:FindFirstChild("ClaimedBy")
				or object:FindFirstChild("UserId")

			if ownerVal then
				local valStr = string.lower(tostring(ownerVal.Value))
				if valStr == myName or ownerVal.Value == localPlayer or valStr == myUserId then
					return object:GetPivot().Position
				end
			end
		end
	end

	if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
		return localPlayer.Character.HumanoidRootPart.Position
	end

	return Vector3.new(0, 5, 0)
end

-- 5. TWEEN & PICKUP
local function tweenToPosition(targetPosition)
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not rootPart then return nil end

	local startPosition = rootPart.Position
	local distance = (targetPosition - startPosition).Magnitude
	local tweenTime = math.max(distance / math.max(10, TWEEN_SPEED), 0.05)

	local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local targetCFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0)) 

	local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
	tween:Play()

	return tween
end

local function autoPickUpTarget(eggObj, duration)
	local startTime = os.clock()

	while os.clock() - startTime < duration do
		local character = localPlayer.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local rootPart = character.HumanoidRootPart

			if eggObj and eggObj.Parent then
				for _, prompt in ipairs(eggObj:GetDescendants()) do
					if prompt:IsA("ProximityPrompt") then
						prompt.HoldDuration = 0
						pcall(fireproximityprompt, prompt)
					end
				end

				for _, part in ipairs(eggObj:GetDescendants()) do
					if part:IsA("BasePart") then
						pcall(firetouchinterest, rootPart, part, 0)
						task.wait(0.02)
						pcall(firetouchinterest, rootPart, part, 1)
					end
				end
			end

			for _, prompt in ipairs(workspace:GetDescendants()) do
				if prompt:IsA("ProximityPrompt") and prompt.Enabled then
					local parentObj = prompt.Parent
					if parentObj and parentObj:IsA("BasePart") then
						if (parentObj.Position - rootPart.Position).Magnitude <= (prompt.MaxActivationDistance + 5) then
							prompt.HoldDuration = 0
							pcall(fireproximityprompt, prompt)
						end
					end
				end
			end
		end

		task.wait(PICKUP_DELAY)
	end
end

-- 6. SERVER HOP
local function serverHop()
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

	TeleportService:Teleport(placeId, localPlayer)
end

----------------------------------------------------
-- RAYFIELD UI INITIALIZATION (CUSTOM VIOLET THEME)
----------------------------------------------------
if Rayfield.Themes then
	Rayfield.Themes["Violet"] = {
		TextColor = Color3.fromRGB(240, 230, 255),
		Background = Color3.fromRGB(28, 15, 45),
		Topbar = Color3.fromRGB(42, 20, 70),
		Shadow = Color3.fromRGB(15, 5, 25),
		ElementBackground = Color3.fromRGB(50, 25, 80),
		ElementBackgroundHover = Color3.fromRGB(65, 35, 105),
		ElementStroke = Color3.fromRGB(90, 45, 145),
		SecondaryElementBackground = Color3.fromRGB(40, 20, 65),
		SecondaryElementStroke = Color3.fromRGB(75, 35, 120),
		SliderBackground = Color3.fromRGB(70, 35, 110),
		SliderProgress = Color3.fromRGB(150, 80, 240),
		SliderStroke = Color3.fromRGB(110, 55, 175),
		ToggleBackground = Color3.fromRGB(45, 20, 70),
		ToggleEnabled = Color3.fromRGB(140, 60, 230),
		ToggleDisabled = Color3.fromRGB(30, 15, 50),
		ToggleStroke = Color3.fromRGB(80, 40, 130),
		DropdownBackground = Color3.fromRGB(45, 20, 70),
		DropdownStroke = Color3.fromRGB(80, 40, 130),
		InputBackground = Color3.fromRGB(45, 20, 70),
		InputStroke = Color3.fromRGB(80, 40, 130),
		PlaceholderColor = Color3.fromRGB(180, 150, 210)
	}
end

local Window = Rayfield:CreateWindow({
	Name = "Auto Steal Egg Hub",
	LoadingTitle = "Loading Violet Hub...",
	LoadingSubtitle = "Protected Callbacks",
	ConfigurationSaving = { Enabled = false },
	KeySystem = false,
	Theme = Rayfield.Themes and "Violet" or "Default"
})

local MainTab = Window:CreateTab("Main", 4483362458)

MainTab:CreateDropdown({
	Name = "Target Rarity",
	Options = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Ethereal", "All"},
	CurrentOption = {"Ethereal"},
	MultipleOptions = false,
	Flag = "RarityDropdown",
	Callback = function(Option)
		if type(Option) == "table" then
			selectedRarity = Option[1] or "Ethereal"
		elseif type(Option) == "string" then
			selectedRarity = Option
		end
	end,
})

MainTab:CreateSlider({
	Name = "Tween Speed",
	Range = {100, 1000},
	Increment = 25,
	Suffix = " Studs/s",
	CurrentValue = TWEEN_SPEED,
	Flag = "TweenSpeedSlider",
	Callback = function(Value)
		TWEEN_SPEED = tonumber(Value) or 300
	end,
})

MainTab:CreateToggle({
	Name = "No Clip",
	CurrentValue = true,
	Flag = "NoClipToggle",
	Callback = function(Value)
		noClipEnabled = not not Value
		if not isRunning then setNoClip(noClipEnabled) end
	end,
})

MainTab:CreateToggle({
	Name = "Remove Screen Shake",
	CurrentValue = true,
	Flag = "RemoveShakeToggle",
	Callback = function(Value)
		removeShakeEnabled = not not Value
		disableScreenShake(removeShakeEnabled)
	end,
})

MainTab:CreateToggle({
	Name = "Auto Server Hop",
	CurrentValue = false,
	Flag = "AutoServerHopToggle",
	Callback = function(Value)
		autoServerHopEnabled = not not Value
	end,
})

MainTab:CreateSlider({
	Name = "Loop Cycles",
	Range = {1, 50},
	Increment = 1,
	Suffix = " Cycles",
	CurrentValue = runCount,
	Flag = "TripCountSlider",
	Callback = function(Value)
		runCount = tonumber(Value) or 5
	end,
})

MainTab:CreateToggle({
	Name = "Auto Steal Egg",
	CurrentValue = false,
	Flag = "AutoStealEggToggle",
	Callback = function(Value)
		isRunning = not not Value

		if isRunning then
			if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
				homePlotPosition = localPlayer.Character.HumanoidRootPart.Position
			end

			if noClipEnabled then setNoClip(true) end
			if removeShakeEnabled then disableScreenShake(true) end

			task.spawn(function()
				local success, err = pcall(function()
					for cycle = 1, runCount do
						if not isRunning then break end

						local activeEggObjects = getActiveEggObjects()

						if #activeEggObjects == 0 then
							Rayfield:Notify({
								Title = "Auto Steal Egg",
								Content = "No " .. tostring(selectedRarity) .. " eggs found!",
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
							for index, eggObj in ipairs(activeEggObjects) do
								if not isRunning then break end
								if not eggObj or not eggObj.Parent then continue end

								local eggPos
								if eggObj:IsA("Model") then
									eggPos = (eggObj.PrimaryPart and eggObj.PrimaryPart.Position) or eggObj:GetPivot().Position
								elseif eggObj:IsA("BasePart") then
									eggPos = eggObj.Position
								end

								if eggPos then
									Rayfield:Notify({
										Title = "Auto Steal Egg (" .. tostring(selectedRarity) .. ")",
										Content = "Cycle " .. cycle .. " | Egg " .. index .. "/" .. #activeEggObjects,
										Duration = 2,
										Image = 4483362458
									})

									local toEggTween = tweenToPosition(eggPos)
									if toEggTween and toEggTween.Completed then
										toEggTween.Completed:Wait()
									end

									if not isRunning then break end

									autoPickUpTarget(eggObj, WAIT_AT_EGG)

									if not isRunning then break end

									local targetPlotPos = getMyPlotPosition()

									Rayfield:Notify({
										Title = "Auto Steal Egg",
										Content = "Returning to Plot...",
										Duration = 1.5,
										Image = 4483362458
									})

									local toPlotTween = tweenToPosition(targetPlotPos)
									if toPlotTween and toPlotTween.Completed then
										toPlotTween.Completed:Wait()
									end

									task.wait(0.5)
								end
							end
						end
					end
				end)

				if not success then
					warn("Auto Steal Error: " .. tostring(err))
				end

				isRunning = false
				setNoClip(false)
			end)
		else
			setNoClip(false)
		end
	end,
})
