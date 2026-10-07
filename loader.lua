----------------------------------------------------
-- SERVICES & LOCAL PLAYER
----------------------------------------------------
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer

----------------------------------------------------
-- ANTI-KICK & ANTI-AFK PROTECTION
----------------------------------------------------
pcall(function()
	local VirtualUser = game:GetService("VirtualUser")
	localPlayer.Idled:Connect(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
	end)

	if hookmetamethod then
		local oldNamecall
		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			local method = getnamecallmethod()
			if method == "Kick" or method == "kick" then
				return nil
			end
			return oldNamecall(self, ...)
		end)
	end
end)

----------------------------------------------------
-- MULTI-SOURCE UI LOADER (FLUENT WITH FALLBACK)
----------------------------------------------------
local Fluent = nil
local libraryType = "Fluent"

local function fetchLibrary(urls)
	for _, url in ipairs(urls) do
		local success, result = pcall(function()
			return loadstring(game:HttpGet(url))()
		end)
		if success and result then
			return result
		end
	end
	return nil
end

-- Try Fluent CDNs
Fluent = fetchLibrary({
	"https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
	"https://raw.githubusercontent.com/dawid-scripts/Fluent/master/main.lua",
	"https://raw.githubusercontent.com/dawid-scripts/Fluent/main/main.lua",
	"https://cdn.jsdelivr.net/gh/dawid-scripts/Fluent@main/main.lua"
})

-- If Fluent fails completely, load fallback UI library (Kavo UI)
if not Fluent then
	libraryType = "Fallback"
	Fluent = fetchLibrary({
		"https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua",
		"https://cdn.jsdelivr.net/gh/xHeptc/Kavo-UI-Library@main/source.lua"
	})
end

----------------------------------------------------
-- CONFIGURATION & STATE
----------------------------------------------------
local selectedRarity = "Ethereal"
local TWEEN_SPEED = 300
local WAIT_AT_EGG = 2.5
local PICKUP_DELAY = 0.25
local runCount = 5

local noClipEnabled = true
local removeShakeEnabled = true
local autoServerHopEnabled = false
local performanceBoostEnabled = true

local isRunning = false
local currentActiveTween = nil
local homePlotPosition = nil
local noClipConnection = nil
local shakeConnection = nil

local ETHEREAL_EGG_NAMES = {
	"blackhole egg", "blackhole",
	"solaris egg", "solaris",
	"cherub egg", "cherub",
	"volcanic egg", "volcanic"
}

local ANIME_PRESETS = {
	["Solo Leveling"] = "rbxassetid://16723223078",
	["Jujutsu Kaisen"] = "rbxassetid://11681287958",
	["Demon Slayer"] = "rbxassetid://11438992080",
	["Cyberpunk Anime"] = "rbxassetid://11326410298",
	["Attack on Titan"] = "rbxassetid://11438991448",
	["None (Purple Theme)"] = ""
}

----------------------------------------------------
-- CORE HELPER FUNCTIONS
----------------------------------------------------

-- 1. SMART FLOOR-AWARE NO-CLIP
local function setNoClip(enable)
	if enable then
		if not noClipConnection then
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.IgnoreWater = true

			noClipConnection = RunService.Stepped:Connect(function()
				local char = localPlayer.Character
				if not char then return end

				local hrp = char:FindFirstChild("HumanoidRootPart")
				if not hrp then return end

				raycastParams.FilterDescendantsInstances = {char}
				local rayResult = workspace:Raycast(hrp.Position, Vector3.new(0, -10, 0), raycastParams)
				local groundPart = rayResult and rayResult.Instance or nil

				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
					end
				end

				if groundPart and groundPart:IsA("BasePart") then
					groundPart.CanCollide = true
				end

				if not isRunning and math.abs(hrp.AssemblyLinearVelocity.Y) < 1 then
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
			end)
		end
	else
		if noClipConnection then
			noClipConnection:Disconnect()
			noClipConnection = nil
		end

		local char = localPlayer.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.CanCollide = true
				end
			end
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
					if scriptObj:IsA("LocalScript") then
						local name = string.lower(scriptObj.Name)
						if string.find(name, "shake") or string.find(name, "recoil") or string.find(name, "camoffset") then
							pcall(function() scriptObj.Disabled = true end)
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
			end)
		end
	else
		if shakeConnection then
			shakeConnection:Disconnect()
			shakeConnection = nil
		end
	end
