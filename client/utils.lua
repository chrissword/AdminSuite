AS = AS or {}
AS.ClientUtils = AS.ClientUtils or {}

local Config = AS.Config or Config

--===============================
-- INTERNAL HELPERS
--===============================
local function isDebug()
    return Config and Config.EnableDebug
end

local function safeFormat(msg, ...)
    if select("#", ...) == 0 then
        return tostring(msg or "")
    end

    local ok, formatted = pcall(string.format, tostring(msg or ""), ...)
    if not ok then
        return tostring(msg or "")
    end
    return formatted
end

--===============================
-- DEBUG LOGGING
--===============================
function AS.ClientUtils.Debug(msg, ...)
    if not isDebug() then return end
    print(("[AdminSuite:Client] %s"):format(safeFormat(msg, ...)))
end

-- Generic warning helper (optional, but useful)
function AS.ClientUtils.Warn(msg, ...)
    print(("[AdminSuite:Client:WARN] %s"):format(safeFormat(msg, ...)))
end

--===============================
-- NUI HELPERS
--===============================
-- NUI message contract:
--   JS receives: { event: <string>, type: <string>, payload: <table> }
-- Our JS clipboard handler in dashboard.js is listening on `data.event`,
-- but other routers may be using `data.type`. We set BOTH so everything
-- stays in sync.
function AS.ClientUtils.SendNUI(eventName, payload)
    eventName = eventName or "as:nui:unknown"
    payload   = payload or {}

    local msg = {
        event   = eventName,  -- what dashboard.js clipboard listener reads
        type    = eventName,  -- what main.js/router may be reading
        payload = payload
    }

    if isDebug() then
        -- Lightweight JSON debug; protect against encoding errors
        local encoded = "<?>"
        if json and json.encode then
            local ok, res = pcall(json.encode, msg)
            if ok then
                encoded = res
            end
        end
        print("[AdminSuite:Client:NUI] -> " .. encoded)
    end

    SendNUIMessage(msg)
end

-- Focus helper
function AS.ClientUtils.SetNuiFocus(hasFocus, showCursor)
    SetNuiFocus(hasFocus, showCursor == nil and hasFocus or showCursor)
end

-- Simple Notify → NUI toast at bottom-center
function AS.ClientUtils.Notify(msg, msgType)
    msg = tostring(msg or "")

    AS.ClientUtils.SendNUI('as:nui:notify', {
        message = msg,
        type    = msgType or 'info'
    })
end

