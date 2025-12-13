Config               = {}
Config.DB            = {}
Config.Theme         = {}
Config.Keys          = {}
Config.Branding      = {}
Config.Integrations  = {}
Config.Persistence   = {}
Config.Permissions   = {}
Config.Inventory     = {}

--=====================================================
--  CORE FLAGS
--=====================================================

-- Whether to enable debug prints/logs
Config.EnableDebug = false

-- Namespace identifier (for clarity, not used as prefix in events)
Config.Namespace = 'as'

-- ESX / skin integration switch (generic + future proof)
-- Possible values: 'qb-clothing', 'illenium-appearance', 'none'
Config.SkinIntegration = 'qb-clothing'

--=====================================================
--  Default Vehicle Spawn Model
--=====================================================

--=====================================================
--  Default Vehicle Spawn Model
--=====================================================

Config.VehicleTools = Config.VehicleTools or {}
Config.VehicleTools.DefaultModel = 'adder' -- change to what you want



--=====================================================
--  BRANDING & IDENTITY
--=====================================================

Config.Branding.ServerName     = 'AdminSuite'
Config.Branding.ProductName    = 'AdminSuite'
Config.Branding.FooterText     = '© 2025 AdminSuite Design'
Config.Branding.DiscordGuildId = '506726333867360256'

-- Used for kick/ban messages and report links, etc.
Config.Branding.ServerDiscord  = 'https://discord.gg/yourdiscord'

--=====================================================
--  DISCORD / WEBHOOKS
--=====================================================

Config.Integrations.Webhooks = {
  Screenshots = 'https://discord.com/api/webhooks/1449228472022208712/d9YyW3Nb7DhFY3WWh_hGCAWo-bUIjPZBpyoEfYML18uTmpS-zIutvo9q2AcivsRWv_01',
  Bans        = '',
  Reports     = '',
  Audit       = '',
  AdminChat   = '',

  Moderation  = '', -- kick/warn/ban/message
  Economy     = '', -- give/take money
  Spawns      = '', -- vehicle spawn / item spawn
  Self        = '', -- godmode/superjump/fastrun/stamina toggles
}


--=====================================================
--  THEME DEFAULTS
--=====================================================

-- 1 = Dark, 0 = Light
Config.Theme.DefaultDarkMode = 0

-- Apply AdminSuite dark/light tokens from shared/theme.lua
Config.Theme.Default = 'light'   -- 'dark' or 'light'

--=====================================================
--  PANEL BEHAVIOR
--=====================================================

-- Whether opening the panel freezes the player
Config.PanelFreezePlayerOnOpen = false

-- Whether the panel should auto-close on player death
Config.PanelCloseOnDeath = true

--=====================================================
--  KEYBINDS
--  Note: registration is done client-side; these are just defaults.
--=====================================================

-- Key to open/close the main admin panel
Config.Keys.TogglePanel = '0'

-- Key to toggle noclip (subject to RBAC)
Config.Keys.ToggleNoclip = 'F2'

-- Key to toggle name tags
Config.Keys.ToggleNames = 'F3'

-- Key to toggle ID display
Config.Keys.ToggleIds = 'F4'

--=====================================================
--  DATABASE SETTINGS (LOGICAL MAPPINGS ONLY)
--  Actual names live in shared/tables.lua
--=====================================================

-- Database adapter; used later in server/utils.lua
-- Possible values: 'mysql-async', 'oxmysql', 'ghmattimysql'
Config.DB.Adapter = 'oxmysql'

-- Optional: prefix for all AdminSuite tables
Config.DB.Prefix = 'as_'

--=====================================================
--  PERSISTENCE OPTIONS
--  These control use of /logs JSON files alongside DB.
--=====================================================

Config.Persistence.Enable = {
    AdminChat = true,
    Reports   = true,
    Audit     = true,
    Bans      = true,
}

Config.Persistence.Paths = {
    AdminChat = 'logs/admin_chat.json',
    Reports   = 'logs/reports.json',
    Audit     = 'logs/audit.json',
    Bans      = 'logs/bans.json',
}

--=====================================================
--  MEDICAL INTEGRATION
--=====================================================

-- How AdminSuite should handle heal / revive actions.
-- "qb-ambulancejob" = default QBCore hospital (uses hospital:client events)
-- "quasar"          = qs-medical-creator (uses ambulance:healPlayer / ambulance:revivePlayer)
-- "custom"          = your own implementation; hook into as:medical:* events.
Config.Medical = {
    Mode = "quasar", -- "qb-ambulancejob", "quasar", or "custom"
}


--=====================================================
--  INVENTORY CONFIG
--  This is where you declare what inventory system AdminSuite targets.
--  The moderation money/item actions already use QBCore functions
--  (AddMoney/AddItem/etc.), which qb-inventory and most others hook into.
--  Later, for "View Inventory" UI we will branch on this.
--=====================================================

-- Possible values (by convention): 'qb-inventory', 'qs-inventory', 'ox_inventory', 'none'
Config.Inventory.System = 'qb-inventory'

-- Optional: future wiring for opening a target inventory
-- (these are placeholders for when we mirror the actual inventory UI)
Config.Inventory.OpenTargetInventoryEvent = ''   -- e.g. 'qb-inventory:server:OpenInventory'
Config.Inventory.OpenSelfInventoryEvent   = ''   -- if you need it later

--=====================================================
--  INVENTORY MODE
--  High-level switch for how we discover item definitions
--  (NOT the same as the UI inventory system)
--=====================================================

Config.Inventory.Mode = 'qb'    -- 'qb' | 'qs' | 'custom'

-- For qb:
--  AdminSuite will use QBCore's shared item definitions
--  (QBCore.Shared.Items or QBShared.Items)
Config.Inventory.QB = {
    -- If you ever need to override the core resource name:
    Resource = 'qb-core',
}

-- For future systems (qs, custom, etc.), we can extend:
--   Config.Inventory.QS = { ... }
--   Config.Inventory.CustomItemsProvider = 'my:items:export'


--=====================================================
--  PERMISSIONS PRESETS (HIGH LEVEL)
--  Detailed RBAC lives in shared/staff.lua and is enforced server-side.
--=====================================================

Config.Permissions.Roles = {
    god = {
        Label    = 'God',
        Inherits = nil,        -- Top of the chain
    },
    admin = {
        Label    = 'Administrator',
        Inherits = 'mod',
    },
    mod = {
        Label    = 'Moderator',
        Inherits = 'helper',
    },
    helper = {
        Label    = 'Helper',
        Inherits = nil,
    },
    dev = {
        Label    = 'Developer',
        Inherits = 'admin',
    },
}

-- How staff are detected from identifiers. This will be used
-- by server/rbac.lua.
Config.Permissions.IdentifierPriority = {
    'discord',   -- discord:xxxxx
    'license',   -- license:xxxxx
    'steam',     -- steam:xxxxx
}

--=====================================================
--  SAFETY / RATE LIMITING
--=====================================================

Config.RateLimits = {
    ReportSubmitPerMinute = 5,
    AdminChatPerMinute    = 20,
}

--=====================================================
--  INTERNAL (DO NOT EDIT UNLESS YOU KNOW WHAT YOU’RE DOING)
--=====================================================

-- Global namespace table (shared with shared/*.lua files)
AS       = AS or {}
AS.Config = Config