end

-- 3. PLOT DETECTION
local function isEggOnPlot(obj)
	if not obj then return true end
	local current = obj
	while current and current ~= workspace do
		local ancestorName = string.lower(current.Name)
		if string.find(ancestorName, "plot") or string.find(ancestorName, "base") or string.find(ancestorName, "house") or string.find(ancestorName, "land") then
			return true
		end
		if current:FindFirstChild("Owner") or current:FindFirstChild("OwnerName") or current:FindFirstChild("ClaimedBy") or current:FindFirstChild("PlacedBy") then
			return true
		end
		current = current.Parent
	end
	return false
end

-- 4. EGG SCANNER
local function getActiveEggObjects()
	local targetEggs = {}
	local processedSet = {}

	local function processEggObject(obj)
		if not obj or not obj.Parent or processedSet[obj] then return end
		if Players:GetPlayerFromCharacter(obj) or (localPlayer.Character and obj:IsDescendantOf(localPlayer.Character)) then return end
		if isEggOnPlot(obj) then return end

		local objectName = string.lower(obj.Name)
		local rarityMatch = false

		if selectedRarity == "Ethereal" then
			for _, etherealName in ipairs(ETHEREAL_EGG_NAMES) do
				if string.find(objectName, etherealName) then rarityMatch = true; break end
			end
		elseif selectedRarity == "All" then
			if string.find(objectName, "egg") then rarityMatch = true end
		else
			if string.find(objectName, string.lower(selectedRarity)) then rarityMatch = true end
		end

		if not rarityMatch then
			local rarityValue = obj:FindFirstChild("Rarity") or obj:FindFirstChild("EggRarity")
			if rarityValue and rarityValue:IsA("StringValue") and string.find(string.lower(rarityValue.Value), string.lower(selectedRarity)) then
				rarityMatch = true
			end
		end

		if rarityMatch then
			processedSet[obj] = true
			table.insert(targetEggs, obj)
		end
	end

	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") or obj:IsA("Folder") then
			for _, child in ipairs(obj:GetDescendants()) do
				if child:IsA("Model") or child:IsA("BasePart") then
					processEggObject(child)
				end
			end
		end
	end

	return targetEggs
end

-- 5. GET MY PLOT POS
local function getMyPlotPosition()
	if homePlotPosition then return homePlotPosition end
	local myName = string.lower(localPlayer.Name)
	local myUserId = tostring(localPlayer.UserId)

	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("Model") or object:IsA("Folder") or object:IsA("BasePart") then
			local ownerVal = object:FindFirstChild("Owner") or object:FindFirstChild("OwnerName") or object:FindFirstChild("Player") or object:FindFirstChild("ClaimedBy") or object:FindFirstChild("UserId")
			if ownerVal then
				local valStr = string.lower(tostring(ownerVal.Value))
				if valStr == myName or ownerVal.Value == localPlayer or valStr == myUserId then
					return object:GetPivot().Position
				end
			end
			local objectName = string.lower(object.Name)
			if string.find(objectName, myName) or string.find(objectName, myUserId) then
				return object:GetPivot().Position
			end
		end
	end

	local character = localPlayer.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		local currentPos = character.HumanoidRootPart.Position
		if (currentPos - Vector3.new(0, 5, 0)).Magnitude > 10 then
			return currentPos
		end
	end

	return Vector3.new(0, 10, 0)
end

-- 6. TWEEN & PICKUP
local function tweenToPosition(targetPosition)
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not rootPart then return nil end

	if currentActiveTween then
		pcall(function() currentActiveTween:Cancel() end)
		currentActiveTween = nil
	end

	local startPosition = rootPart.Position
	local distance = (targetPosition - startPosition).Magnitude
	local tweenTime = math.max(distance / math.max(10, TWEEN_SPEED), 0.05)

	local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local targetCFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0))

	currentActiveTween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
	currentActiveTween:Play()

	return currentActiveTween
end

local function safeWaitTween(tween)
	if not tween then return end
	pcall(function()
		local completed = false
		local conn
		conn = tween.Completed:Connect(function()
			completed = true
			if conn then conn:Disconnect() end
		end)

		local start = os.clock()
		while not completed and (os.clock() - start < 15) do
			if not isRunning or not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then
				tween:Cancel()
				break
			end
			task.wait(0.1)
		end
	end)
