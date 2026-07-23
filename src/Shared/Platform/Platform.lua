--!strict
-- Platform
--
-- Cross-platform input detection + adaptive UI helpers shared by every
-- place's client Controllers (Hub, Lobby, PlayArea all require this same
-- module — it lives in Shared, not under any one place's Controllers/).
--
-- Roblox's own input classes (ProximityPrompt, ContextActionService,
-- default TextBox/Button focus handling) already adapt automatically to
-- touch/gamepad/keyboard — this module exists only for the UI-layer
-- decisions Roblox does NOT make for you: text/hit-target sizing per
-- device class, and which control-scheme hint icons to show. Prefer
-- ProximityPrompt-driven interactions over custom input handling wherever
-- possible; only build custom touch/gamepad/keyboard handling (as the
-- minigame UIs will need to) when the interaction genuinely can't be a
-- ProximityPrompt.

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

export type InputScheme = "Touch" | "Gamepad" | "MouseKeyboard"

local Platform = {}

function Platform.IsConsole(): boolean
    return GuiService:IsTenFootInterface()
end

function Platform.GetCurrentScheme(): InputScheme
    if
        UserInputService.GamepadEnabled
        and (Platform.IsConsole() or not UserInputService.KeyboardEnabled)
    then
        return "Gamepad"
    end
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        return "Touch"
    end
    return "MouseKeyboard"
end

-- Recommended UIScale factor for the current device class. Bind this to a
-- UIScale instance on each ScreenGui rather than hardcoding text/element
-- sizes, so one layout works from a phone up to a TV.
function Platform.GetRecommendedUIScale(): number
    if Platform.IsConsole() then
        return 1.15
    elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize
        if viewport and viewport.X < 500 then
            return 1.25 -- small phone screens: bigger touch targets
        end
        return 1.1
    end
    return 1.0
end

-- Fires `callback(scheme)` immediately and again whenever the player
-- switches input device (e.g. picks up a controller mid-session, or plugs
-- a keyboard into a console). Returns connections for the caller's Maid.
function Platform.ObserveScheme(callback: (InputScheme) -> ()): { RBXScriptConnection }
    callback(Platform.GetCurrentScheme())
    return {
        UserInputService.LastInputTypeChanged:Connect(function()
            callback(Platform.GetCurrentScheme())
        end),
    }
end

return Platform
