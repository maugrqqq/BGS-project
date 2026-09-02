local Services = require(game.ReplicatedStorage.Assets.Modules.Services)
local GuiService = Services:GetService('GuiService')
local ScreenGui = game.Players.LocalPlayer.PlayerGui:WaitForChild('ScreenGui', 10)
local HttpService = game:GetService('HttpService')
local Event = game:GetService('ReplicatedStorage').NetworkRemoteEvent

-- Простой GUI для таймеров
local StatusGui = Instance.new('ScreenGui')
StatusGui.Name = 'BGSTimers'
StatusGui.ResetOnSpawn = false
StatusGui.Parent = game.Players.LocalPlayer.PlayerGui

local Frame = Instance.new('Frame')
Frame.Size = UDim2.new(0, 300, 0, 80)
Frame.Position = UDim2.new(1, -310, 0, 10)
Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Frame.BackgroundTransparency = 0.2
Frame.BorderSizePixel = 0
Frame.Parent = StatusGui

local GroupLabel = Instance.new('TextLabel')
GroupLabel.Size = UDim2.new(1, -10, 0.5, 0)
GroupLabel.Position = UDim2.new(0, 5, 0, 5)
GroupLabel.BackgroundTransparency = 1
GroupLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
GroupLabel.TextSize = 14
GroupLabel.Font = Enum.Font.GothamBold
GroupLabel.TextXAlignment = Enum.TextXAlignment.Left
GroupLabel.Text = 'Group: Loading...'
GroupLabel.Parent = Frame

local DailyLabel = Instance.new('TextLabel')
DailyLabel.Size = UDim2.new(1, -10, 0.5, 0)
DailyLabel.Position = UDim2.new(0, 5, 0.5, 0)
DailyLabel.BackgroundTransparency = 1
DailyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
DailyLabel.TextSize = 13
DailyLabel.Font = Enum.Font.Gotham
DailyLabel.TextXAlignment = Enum.TextXAlignment.Left
DailyLabel.TextWrapped = true
DailyLabel.Text = 'Daily: Loading...'
DailyLabel.Parent = Frame

local groupSeconds = -1
local lastGroupRefresh = 0
local dailyText = 'Loading...'
local lastDailyRefresh = 0

local function formatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then return string.format('%dh %dm %ds', h, m, s) end
    return string.format('%dm %ds', m, s)
end

local function readGroupSeconds()
    local deadline = os.clock() + 8
    repeat
        pcall(function() GuiService:ShowGroupBenefits() end)
        wait(0.5)
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

local function readDailyText()
    local deadline = os.clock() + 8
    repeat
        pcall(function() GuiService:DisplayFrame('DailyRewards') end)
        wait(0.5)
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
            if claimed and nextReward ~= '' then result = 'Done! Next in ' .. nextReward:gsub('Next reward in ', '')
            elseif category ~= '' and progress ~= '' then result = category .. ' [' .. progress .. ']'
            elseif category ~= '' then result = category end
            pcall(function() GuiService:DisplayFrame('') end)
            return result
        end
    until os.clock() >= deadline
    pcall(function() GuiService:DisplayFrame('') end)
    return '...'
end

local function canClaimDaily()
    if not dailyText or dailyText == '...' then return false end
    if dailyText:find('Done!') then return false end
    local progress = dailyText:match('%[(.-)%]')
    if not progress then return false end
    local currentStr = progress:match('([%d,]+)')
    local targetStr = progress:match('/(%s*[%d,]+)')
    if not currentStr or not targetStr then return false end
    local current = tonumber(currentStr:gsub(',', '')) or 0
    local target = tonumber(targetStr:gsub(',', '')) or 0
    return current >= target
end

-- Автозабирание наград
local autoGroupBenefits = true
local autoDailyRewards = true

wait(3)
groupSeconds = readGroupSeconds()
lastGroupRefresh = os.clock()
dailyText = readDailyText()
lastDailyRefresh = os.clock()

if groupSeconds > 0 then GroupLabel.Text = 'Group: ' .. formatTime(groupSeconds)
elseif groupSeconds == 0 then GroupLabel.Text = 'Group: Ready'
else GroupLabel.Text = 'Group: ...' end
DailyLabel.Text = 'Daily: ' .. dailyText

local lastTick = os.clock()
while true do
    local now = os.clock()
    local delta = now - lastTick
    lastTick = now
    
    if groupSeconds > 0 then
        groupSeconds = math.max(0, groupSeconds - delta)
        GroupLabel.Text = 'Group: ' .. formatTime(groupSeconds)
        if groupSeconds <= 0 then
            GroupLabel.Text = 'Group: Ready'
            if autoGroupBenefits then
                Event:FireServer('CollectGroupReward')
                wait(0.5)
                groupSeconds = readGroupSeconds()
                lastGroupRefresh = os.clock()
            end
        end
    else
        GroupLabel.Text = 'Group: Ready'
    end
    
    if now - lastGroupRefresh >= 30 then
        groupSeconds = readGroupSeconds()
        lastGroupRefresh = now
        if groupSeconds > 0 then GroupLabel.Text = 'Group: ' .. formatTime(groupSeconds) end
    end
    
    if now - lastDailyRefresh >= 10 then
        dailyText = readDailyText()
        lastDailyRefresh = now
        DailyLabel.Text = 'Daily: ' .. dailyText
    end
    
    if autoDailyRewards and canClaimDaily() then
        Event:FireServer('ClaimDailyReward')
        wait(0.5)
        dailyText = readDailyText()
        lastDailyRefresh = os.clock()
        DailyLabel.Text = 'Daily: ' .. dailyText
    end
    
    wait(0.2)
end