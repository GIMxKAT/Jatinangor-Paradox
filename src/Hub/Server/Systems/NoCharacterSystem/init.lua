--!strict
-- NoCharacterSystem (Hub)
--
-- The Hub is a family-registration screen (see HubUIController), not a
-- place players walk around in. Disabling character auto-load means no
-- avatar ever spawns here -- no movement to block, nothing to render or
-- animate per player -- while the UI runs on top of an otherwise-empty
-- Workspace. Init runs before any player connection is processed (server
-- bootstrap is synchronous), so this is set before Roblox would ever spawn
-- a character.
--
-- Side effect: StarterGui is normally copied into a player's PlayerGui when
-- their character spawns (even ResetOnSpawn=false GUIs wait for the first
-- spawn). With no character ever spawning, that copy never happens, so
-- HubGui would never reach the player -- this system is responsible for
-- provisioning it manually instead.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local NoCharacterSystem = { Name = "NoCharacterSystem", Dependencies = {} }

local function provisionGui(player: Player)
    local playerGui = player:WaitForChild("PlayerGui")
    for _, child in StarterGui:GetChildren() do
        if not playerGui:FindFirstChild(child.Name) then
            child:Clone().Parent = playerGui
        end
    end
end

function NoCharacterSystem.Init()
    Players.CharacterAutoLoads = false
end

function NoCharacterSystem.Start()
    Players.PlayerAdded:Connect(provisionGui)
    for _, player in Players:GetPlayers() do
        provisionGui(player)
    end
end

return NoCharacterSystem
