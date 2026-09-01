local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/jensonhirst/Orion/main/source'))()

local Window = OrionLib:MakeWindow({
    Name = "BGS Egg Opener",
    HidePremium = false,
    IntroText = "BGS Project",
    SaveConfig = true,
    ConfigFolder = "BGS-Egg-Opener"
})

local Tab = Window:MakeTab({
    Name = "Egg Opener",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

local Section = Tab:AddSection({
    Name = "Egg Selection"
})

local selectedEgg = "Spotted Egg"
local autoHatchEnabled = false

local eggList = {
    "Common Egg",
    "Spotted Egg",
    "Ice Shard Egg",
    "Spikey Egg",
    "Magma Egg",
    "Crystal Egg",
    "Lunar Egg",
    "Void Shard Egg",
    "Nightmare Egg",
    "Hell Egg",
    "Rainbow Egg",
    "New Year Egg",
    "100K Egg",
    "Valentine Egg",
    "Lucky Egg",
    "300m Egg",
    "Snowman Egg",
    "Festive Egg",
    "Globe Egg",
    "Hot Cocoa Egg",
    "Frost Egg",
    "Christmas Egg",
    "Ice Cream Egg",
    "Gummy Egg",
    "Slushy Egg"
}

local dropdown = Section:AddDropdown({
    Name = "Select Egg",
    Default = "Spotted Egg",
    Options = eggList,
    Callback = function(Value)
        selectedEgg = Value
        OrionLib:MakeNotification({
            Name = "Egg Selected",
            Content = "Selected: " .. Value,
            Time = 3
        })
    end
})

local toggle = Section:AddToggle({
    Name = "Auto Hatch Selected Egg",
    Default = false,
    Callback = function(Value)
        autoHatchEnabled = Value
        if Value then
            OrionLib:MakeNotification({
                Name = "Auto Hatch",
                Content = "Enabled - Opening " .. selectedEgg,
                Time = 3
            })
        else
            OrionLib:MakeNotification({
                Name = "Auto Hatch",
                Content = "Disabled",
                Time = 3
            })
        end
    end
})

local function fireRemote(remoteName, ...)
    local args = {...}
    local RemoteEvent = game:GetService("ReplicatedStorage"):FindFirstChild("NetworkRemoteEvent")
    if RemoteEvent then
        RemoteEvent:FireServer(remoteName, unpack(args))
    else
        warn("NetworkRemoteEvent not found")
    end
end

local function openEgg(eggName)
    fireRemote("PurchaseEgg", eggName, false)
    OrionLib:MakeNotification({
        Name = "Opening Egg",
        Content = "Attempting to open: " .. eggName,
        Time = 3
    })
end

Section:AddButton({
    Name = "Open Selected Egg",
    Callback = function()
        openEgg(selectedEgg)
    end
})

local lastRemoteCall = 0
local RemoteEvent = game:GetService("ReplicatedStorage"):FindFirstChild("NetworkRemoteEvent")
if RemoteEvent then
    RemoteEvent.OnClientEvent:Connect(function(remoteName, ...)
        lastRemoteCall = os.time()
    end)
end

task.spawn(function()
    while true do
        if autoHatchEnabled then
            openEgg(selectedEgg)
        end
        wait(1)
    end
end)

OrionLib:Init()
