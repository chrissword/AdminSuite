window.AdminSuite = window.AdminSuite || {};

(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});

    AS.utils = AS.utils || {};

    AS.utils.resourceName =
        typeof GetParentResourceName === "function"
            ? GetParentResourceName()
            : "AdminSuite";

    /**
     * Send data back to Lua via NUI callback
     * name: callback name (recommend mirroring as:nui:* namespace or a short alias)
     */
    AS.utils.sendNuiCallback = function (name, data) {
        try {
            fetch(`https://${AS.utils.resourceName}/${name}`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json; charset=utf-8",
                },
                body: JSON.stringify(data || {}),
            }).catch((e) => console.error("AdminSuite NUI fetch error:", e));
        } catch (e) {
            console.error("AdminSuite NUI callback failed:", e);
        }
    };

    AS.utils.setTheme = function (theme) {
        const body = document.body;
        if (theme === "light") {
            body.classList.remove("theme-dark");
            body.classList.add("theme-light");
        } else {
            body.classList.remove("theme-light");
            body.classList.add("theme-dark");
        }
    };

    AS.utils.setDarkMode = function (isDark) {
        AS.utils.setTheme(isDark ? "dark" : "light");
    };

    AS.utils.setHeaderContext = function (text) {
        const el = document.getElementById("as-header-context");
        if (el) el.textContent = text || "";
    };

    /**
     * Update the header counters (Players / Staff / Open Reports)
     * Called from dashboard.updateSummary(...)
     */
    AS.utils.updateHeaderCounters = function (data) {
        const players     = (data && typeof data.players === "number") ? data.players : 0;
        const maxPlayers  = (data && typeof data.maxPlayers === "number") ? data.maxPlayers : 0;
        const staffOnline = (data && typeof data.staffOnline === "number") ? data.staffOnline : 0;
        const openReports = (data && typeof data.openReports === "number") ? data.openReports : 0;

        const p = document.getElementById("as-header-players");
        const s = document.getElementById("as-header-staff");
        const r = document.getElementById("as-header-reports");

        if (p) {
            p.textContent = `${players} / ${maxPlayers}`;
        }
        if (s) {
            s.textContent = String(staffOnline);
        }
        if (r) {
            r.textContent = String(openReports);
        }
    };

    AS.utils.showPanel = function () {
        const root = document.getElementById("adminsuite-root");
        if (!root) return;
        root.classList.remove("hidden");
        document.body.dataset.panelOpen = "true";
    };

    // ========================================
    // Toast notifications (bottom-center)
    // ========================================

    (function setupNotify() {
        function ensureRoot() {
            let root = document.getElementById("as-toast-root");
            if (!root) {
                root = document.createElement("div");
                root.id = "as-toast-root";
                root.className = "as-toast-root";
                document.body.appendChild(root);
            }
            return root;
        }

        AS.utils.notify = function (message, options) {
            if (!message) return;

            const root = ensureRoot();

            const type =
                (options && options.type) ||
                (typeof options === "string" ? options : "info");
            const duration =
                typeof options?.duration === "number" ? options.duration : 3500;

            const toast = document.createElement("div");
            toast.className = `as-toast as-toast--${type}`;

            const iconWrap = document.createElement("div");
            iconWrap.className = "as-toast__icon";

            const iconImg = document.createElement("img");

            // If you ever add more icons later, you can switch on `type`,
            // but for now we just always use notification.png.
            iconImg.src = "img/notification.png";
            iconImg.alt = (type || "info") + " notification";

            iconWrap.appendChild(iconImg);

            const text = document.createElement("div");
            text.className = "as-toast__text";
            text.textContent = message;

            toast.appendChild(iconWrap);
            toast.appendChild(text);
            root.appendChild(toast);

            // Keep the last few toasts visible; drop the oldest if we exceed the cap.
            const maxToasts = 4;
            while (root.children.length > maxToasts) {
                root.removeChild(root.firstElementChild);
            }

            window.setTimeout(() => {
                toast.classList.add("as-toast--hide");
                window.setTimeout(() => {
                    if (root.contains(toast)) {
                        root.removeChild(toast);
                    }
                }, 220);
            }, duration);
        };
    })();

    AS.utils.hidePanel = function () {
        const root = document.getElementById("adminsuite-root");
        if (!root) return;
        root.classList.add("hidden");
        document.body.dataset.panelOpen = "false";
    };

    AS.utils.setActiveNav = function (viewId) {
        document.querySelectorAll(".as-nav__item").forEach((btn) => {
            btn.classList.toggle(
                "as-nav__item--active",
                btn.getAttribute("data-view") === viewId
            );
        });
    };

    /**
     * Hide nav items based on RBAC flags.
     *
     * Rule: if *no* actions for a route are allowed for the role,
     *       hide that nav entry.
     */
    AS.utils.applyNavRBAC = function () {
        const ASGlobal = window.AdminSuite || {};
        const rbac = ASGlobal.rbac || {};

        // If RBAC isn't loaded yet, don't touch nav.
        if (!rbac.role) return;

        const flags = rbac.flags || {};
        const hasFullAccess = !!flags.full_access;

        const hasFlag = (name) => {
            if (!name) return true;
            return hasFullAccess || !!flags[name];
        };

        // Map nav "viewId" -> RBAC flag(s) that power that section.
        // If NONE of these flags are true, hide that nav item.
        const navRequirements = {
            // Player Moderation: any moderation / economy flag
            moderation: [
                "can_kick",
                "can_warn",
                "can_ban_perm",
                "can_ban_temp",
                "can_heal_revive",
                "can_freeze",
                "can_teleport",
                "can_spectate",
                "can_view_inv",
                "can_give_item",
                "can_take_item",
                "can_give_money",
                "can_take_money",
            ],

            // Discipline
            discipline: "can_view_discipline",

            // Banned Players (Unban)
            bannedplayers: ["can_ban_perm", "can_ban_temp"],

            // World Controls
            world: "can_use_world",

            // Player Settings: management-style things (per-player)
            settings: [
                "can_manage_jobs",
                "can_manage_gangs",
                "can_manage_staff_roles",
            ],

            // Global AdminSuite Settings
            adminsettings: ["can_view_settings", "can_manage_settings"],
            

            // Google Docs
            docs: "can_manage_docs",

            // Vehicles: any vehicle tool
            vehicles: [
                "can_spawn_vehicle",
                "can_fix_vehicle",
                "can_wash_vehicle",
                "can_refuel_vehicle",
                "can_delete_vehicle",
                "can_seat_in_vehicle",
                "can_seat_out_vehicle",
            ],

            // Reports: view or handle
            reports: ["can_view_reports", "can_handle_reports"],

            // Resources: can see resources view
            resources: "can_view_resources",

            // Items: give / take items (for when Items nav is added)
            items: ["can_give_item", "can_take_item"],
        };

        document.querySelectorAll(".as-nav__item").forEach((btn) => {
            const viewId = btn.getAttribute("data-view");
            const requirement = navRequirements[viewId];

            // No requirement defined → always visible
            if (!requirement) return;

            let allowed = true;

            if (Array.isArray(requirement)) {
                // Allowed if ANY required flag is true
                allowed = requirement.some((flag) => hasFlag(flag));
            } else if (typeof requirement === "string") {
                allowed = hasFlag(requirement);
            }

            if (!allowed) {
                btn.classList.add("as-hidden-rbac");
            } else {
                btn.classList.remove("as-hidden-rbac");
            }
        });

        // If the current view is now hidden, bump the user back to Dashboard
        if (AS.router && typeof AS.router.getCurrentView === "function") {
            const currentView = AS.router.getCurrentView();
            if (currentView) {
                const currentBtn = document.querySelector(
                    `.as-nav__item[data-view="${currentView}"]`
                );
                if (
                    currentBtn &&
                    currentBtn.classList.contains("as-hidden-rbac") &&
                    typeof AS.router.navigate === "function"
                ) {
                    AS.router.navigate("dashboard");
                }
            }
        }
    };
})();
