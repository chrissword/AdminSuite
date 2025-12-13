window.AdminSuite = window.AdminSuite || {};

(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});
    AS.app = AS.app || {};
    AS.rbac = AS.rbac || {
        role: null,
        label: null,
        color: null,
        priority: 0,
        flags: {},
    };

    
//========================================
// Local storage helpers (prefs)
//========================================
const PREFS_KEY = "AdminSuite:prefs";
function loadPrefs() {
    try {
        const raw = window.localStorage.getItem(PREFS_KEY);
        return raw ? JSON.parse(raw) : {};
    } catch (e) {
        return {};
    }
}

//========================================
    // Player /report overlay helpers
    //========================================

    function openPlayerReportOverlay(prefill) {
        const overlay = document.getElementById("as-player-report-overlay");
        if (!overlay) return;

        overlay.classList.remove("hidden");

        const subjectEl = document.getElementById("as-player-report-subject");
        const descEl = document.getElementById("as-player-report-description");

        if (subjectEl) subjectEl.value = (prefill && prefill.subject) || "";
        if (descEl) descEl.value = (prefill && prefill.description) || "";

        // default to "general" unless specified
        const type = (prefill && prefill.type) || "general";
        const radios = document.querySelectorAll(
            'input[name="as-player-report-type"]'
        );
        radios.forEach((r) => {
            r.checked = r.value === type;
        });

        const submitBtn = document.getElementById("as-player-report-submit");
        const cancelBtn = document.getElementById("as-player-report-cancel");

        if (submitBtn) {
            submitBtn.onclick = function () {
                const subject = subjectEl ? subjectEl.value.trim() : "";
                const description = descEl ? descEl.value.trim() : "";
                const selected = document.querySelector(
                    'input[name="as-player-report-type"]:checked'
                );
                const reportType = selected ? selected.value : "general";

                if (!description) {
                    if (
                        AdminSuite.utils &&
                        typeof AdminSuite.utils.notify === "function"
                    ) {
                        AdminSuite.utils.notify(
                            "Please provide a description for your report."
                        );
                    }
                    return;
                }

                AdminSuite.utils.sendNuiCallback(
                    "as:nui:reports:submitFromPlayer",
                    {
                        subject,
                        description,
                        reportType,
                    }
                );
            };
        }

        if (cancelBtn) {
            cancelBtn.onclick = function () {
                AdminSuite.utils.sendNuiCallback(
                    "as:nui:reports:cancelPlayer",
                    {}
                );
            };
        }
    }

    function closePlayerReportOverlay() {
        const overlay = document.getElementById("as-player-report-overlay");
        if (!overlay) return;
        overlay.classList.add("hidden");
    }

    //========================================
    // Spectate UI helpers (transparent mode)
    //========================================

    function setSpectateUIActive(active, playerName) {
        const body = document.body;
        if (!body) return;

        if (active) {
            body.classList.add("as-spectate-active");

            if (playerName) {
                const label = document.querySelector(
                    ".as-spectate-player-name"
                );
                if (label) {
                    label.textContent = `Spectating: ${playerName}`;
                }
            }
        } else {
            body.classList.remove("as-spectate-active");
        }
    }

    function updateSpectatePlayerName(playerName) {
        if (!playerName) return;
        const label = document.querySelector(".as-spectate-player-name");
        if (label) {
            label.textContent = `Spectating: ${playerName}`;
        }
    }

    //========================================
    // App init
    //========================================

    AS.app.init = function () {
        // Global AdminSuite Settings (per-user, stored in localStorage)
        if (
            AdminSuite.adminSettings &&
            typeof AdminSuite.adminSettings.init === "function"
        ) {
            AdminSuite.adminSettings.init();
        }

        // Theme toggle
        const themeToggle = document.getElementById("as-theme-toggle");
        if (themeToggle) {
            themeToggle.addEventListener("click", () => {
                const isDark = document.body.classList.contains("theme-dark");
                const next = !isDark;

                if (AdminSuite.utils) {
                    AdminSuite.utils.setDarkMode(next);
                    AdminSuite.utils.sendNuiCallback(
                        "as:nui:panel:setDarkMode",
                        { dark: next }
                    );
                }
            });
        }

        // Close button (bottom-left in nav)
        const closeBtn = document.getElementById("as-panel-close");
        if (closeBtn) {
            closeBtn.addEventListener("click", () => {
                if (AdminSuite.utils) {
                    AdminSuite.utils.sendNuiCallback("as:nui:panel:close", {});
                }
            });
        }

        // Router
        if (AdminSuite.router && typeof AdminSuite.router.init === "function") {
            AdminSuite.router.init();
        }

        // Notify Lua that panel is ready
        if (AdminSuite.utils) {
            AdminSuite.utils.sendNuiCallback("as:nui:panel:ready", {});
        }
    };

    //========================================
    // Handle messages from Lua (SendNUIMessage)
    //========================================

    window.addEventListener("message", (event) => {
        const data = event.data || {};
        // Support both legacy `event` and newer `type` keys
        const ev = data.type || data.event;

        switch (ev) {
            //===============================
            // PANEL / THEME
            //===============================
            case "as:nui:panel:open": {
                const payload =
                    data && data.payload != null ? data.payload : data || {};

                if (AdminSuite.utils && AdminSuite.utils.showPanel) {
                    AdminSuite.utils.showPanel();
                }

                // Apply default theme from Lua config whenever panel is opened.
                // Lua sends `payload.darkMode = true/false`
                if (
                    AdminSuite.utils &&
                    typeof payload.darkMode !== "undefined"
                ) {
                    AdminSuite.utils.setDarkMode(!!payload.darkMode);
                }

                // Re-apply per-user AdminSuite Settings on open (theme override,
                // palettes, toggles that affect rendering).
                if (
                    AdminSuite.adminSettings &&
                    typeof AdminSuite.adminSettings.init === "function"
                ) {
                    AdminSuite.adminSettings.init();
                }


// Decide which view to show on open:
// - If Lua provided an explicit view, we honor it (handled below).
// - Otherwise:
//   * autoOpenLastTab OFF  -> always Dashboard
//   * autoOpenLastTab ON   -> reopen lastViewId (fallback Dashboard)
const shouldAutoOpen =
    AdminSuite.adminSettings &&
    typeof AdminSuite.adminSettings.shouldAutoOpenLastTab === "function"
        ? AdminSuite.adminSettings.shouldAutoOpenLastTab()
        : false;

if (
    !payload.view &&
    AdminSuite.router &&
    typeof AdminSuite.router.navigate === "function"
) {
    if (!shouldAutoOpen) {
        AdminSuite.router.navigate("dashboard");
    } else {
        const prefs = loadPrefs();
        const last =
            (prefs && prefs.lastViewId) ? prefs.lastViewId : "dashboard";
        AdminSuite.router.navigate(last);
    }
}

                // Optional view override from Lua
                if (
                    payload.view &&
                    AdminSuite.router &&
                    typeof AdminSuite.router.navigate === "function"
                ) {
                    AdminSuite.router.navigate(payload.view);
                }
                break;
            }

case "as:nui:panel:close":
    // Hide the panel first
    if (AdminSuite.utils && AdminSuite.utils.hidePanel) {
        AdminSuite.utils.hidePanel();
    }

    // If we're currently on the Moderation view, clear the selected player
    // so that the actions panel shows "No player selected" next time.
    if (
        AdminSuite.router &&
        typeof AdminSuite.router.getCurrentView === "function" &&
        AdminSuite.moderation &&
        typeof AdminSuite.moderation.clearSelection === "function"
    ) {
        const currentView = AdminSuite.router.getCurrentView();
        if (currentView === "moderation" || currentView === "items") {
            AdminSuite.moderation.clearSelection();
        }
    }


    // Ensure transparent spectate mode is cleared when panel is closed
    setSpectateUIActive(false);
    break;


            case "as:nui:panel:setTheme":
                if (data.theme && AdminSuite.utils && AdminSuite.utils.setTheme) {
                    AdminSuite.utils.setTheme(data.theme);
                }
                break;

            case "as:nui:panel:setDarkMode":
                if (AdminSuite.utils && AdminSuite.utils.setDarkMode) {
                    AdminSuite.utils.setDarkMode(!!data.dark);
                }
                break;

//===============================
// DASHBOARD SUMMARY
//===============================
case "as:nui:dashboard:updateSummary": {
    let summary = data.summary ?? data.payload ?? data;

    // Handle shapes like:
    //   { summary: { ... } }
    //   { payload: { players, maxPlayers, ... } }
    if (summary && typeof summary === "object") {
        if (summary.summary && typeof summary.summary === "object") {
            summary = summary.summary;
        } else if (
            summary.payload &&
            typeof summary.payload === "object" &&
            (summary.payload.players != null ||
                summary.payload.maxPlayers != null)
        ) {
            summary = summary.payload;
        }
    }

    if (
        AdminSuite.dashboard &&
        typeof AdminSuite.dashboard.updateSummary === "function"
    ) {
        AdminSuite.dashboard.updateSummary(summary || {});
    }
    break;
}



            //===============================
            // VEHICLES
            //===============================
            case "as:nui:vehicles:load":
            case "as:nui:vehicles:refresh": {
                const payload = data.payload || data;
                const list =
                    (payload && (payload.vehicles || payload.list)) || payload || [];

                if (
                    AdminSuite.vehicles &&
                    typeof AdminSuite.vehicles.setList === "function"
                ) {
                    AdminSuite.vehicles.setList(list);
                }
                break;
            }

            //===============================

            //===============================
// ITEMS
//===============================
case "as:nui:items:load":
case "as:nui:items:refresh": {
    const payload = data.payload || data;
    const list =
        (payload && (payload.items || payload.list)) || payload || [];

    if (AdminSuite.items && typeof AdminSuite.items.setList === "function") {
        AdminSuite.items.setList(list);
    }
    break;
}

// RESOURCES
//===============================
case "as:nui:resources:load":
case "as:nui:resources:refresh": {
    const payload = data.payload || data;
    const list =
        (payload && (payload.resources || payload.list)) || payload || [];

    if (
        AdminSuite.resources &&
        typeof AdminSuite.resources.setList === "function"
    ) {
        AdminSuite.resources.setList(list);
    }
    break;
}


            //===============================
            // MODERATION: PLAYER LIST / DETAIL
            //===============================
            case "as:nui:moderation:loadPlayers":
            case "as:nui:moderation:refreshPlayer": {
                const payload = data.payload != null ? data.payload : data;
                let players = [];

                if (Array.isArray(payload)) {
                    players = payload;
                } else if (Array.isArray(payload.players)) {
                    players = payload.players;
                }

                if (
                    AdminSuite.moderation &&
                    typeof AdminSuite.moderation.updatePlayers === "function"
                ) {
                    AdminSuite.moderation.updatePlayers(players);
                }
                break;
            }

            //===============================
            // MODERATION: CUSTOM INVENTORY WINDOW
            //===============================
            case "as:nui:moderation:openInventory": {
                const payload = data.payload || data;
                if (
                    AdminSuite.moderation &&
                    typeof AdminSuite.moderation.openInventory === "function"
                ) {
                    AdminSuite.moderation.openInventory(payload);
                }
                break;
            }

            //===============================
            // MODERATION: SPECTATE MINI-UI
            //===============================
            case "as:nui:moderation:spectate:start": {
                const payload = data.payload || data;

                // Activate transparent spectate mode
                setSpectateUIActive(true, payload.playerName);

                if (
                    AdminSuite.moderation &&
                    typeof AdminSuite.moderation.onSpectateStart === "function"
                ) {
                    AdminSuite.moderation.onSpectateStart(payload || {});
                }
                break;
            }

            case "as:nui:moderation:spectate:update": {
                const payload = data.payload || data;

                if (payload.playerName) {
                    updateSpectatePlayerName(payload.playerName);
                }

                if (
                    AdminSuite.moderation &&
                    typeof AdminSuite.moderation.onSpectateUpdate === "function"
                ) {
                    AdminSuite.moderation.onSpectateUpdate(payload || {});
                }
                break;
            }

            case "as:nui:moderation:spectate:stop": {
                // Turn off transparent spectate mode
                setSpectateUIActive(false);

                if (
                    AdminSuite.moderation &&
                    typeof AdminSuite.moderation.onSpectateStop === "function"
                ) {
                    AdminSuite.moderation.onSpectateStop();
                }
                break;
            }

            // Direct spectate enter/exit fallbacks
            case "as:spectate:enter": {
                const payload = data.payload || data;
                setSpectateUIActive(true, payload.playerName);
                break;
            }

            case "as:spectate:exit": {
                setSpectateUIActive(false);
                break;
            }

            //===============================
            // SETTINGS
            //===============================
            case "as:nui:settings:load": {
                const payload = data.payload || data;
                if (
                    AdminSuite.settings &&
                    typeof AdminSuite.settings.populate === "function"
                ) {
                    AdminSuite.settings.populate(payload.player || {});
                }
                break;
            }

            //===============================
            // RBAC UPDATE
            //===============================
            case "as:nui:rbac:update": {
                const payload = data.payload || data || {};
                const flags = payload.flags || {};

                const rbac = (AdminSuite.rbac = AdminSuite.rbac || {});
                rbac.role = payload.role || null;
                rbac.label = payload.label || null;
                rbac.color = payload.color || null;
                rbac.priority = payload.priority || 0;
                rbac.flags = flags;

                // Apply nav RBAC
                if (
                    AdminSuite.utils &&
                    typeof AdminSuite.utils.applyNavRBAC === "function"
                ) {
                    AdminSuite.utils.applyNavRBAC();
                }

                // Let settings panel react to RBAC changes (e.g. Admin Management card)
                if (
                    AdminSuite.settings &&
                    typeof AdminSuite.settings.setRBAC === "function"
                ) {
                    AdminSuite.settings.setRBAC(rbac);
                }

                // NEW: let dashboard re-apply RBAC to quick actions / world cards
                if (
                    AdminSuite.dashboard &&
                    typeof AdminSuite.dashboard.onRBACUpdate === "function"
                ) {
                    AdminSuite.dashboard.onRBACUpdate(rbac);
                }

                break;
            }

            //===============================
            // REPORTS (staff view)
            //===============================
            case "as:nui:reports:loadOpen":
            case "as:nui:reports:loadMine":
            case "as:nui:reports:loadAll": {
                const payload = data.payload || data;
                if (
                    AdminSuite.reports &&
                    typeof AdminSuite.reports.updateList === "function"
                ) {
                    AdminSuite.reports.updateList(payload.reports || []);
                }
                break;
            }

            case "as:nui:reports:updateStatus": {
                const payload = data.payload || data;
                if (AdminSuite.reports) {
                    if (
                        payload.reports &&
                        typeof AdminSuite.reports.updateList === "function"
                    ) {
                        AdminSuite.reports.updateList(payload.reports);
                    }
                    if (
                        payload.report &&
                        typeof AdminSuite.reports.select === "function"
                    ) {
                        AdminSuite.reports.select(payload.report);
                    }
                }
                break;
            }

            //===============================
            // BANNED PLAYERS (staff view)
            //===============================
            case "as:nui:bannedplayers:load": {
                const payload = data.payload || data;
                const bans = payload.bans || [];

                if (
                    AdminSuite.bannedPlayers &&
                    typeof AdminSuite.bannedPlayers.updateList === "function"
                ) {
                    AdminSuite.bannedPlayers.updateList(bans);
                }
                break;
            }

            //===============================
            // REPORTS: PLAYER /report OVERLAY
            //===============================
            case "as:nui:reports:openSubmit": {
                const payload = data.payload || data;
                openPlayerReportOverlay(payload || {});
                break;
            }

            case "as:nui:reports:closeSubmit": {
                closePlayerReportOverlay();
                break;
            }

            //===============================
            // GOOGLE DOCS
            //===============================
            case "as:nui:docs:list": {
                const payload = data.payload || data;
                if (
                    AdminSuite.googleDocs &&
                    typeof AdminSuite.googleDocs.updateList === "function"
                ) {
                    AdminSuite.googleDocs.updateList(payload.docs || []);
                }
                break;
            }

            case "as:nui:docs:open": {
                const payload = data.payload || data;
                if (
                    AdminSuite.googleDocs &&
                    typeof AdminSuite.googleDocs.open === "function"
                ) {
                    AdminSuite.googleDocs.open(payload.doc || null);
                }
                break;
            }

            //===============================
            // ADMIN CHAT NUI EVENTS
            //===============================
            case "as:nui:adminchat:loadHistory": {
                const payload = data.payload || data;
                const messages = payload.messages || payload || [];
                if (
                    AdminSuite.dashboard &&
                    typeof AdminSuite.dashboard
                        .updateAdminChatHistory === "function"
                ) {
                    AdminSuite.dashboard.updateAdminChatHistory(messages);
                }
                break;
            }

            case "as:nui:adminchat:receiveMessage": {
                const payload = data.payload || data;
                const entry = payload.entry || payload || null;
                if (
                    entry &&
                    AdminSuite.dashboard &&
                    typeof AdminSuite.dashboard
                        .appendAdminChatMessage === "function"
                ) {
                    AdminSuite.dashboard.appendAdminChatMessage(entry);
                }
                break;
            }

            default:
                // Unknown / unhandled event; safe to ignore
                break;
        }
    });

    //========================================
    // DOM ready wiring
    //========================================
    document.addEventListener("DOMContentLoaded", () => {
        AS.app.init();

        // ESC key closes the AdminSuite panel
        window.addEventListener("keydown", (event) => {
            if (event.key !== "Escape") return;

            // Optional: don't close if typing in an input/textarea
            const active = document.activeElement;
            const tag = active && active.tagName;
            if (tag === "INPUT" || tag === "TEXTAREA") {
                return;
            }

            // Only close if panel is actually open
            const body = document.body;
            const isOpen =
                body && body.getAttribute("data-panel-open") === "true";

            if (!isOpen) return;

            event.preventDefault();
            if (AdminSuite.utils) {
                AdminSuite.utils.sendNuiCallback("as:nui:panel:close", {});
            }
        });
    });
})();
