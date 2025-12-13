AS = AS or {}
AS.Staff = AS.Staff or {}

--=====================================================
--  ROLE DEFINITIONS
--=====================================================

-- Each role:
--   label       -> Display name in UI
--   color       -> Hex color used in NUI + client visuals only
--   priority    -> Higher = more powerful
--   inherits    -> Optional parent role (for cascading permissions)
--   flags       -> Capability booleans; server-side will enforce

AS = AS or {}
AS.Staff = AS.Staff or {}

AS.Staff.Roles = {
    god = {
        label    = 'God',
        color    = '#b035f6',
        priority = 100,
        inherits = nil,
        flags = {
            full_access     = true,

            -- Core moderation
            can_ban_perm    = true,
            can_ban_temp    = true,
            can_kick        = true,
            can_warn        = true,
            can_heal_revive = true,
            can_freeze      = true,
            can_teleport    = true,
            can_spectate    = true,

            -- Discipline
            can_delete_discipline = true,
            can_view_discipline   = true,

            -- Inventory / money
            can_view_inv    = true,
            can_give_item   = true,
            can_take_item   = true,
            can_give_money  = true,
            can_take_money  = true,

            -- World controls
            can_use_world   = true,
            can_world_time    = true,
            can_world_weather = true,

            -- Reports
            can_view_reports   = true,
            can_handle_reports = true,

            -- Vehicles (granular)
            can_spawn_vehicle   = true,
            can_fix_vehicle     = true,
            can_wash_vehicle    = true,
            can_refuel_vehicle  = true,
            can_delete_vehicle  = true,
            can_seat_in_vehicle = true,
            can_seat_out_vehicle = true,

            -- Management / docs / audit
            can_manage_jobs         = true,
            can_manage_gangs        = true,
            can_manage_staff_roles  = true,
            can_use_adminchat_purge = true,
            can_manage_docs         = true,
            can_view_audit          = true,
            can_flush_cache         = true,
            can_screenshot          = true,

            -- Resources
            can_view_resources    = true,
            can_start_resource    = true,
            can_stop_resource     = true,
            can_restart_resource  = true,
            can_refresh_resources = true,

            -- Settings
            can_view_settings   = true,
            can_manage_settings = true,

            -- Movement / noclip
            can_noclip       = true,

            -- Quick action / dev / management flags
            can_self_godmode  = true,
            can_self_powers   = true,
            can_self_cosmetic = true,
            can_use_devtools  = true,
            can_toggle_ids    = true,
            can_toggle_names  = true,
            can_toggle_radar  = true,
        }
    },

    admin = {
        label    = 'Administrator',
        color    = '#FA8903',  -- From light theme accent
        priority = 80,
        inherits = nil,
        flags = {
            full_access     = false,

            -- Core moderation
            can_ban_perm    = true,
            can_ban_temp    = true,
            can_kick        = true,
            can_warn        = true,
            can_heal_revive = true,
            can_freeze      = true,
            can_teleport    = true,
            can_spectate    = true,

            -- Discipline
            can_delete_discipline = true,
            can_view_discipline   = true,

            -- Inventory / money
            can_view_inv    = true,
            can_give_item   = true,
            can_take_item   = true,
            can_give_money  = true,
            can_take_money  = true,

            -- World controls
            can_use_world     = true,
            can_world_time    = true,
            can_world_weather = true,

            -- Reports (match old can_kick behavior)
            can_view_reports   = true,
            can_handle_reports = true,

            -- Vehicles (match old can_use_vehicles_tools = true)
            can_spawn_vehicle    = true,
            can_fix_vehicle      = true,
            can_wash_vehicle     = true,
            can_refuel_vehicle   = true,
            can_delete_vehicle   = true,
            can_seat_in_vehicle  = true,
            can_seat_out_vehicle = true,

            -- Management / docs / audit
            can_manage_jobs         = true,
            can_manage_gangs        = true,
            can_manage_staff_roles  = false,
            can_use_adminchat_purge = false,
            can_manage_docs         = true,
            can_view_audit          = false,
            can_flush_cache         = false,
            can_screenshot          = true,

            -- Resources (strong admin, but not full like god)
            can_view_resources    = true,
            can_start_resource    = true,
            can_stop_resource     = true,
            can_restart_resource  = true,
            can_refresh_resources = true,

            -- Settings
            can_view_settings   = true,
            can_manage_settings = true,

            -- Movement / noclip
            can_noclip       = true,

            -- Quick action / dev / management flags
            can_self_godmode  = true,
            can_self_powers   = true,
            can_self_cosmetic = true,
            can_use_devtools  = false,
            can_toggle_ids    = true,
            can_toggle_names  = true,
            can_toggle_radar  = true,
        }
    },

    mod = {
        label    = 'Moderator',
        color    = '#2b8cff',
        priority = 60,
        inherits = nil,
        flags = {
            full_access     = false,

            -- Core moderation
            can_ban_perm    = false,
            can_ban_temp    = true,
            can_kick        = true,
            can_warn        = true,
            can_heal_revive = true,
            can_freeze      = true,
            can_teleport    = true,
            can_spectate    = true,

            -- Discipline
            can_delete_discipline = false,
            can_view_discipline   = true,

            -- Inventory / money
            can_view_inv    = false,
            can_give_item   = false,
            can_take_item   = false,
            can_give_money  = false,
            can_take_money  = false,

            -- World controls
            can_use_world     = false,
            can_world_time    = false,
            can_world_weather = false,

            -- Reports (match old can_kick behavior)
            can_view_reports   = true,
            can_handle_reports = true,

            -- Vehicles (match old can_use_vehicles_tools = false)
            can_spawn_vehicle    = false,
            can_fix_vehicle      = false,
            can_wash_vehicle     = false,
            can_refuel_vehicle   = false,
            can_delete_vehicle   = false,
            can_seat_in_vehicle  = false,
            can_seat_out_vehicle = false,

            -- Management / docs / audit
            can_manage_jobs         = false,
            can_manage_gangs        = false,
            can_manage_staff_roles  = false,
            can_use_adminchat_purge = false,
            can_manage_docs         = false,
            can_view_audit          = false,
            can_flush_cache         = false,
            can_screenshot          = true,

            -- Resources
            can_view_resources    = false,
            can_start_resource    = false,
            can_stop_resource     = false,
            can_restart_resource  = false,
            can_refresh_resources = false,

            -- Settings
            can_view_settings   = false,
            can_manage_settings = false,

            -- Movement / noclip
            can_noclip       = true,

            -- Quick action / dev / management flags
            -- Mods get self powers + cosmetics + mgmt toggles, but no dev tools
            can_self_godmode  = false,
            can_self_powers   = true,   -- super jump / fast run / infinite stamina
            can_self_cosmetic = true,   -- clear/wet/dry clothes
            can_use_devtools  = false,  -- no Developer tab
            can_toggle_ids    = true,
            can_toggle_names  = true,
            can_toggle_radar  = true,
        }
    },

    helper = {
        label    = 'Helper',
        color    = '#35c88a',
        priority = 40,
        inherits = nil,
        flags = {
            full_access     = false,

            -- Core moderation (very limited)
            can_ban_perm    = false,
            can_ban_temp    = false,
            can_kick        = false,
            can_warn        = true,
            can_heal_revive = false,
            can_freeze      = false,
            can_teleport    = false,
            can_spectate    = false,

            -- Discipline
            can_delete_discipline = false,
            can_view_discipline   = false,

            -- Inventory / money
            can_view_inv    = false,
            can_give_item   = false,
            can_take_item   = false,
            can_give_money  = false,
            can_take_money  = false,

            -- World controls
            can_use_world     = false,
            can_world_time    = false,
            can_world_weather = false,

            -- Reports
            can_view_reports   = false,
            can_handle_reports = false,

            -- Vehicles
            can_spawn_vehicle    = false,
            can_fix_vehicle      = false,
            can_wash_vehicle     = false,
            can_refuel_vehicle   = false,
            can_delete_vehicle   = false,
            can_seat_in_vehicle  = false,
            can_seat_out_vehicle = false,

            -- Management / docs / audit
            can_manage_jobs         = false,
            can_manage_gangs        = false,
            can_manage_staff_roles  = false,
            can_use_adminchat_purge = false,
            can_manage_docs         = false,
            can_view_audit          = false,
            can_flush_cache         = false,
            can_screenshot          = false,

            -- Resources
            can_view_resources    = false,
            can_start_resource    = false,
            can_stop_resource     = false,
            can_restart_resource  = false,
            can_refresh_resources = false,

            -- Settings
            can_view_settings   = false,
            can_manage_settings = false,

            -- Movement / noclip
            can_noclip       = false,

            -- Quick action / dev / management flags
            -- Very limited: no self powers, dev tools, or mgmt toggles
            can_self_godmode  = false,
            can_self_powers   = false,
            can_self_cosmetic = false,
            can_use_devtools  = false,
            can_toggle_ids    = true,
            can_toggle_names  = false,
            can_toggle_radar  = false,
        }
    },

    dev = {
        label    = 'Developer',
        color    = '#DF5702',  -- From dark theme accent
        priority = 70,
        inherits = nil,
        flags = {
            full_access     = false,

            -- Core moderation: all off (no kicks/bans/warns, etc.)
            can_ban_perm    = false,
            can_ban_temp    = false,
            can_kick        = false,
            can_warn        = false,
            can_heal_revive = true,
            can_freeze      = false,
            can_teleport    = true,
            can_spectate    = false,

            -- Discipline
            can_delete_discipline = false,
            can_view_discipline   = false,

            -- Inventory / money
            can_view_inv    = false,
            can_give_item   = false,
            can_take_item   = false,
            can_give_money  = false,
            can_take_money  = false,

            -- World / tools / docs
            can_use_world     = true,
            can_world_time    = true,
            can_world_weather = true,

            -- Reports (no access, to match old can_kick = false)
            can_view_reports   = false,
            can_handle_reports = false,

            -- Vehicles (match old can_use_vehicles_tools = true)
            can_spawn_vehicle    = true,
            can_fix_vehicle      = true,
            can_wash_vehicle     = true,
            can_refuel_vehicle   = true,
            can_delete_vehicle   = true,
            can_seat_in_vehicle  = true,
            can_seat_out_vehicle = true,

            -- Management / docs / audit
            can_manage_jobs         = false,
            can_manage_gangs        = false,
            can_manage_staff_roles  = false,
            can_use_adminchat_purge = false,
            can_manage_docs         = true,
            can_view_audit          = true,
            can_flush_cache         = true,
            can_screenshot          = false,

            -- Resources (conservative: no resource control by default)
            can_view_resources    = true,
            can_start_resource    = true,
            can_stop_resource     = true,
            can_restart_resource  = true,
            can_refresh_resources = true,

            -- Settings
            can_view_settings   = true,
            can_manage_settings = true,

            -- Movement / noclip
            can_noclip       = true,

            -- Quick action / dev / management flags
            -- As per your requirements:
            -- Self tab: Heal, Revive, Super Jump, Fast Run, Infinite Stamina
            -- Dev tab: all actions
            -- Mgmt tab: hidden
            can_self_godmode  = true,  -- no God mode
            can_self_powers   = true,   -- super jump / fast run / infinite stamina
            can_self_cosmetic = true,  -- no clear/wet/dry clothes
            can_use_devtools  = true,   -- Developer quick actions visible
            can_toggle_ids    = false,  -- management tab stays hidden
            can_toggle_names  = false,
            can_toggle_radar  = false,
        }
    },
}


