-- BGS Egg Opener - Fixed v8
-- Тайминги синхронизации ровно 30 секунд для всех трёх

local NetworkRemoteEvent = game.ReplicatedStorage.NetworkRemoteEvent
local Services = require(game.ReplicatedStorage.Assets.Modules.Services)
local GuiService = Services:GetService('GuiService')
local ScreenGui = game.Players.LocalPlayer.PlayerGui:WaitForChild('ScreenGui', 10)
local HttpService = game:GetService('HttpService')
local Event = game:GetService('ReplicatedStorage').NetworkRemoteEvent

-- Безопасная обёртка для label:Set
local function safeSet(label, text)
    local ok, err = pcall(function()
        label:Set(text)
    end)
    if not ok then
        task.spawn(function()
            task.wait(0.05)
            pcall(function() label:Set(text) end)
        end)
    end
end

-- Удаляем старые Rayfield GUI
pcall(function()
    if gethui then
        local old = gethui():FindFirstChild('Rayfield')
        if old then old:Destroy() end
    end
    local coreOld = game:GetService('CoreGui'):FindFirstChild('Rayfield')
    if coreOld then coreOld:Destroy() end
end)

local RayfieldSrc = game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua')
RayfieldSrc = RayfieldSrc:gsub('Settings%.ConfigurationSaving%.FileName = tostring%(game%.PlaceId%)', 'Settings.ConfigurationSaving.FileName = tostring(game.JobId)')
local Rayfield = loadstring(RayfieldSrc)()

local CONFIG_FILE = 'BGS_Egg_Opener_Config.json'
local function loadConfig()
    local ok, data = pcall(function() if isfile(CONFIG_FILE) then return HttpService:JSONDecode(readfile(CONFIG_FILE)) end return {} end)
    if ok then return data end return {}
end
local function saveConfig(cfg) pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(cfg)) end) end
local config = loadConfig()

-- Автоматическое уничтожение всплывающих окон Roblox
local CoreGui = game:GetService('CoreGui')
local function autoDestroyRobloxPrompts()
    pcall(function()
        for _, name in ipairs({'RobloxPromptGui','PurchasePromptApp','BulkPurchaseApp','CommercePurchaseApp'}) do
            local obj = CoreGui:FindFirstChild(name)
            if obj then obj:Destroy() end
        end
    end)
end

local Window = Rayfield:CreateWindow({
    Name = 'BGS Egg Opener', Icon = 4483362458, LoadingTitle = 'BGS Project', LoadingSubtitle = 'by maugrqqq',
    Theme = 'Default', DisableRayfieldPrompts = true, DisableBuildWarnings = true,
    ConfigurationSaving = {Enabled = true, FolderName = nil, FileName = 'BGS_Egg_Opener'},
    Discord = {Enabled = false, Invite = '', RememberJoins = true}, KeySystem = false
})
local MainTab = Window:CreateTab('Main', 4483362458)
local EventTab = Window:CreateTab('Events', 4483362458)
local WebhookTab = Window:CreateTab('Webhook', 4483362458)
local TasksTab = Window:CreateTab('Tasks', 4483362458)

local selectedEgg = config.selectedEgg or 'Hacker Egg'
local autoHatchEnabled = config.autoHatchEnabled or false
local tripleHatchEnabled = config.tripleHatchEnabled or false
local webhookEnabled = config.webhookEnabled or false
local webhookURL = config.webhookURL or ''
local eventsEnabled = config.eventsEnabled or false
local autoGroupBenefits = config.autoGroupBenefits or false
local autoSpinToWin = config.autoSpinToWin or false
local autoDailyRewards = config.autoDailyRewards or false

local LocalPlayer = game.Players.LocalPlayer
local Workspace = game:GetService('Workspace')
local RunService = game:GetService('RunService')

local eggsFolder = Workspace:FindFirstChild('Eggs')
local eggList = {}
if eggsFolder then
    for _, child in ipairs(eggsFolder:GetChildren()) do
        if child:IsA('Model') and child.Name:find('Egg') then table.insert(eggList, child.Name) end
    end
end
table.sort(eggList)
if #eggList == 0 then eggList = {'Common Egg','Spotted Egg','Hacker Egg'} end

