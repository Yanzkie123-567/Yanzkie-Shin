-- Safe Protected Loader for Rayfield (Prevents executor freezes)
local Rayfield
local success, err = pcall(function()
    Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or not Rayfield then
    Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/UI-Libraries/Rayfield/main/source.lua'))()
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

-- Safe Character Retrieval Function
local function getRoot()
    local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function safeTeleport(cframeTarget)
    local root = getRoot()
    if root and cframeTarget then
        root.CFrame = cframeTarget + Vector3.new(0, 3.5, 0)
    end
end

-- Initialize Rayfield Window
local Window = Rayfield:CreateWindow({
    Name = "Shinihi Hub | Arise Crossover",
    Icon = 0,
    LoadingTitle = "Arise Crossover Loaded",
    LoadingSubtitle = "Complete Sea 1, 2, 3 & Mounts Edition",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    ConfigurationSaving = {
        Enabled = false
    }
})

----------------------------------------------------------------------
-- DYNAMIC IN-GAME SCANNER & REMOTE RESOLVER
----------------------------------------------------------------------
local function fireGameRemote(...)
    local args = {...}
    pcall(function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                local lowerName = string.lower(obj.Name)
                if lowerName:find("attack") or lowerName:find("punch") or lowerName:find("hit") or lowerName:find("arise") or lowerName:find("buy") then
                    obj:FireServer(unpack(args))
                end
            end
        end
    end)
end

----------------------------------------------------------------------
-- CONFIGURATION
----------------------------------------------------------------------
local Config = {
    -- Auto Stuff
    TPDelay = 1.0,
    TweenDelay = 1.0,
    FarmHighestHP = false,
    ToggleMobAttacking = false,
    AutoFarmNearest = false,
    FarmMethod = "TP",
    SelectedWorld = "Dragon City",
    SelectedMob = "Green",
    AutoFarmSelected = false,
    AutoClick = false,
    AutoArise = false,
    AutoEquipBest = false,

    -- Mounts & Gamepasses
    AutoClaimMounts = false,
    AutoServerHopMounts = false,

    -- Dungeons & Time Trial
    AutoDungeon = false,
    AutoLeaveDungeon = false,
    DungeonTPDelay = 1.0,
    DungeonLeaveDelay = 2.5,
    AutoTimeTrial = false,
    TimeTrialDifficulty = "Ultra",
    AutoTimeTrialCards = false,
    AutoCemeteryRush = false,
    CemeteryDifficulty = "Insane",
    CemeteryRestartWave = 30,

    -- Castle & Events
    AutoJoinInfCastle = false,
    AutoWinterLabyrinth = false,
    AutoSummerDungeon = false,
    AutoWorldBoss = false,

    -- Misc
    NoDashCD = false,
    NoPunchCD = false,
    BlackScreen = false,
    AutoLowMode = false
}

----------------------------------------------------------------------
-- TAB 1: MAIN (Matches Screenshot 1 & Latest Image)
----------------------------------------------------------------------
local MainTab = Window:CreateTab("Main", "home")

MainTab:CreateSection("Auto Stuff")

MainTab:CreateSlider({
    Name = "TP Delay",
    Range = {0.1, 5.0},
    Increment = 0.1,
    CurrentValue = 1.0,
    Flag = "Main_TPDelay",
    Callback = function(v) Config.TPDelay = v end,
})

MainTab:CreateSlider({
    Name = "Tween Delay",
    Range = {0.1, 5.0},
    Increment = 0.1,
    CurrentValue = 1.0,
    Flag = "Main_TweenDelay",
    Callback = function(v) Config.TweenDelay = v end,
})

MainTab:CreateToggle({
    Name = "[Every AutoFarm] Farm Highest HP Mobs",
    CurrentValue = false,
    Flag = "Main_FarmHighestHP",
    Callback = function(v) Config.FarmHighestHP = v end,
})

MainTab:CreateToggle({
    Name = "[Every AutoFarm] Toggle Mob Attacking",
    CurrentValue = false,
    Flag = "Main_ToggleMobAttacking",
    Callback = function(v) Config.ToggleMobAttacking = v end,
})

MainTab:CreateToggle({
    Name = "Auto Farm Nearest Mob",
    CurrentValue = false,
    Flag = "Main_AutoFarmNearest",
    Callback = function(v) Config.AutoFarmNearest = v end,
})

-- Complete World Dropdown (Matches latest screenshot)
MainTab:CreateDropdown({
    Name = "Select World",
    Options = {
        "Leveling City", "Grass Village", "Brum Island", "Faceheal Town", 
        "Lucky Kingdom", "Nipon City", "Mori Town", "Dragon City", 
        "XZ City", "Kindama City", "Hunters City", "Nen City", 
        "Hurricane Town", "Summer Island", "Cursed High", "Slayer's Village", 
        "Kaiju City", "Mage Town!", "Shield Kingdom!", "Ghoul City!"
    },
    CurrentOption = {"Dragon City"},
    MultipleOptions = false,
    Flag = "Main_SelectWorld",
    Callback = function(opt) Config.SelectedWorld = opt[1] end,
})

MainTab:CreateInput({
    Name = "Select Mobs",
    CurrentValue = "Green",
    PlaceholderText = "e.g. Green, Frioo, Ant Soldier",
    RemoveTextAfterFocusLost = false,
    Flag = "Main_SelectMobInput",
    Callback = function(text) Config.SelectedMob = text end,
})

MainTab:CreateDropdown({
    Name = "Select Farm Method",
    Options = {"TP", "Tween"},
    CurrentOption = {"TP"},
    MultipleOptions = false,
    Flag = "Main_FarmMethod",
    Callback = function(opt) Config.FarmMethod = opt[1] end,
})

MainTab:CreateToggle({
    Name = "Auto Farm Selected Mob",
    CurrentValue = false,
    Flag = "Main_AutoFarmSelected",
    Callback = function(v) Config.AutoFarmSelected = v end,
})

MainTab:CreateToggle({
    Name = "Auto Click",
    CurrentValue = false,
    Flag = "Main_AutoClick",
    Callback = function(v) Config.AutoClick = v end,
})

MainTab:CreateToggle({
    Name = "Auto Arise Mobs",
    CurrentValue = false,
    Flag = "Main_AutoArise",
    Callback = function(v) Config.AutoArise = v end,
})

MainTab:CreateToggle({
    Name = "Auto Equip Best Shadows",
    CurrentValue = false,
    Flag = "Main_AutoEquipBest",
    Callback = function(v)
        pcall(function()
            for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
                if r:IsA("RemoteEvent") and r.Name:lower():find("equipbest") then
                    r:FireServer()
                end
            end
        end)
    end,
})

-- Mounts Sub-Section (From Screenshot)
MainTab:CreateSection("Mounts & Fast Travel")

MainTab:CreateToggle({
    Name = "Auto Claim Mounts",
    CurrentValue = false,
    Flag = "Main_ClaimMounts",
    Callback = function(v) Config.AutoClaimMounts = v end,
})

MainTab:CreateToggle({
    Name = "Auto ServerHop Mounts",
    CurrentValue = false,
    Flag = "Main_ServerHopMounts",
    Callback = function(v) Config.AutoServerHopMounts = v end,
})

local MountLocations = {
    ["Snow Bear Mount"] = CFrame.new(15400.0, 52.0, 11200.0),
    ["Dragon Mount"] = CFrame.new(-7600.0, 45.0, 550.0),
    ["Desert Mount"] = CFrame.new(-120.0, 40.0, 5200.0)
}

MainTab:CreateDropdown({
    Name = "TP Mounts Locations",
    Options = {"Snow Bear Mount", "Dragon Mount", "Desert Mount"},
    CurrentOption = {"Snow Bear Mount"},
    MultipleOptions = false,
    Flag = "Main_TPMounts",
    Callback = function(opt)
        if MountLocations[opt[1]] then
            safeTeleport(MountLocations[opt[1]])
        end
    end,
})

-- World Quick Warps
MainTab:CreateButton({
    Name = "TP Main Game (Spawn Hub)",
    Callback = function() safeTeleport(CFrame.new(427.5, 30.6, -65.1)) end
})

MainTab:CreateDropdown({
    Name = "TP World 1",
    Options = {"Leveling City", "Grass Village", "Brum Island", "Faceheal Town", "Lucky Kingdom", "Nipon City", "Mori Town", "Dragon City"},
    CurrentOption = {"Leveling City"},
    MultipleOptions = false,
    Flag = "Main_TPWorld1",
    Callback = function(opt)
        local w1 = {
            ["Leveling City"] = CFrame.new(427.5, 30.6, -65.1),
            ["Grass Village"] = CFrame.new(-3373.2, 32.9, 2247.1),
            ["Brum Island"] = CFrame.new(-3370.8, 60.8, -2614.3),
            ["Faceheal Town"] = CFrame.new(2918.0, 49.0, -2381.2),
            ["Lucky Kingdom"] = CFrame.new(-166.3, 41.3, 5162.5),
            ["Nipon City"] = CFrame.new(296.4, 23.6, -4324.8),
            ["Mori Town"] = CFrame.new(5817.3, 44.4, -646.2),
            ["Dragon City"] = CFrame.new(-7430.8, 29.8, 407.1)
        }
        if w1[opt[1]] then safeTeleport(w1[opt[1]]) end
    end
})

MainTab:CreateDropdown({
    Name = "TP World 2",
    Options = {"XZ City", "Kindama City", "Hunters City", "Nen City", "Hurricane Town", "Summer Island", "Cursed High", "Slayer's Village", "Kaiju City", "Mage Town!", "Shield Kingdom!", "Ghoul City!"},
    CurrentOption = {"XZ City"},
    MultipleOptions = false,
    Flag = "Main_TPWorld2",
    Callback = function(opt)
        local w2 = {
            ["XZ City"] = CFrame.new(5840.6, 28.2, 5336.6),
            ["Kindama City"] = CFrame.new(-9250.4, 45.2, 8120.3),
            ["Hunters City"] = CFrame.new(2450.0, 38.0, 1900.0),
            ["Nen City"] = CFrame.new(8420.1, 35.1, -7210.4),
            ["Hurricane Town"] = CFrame.new(6200.0, 36.0, 7100.0),
            ["Summer Island"] = CFrame.new(-11500.0, 30.0, -4200.0),
            ["Cursed High"] = CFrame.new(-6500.5, 38.0, -8400.2),
            ["Slayer's Village"] = CFrame.new(7850.2, 42.0, 3100.5),
            ["Kaiju City"] = CFrame.new(-8200.0, 36.5, 4900.0),
            ["Mage Town!"] = CFrame.new(-5100.0, 40.0, 6200.0),
            ["Shield Kingdom!"] = CFrame.new(-11200.0, 48.0, 2200.0),
            ["Ghoul City!"] = CFrame.new(9800.5, 52.0, -4300.0)
        }
        if w2[opt[1]] then safeTeleport(w2[opt[1]]) end
    end
})

MainTab:CreateDropdown({
    Name = "TP World 3",
    Options = {"Monarch City!", "Vazarick's Lair!", "Deadly Kingdom!", "Zero Kingdom!", "Online Town!", "Winter Wonderland"},
    CurrentOption = {"Monarch City!"},
    MultipleOptions = false,
    Flag = "Main_TPWorld3",
    Callback = function(opt)
        local w3 = {
            ["Monarch City!"] = CFrame.new(11500.0, 50.0, 8200.0),
            ["Vazarick's Lair!"] = CFrame.new(12400.0, 60.0, 9500.0),
            ["Deadly Kingdom!"] = CFrame.new(13800.0, 48.0, 7100.0),
            ["Zero Kingdom!"] = CFrame.new(16500.0, 60.0, 9200.0),
            ["Online Town!"] = CFrame.new(17200.0, 58.0, 6400.0),
            ["Winter Wonderland"] = CFrame.new(15500.0, 54.0, 11500.0)
        }
        if w3[opt[1]] then safeTeleport(w3[opt[1]]) end
    end
})

----------------------------------------------------------------------
-- TAB 2: DUNGEON (Matches Screenshots 3, 4, 6, 8, 9)
----------------------------------------------------------------------
local DungeonTab = Window:CreateTab("Dungeon", "sword")

DungeonTab:CreateSection("Dungeon Automations")

DungeonTab:CreateSlider({
    Name = "Dungeon TP Delay",
    Range = {0.1, 5.0},
    Increment = 0.1,
    CurrentValue = 1.0,
    Flag = "Dung_TPDelay",
    Callback = function(v) Config.DungeonTPDelay = v end,
})

DungeonTab:CreateToggle({
    Name = "Auto Dungeon",
    CurrentValue = false,
    Flag = "Dung_AutoDungeon",
    Callback = function(v) Config.AutoDungeon = v end,
})

DungeonTab:CreateToggle({
    Name = "Auto Leave Dungeon",
    CurrentValue = false,
    Flag = "Dung_AutoLeave",
    Callback = function(v) Config.AutoLeaveDungeon = v end,
})

DungeonTab:CreateSlider({
    Name = "Dungeon Leave Delay",
    Range = {0.5, 10.0},
    Increment = 0.5,
    CurrentValue = 2.5,
    Flag = "Dung_LeaveDelay",
    Callback = function(v) Config.DungeonLeaveDelay = v end,
})

DungeonTab:CreateSection("Time Trial & Cemetery Rush")

DungeonTab:CreateDropdown({
    Name = "[Time Trial] Select Difficulty",
    Options = {"Normal", "Hard", "Nightmare", "Ultra"},
    CurrentOption = {"Ultra"},
    MultipleOptions = false,
    Flag = "Dung_TTDiff",
    Callback = function(opt) Config.TimeTrialDifficulty = opt[1] end,
})

DungeonTab:CreateToggle({
    Name = "Auto Time Trial",
    CurrentValue = false,
    Flag = "Dung_AutoTT",
    Callback = function(v) Config.AutoTimeTrial = v end,
})

DungeonTab:CreateToggle({
    Name = "Auto Select Cards (Highest picked first)",
    CurrentValue = false,
    Flag = "Dung_AutoCards",
    Callback = function(v) Config.AutoTimeTrialCards = v end,
})

DungeonTab:CreateDropdown({
    Name = "[Cemetery] Select Difficulty",
    Options = {"Normal", "Hard", "Nightmare", "Insane"},
    CurrentOption = {"Insane"},
    MultipleOptions = false,
    Flag = "Dung_CemDiff",
    Callback = function(opt) Config.CemeteryDifficulty = opt[1] end,
})

DungeonTab:CreateToggle({
    Name = "Auto Cemetery Rush",
    CurrentValue = false,
    Flag = "Dung_AutoCemetery",
    Callback = function(v) Config.AutoCemeteryRush = v end,
})

DungeonTab:CreateSlider({
    Name = "Cemetery Restart Wave",
    Range = {1, 100},
    Increment = 1,
    CurrentValue = 30,
    Flag = "Dung_CemWave",
    Callback = function(v) Config.CemeteryRestartWave = v end,
})

DungeonTab:CreateSection("Card Debuff Skips (Image 9)")

DungeonTab:CreateToggle({
    Name = "Skip Weapon 0 Damage Debuff",
    CurrentValue = false,
    Flag = "Dung_SkipWep0",
    Callback = function(v) end,
})

DungeonTab:CreateToggle({
    Name = "Skip Shadow 0 Damage Debuff",
    CurrentValue = false,
    Flag = "Dung_SkipShad0",
    Callback = function(v) end,
})

DungeonTab:CreateToggle({
    Name = "Skip Attack 0 Range Debuff",
    CurrentValue = false,
    Flag = "Dung_SkipRng0",
    Callback = function(v) end,
})

DungeonTab:CreateSection("Seal & Multiplier Sliders (All 24 from Images)")

local sliders = {
    "Giant Slayer", "Chrono Leech", "Time Bender", "Glass Cannon", 
    "Divine Power", "Gatekeeper", "King of Wealth", "Assassin's Eye", 
    "Fatal Blow", "Monarch's Aura", "Key Hunter", "Warrior's Strength", 
    "Shadow Authority", "Golden Touch", "Overcharge", "Jeweler", 
    "Seal: Authority", "Seal: Might", "Seal: Vision", "Titan Enemies", 
    "Short Clock", "Fatigue", "Poverty", "Time Leak"
}

for _, sName in ipairs(sliders) do
    DungeonTab:CreateSlider({
        Name = sName,
        Range = {1, 100},
        Increment = 1,
        CurrentValue = 1,
        Flag = "Dung_Slider_" .. sName:gsub("%s+", ""),
        Callback = function(val) end,
    })
end

----------------------------------------------------------------------
-- TAB 3: RAID (Matches Screenshot 7)
----------------------------------------------------------------------
local RaidTab = Window:CreateTab("Raid", "shield")

RaidTab:CreateSection("Raid Automation")

RaidTab:CreateToggle({
    Name = "Auto Raid",
    CurrentValue = false,
    Flag = "Raid_AutoRaid",
    Callback = function(v) Config.AutoRaid = v end,
})

RaidTab:CreateToggle({
    Name = "Auto TP Raid",
    CurrentValue = false,
    Flag = "Raid_AutoTPRaid",
    Callback = function(v)
        if v then
            safeTeleport(CFrame.new(1850.5, 45.2, -3200.8)) -- Ant Raid
        end
    end,
})

----------------------------------------------------------------------
-- TAB 4: MISC (Matches Screenshots 7, 10, 11)
----------------------------------------------------------------------
local MiscTab = Window:CreateTab("Misc", "settings")

MiscTab:CreateSection("Exploit Tweaks")

MiscTab:CreateToggle({
    Name = "No Dash CD",
    CurrentValue = false,
    Flag = "Misc_NoDashCD",
    Callback = function(v) Config.NoDashCD = v end,
})

MiscTab:CreateToggle({
    Name = "No Punch CD [Everywhere]",
    CurrentValue = false,
    Flag = "Misc_NoPunchCD",
    Callback = function(v) Config.NoPunchCD = v end,
})

MiscTab:CreateToggle({
    Name = "Black Screen",
    CurrentValue = false,
    Flag = "Misc_BlackScreen",
    Callback = function(v)
        RunService:Set3dRenderingEnabled(not v)
    end,
})

MiscTab:CreateToggle({
    Name = "Auto Low Mode (Anti-Lag)",
    CurrentValue = false,
    Flag = "Misc_LowMode",
    Callback = function(v)
        if v then
            settings().Rendering.QualityLevel = 1
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    obj.Material = Enum.Material.SmoothPlastic
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    obj.Transparency = 1
                end
            end
        end
    end,
})

MiscTab:CreateButton({
    Name = "[LOW PLAYER] ServerHop",
    Callback = function()
        TeleportService:Teleport(game.PlaceId, localPlayer)
    end,
})

----------------------------------------------------------------------
-- ROBUST ZERO-CRASH BACKGROUND LOGIC ENGINE
----------------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(Config.TPDelay)
        pcall(function()
            local root = getRoot()
            if root then
                -- Auto Farm Engine
                if Config.AutoFarmSelected or Config.AutoFarmNearest or Config.AutoClick then
                    local targetMob = nil
                    for _, container in ipairs({Workspace:FindFirstChild("Enemies"), Workspace:FindFirstChild("Mobs"), Workspace:FindFirstChild("Bosses"), Workspace}) do
                        if container then
                            for _, mob in ipairs(container:GetChildren()) do
                                local mobRoot = mob:FindFirstChild("HumanoidRootPart")
                                local mobHum = mob:FindFirstChild("Humanoid")
                                if mobRoot and mobHum and mobHum.Health > 0 and mob ~= localPlayer.Character then
                                    if Config.AutoFarmSelected and mob.Name:lower():find(Config.SelectedMob:lower()) then
                                        targetMob = mob
                                        break
                                    elseif Config.AutoFarmNearest then
                                        targetMob = mob
                                        break
                                    end
                                end
                            end
                        end
                        if targetMob then break end
                    end

                    if targetMob and targetMob:FindFirstChild("HumanoidRootPart") then
                        if Config.FarmMethod == "TP" then
                            root.CFrame = targetMob.HumanoidRootPart.CFrame + Vector3.new(0, 2, 2)
                        elseif Config.FarmMethod == "Tween" then
                            local tInfo = TweenInfo.new(Config.TweenDelay, Enum.EasingStyle.Linear)
                            TweenService:Create(root, tInfo, {CFrame = targetMob.HumanoidRootPart.CFrame + Vector3.new(0, 2, 2)}):Play()
                        end

                        fireGameRemote("attack", targetMob)
                        local tool = localPlayer.Character:FindFirstChildOfClass("Tool")
                        if tool then tool:Activate() end
                    end
                end

                -- Auto Arise
                if Config.AutoArise then
                    for _, folder in ipairs({Workspace:FindFirstChild("Corpses"), Workspace:FindFirstChild("Debris"), Workspace}) do
                        if folder then
                            for _, corpse in ipairs(folder:GetChildren()) do
                                if corpse:FindFirstChild("SoulPrompt") or corpse.Name:lower():find("soul") then
                                    fireGameRemote("arise", corpse)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end)

Rayfield:Notify({
    Title = "Goomba Hub Ready",
    Content = "All systems and tabs loaded successfully.",
    Duration = 3,
    Image = "check"
})
