AS = AS or {}
AS.RBAC = AS.RBAC or {}

local Staff  = AS.Staff
local Config = AS.Config or Config
local Utils  = AS.Utils

--=====================================================
--  IDENTIFIER RESOLUTION
--=====================================================

local function getPlayerIdentifiers(source)
    local ids = {}
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        local prefix, value = id:match('^(.-):(.*)$')
        if prefix and value then
            ids[prefix] = id
        end
    end
    return ids
end

local function resolveRoleFromMappings(ids)
    if not Staff or not Staff.Mappings then return nil end

    for _, fullId in pairs(ids) do
        local role = Staff.Mappings[fullId]
        if role then
            return role
        end
    end

    return nil
end

--=====================================================
--  RBAC CORE
--=====================================================

function AS.RBAC.GetRole(source)
    if not Staff or not Staff.Roles then return nil end

    local ids = getPlayerIdentifiers(source)
    local mappedRole = resolveRoleFromMappings(ids)
    if mappedRole then return mappedRole end

    -- Future: add dynamic resolution (DB, external perms, etc.)
    return nil
end

function AS.RBAC.GetRoleData(source)
    local roleName = AS.RBAC.GetRole(source)
    if not roleName then return nil end
    return Staff.Roles[roleName], roleName
end

function AS.RBAC.Can(source, flagName)
    local roleData, roleName = AS.RBAC.GetRoleData(source)
    if not roleData then return false, 'no_role' end

    -- direct flag
    if roleData.flags and roleData.flags[flagName] then
        return true, roleName
    end

    -- inheritance chain
    local inherits = roleData.inherits
    while inherits do
        local parent = Staff.Roles[inherits]
        if not parent then break end
        if parent.flags and parent.flags[flagName] then
            return true, inherits
        end
        inherits = parent.inherits
    end

    return false, roleName
end

-- Convenience checks for common actions
function AS.RBAC.CanUseModeration(source)
    return AS.RBAC.Can(source, 'can_kick')
end

function AS.RBAC.CanUseWorldControls(source)
    return AS.RBAC.Can(source, 'can_use_world')
end

function AS.RBAC.CanUseVehicleTools(source)
    -- Vehicle tools are considered available if the player has ANY of the granular
    -- vehicle flags. This replaces the old can_use_vehicles_tools flag.
    return AS.RBAC.Can(source, 'can_spawn_vehicle')
        or AS.RBAC.Can(source, 'can_fix_vehicle')
        or AS.RBAC.Can(source, 'can_wash_vehicle')
        or AS.RBAC.Can(source, 'can_refuel_vehicle')
        or AS.RBAC.Can(source, 'can_delete_vehicle')
        or AS.RBAC.Can(source, 'can_seat_in_vehicle')
        or AS.RBAC.Can(source, 'can_seat_out_vehicle')
end

function AS.RBAC.IsStaff(source)
    local role = AS.RBAC.GetRole(source)
    return role ~= nil
end

-- Build effective flags for a role, including inheritance
local function buildEffectiveFlags(roleName)
    local combined = {}
    local visited  = {}

    local function apply(name)
        if not name or visited[name] then return end
        visited[name] = true

        local role = Staff and Staff.Roles and Staff.Roles[name]
        if not role then return end

        -- First apply inherited roles so children can override/extend
        if role.inherits then
            apply(role.inherits)
        end

        if role.flags then
            for k, v in pairs(role.flags) do
                if v then
                    combined[k] = true
                end
            end
        end
    end

    apply(roleName)
    return combined
end


--=====================================================
--  SERVER → CLIENT RBAC SYNC
--=====================================================

local Events = AS.Events

if Events and Events.RBAC and Events.RBAC.GetSelf then
    RegisterNetEvent(Events.RBAC.GetSelf, function()
        local src = source

        local roleData, roleName = AS.RBAC.GetRoleData(src)
        local payload

        if roleData and roleName then
            payload = {
                role     = roleName,
                label    = roleData.label,
                color    = roleData.color,
                priority = roleData.priority,
                flags    = roleData.flags or {},
            }
        else
            payload = nil
        end

        -- Send RBAC payload to the requesting client
        TriggerClientEvent(Events.RBAC.GetSelf, src, payload)
    end)
end



--=====================================================
--  INIT LOGGING
--=====================================================

local function countRoles()
    local n = 0
    for _ in pairs(Staff and Staff.Roles or {}) do
        n = n + 1
    end
    return n
end

if Utils and Utils.Info then
    Utils.Info('RBAC initialized (roles=%d)', countRoles())
else
    print(('[AdminSuite] RBAC initialized (roles=%d)'):format(countRoles()))
end