end

local function autoPickUpTarget(eggObj, duration)
	local startTime = os.clock()
	while os.clock() - startTime < duration do
		if not isRunning then break end
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
		end
		task.wait(PICKUP_DELAY)
	end
end

-- 7. SERVER HOP & BOOST
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

local function applyPerformanceBoost(enable)
	if enable then
		pcall(function()
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
			game:GetService("Lighting").GlobalShadows = false
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("BasePart") then
					obj.CastShadow = false
				elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
					obj.Enabled = false
				end
			end
		end)
	end
end

local function cleanupAll()
	isRunning = false
	if currentActiveTween then
		pcall(function() currentActiveTween:Cancel() end)
		currentActiveTween = nil
	end
	setNoClip(false)
	disableScreenShake(false)

	local char = localPlayer.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		char.HumanoidRootPart.AssemblyAngularVelocity = Vector3.zero
	end
	collectgarbage("collect")
end

----------------------------------------------------
-- UI INITIALIZATION (FLUENT OR FALLBACK)
----------------------------------------------------
local Window = nil
local mainTab = nil
local settingsTab = nil

if libraryType == "Fluent" and Fluent then
	Window = Fluent:CreateWindow({
		Title = "FluentPro",
		SubTitle = "Mobile Edition",
		TabWidth = 130,
		Size = UDim2.fromOffset(480, 340),
		Acrylic = false,
		Theme = "Amethyst"
	})

	mainTab = Window:AddTab({ Title = "Main", Icon = "egg" })
	settingsTab = Window:AddTab({ Title = "Background", Icon = "image" })

	-- Fluent Dropdowns & Controls
	mainTab:AddDropdown("TargetRarity", {
		Title = "Target Rarity",
		Values = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Ethereal", "All"},
		Default = "Ethereal",
		Callback = function(v) selectedRarity = v end
	})

	mainTab:AddSlider("TweenSpeed", {
		Title = "Tween Speed",
		Default = TWEEN_SPEED, Min = 100, Max = 1000, Rounding = 0,
		Callback = function(v) TWEEN_SPEED = tonumber(v) or 300 end
	})

	mainTab:AddInput("LoopCyclesInput", {
		Title = "Loop Cycles",
		Default = tostring(runCount),
		Numeric = true, Finished = true,
		Callback = function(v)
			local num = tonumber(v)
			runCount = (num and num > 0) and math.min(math.floor(num), 1000) or 5
		end
	})

	mainTab:AddToggle("NoClip", { Title = "Smart Floor-Safe No-Clip", Default = true, Callback = function(v) noClipEnabled = v end })
	mainTab:AddToggle("RemoveShake", { Title = "Remove Screen Shake", Default = true, Callback = function(v) removeShakeEnabled = v; disableScreenShake(v) end })
	mainTab:AddToggle("PerformanceBoost", { Title = "FPS Boost", Default = true, Callback = function(v) performanceBoostEnabled = v; applyPerformanceBoost(v) end })
	mainTab:AddToggle("AutoServerHop", { Title = "Auto Server Hop", Default = false, Callback = function(v) autoServerHopEnabled = v end })

	mainTab:AddToggle("AutoStealEgg", {
		Title = "Auto Steal Egg",
		Default = false,
		Callback = function(v)
			isRunning = v
			if isRunning then
				if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
					homePlotPosition = localPlayer.Character.HumanoidRootPart.Position
				end
				if noClipEnabled then setNoClip(true) end
				if removeShakeEnabled then disableScreenShake(true) end
				if performanceBoostEnabled then applyPerformanceBoost(true) end

				task.spawn(function()
					pcall(function()
						for cycle = 1, runCount do
							if not isRunning then break end
							local activeEggObjects = getActiveEggObjects()
							if #activeEggObjects == 0 then
								if autoServerHopEnabled then task.wait(1); serverHop(); break else task.wait(2) end
							else
								for _, eggObj in ipairs(activeEggObjects) do
									if not isRunning or not eggObj or not eggObj.Parent then continue end
									local eggPos = (eggObj:IsA("Model") and (eggObj.PrimaryPart and eggObj.PrimaryPart.Position or eggObj:GetPivot().Position)) or eggObj.Position
									if eggPos then
										safeWaitTween(tweenToPosition(eggPos))
										if not isRunning then break end
										autoPickUpTarget(eggObj, WAIT_AT_EGG)
										if not isRunning then break end
										safeWaitTween(tweenToPosition(getMyPlotPosition()))
										task.wait(0.5)
									end
								end
							end
						end
					end)
					cleanupAll()
				end)
			else
				cleanupAll()
			end
		end
	})

	Window:SelectTab(1)

