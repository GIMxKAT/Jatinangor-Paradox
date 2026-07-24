--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local RoleController = { Name = "RoleController", Dependencies = {} }

RoleController.RoleAssigned = Signal.new()

local myRole: string? = nil

function RoleController.Start()
    Net.OnClientEvent(RemoteNames.Role_Assigned, function(role: string)
        myRole = role
        RoleController.RoleAssigned:Fire(role)
    end)
end

function RoleController.GetMyRole(): string?
    return myRole
end

return RoleController
