-- Optional Google Docs / Sheets configuration.
-- Each entry can specify:
--   title    (required)  - display name
--   url      (required)  - full Google Docs/Sheets URL
--   type     (optional)  - 'doc' | 'sheet' (used for icon hint only)
--   id       (optional)  - override auto-generated id
--   minRole  (optional)  - minimum staff role to view (defaults to 'helper')
--   editRole (optional)  - minimum staff role to request edit (defaults to 'admin')
--   icon     (optional)  - custom icon text/emoji shown in the list
--
-- You can freely edit this list without touching any Lua logic.

Config.Docs = {
   --[[ {
        title = "Staff Rules",
        url   = "https://docs.google.com/document/d/XXXXXXXXXXXXXXX",
        type  = "doc",
    },--]]
    {
        title = "MCSO SOP",
        url   = "https://docs.google.com/document/d/1bOJ6wwfZcyczPh0ziPakIF-tqTSduWg1UikaiuRVegk/edit?usp=sharing",
        type  = "doc",
    },
    {
        title = "Staff Handbook",
        url   = "https://docs.google.com/document/d/1Uzoeh-cWjvr7gE5ue0CG4Ss_Gqf1LhA-gxSiTJsm2zM/edit?usp=sharing",
        type  = "docs",
    },
 --[[]   {
        title = "MCRP Disipline Tracker",
        url   = "https://docs.google.com/spreadsheets/d/e/2PACX-1vQcnegiSPihoARm2Iy-huIAipRQfDFs8gfCGa5rNFiCwOwmpJyitRNm2PsPrhbBZMQpuk4CKnpgNcZI/pubhtml",
        type  = "sheet",
    },--]]
}

Config.DisciplineSheet = {
    apiUrl = "https://script.google.com/macros/s/AKfycbwKqf35VaGq1uHrEUcGB4LRVeV6WH4hAIDeaYtzAW4StrkbzbClASdKJAj4y-OKBu1iPQ/exec",
    secret = "AdminSuite2025_DisciplineTracker12_4_2025", -- must match SHARED_SECRET in Apps Script

    -- RBAC thresholds
    minRoleView  = "mod",   -- minimum RBAC role to see the tracker UI
    minRoleAdd   = "mod",   -- can create new entries
    minRoleEdit  = "admin", -- can edit existing entries
    minRoleDelete= "admin", -- can delete entries
}
