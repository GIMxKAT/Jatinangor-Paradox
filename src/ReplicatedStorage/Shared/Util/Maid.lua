--!strict
-- Standard "Maid" pattern: collects connections/instances/callbacks and
-- cleans them all up in one call. Use this in every Service/Controller
-- that connects to PlayerAdded, PlayerRemoving, signals, etc. so cleanup
-- is never forgotten (a common source of memory leaks in long-running
-- Roblox servers).

local Maid = {}
Maid.__index = Maid

export type Task = RBXScriptConnection | Instance | (() -> ()) | { Destroy: (any) -> () }

export type Maid = typeof(setmetatable(
    {} :: {
        _tasks: { Task },
    },
    Maid
))

function Maid.new(): Maid
    return setmetatable({ _tasks = {} }, Maid) :: Maid
end

function Maid.Give(self: Maid, task_: Task)
    table.insert(self._tasks, task_)
end

function Maid.DoCleaning(self: Maid)
    for _, task_ in self._tasks do
        if typeof(task_) == "RBXScriptConnection" then
            task_:Disconnect()
        elseif typeof(task_) == "Instance" then
            task_:Destroy()
        elseif typeof(task_) == "function" then
            task_()
        elseif typeof(task_) == "table" and (task_ :: any).Destroy then
            (task_ :: any):Destroy()
        end
    end
    table.clear(self._tasks)
end

return Maid
