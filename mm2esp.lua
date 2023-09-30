local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
local roles
getgenv().loop = true
-- > Functions <--

function CreateHighlight() -- make any new highlights for new players
	for i, v in pairs(Players:GetChildren()) do
		if v ~= LP and v.Character and not v.Character:FindFirstChild("Highlight") then
			Instance.new("Highlight", v.Character)           
		end
	end
end

function IsAlive(Player) -- Simple sexy function
	for i, v in pairs(roles) do
		if Player.Name == i then
			if not v.Killed and not v.Dead then
				return true
			else
				return true
			end
		end
	end
end


function UpdateHighlights()
    -- Get Current Role Colors (messy)
    for _, v in pairs(Players:GetChildren()) do
        if v == LP or not v.Character then
            continue
        end
        local Highlight = v.Character:FindFirstChild("Highlight")
        if not Highlight then
            Highlight = Instance.new("Highlight", v.Character)
        end
        
        if v.Name == Sheriff and IsAlive(v) then
            Highlight.FillColor = Color3.fromRGB(0, 0, 225)
        elseif v.Name == Murder and IsAlive(v) then
            Highlight.FillColor = Color3.fromRGB(225, 0, 0)
        elseif v.Name == Hero and IsAlive(v) and not IsAlive(game.Players[Sheriff]) then
            Highlight.FillColor = Color3.fromRGB(255, 250, 0)
        else
            Highlight.FillColor = Color3.fromRGB(0, 225, 0)
        end
    end
end	



getgenv().SecureMode = true
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source'))()

local Window = Rayfield:CreateWindow({
   Name = "MM2 ESP",
   LoadingTitle = "Murder Mystery 2 ESP",
   LoadingSubtitle = "by !Spl||HasH!",
   ConfigurationSaving = {
      Enabled = false,
      FolderName = nil, -- Create a custom folder for your hub/game
      FileName = "..."
   },
   Discord = {
      Enabled = false,
      Invite = "noinvitelink", -- The Discord invite code, do not include discord.gg/. E.g. discord.gg/ABCD would be ABCD.
      RememberJoins = true -- Set this to false to make them join the discord every time they load it up
   },
   KeySystem = false, -- Set this to true to use our key system
   KeySettings = {
      Title = "Sirius Hub",
      Subtitle = "Key System",
      Note = "Join the discord (discord.gg/sirius)",
      FileName = "SiriusKey",
      SaveKey = true,
      GrabKeyFromSite = false, -- If this is true, set Key below to the RAW site you would like Rayfield to get the key from
      Key = "Hello"
   }
})

local Tab = Window:CreateTab("Main", 4483362458)

local Section = Tab:CreateSection("ESP")

local Toggle = Tab:CreateToggle({
   Name = "Enable",
   CurrentValue = false,
   Flag = "Toggle1",
   Callback = function(Value)
   if Value then
   loop = true
   while loop do
	roles = ReplicatedStorage:FindFirstChild("GetPlayerData", true):InvokeServer()
	for i, v in pairs(roles) do
		if v.Role == "Murderer" then
			Murder = i
		elseif v.Role == 'Sheriff'then
			Sheriff = i
		elseif v.Role == 'Hero'then
			Hero = i
		end
	end
	CreateHighlight()
	UpdateHighlights()
   end
   elseif not Value then
   loop = false
   end
   end,
})

Rayfield:Notify({
   Title = "Executed",
   Content = "Script Succesfully Executed",
   Duration = 5.5,
   Image = 4483362458,
   Actions = { -- Notification Buttons
      Ignore = {
         Name = "Alright!",
         Callback = function()
         print("The user tapped Alright!")
      end
   },
},
})
