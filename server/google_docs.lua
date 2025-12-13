AS = AS or {}
AS.Docs = AS.Docs or {}

local RBAC   = AS.RBAC
local Audit  = AS.Audit
local Events = AS.Events
local Utils  = AS.Utils

local function slugifyId(title, index)
    if type(title) ~= 'string' or title == '' then
        return ('doc_%d'):format(index or 0)
    end

    local slug = title:lower()
    slug = slug:gsub('%s+', '_')
    slug = slug:gsub('[^%w_]+', '')
    if slug == '' then
        slug = ('doc_%d'):format(index or 0)
    end
    return slug
end

--=====================================================
--  SOURCE LIST (Config.Docs → AS.Docs.Listing)
--=====================================================

AS.Docs.Listing = {}

if Config and Config.Docs and type(Config.Docs) == 'table' and #Config.Docs > 0 then
    for i, entry in ipairs(Config.Docs) do
        if entry.url and entry.url ~= '' then
            local id = entry.id or slugifyId(entry.title, i)

            AS.Docs.Listing[#AS.Docs.Listing + 1] = {
                id       = id,
                title    = entry.title or entry.name or id,
                url      = entry.url,
                minRole  = entry.minRole or 'helper',  -- default visibility
                editRole = entry.editRole or 'admin',  -- default edit role
                icon     = entry.icon or (entry.type == 'sheet' and '📊' or '📄'),
            }
        end
    end
end

-- Fallback: if Config.Docs is empty/missing, keep the original static examples
if #AS.Docs.Listing == 0 then
    AS.Docs.Listing = {
        {
            id          = 'rules',
            title       = 'Server Rules',
            url         = 'https://docs.google.com/document/d/EXAMPLE_RULES',
            minRole     = 'helper',   -- minimum RBAC role allowed to view
            editRole    = 'admin',    -- minimum role that can edit
            icon        = '📄',
        },
        {
            id          = 'staff_guide',
            title       = 'Staff Guide',
            url         = 'https://docs.google.com/document/d/EXAMPLE_GUIDE',
            minRole     = 'mod',
            editRole    = 'admin',
            icon        = '📄',
        },
    }
end

--========================================
-- Helpers
--========================================

local function getRolePriority(role)
    if not AS.Staff or not AS.Staff.Roles then return 0 end
    local r = AS.Staff.Roles[role]
    return r and r.priority or 0
end

local function roleAtLeast(role, required)
    if not required then return true end
    return getRolePriority(role) >= getRolePriority(required)
end

local function getDoc(id)
    for _, doc in ipairs(AS.Docs.Listing) do
        if doc.id == id then
            return doc
        end
    end
    return nil
end

--========================================
-- Core operations
--========================================

function AS.Docs.GetFilteredList(src)
    local _, roleName = AS.RBAC.GetRoleData(src)
    local results = {}

    for _, doc in ipairs(AS.Docs.Listing) do
        if roleAtLeast(roleName, doc.minRole) then
            results[#results + 1] = {
                id       = doc.id,
                title    = doc.title,
                name     = doc.title, -- convenience field for NUI
                url      = doc.url,
                icon     = doc.icon,
                canEdit  = roleAtLeast(roleName, doc.editRole),
            }
        end
    end

    Audit.Log(src, nil, 'docs:list', { count = #results })
    return results
end

function AS.Docs.Open(src, id)
    local doc = getDoc(id)
    if not doc then return nil end

    local _, roleName = AS.RBAC.GetRoleData(src)
    if not roleAtLeast(roleName, doc.minRole) then
        return nil
    end

    Audit.Log(src, nil, 'docs:open', { id = id })

    return {
        id      = doc.id,
        title   = doc.title,
        name    = doc.title,
        url     = doc.url,
        icon    = doc.icon,
        canEdit = roleAtLeast(roleName, doc.editRole),
    }
end

function AS.Docs.RequestEdit(src, id)
    local doc = getDoc(id)
    if not doc then return false end

    local _, roleName = AS.RBAC.GetRoleData(src)
    local allowed = roleAtLeast(roleName, doc.editRole)

    Audit.Log(src, nil, 'docs:requestEdit', {
        id      = id,
        allowed = allowed,
    })

    return allowed
end

function AS.Docs.UpdatePermissions(src, id, payload)
    -- In a real integration this would talk to Google APIs.
    -- For now we just audit the intent.
    Audit.Log(src, nil, 'docs:updatePermissions', {
        id      = id,
        payload = payload,
    })
end

function AS.Docs.Refresh(src, id)
    -- Placeholder for future; just re-open
    return AS.Docs.Open(src, id)
end

if Utils and Utils.Info then
    Utils.Info('Google Docs integration surface initialized (docs=%d)', #AS.Docs.Listing)
end