local groupSeconds = -1
local dailyText = 'Off'
local dailySeconds = -1
local spinSeconds = -1
local lastGroupRefresh = 0
local lastDailyRefresh = 0
local lastSpinRefresh = 0
local SYNC_INTERVAL = 30 -- Единый интервал 30 секунд для всех

local function getCharacter() return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() end
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
        local char = getCharacter() local root = char:FindFirstChild('HumanoidRootPart')
        if not root then return end
        local eggPos = getEggPosition()
        if eggPos then root.CFrame = CFrame.new(eggPos + Vector3.new(0, 10, 0)) end
    end)
end
local function stopTeleportLoop()
    if teleportLoop then teleportLoop:Disconnect() teleportLoop = nil end
end
local function hatchEgg() pcall(function() Event:FireServer('PurchaseEgg', selectedEgg, tripleHatchEnabled) end) end
local function formatTime(seconds)
    local h = math.floor(seconds / 3600) local m = math.floor((seconds % 3600) / 60) local s = math.floor(seconds % 60)
    if h > 0 then return string.format('%dh %dm %ds', h, m, s) end
    return string.format('%dm %ds', m, s)
end

-- Парсинг времени из текста
local function parseTimeFromText(text)
    if not text then return -1 end
    for hours, mins, secs in text:gmatch('(%d+)h%s*(%d+)m%s*(%d+)s') do
        return tonumber(hours) * 3600 + tonumber(mins) * 60 + tonumber(secs)
    end
    for mins, secs in text:gmatch('(%d+)m%s*(%d+)s') do
        return tonumber(mins) * 60 + tonumber(secs)
    end
    return -1
end

-- Чтение Group Benefits
local function readGroupSeconds()
    local deadline = os.clock() + 8
    repeat
        pcall(function() GuiService:ShowGroupBenefits() end)
        wait(0.4)
        local problemFrame = ScreenGui:FindFirstChild('GroupBenefitsProblem')
        if problemFrame then
            for _, d in ipairs(problemFrame:GetDescendants()) do
                if d:IsA('TextLabel') and d.Name == 'Desc' and d.Text ~= '' then
                    local text = d.Text
                    if text:find('Come back in') then
                        local hours = text:match('(%d+)h') or 0
                        local mins = text:match('(%d+)m') or 0
                        local secs = text:match('(%d+)s') or 0
                        local total = tonumber(hours) * 3600 + tonumber(mins) * 60 + tonumber(secs)
                        problemFrame.Visible = false
                        return total
                    end
                end
            end
        end
    until os.clock() >= deadline
    return -1
end

-- Чтение Daily Rewards
local function readDailyText()
    local deadline = os.clock() + 8
    repeat
        pcall(function() GuiService:DisplayFrame('DailyRewards') end)
        wait(0.4)
        local frame = ScreenGui:FindFirstChild('DailyRewards')
        if frame then
            local category, progress, nextReward, claimed = '', '', '', false
            for _, d in ipairs(frame:GetDescendants()) do
                if d:IsA('TextLabel') then
                    if d.Name == 'Category' and d.Text ~= '' then category = d.Text end
                    if d.Text:find('%d+ %/ %d+') then progress = d.Text end
                    if d.Name == 'NextRewardIn' then nextReward = d.Text end
                    if d.Text == 'Claimed reward!' then claimed = true end
                end
            end
            local result = '...'
            if claimed and nextReward ~= '' then
                local timeStr = nextReward:gsub('Next reward in ', '')
                result = 'Next in ' .. timeStr
                dailySeconds = parseTimeFromText(timeStr)
            elseif category ~= '' and progress ~= '' then
                result = category .. ' [' .. progress .. ']'
                dailySeconds = -1
            elseif category ~= '' then
                result = category
                dailySeconds = -1
            end
            pcall(function() GuiService:DisplayFrame('') end)
            return result
        end
    until os.clock() >= deadline
    pcall(function() GuiService:DisplayFrame('') end)
    return '...'
end

-- Чтение Spin To Win - правильный расчёт через os.time()
local function readSpinSeconds()
    local GetHalfDay = function() return math.floor(os.time() / 43200) end
    local secondsLeft = (GetHalfDay() + 1) * 43200 - os.time()
    
    -- Проверяем, есть ли реальное значение в TimeRemaining
    local spinToWin = ScreenGui:FindFirstChild('SpinToWinSpooky')
    if spinToWin then
        local timeRemaining = spinToWin:FindFirstChild('TimeRemaining', true)
        if timeRemaining and timeRemaining:IsA('TextLabel') then
            if not timeRemaining.Visible then
                return 0 -- Спин доступен
            end
        end
    end
    
    return math.max(0, secondsLeft)
