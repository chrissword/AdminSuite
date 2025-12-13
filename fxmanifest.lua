fx_version 'cerulean'
game 'gta5'

name 'AdminSuite'
description 'Administration & Moderation Suite for QBCore'
author 'AdminSuite Design'
version '1.0.0'

lua54 'yes'

--=====================================================
--  CORE METADATA
--=====================================================

-- All database structures are created by server/migrations.lua
-- (Phase 1). No standalone .sql files are used.

-- No use of require/dofile for load order.
-- All scripts are declared explicitly here.

--=====================================================
--  SHARED CONFIG & DEFINITIONS (PHASE 0)
--=====================================================

shared_scripts {
    'config.lua',
    'config_docs.lua',

    'shared/staff.lua',
    'shared/events.lua',
    'shared/tables.lua',
    'shared/theme.lua',
}

--=====================================================
--  CLIENT SCRIPTS (PHASE 3)
--=====================================================
client_scripts {
    'config.lua',

    'shared/staff.lua',
    'shared/events.lua',
    'shared/tables.lua',
    'shared/theme.lua',

    'client/utils.lua',
    'client/rbac.lua',
    'client/nui.lua',
    'client/dashboard.lua',
    'client/admin_chat.lua',
    'client/player_moderation.lua',
    'client/spectate.lua',
    'client/player_settings.lua',
    'client/vehicles.lua',
    'client/items.lua',
    'client/world_controls.lua',
    'client/reports.lua',
    'client/resources.lua',
    'client/google_docs.lua',

    -- 👇 client-side audit bridge
    'client/audit.lua',

    'client/main.lua',
    'client/noclip.lua',
}

--=====================================================
--  SERVER SCRIPTS (PHASE 1/2)
--=====================================================
server_scripts {

    'shared/staff.lua',
    'shared/events.lua',
    'shared/tables.lua',
    'shared/theme.lua',

    'server/utils.lua',
    'server/persistence.lua',
    'server/rbac.lua',
    'server/audit.lua',
    'server/players.lua',
    'server/reports.lua',
    'server/admin_chat.lua',
    'server/google_docs.lua',
    'server/discipline.lua',
    'server/world_controls.lua',
    'server/vehicles.lua',
    'server/items.lua',
    'server/resources.lua',

    'server/events/as_admin.lua',
    'server/events/as_player.lua',
    'server/events/as_reports.lua',
    'server/events/as_docs.lua',
    'server/events/as_discipline.lua',
    'server/events/as_world.lua',

    'server/migrations.lua',
    'server/main.lua',
}

--=====================================================
--  NUI (PHASE 4)
--=====================================================
ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/css/main.css',
    'nui/css/theme_dark.css',
    'nui/css/theme_light.css',
    'nui/css/reports.css',

    -- Vehicles Navigation
    'nui/img/vehicles/*.png',
    'nui/img/vehicle_fallback.png',

    'nui/js/main.js',
    'nui/js/router.js',
    'nui/js/dashboard.js',
    'nui/js/moderation.js',
    'nui/js/discipline.js',
    'nui/js/bannedplayers.js',
    'nui/js/settings.js',
    'nui/js/admin_settings.js',
    'nui/js/reports.js',
    'nui/js/google_docs.js',
    'nui/js/utils.js',
    'nui/js/vehicles.js',
    'nui/js/items.js',
    'nui/js/resources.js',

    -- Audit view
    'nui/js/audit.js',

    'nui/img/adminsuite_logo.png',
    'nui/img/adminsuite_report_logo.png',
    'nui/img/dark_bg.png',
    'nui/img/light_bg.png',
    'nui/img/notification.png',
    'nui/img/unban.png',
}
