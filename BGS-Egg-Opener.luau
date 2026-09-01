local NetworkRemoteEvent = game.ReplicatedStorage.NetworkRemoteEvent

local RayfieldSrc = game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua')
RayfieldSrc = RayfieldSrc:gsub('Settings%.ConfigurationSaving%.FileName = tostring%(game%.PlaceId%)', 'Settings.ConfigurationSaving.FileName = tostring(game.JobId)')
local Rayfield = loadstring(RayfieldSrc)()

local CONFIG_FILE = 'BGS_Egg_Opener_Config.json'
local HttpService = game:GetService('HttpService')

local function loadConfig()
    local success, data = pcall(function()
        if isfile(CONFIG_FILE) then return HttpService:JSONDecode(readfile(CONFIG_FILE)) end
        return {}
    end)
    if success then return data end
    return {}
end

local function saveConfig(cfg)
    pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(cfg)) end)
end

local config = loadConfig()

task.spawn(function()
    local CoreGui = game:GetService('CoreGui')
    while true do
        pcall(function()
            for _, name in ipairs({'RobloxPromptGui', 'PurchasePromptApp', 'BulkPurchaseApp', 'CommercePurchaseApp'}) do
                local obj = CoreGui:FindFirstChild(name)
                if obj then obj:Destroy() end
            end
        end)
        wait(0.2)
    end
end)

local Window = Rayfield:CreateWindow({Name='BGS Egg Opener', Icon=4483362458, LoadingTitle='BGS Project', LoadingSubtitle='by maugrqqq', Theme='Default', DisableRayfieldPrompts=true, DisableBuildWarnings=true, ConfigurationSaving={Enabled=true, FolderName=nil, FileName='BGS_Egg_Opener'}, Discord={Enabled=false, Invite='', RememberJoins=true}, KeySystem=false})
local MainTab = Window:CreateTab('Main', 4483362458)
local EventTab = Window:CreateTab('Events', 4483362458)
local WebhookTab = Window:CreateTab('Webhook', 4483362458)

local selectedEgg = config.selectedEgg or 'Hacker Egg'
local autoHatchEnabled = config.autoHatchEnabled or false
local tripleHatchEnabled = config.tripleHatchEnabled or false
local webhookEnabled = config.webhookEnabled or false
local webhookURL = config.webhookURL or ''
local eventsEnabled = config.eventsEnabled or false

local LocalPlayer = game.Players.LocalPlayer
local Workspace = game:GetService('Workspace')
local Event = game:GetService('ReplicatedStorage').NetworkRemoteEvent
local RunService = game:GetService('RunService')

local eggsFolder = Workspace:FindFirstChild('Eggs')
local eggList = {}
if eggsFolder then
    for _, child in ipairs(eggsFolder:GetChildren()) do
        if child:IsA('Model') and child.Name:find('Egg') then table.insert(eggList, child.Name) end
    end
end
table.sort(eggList)
if #eggList == 0 then eggList = {'Common Egg', 'Spotted Egg', 'Hacker Egg'} end

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getEggPosition()
    local eggModel = eggsFolder and eggsFolder:FindFirstChild(selectedEgg)
    if not eggModel then return nil end
    local primary = eggModel.PrimaryPart or eggModel:FindFirstChildWhichIsA('BasePart')
    if not primary then return nil end
    return primary.Position
end

local teleportLoop = nil

local function startTeleportLoop()
    if teleportLoop then return end
    teleportLoop = RunService.RenderStepped:Connect(function()
        local char = getCharacter()
        local root = char:FindFirstChild('HumanoidRootPart')
        if not root then return end
        local eggPos = getEggPosition()
        if eggPos then
            root.CFrame = CFrame.new(eggPos + Vector3.new(0, 10, 0))
        end
    end)
end

local function stopTeleportLoop()
    if teleportLoop then teleportLoop:Disconnect() teleportLoop = nil end
