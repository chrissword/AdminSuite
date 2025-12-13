-- /locales/en.lua
-- Default English locale for AdminSuite

AS         = AS or {}
AS.Locales = AS.Locales or {}

local L = {}

L.meta = {
    code   = "en",
    name   = "English",
    author = "AdminSuite",
}

----------------------------------------------------------------------
-- General / System
----------------------------------------------------------------------

L.system = {
    panel_opened    = "AdminSuite panel opened.",
    panel_closed    = "AdminSuite panel closed.",
    no_permission   = "You do not have permission to perform that action.",
    action_failed   = "The requested action could not be completed.",
    invalid_player  = "Selected player is no longer available.",
    loading         = "Loading…",
    saving          = "Saving…",
}

----------------------------------------------------------------------
-- Navigation
----------------------------------------------------------------------

L.nav = {
    dashboard       = "Dashboard",
    admin_chat      = "Admin Chat",
    moderation      = "Player Moderation",
    settings        = "Manage Player Settings",
   -- vehicles        = "Vehicles",
    world_controls  = "World Controls",
    reports         = "Reports",
    docs            = "Google Docs",
}

----------------------------------------------------------------------
-- Vehicles Panel
----------------------------------------------------------------------

L.vehicles_ui = {
    title                = "Vehicles",
    subtitle             = "Read-only list of server-approved vehicles.",
    search_placeholder   = "Search by name, model, class, or category…",
    filter_category      = "Category",
    filter_class         = "Class",
    filter_garage        = "Garage",
    filter_clear         = "Clear Filters",

    column_label         = "Vehicle",
    column_model         = "Model",
    column_category      = "Category",
    column_class         = "Class",
    column_seats         = "Seats",
    column_garage        = "Garage",
    column_notes         = "Notes",

    badge_restricted     = "Restricted",
    badge_unrestricted   = "Unrestricted",

    status_total         = "Total Vehicles",
    status_showing       = "Showing {count} of {total}",

    empty_state_title    = "No Vehicles Found",
    empty_state_body     = "Try adjusting your filters or search terms.",

    tooltip_restricted   = "This vehicle is restricted to specific staff roles.",
    tooltip_unrestricted = "This vehicle is not restricted by AdminSuite.",
}

----------------------------------------------------------------------
-- Vehicle Category Labels
----------------------------------------------------------------------

L.vehicle_categories = {
    LEO   = "Law Enforcement",
    EMS   = "EMS",
    FIRE  = "Fire & Rescue",
    GOV   = "Government",
    STAFF = "Staff Utility",
    CIV   = "Civilian",
    OTHER = "Other",
}

----------------------------------------------------------------------
-- Vehicle Name/Description Locales
-- These map to localeKey values used in /vehicles/models.lua
----------------------------------------------------------------------

L.vehicles = {
    police_interceptor = {
        name        = "Police Interceptor",
        description = "Standard city patrol vehicle for general law enforcement duties."
    },
    police_slicktop = {
        name        = "Police Slicktop",
        description = "Marked patrol car with reduced light bar profile for traffic and supervisor units."
    },
    police_suv = {
        name        = "Police Utility SUV",
        description = "Utility SUV for supervisors, transport, and special operations."
    },
    ems_ambulance = {
        name        = "EMS Ambulance",
        description = "Primary medical response and patient transport unit."
    },
    fire_engine = {
        name        = "Fire Engine",
        description = "Fire and rescue apparatus for structure, vehicle, and large-scale incidents."
    },
    gov_sedan = {
        name        = "Government Sedan",
        description = "Unmarked executive sedan for government and command staff use."
    },
    staff_suv = {
        name        = "Staff Utility SUV",
        description = "Staff-only vehicle for oversight, events, and administrative duties."
    },
    civ_compact = {
        name        = "Dinka Issi",
        description = "Compact hatchback suitable for city commuting."
    },
    civ_muscle = {
        name        = "Vapid Dominator",
        description = "High-powered muscle car tuned for straight-line performance."
    },
}

----------------------------------------------------------------------
-- Dashboard / Other (skeletons for future expansion)
----------------------------------------------------------------------

L.dashboard = {
    players_online   = "Players",
    staff_online     = "Staff Online",
    reports_open     = "Open Reports",
    quick_actions    = "Quick Actions",
}

L.admin_chat = {
    title            = "Admin Chat",
    input_placeholder = "Type a message to staff…",
}

L.moderation = {
    title            = "Player Moderation",
}

L.settings_ui = {
    title            = "Manage Player Settings",
}

L.world_controls_ui = {
    title            = "World Controls",
}

L.reports_ui = {
    title            = "Reports",
}

L.docs_ui = {
    title            = "Google Docs",
}

----------------------------------------------------------------------
-- Registration
----------------------------------------------------------------------

AS.Locales["en"] = L
return L
