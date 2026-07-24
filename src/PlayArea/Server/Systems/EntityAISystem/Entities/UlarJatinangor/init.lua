--!strict
-- UlarJatinangor ("Jatinangor Snake") — reference entity implementation.
--
-- Minimal waypoint patrol between sibling Parts tagged "PatrolPoint" under
-- the same Model. Copy this file's shape (Id + OnSpawn) for any new
-- creature/NPC type; EntityAISystem never needs to change to pick it up.
-- Deliberately simple — real patrol/aggro/pathfinding behavior is level
-- design + gameplay-programming work, not part of this baseline.

local CollectionService = game:GetService("CollectionService")

local PATROL_SPEED = 8

local UlarJatinangor = {
    Id = "UlarJatinangor",
    DisplayName = "Ular Jatinangor",
}

function UlarJatinangor.OnSpawn(instance: Instance, _context: { [string]: any })
    local humanoid = instance:FindFirstChildWhichIsA("Humanoid")
    local rootPart = instance:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not (humanoid and rootPart) then
        return -- not a rigged model; nothing to patrol with
    end
    humanoid.WalkSpeed = PATROL_SPEED

    local waypoints = {}
    for _, child in instance:GetChildren() do
        if CollectionService:HasTag(child, "PatrolPoint") and child:IsA("BasePart") then
            table.insert(waypoints, child)
        end
    end
    if #waypoints == 0 then
        return -- no patrol route configured; stands idle
    end

    task.spawn(function()
        local index = 1
        while instance.Parent do
            local target = waypoints[index]
            humanoid:MoveTo(target.Position)
            local reached = humanoid.MoveToFinished:Wait()
            if not reached then
                task.wait(1) -- got stuck; brief pause before retrying
            end
            index = (index % #waypoints) + 1
        end
    end)
end

return UlarJatinangor
