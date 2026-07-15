--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local log = Log.new("ClientBootstrap")

local Controllers = script.Controllers

local RoleController = require(Controllers.RoleController)
local DimensionController = require(Controllers.DimensionController)
local PuzzleController = require(Controllers.PuzzleController)
local JournalController = require(Controllers.JournalController)
local UIController = require(Controllers.UIController)

local ControllerRegistry = {
    Role = RoleController,
    Dimension = DimensionController,
    Puzzle = PuzzleController,
    Journal = JournalController,
    UI = UIController,
}

for name, controller in ControllerRegistry do
    if controller.Init then
        controller.Init(ControllerRegistry)
        log:Info(("%s initialized"):format(name))
    end
end

for name, controller in ControllerRegistry do
    if controller.Start then
        controller.Start()
        log:Info(("%s started"):format(name))
    end
end

log:Info("All controllers booted.")
