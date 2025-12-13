window.AdminSuite = window.AdminSuite || {};

(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});
    AS.router = AS.router || {};

    // ---------------------------------------------
    // Simple shared preferences helper
    // - Used here for "Auto-Open Last Tab" support.
    // - admin_settings.js can read/write the same key.
    // ---------------------------------------------
    const PREFS_KEY = "AdminSuite:prefs";

    function loadPrefs() {
        try {
            const raw = window.localStorage.getItem(PREFS_KEY);
            if (!raw) return {};
            const parsed = JSON.parse(raw);
            return parsed && typeof parsed === "object" ? parsed : {};
        } catch (e) {
            return {};
        }
    }

    function savePrefs(next) {
        try {
            const current = loadPrefs();
            const merged = Object.assign({}, current, next || {});
            window.localStorage.setItem(PREFS_KEY, JSON.stringify(merged));
        } catch (e) {
            // ignore write failures (incognito / disabled storage, etc.)
        }
    }

    // ---------------------------------------------
    // View registry
    // ---------------------------------------------
    const VIEWS = {
        dashboard: {
            label: "Dashboard",
            render: (root, state) => AS.dashboard.render(root, state),
        },

        adminchat: {
            label: "Admin Chat",
            render: (root, state) => AS.dashboard.renderAdminChat(root, state),
        },

        moderation: {
            label: "Player Moderation",
            render: (root, state) => AS.moderation.render(root, state),
        },

        // Discipline
        discipline: {
            label: "Discipline",
            render: (root, state) => AS.discipline.render(root, state),
        },

        // Banned Players
        bannedplayers: {
            label: "Banned Players",
            render: (root, state) => AS.bannedPlayers.render(root, state),
        },

        // Audit Log
        audit: {
            label: "Audit Log",
            render: (root, state) => AS.audit.render(root, state),
        },

        // Player Settings (per-player, jobs, gangs, admins, etc.)
        settings: {
            label: "Player Settings",
            render: (root, state) => AS.settings.render(root, state),
        },

        // Items
        items: {
            label: "Items",
            render: (root, state) =>
                AS.items && typeof AS.items.render === "function"
                    ? AS.items.render(root, state)
                    : null,
        },

        // Vehicles
        vehicles: {
            label: "Vehicles",
            render: (root, state) => AS.vehicles.render(root, state),
        },

        // World Controls
        world: {
            label: "World Controls",
            render: (root, state) => AS.dashboard.renderWorld(root, state),
        },

        // Resources
        resources: {
            label: "Resources",
            render: (root, state) =>
                AS.resources && typeof AS.resources.render === "function"
                    ? AS.resources.render(root, state)
                    : null,
        },

        // Reports
        reports: {
            label: "Reports",
            render: (root, state) => AS.reports.render(root, state),
        },

        // Global AdminSuite Settings (separate from Player Settings)
        adminsettings: {
            label: "Settings",
            render: (root, state) =>
                AS.adminSettings && typeof AS.adminSettings.render === "function"
                    ? AS.adminSettings.render(root, state)
                    : null,
        },

        // Google Docs
        docs: {
            label: "Google Docs",
            render: (root, state) => AS.googleDocs.render(root, state),
        },
    };

    // ---------------------------------------------
    // Router state
    // ---------------------------------------------
    let currentView = "dashboard";

    // ---------------------------------------------
    // Init – called once when NUI loads
    // ---------------------------------------------
    AS.router.init = function () {
        const main = document.getElementById("as-main");
        if (!main) return;

        // Respect "Auto-Open Last Tab" if enabled in AdminSuite Settings.
        // If disabled, we always default back to Dashboard on open.
        const prefs = loadPrefs();
        const allowAutoOpen =
            AS.adminSettings &&
            typeof AS.adminSettings.shouldAutoOpenLastTab === "function"
                ? AS.adminSettings.shouldAutoOpenLastTab()
                : true;

        if (allowAutoOpen && prefs.lastViewId && VIEWS[prefs.lastViewId]) {
            currentView = prefs.lastViewId;
        } else {
            currentView = "dashboard";
        }

        const initial = VIEWS[currentView];
        if (initial && typeof initial.render === "function") {
            initial.render(main, {});

            if (AS.utils) {
                AS.utils.setHeaderContext(initial.label);
                AS.utils.setActiveNav(currentView);
            }
        }

        // Hook up navigation buttons
        document.querySelectorAll(".as-nav__item").forEach((btn) => {
            btn.addEventListener("click", () => {
                // Ignore disabled nav items
                if (btn.hasAttribute("data-disabled")) return;

                const target = btn.getAttribute("data-view");
                if (!target || !VIEWS[target]) return;

                AS.router.navigate(target);
            });
        });
    };

    // ---------------------------------------------
    // Navigate to a given view
    // ---------------------------------------------
    AS.router.navigate = function (viewId, state) {
        const view = VIEWS[viewId];
        if (!view) return;

        const viewRoot = document.getElementById("as-main");
        if (!viewRoot) return;

        const previousView = currentView;
        currentView = viewId;

        // Clear existing DOM for the view region
        viewRoot.innerHTML = "";

        // If we are leaving the Items view, clear the selected player
        // so Items' target player does not persist across navigations.
        if (
            previousView === "items" &&
            AS.moderation &&
            typeof AS.moderation.clearSelection === "function"
        ) {
            AS.moderation.clearSelection();
        }

        if (view && typeof view.render === "function") {
            view.render(viewRoot, state || {});
        }

        // Persist last view so "Auto-Open Last Tab" can use it
        savePrefs({ lastViewId: currentView });

        if (AS.utils) {
            AS.utils.setHeaderContext(view.label);
            AS.utils.setActiveNav(currentView);
        }
    };

    // ---------------------------------------------
    // Getter for current view id
    // ---------------------------------------------
    AS.router.getCurrentView = function () {
        return currentView;
    };
})();
