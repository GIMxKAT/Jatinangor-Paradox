--!strict
-- Centralized logging. Use Log.new("ServiceName") once per module instead
-- of calling print/warn directly, so every line is consistently tagged and
-- can be grepped from the output during a live event.

local Log = {}
Log.__index = Log

export type Logger = typeof(setmetatable(
    {} :: {
        _tag: string,
    },
    Log
))

function Log.new(tag: string): Logger
    return setmetatable({ _tag = tag }, Log) :: Logger
end

local function timestamp(): string
    return os.date("%H:%M:%S")
end

function Log.Info(self: Logger, message: string)
    print(("[%s][%s][INFO] %s"):format(timestamp(), self._tag, message))
end

function Log.Warn(self: Logger, message: string)
    warn(("[%s][%s][WARN] %s"):format(timestamp(), self._tag, message))
end

function Log.Error(self: Logger, message: string)
    warn(("[%s][%s][ERROR] %s"):format(timestamp(), self._tag, message))
end

return Log
