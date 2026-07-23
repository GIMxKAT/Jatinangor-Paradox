--!strict
-- ContentRegistry
--
-- The second half of the loose-coupling story alongside PluginRegistry.
-- Systems (Role, Inventory, Item, Minigame, ...) are *booted* — long-lived,
-- ordered, Init/Start. Content plugins (one specific item, one specific
-- minigame, one specific skill, one specific AI entity, one specific
-- dialog tree) are *indexed* — no lifecycle of their own, just a unique Id
-- looked up on demand by whichever System owns that content category.
--
-- Contract: every module under `container` must return a table with a
-- unique string `.Id`. That is the ONLY thing ContentRegistry checks —
-- everything else in the table belongs entirely to whoever authored that
-- content, and to the System that consumes it (see the *Definition types
-- in Shared/Types/Types.lua for the conventions each category follows).
--
-- This is what makes "add a new item" or "add a new minigame" a
-- zero-shared-file-edit operation: drop a module in e.g.
-- PlayArea/Server/Systems/ItemSystem/Items/MyNewItem/init.lua returning
-- `{ Id = "MyNewItem", ... }`, and ItemSystem picks it up on next boot with
-- no other file touched.

local Log = require(script.Parent.Parent.Util.Log)

export type ContentDefinition = { Id: string, [string]: any }

local ContentRegistry = {}

local function resolveModule(child: Instance): ModuleScript?
    if child:IsA("ModuleScript") then
        return child
    elseif child:IsA("Folder") then
        local init = child:FindFirstChild("init")
        if init and init:IsA("ModuleScript") then
            return init
        end
    end
    return nil
end

-- `label` is used only for the log tag (e.g. "Items", "Skills",
-- "Minigames") so a warning is traceable to which category it came from.
function ContentRegistry.Load(container: Instance, label: string): { [string]: ContentDefinition }
    local log = Log.new(("ContentRegistry:%s"):format(label))
    local index: { [string]: ContentDefinition } = {}
    local count = 0

    for _, child in container:GetChildren() do
        local moduleScript = resolveModule(child)
        if moduleScript then
            local ok, result = pcall(require, moduleScript)
            if not ok then
                log:Error(
                    ("Failed to require %s: %s"):format(
                        moduleScript:GetFullName(),
                        tostring(result)
                    )
                )
            elseif typeof(result) ~= "table" or typeof((result :: any).Id) ~= "string" then
                log:Error(
                    ("%s does not return a table with a string .Id — skipping"):format(
                        moduleScript:GetFullName()
                    )
                )
            elseif index[(result :: ContentDefinition).Id] then
                log:Error(
                    ("Duplicate content Id '%s' at %s — ignoring the second registration"):format(
                        (result :: ContentDefinition).Id,
                        moduleScript:GetFullName()
                    )
                )
            else
                local def = result :: ContentDefinition
                index[def.Id] = def
                count += 1
            end
        end
    end

    log:Info(("Loaded %d entries"):format(count))
    return index
end

return ContentRegistry