end

local function canClaimDaily()
    if not dailyText or dailyText == '...' or dailyText == 'Off' then return false end
    if dailyText:find('Next in') then return false end
    local progress = dailyText:match('%[(.-)%]')
    if not progress then return false end
    local currentStr = progress:match('([%d,]+)')
    local targetStr = progress:match('/(%s*[%d,]+)')
    if not currentStr or not targetStr then return false end
    local current = tonumber(currentStr:gsub(',', '')) or 0
    local target = tonumber(targetStr:gsub(',', '')) or 0
    return current >= target
end
local function collectGroupReward()
    pcall(function() Event:FireServer('CollectGroupReward') end)
    wait(0.5)
    groupSeconds = readGroupSeconds()
    lastGroupRefresh = os.clock()
end
local function spinToWin() pcall(function() Event:FireServer('SpinToWin') end) end
local function claimDaily()
    pcall(function() Event:FireServer('ClaimDailyReward') end)
    wait(0.5)
    dailyText = readDailyText()
    lastDailyRefresh = os.clock()
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
    saveConfig({selectedEgg=selectedEgg, autoHatchEnabled=autoHatchEnabled, tripleHatchEnabled=tripleHatchEnabled,
        webhookEnabled=webhookEnabled, webhookURL=webhookURL, eventsEnabled=eventsEnabled,
        autoGroupBenefits=autoGroupBenefits, autoSpinToWin=autoSpinToWin, autoDailyRewards=autoDailyRewards})
end