end

local function hatchEgg()
    pcall(function() Event:FireServer('PurchaseEgg', selectedEgg, tripleHatchEnabled) end)
end

local function enableEvents()
    local WeekendEventSchedule = require(game.ReplicatedStorage.Assets.Modules.WeekendEventSchedule)
    WeekendEventSchedule.IsActive = function() return true end
    local Is2xShiny = require(game.ReplicatedStorage.Assets.Modules.Is2xShinyEnabled)
    local Is2xMythic = require(game.ReplicatedStorage.Assets.Modules.Is2xMythicEnabled)
    pcall(function() debug.setupvalue(Is2xShiny, 1, true) end)
    pcall(function() debug.setupvalue(Is2xMythic, 1, true) end)
end

local function disableEvents()
    local WeekendEventSchedule = require(game.ReplicatedStorage.Assets.Modules.WeekendEventSchedule)
    WeekendEventSchedule.IsActive = function() return false end
    local Is2xShiny = require(game.ReplicatedStorage.Assets.Modules.Is2xShinyEnabled)
    local Is2xMythic = require(game.ReplicatedStorage.Assets.Modules.Is2xMythicEnabled)
    pcall(function() debug.setupvalue(Is2xShiny, 1, false) end)
    pcall(function() debug.setupvalue(Is2xMythic, 1, false) end)
end

local function sendWebhook(message)
    if not webhookEnabled or webhookURL == '' then return end
    pcall(function() HttpService:PostAsync(webhookURL, HttpService:JSONEncode({content = message})) end)
end

local function saveCurrent()
    saveConfig({selectedEgg=selectedEgg, autoHatchEnabled=autoHatchEnabled, tripleHatchEnabled=tripleHatchEnabled, webhookEnabled=webhookEnabled, webhookURL=webhookURL, eventsEnabled=eventsEnabled})
end

NetworkRemoteEvent.OnClientEvent:Connect(function(eventName, ...)
    if eventName == 'DisplayLegendaryInChat' then
        local args = {...}
        if webhookEnabled and webhookURL ~= '' then
            sendWebhook(args[1] .. ' hatched a Legendary ' .. args[2])
        end
    end
end)

MainTab:CreateParagraph({Title='Egg Opener', Content='Auto hatch eggs'})
MainTab:CreateDropdown({Name='Select Egg', Options=eggList, CurrentOption={selectedEgg}, Callback=function(opt) selectedEgg = opt[1] saveCurrent() end})
MainTab:CreateToggle({Name='Open Selected Egg', CurrentValue=autoHatchEnabled, Callback=function(v) autoHatchEnabled = v if v then startTeleportLoop() else stopTeleportLoop() end saveCurrent() end})
MainTab:CreateToggle({Name='Triple Hatch', CurrentValue=tripleHatchEnabled, Callback=function(v) tripleHatchEnabled = v saveCurrent() end})

EventTab:CreateParagraph({Title='Events', Content='Activate 2x events'})
EventTab:CreateToggle({Name='Enable Weekend Event', CurrentValue=eventsEnabled, Callback=function(v) eventsEnabled = v if v then enableEvents() else disableEvents() end saveCurrent() end})

WebhookTab:CreateParagraph({Title='Discord Webhook', Content='Send hatched pets to Discord'})
WebhookTab:CreateToggle({Name='Enable Webhook', CurrentValue=webhookEnabled, Callback=function(v) webhookEnabled = v saveCurrent() end})
WebhookTab:CreateInput({Name='Webhook URL', PlaceholderText='https://discord.com/api/webhooks/...', RemoveTextAfterFocusLost=false, Callback=function(text) webhookURL = text saveCurrent() end})

if autoHatchEnabled then startTeleportLoop() end
if eventsEnabled then enableEvents() end

task.spawn(function()
    while true do
        if autoHatchEnabled then hatchEgg() end
        wait(0.5)
    end
end)