else
	-- FALLBACK UI INITIALIZATION
	local Kavo = Fluent
	Window = Kavo.CreateLib("FluentPro (Fallback)", "Midnight")
	mainTab = Window:NewTab("Main"):NewSection("Stealer Controls")

	mainTab:NewDropdown("Target Rarity", "Select Rarity", {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Ethereal", "All"}, function(v) selectedRarity = v end)
	mainTab:NewSlider("Tween Speed", "Speed", 1000, 100, function(v) TWEEN_SPEED = tonumber(v) or 300 end)
	mainTab:NewToggle("Smart Floor No-Clip", "NoClip", function(v) noClipEnabled = v end)
	mainTab:NewToggle("Remove Screen Shake", "Shake", function(v) removeShakeEnabled = v; disableScreenShake(v) end)
	mainTab:NewToggle("FPS Boost", "Boost", function(v) performanceBoostEnabled = v; applyPerformanceBoost(v) end)
	
	mainTab:NewToggle("Auto Steal Egg", "Start Stealing", function(v)
		isRunning = v
		if isRunning then
			if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
				homePlotPosition = localPlayer.Character.HumanoidRootPart.Position
			end
			if noClipEnabled then setNoClip(true) end
			if removeShakeEnabled then disableScreenShake(true) end

			task.spawn(function()
				pcall(function()
					for cycle = 1, runCount do
						if not isRunning then break end
						local activeEggObjects = getActiveEggObjects()
						if #activeEggObjects == 0 then
							if autoServerHopEnabled then task.wait(1); serverHop(); break else task.wait(2) end
						else
							for _, eggObj in ipairs(activeEggObjects) do
								if not isRunning or not eggObj or not eggObj.Parent then continue end
								local eggPos = (eggObj:IsA("Model") and (eggObj.PrimaryPart and eggObj.PrimaryPart.Position or eggObj:GetPivot().Position)) or eggObj.Position
								if eggPos then
									safeWaitTween(tweenToPosition(eggPos))
									if not isRunning then break end
									autoPickUpTarget(eggObj, WAIT_AT_EGG)
									if not isRunning then break end
									safeWaitTween(tweenToPosition(getMyPlotPosition()))
									task.wait(0.5)
								end
							end
						end
					end
				end)
				cleanupAll()
			end)
		else
			cleanupAll()
		end
	end)
end

----------------------------------------------------
-- DRAGGABLE TOGGLE BUTTON FOR UI
----------------------------------------------------
task.spawn(function()
	pcall(function()
		local old = CoreGui:FindFirstChild("MobileFluentToggle")
		if old then old:Destroy() end

		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "MobileFluentToggle"
		screenGui.Parent = CoreGui
		screenGui.ResetOnSpawn = false

		local button = Instance.new("TextButton")
		button.Name = "ToggleButton"
		button.Parent = screenGui
		button.Size = UDim2.new(0, 56, 0, 56)
		button.Position = UDim2.new(0.05, 0, 0.2, 0)
		button.BackgroundColor3 = Color3.fromRGB(35, 15, 50)
		button.BorderSizePixel = 0
		button.Text = "HUB"
		button.TextColor3 = Color3.fromRGB(230, 190, 255)
		button.TextSize = 16
		button.Font = Enum.Font.SourceSansBold
		button.Active = true
		button.Draggable = true

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 28)
		corner.Parent = button

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = Color3.fromRGB(170, 50, 250)
		stroke.Parent = button

		local isVisible = true
		button.MouseButton1Click:Connect(function()
			isVisible = not isVisible
			if libraryType == "Fluent" and Window and Window.Root then
				Window.Root.Visible = isVisible
			else
				pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.RightControl, false, game) end)
			end
		end)
	end)
end)

applyPerformanceBoost(t