NetworkRemoteEvent.OnClientEvent:Connect(function(eventName, ...)
    if eventName == 'DisplayLegendaryInChat' then
        local args = {...}
        if webhookEnabled and webhookURL ~= '' then sendWebhook(args[1] .. ' hatched a Legendary ' .. args[2]) end
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
TasksTab:CreateParagraph({Title='Tasks', Content='Auto tasks'})

-- Auto Group Benefits
TasksTab:CreateToggle({Name='Auto Group Benefits', CurrentValue=autoGroupBenefits, Callback=function(v)
    autoGroupBenefits = v
    saveCurrent()
    if v then
        safeSet(GroupLabel, 'Loading...')
        task.spawn(function()
            groupSeconds = readGroupSeconds()
            lastGroupRefresh = os.clock()
            if groupSeconds > 0 then
                safeSet(GroupLabel, 'Next in ' .. formatTime(groupSeconds))
            elseif groupSeconds == 0 then
                safeSet(GroupLabel, 'Ready')
            else
                safeSet(GroupLabel, 'Loading...')
            end
        end)
    else
        safeSet(GroupLabel, 'Off')
    end
end})
local GroupLabel = TasksTab:CreateLabel('Off')

-- Auto Spin To Win
TasksTab:CreateToggle({Name='Auto Spin To Win', CurrentValue=autoSpinToWin, Callback=function(v)
    autoSpinToWin = v
    saveCurrent()
    if v then
        safeSet(SpinLabel, 'Loading...')
        task.spawn(function()
            spinSeconds = readSpinSeconds()
            lastSpinRefresh = os.clock()
            if spinSeconds > 0 then
                safeSet(SpinLabel, 'Next in ' .. formatTime(spinSeconds))
            elseif spinSeconds == 0 then
                safeSet(SpinLabel, 'Ready')
            else
                safeSet(SpinLabel, 'Loading...')
            end
        end)
    else
        safeSet(SpinLabel, 'Off')
    end
end})
local SpinLabel = TasksTab:CreateLabel('Off')

-- Auto Daily Rewards
TasksTab:CreateToggle({Name='Auto Daily Rewards', CurrentValue=autoDailyRewards, Callback=function(v)
    autoDailyRewards = v
    saveCurrent()
    if v then
        safeSet(DailyLabel, 'Loading...')
        task.spawn(function()
            dailyText = readDailyText()
            lastDailyRefresh = os.clock()
            safeSet(DailyLabel, dailyText)
        end)
    else
        safeSet(DailyLabel, 'Off')
    end
end})
local DailyLabel = TasksTab:CreateLabel('Off')

if autoHatchEnabled then startTeleportLoop() end
if eventsEnabled then enableEvents() end

-- Начальная загрузка только если тумблеры включены
if autoGroupBenefits then
    safeSet(GroupLabel, 'Loading...')
    task.spawn(function()
        groupSeconds = readGroupSeconds()
        lastGroupRefresh = os.clock()
        if groupSeconds > 0 then
            safeSet(GroupLabel, 'Next in ' .. formatTime(groupSeconds))
        elseif groupSeconds == 0 then
            safeSet(GroupLabel, 'Ready')
        else
            safeSet(GroupLabel, 'Loading...')
        end
    end)
end
if autoSpinToWin then
    safeSet(SpinLabel, 'Loading...')
    task.spawn(function()
        spinSeconds = readSpinSeconds()
        lastSpinRefresh = os.clock()
        if spinSeconds > 0 then
            safeSet(SpinLabel, 'Next in ' .. formatTime(spinSeconds))
        elseif spinSeconds == 0 then
            safeSet(SpinLabel, 'Ready')
        else
            safeSet(SpinLabel, 'Loading...')
        end
    end)
end
if autoDailyRewards then
    safeSet(DailyLabel, 'Loading...')
    task.spawn(function()
        dailyText = readDailyText()
        lastDailyRefresh = os.clock()
        safeSet(DailyLabel, dailyText)
    end)
end

local lastTick = os.clock()
while true do
    autoDestroyRobloxPrompts()
    local now = os.clock()
    local delta = now - lastTick
    lastTick = now

    -- Искусственный таймер для group
    if autoGroupBenefits then
        if groupSeconds > 0 then
            groupSeconds = math.max(0, groupSeconds - delta)
            if groupSeconds <= 0 then
                safeSet(GroupLabel, 'Ready')
                collectGroupReward()
            else
                safeSet(GroupLabel, 'Next in ' .. formatTime(groupSeconds))
            end
        elseif groupSeconds == 0 then
            safeSet(GroupLabel, 'Ready')
        end
    end

    -- Искусственный таймер для spin
    if autoSpinToWin then
        if spinSeconds > 0 then
            spinSeconds = math.max(0, spinSeconds - delta)
            if spinSeconds <= 0 then
                safeSet(SpinLabel, 'Ready')
                spinToWin()
            else
                safeSet(SpinLabel, 'Next in ' .. formatTime(spinSeconds))
            end
        elseif spinSeconds == 0 then
            safeSet(SpinLabel, 'Ready')
        end
    end

    -- Искусственный таймер для daily
    if autoDailyRewards then
        if dailySeconds > 0 then
            dailySeconds = math.max(0, dailySeconds - delta)
            if dailySeconds <= 0 then
                dailyText = 'Ready'
                safeSet(DailyLabel, dailyText)
            else
                dailyText = 'Next in ' .. formatTime(dailySeconds)
                safeSet(DailyLabel, dailyText)
            end
        end
    end

    -- Реальная синхронизация всех трёх раз в 30 секунд
    if now - lastGroupRefresh >= SYNC_INTERVAL then
        if autoGroupBenefits then
            task.spawn(function()
                groupSeconds = readGroupSeconds()
                lastGroupRefresh = os.clock()
                if groupSeconds > 0 then safeSet(GroupLabel, 'Next in ' .. formatTime(groupSeconds)) end
            end)
        end
    end

    if now - lastSpinRefresh >= SYNC_INTERVAL then
        if autoSpinToWin then
            task.spawn(function()
                spinSeconds = readSpinSeconds()
                lastSpinRefresh = os.clock()
                if spinSeconds > 0 then safeSet(SpinLabel, 'Next in ' .. formatTime(spinSeconds)) end
            end)
        end
    end

    if now - lastDailyRefresh >= SYNC_INTERVAL then
        if autoDailyRewards then
            task.spawn(function()
                dailyText = readDailyText()
                lastDailyRefresh = os.clock()
                safeSet(DailyLabel, dailyText)
            end)
        end
    end

    if autoDailyRewards and canClaimDaily() then
        claimDaily()
    end

    if autoHatchEnabled then hatchEgg() end

    wait(0.2)
end