--=====================================================
--  ROLE MAPPINGS
--=====================================================

-- Structure used by server/rbac.lua to match identifiers
-- to AdminSuite roles.
AS.Staff.Mappings = {
    -- [identifier] = 'role'
    ['discord:506726333867360256'] = 'god',
    ['license:enteryourlicenseehre'] = 'god', 

}

--=====================================================
--  RUNTIME MAPPING HELPERS
--=====================================================

-- Adds or updates a staff mapping and attempts to persist it
-- back into this shared/staff.lua file on the server.
function AS.Staff.AddOrUpdateMapping(identifier, role, actorSrc, targetSrc)
    AS.Staff.Mappings = AS.Staff.Mappings or {}
    AS.Staff.Mappings[identifier] = role

    -- Only attempt to write on the server.
    if type(GetCurrentResourceName) ~= 'function'
        or type(LoadResourceFile) ~= 'function'
        or type(SaveResourceFile) ~= 'function' then
        return
    end

-- Removes a staff mapping and attempts to persist the change
-- back into this shared/staff.lua file on the server.
function AS.Staff.RemoveMapping(identifier, actorSrc, targetSrc)
    if not identifier or identifier == '' then return end

    AS.Staff.Mappings = AS.Staff.Mappings or {}
    AS.Staff.Mappings[identifier] = nil

    -- Only attempt to write on the server.
    if type(GetCurrentResourceName) ~= 'function'
        or type(LoadResourceFile) ~= 'function'
        or type(SaveResourceFile) ~= 'function' then
        return
    end

    local resourceName = GetCurrentResourceName()
    local relPath      = 'shared/staff.lua'

    local content = LoadResourceFile(resourceName, relPath)
    if not content then return end

    local escapedId = identifier:gsub('(%W)', '%%%1')

    -- Remove table-style mapping entries: ['license:xxx'] = 'role',
    local patternTable = "%s*%['" .. escapedId .. "'%]%s*=%s*'[^']*',%s*\n"
    content = content:gsub(patternTable, "\n")

    -- Remove top-level assignments: AS.Staff.Mappings['license:xxx'] = 'role'
    local patternAssign = "%s*AS%.Staff%.Mappings%['" .. escapedId .. "'%]%s*=%s*'[^']*'%s*\n"
    content = content:gsub(patternAssign, "\n")

    SaveResourceFile(resourceName, relPath, content, #content)
end


    local resourceName = GetCurrentResourceName()
    local relPath      = 'shared/staff.lua'

    local content = LoadResourceFile(resourceName, relPath)
    if not content then return end

    -- Escape identifier for pattern use
    local escapedId = identifier:gsub('(%W)', '%%%1')
    local pattern   = "%['" .. escapedId .. "'%]%s*=%s*'([^']+)'"

    local mappingLine = ("    ['%s'] = '%s',\n"):format(identifier, role)

    ----------------------------------------------------------------
    -- 1) If there is already an *active* mapping line, update it
    --    (ignore commented-out lines that just happen to contain it)
    ----------------------------------------------------------------
    local existingPos = content:find(pattern)
    if existingPos then
        -- Look at the text before the match on that same line
        local before     = content:sub(1, existingPos - 1)
        local linePrefix = before:match("([^\r\n]*)$") or ""

        -- If the line starts with --, treat it as COMMENTED and ignore it
        if linePrefix:match("^%s*%-%-") then
            existingPos = nil
        end
    end

    if existingPos then
        -- Update existing active mapping line
        content = content:gsub(pattern, "['" .. identifier .. "'] = '" .. role .. "'", 1)
        SaveResourceFile(resourceName, relPath, content, #content)
        return
    end

    ----------------------------------------------------------------
    -- 2) Otherwise, inject the new line inside AS.Staff.Mappings = { }
    ----------------------------------------------------------------
    -- We know the file structure, so we can anchor on the end of the
    -- mappings table right before the RUNTIME MAPPING HELPERS header.
    local blockAnchor = "\n}\n\n--=====================================================\n--  RUNTIME MAPPING HELPERS"
    local anchorPos   = content:find(blockAnchor, 1, true)

    if anchorPos then
        local before = content:sub(1, anchorPos - 1)
        local after  = content:sub(anchorPos)
        content = before .. mappingLine .. after
    else
        ----------------------------------------------------------------
        -- 3) Last resort: append at end if we fail to find the block
        ----------------------------------------------------------------
        content = content .. ("\nAS.Staff.Mappings['%s'] = '%s'\n"):format(identifier, role)
    end

    SaveResourceFile(resourceName, relPath, content, #content)
end

--=====================================================
--  UTILITY HELPERS
--=====================================================

function AS.Staff.GetRole(role)
    return AS.Staff.Roles[role]
end

function AS.Staff.GetPriority(role)
    local r = AS.Staff.Roles[role]
    return r and r.priority or 0
end
