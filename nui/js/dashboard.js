window.AdminSuite = window.AdminSuite || {};

(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});
    AS.dashboard = AS.dashboard || {};

    // Keep track of last rendered roots so we can re-apply RBAC
    let lastDashboardRoot = null;
    let lastWorldRoot = null;

    //========================================
    // Shared prefs helper (matches router.js)
    //========================================
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

    //========================================
    // Events
    //========================================

    const DASH_COPY_EVENT = "as:nui:dashboard:copyResult";
    const DASH_RECENT_EVENT = "as:nui:dashboard:recent";
    const NOTIFY_EVENT = "as:nui:notify";

    //========================================
    // RBAC helpers
    //========================================

    function getRBACFlags() {
        const ASGlobal = window.AdminSuite || {};
        const rbac = ASGlobal.rbac || {};

        // If role not set yet, don't filter anything (avoid hiding everything
        // before RBAC is loaded from Lua).
        if (!rbac.role) return null;

        return rbac.flags || {};
    }

    function makeRBACChecker() {
        const flags = getRBACFlags();
        if (!flags) {
            // Return a checker that always "allows" when RBAC isn't ready.
            return {
                ready: false,
                has: () => true,
            };
        }

        const hasFullAccess = !!flags.full_access;
        const has = (name) =>
            hasFullAccess || (name && flags && !!flags[name]);

        return { ready: true, has, hasFullAccess, flags };
    }

    function applyRBACToQuickActions(root) {
        if (!root) return;

        const { ready, has } = makeRBACChecker();
        if (!ready) return;

        // Map Quick Action chips -> RBAC flags.
        // Keys are `${group}:${id}`.
        const requirements = {
            // Self utilities
            "self:heal": "can_heal_revive",
            "self:revive": "can_heal_revive",
            "self:god-mode": "can_self_godmode",
            "self:super-jump": "can_self_powers",
            "self:fast-run": "can_self_powers",
            "self:infinite-stamina": "can_self_powers",
            "self:clear-blood": "can_self_cosmetic",
            "self:wet-clothes": "can_self_cosmetic",
            "self:dry-clothes": "can_self_cosmetic",

            // Developer tools – copy helpers + overlays
            "dev:copy-v3": "can_use_devtools",
            "dev:copy-v4": "can_use_devtools",
            "dev:copy-heading": "can_use_devtools",
            "dev:copy-cam-rot": "can_use_devtools",
            "dev:copy-entity-model": "can_use_devtools",
            "dev:toggle-dev-overlay": "can_use_devtools",
            "dev:toggle-entity-info": "can_use_devtools",

            // Vehicle tools
            "vehicle:spawn": "can_spawn_vehicle",
            "vehicle:fix": "can_fix_vehicle",
            "vehicle:wash": "can_wash_vehicle",
            "vehicle:refuel": "can_refuel_vehicle",
            "vehicle:delete": "can_delete_vehicle",
            "vehicle:seat-in": "can_seat_in_vehicle",
            "vehicle:seat-out": "can_seat_out_vehicle",

            // Management tools
            "mgmt:toggle-ids": "can_toggle_ids",
            "mgmt:toggle-names": "can_toggle_names",
            "mgmt:toggle-radar": "can_toggle_radar",
        };

        // Hide disallowed chips
        const qaButtons = root.querySelectorAll(".as-qa-grid [data-qa]");
        qaButtons.forEach((btn) => {
            const group = btn.getAttribute("data-qa");
            const id = btn.getAttribute("data-id");
            const key = `${group}:${id}`;
            const requirement = requirements[key];

            let allowed = true;
            if (Array.isArray(requirement)) {
                allowed = requirement.some((f) => has(f));
            } else if (typeof requirement === "string") {
                allowed = has(requirement);
            }

            if (!allowed) {
                btn.classList.add("as-hidden-rbac");
            }
        });

        // Hide tabs that have no visible actions
        ["self", "dev", "vehicle", "mgmt"].forEach((group) => {
            const tabBtn = root.querySelector(
                `.as-qa-tab[data-qa-tab="${group}"]`
            );
            if (!tabBtn) return;

            const visibleButtons = Array.from(
                root.querySelectorAll(
                    `.as-qa-grid [data-qa="${group}"]:not(.as-hidden-rbac)`
                )
            );

            if (visibleButtons.length === 0) {
                tabBtn.classList.add("as-hidden-rbac");
            }
        });
    }

    function applyRBACToWorld(root) {
        if (!root) return;

        const { ready, has } = makeRBACChecker();
        if (!ready) return;

        // World controls: time + weather
        const timeCard = root.querySelector("#as-world-time-apply")?.closest(
            ".as-card"
        );
        const weatherCard = root.querySelector(
            "#as-world-weather-apply"
        )?.closest(".as-card");

        if (timeCard && !has("can_world_time")) {
            timeCard.classList.add("as-hidden-rbac");
        }

        if (weatherCard && !has("can_world_weather")) {
            weatherCard.classList.add("as-hidden-rbac");
        }
    }

    //========================================
    // DEV COPY → CLIPBOARD SUPPORT
    //========================================

    function fallbackCopyText(text) {
        if (!text) return false;

        try {
            const textArea = document.createElement("textarea");
            textArea.value = text;

            textArea.style.position = "fixed";
            textArea.style.top = "0";
            textArea.style.left = "0";
            textArea.setAttribute("readonly", "");

            document.body.appendChild(textArea);
            textArea.focus();
            textArea.select();

            const successful = document.execCommand("copy");
            document.body.removeChild(textArea);

            if (!successful) {
                console.warn(
                    "[AdminSuite] document.execCommand('copy') reported false"
                );
            }
            return successful;
        } catch (e) {
            console.error("AdminSuite fallback clipboard copy failed:", e);
            return false;
        }
    }

    function applyCopyFeedbackButton(id) {
        if (!id) return;

        const btn = document.querySelector(
            '.as-qa-grid [data-qa="dev"][data-id="' + id + '"]'
        );
        if (!btn) return;

        const original = btn.textContent;
        if (!btn.dataset.originalLabel) {
            btn.dataset.originalLabel = original;
        }

        btn.textContent = "Copied!";
        btn.classList.add("as-chip--copied");

        setTimeout(() => {
            btn.textContent = btn.dataset.originalLabel || original;
            btn.classList.remove("as-chip--copied");
        }, 900);
    }

    function copyTextToClipboard(id, label, text) {
        if (!text) return;

        const ok = fallbackCopyText(text);
        console.log(
            `[AdminSuite] Clipboard copy ${
                ok ? "succeeded" : "attempted"
            } for ${label || "value"}`
        );

        // Visual feedback regardless – button flips to "Copied!"
        applyCopyFeedbackButton(id);
    }

    AS.dashboard.handleClipboardCopy = function (payload) {
        if (!payload) return;

        const text = payload.text || payload.value || payload.clipboard || "";
        const label = payload.label || "value";
        const id = payload.id || null;

        if (!text) {
            console.warn(
                "[AdminSuite] clipboard copy requested but no text present in payload:",
                payload
            );
            return;
        }

        copyTextToClipboard(id, label, text);
    };

    // Listen for Lua → NUI dashboard events
    window.addEventListener("message", (event) => {
        const data = event.data || {};
        const evt = data.event;

        if (!evt) return;

        // Dev copy
        if (evt === DASH_COPY_EVENT) {
            const payload = data.payload || data;
            AS.dashboard.handleClipboardCopy(payload);
            return;
        }

        // Generic notifications (Lua → NUI)
        if (evt === NOTIFY_EVENT) {
            const payload = data.payload || data;
            const msg = payload.message || payload.text || "";
            const type = payload.type || "info";

            if (
                AdminSuite.utils &&
                typeof AdminSuite.utils.notify === "function"
            ) {
                AdminSuite.utils.notify(msg, { type });
            }
            return;
        }

        // Recent actions (dashboard "Recent Actions" card)
        if (evt === DASH_RECENT_EVENT) {
            const payload = data.payload || data;
            const entries = payload.entries || payload.data || payload || [];
            AS.dashboard.updateRecentActions(entries);
            return;
        }
    });

    //===============================
    // DASHBOARD MAIN VIEW
    //===============================
    AS.dashboard.render = function (root) {
        // Track last dashboard root so we can re-apply RBAC when RBAC updates
        lastDashboardRoot = root;

        root.innerHTML = `
            <div class="as-grid">

                <!-- Row 1: Online Snapshot -->
                <section class="as-card" style="grid-column: span 12;">
                    <header class="as-card__header">
                        <div>
                            <h2 class="as-card__title">Online Snapshot</h2>
                            <p class="as-card__subtitle">Players, staff &amp; reports at a glance</p>
                        </div>
                        <button class="as-chip" id="as-dash-refresh">Refresh</button>
                    </header>
                    <div class="as-card__body" id="as-dash-summary">
                        Loading summary…
                    </div>
                </section>

                <!-- Row 2: Quick Actions full-width -->
                <section class="as-card" style="grid-column: span 12;">
                    <header class="as-card__header">
                        <div>
                            <h2 class="as-card__title">Quick Actions</h2>
                            <p class="as-card__subtitle">Self, developer, vehicle, and management utilities</p>
                        </div>
                    </header>

                    <div class="as-card__body">
                        <!-- Tabs -->
                        <div class="as-qa-tabs" style="display:flex; gap:6px; margin-bottom:8px;">
                            <button class="as-chip as-chip--tab as-qa-tab as-qa-tab--active" data-qa-tab="self">
                                Self
                            </button>
                            <button class="as-chip as-chip--tab as-qa-tab" data-qa-tab="dev">
                                Developer
                            </button>
                            <button class="as-chip as-chip--tab as-qa-tab" data-qa-tab="vehicle">
                                Vehicle
                            </button>
                            <button class="as-chip as-chip--tab as-qa-tab" data-qa-tab="mgmt">
                                Management
                            </button>
                        </div>

                        <!-- Actions Grid -->
                        <div class="as-grid as-qa-grid">
                            <!-- Self Utilities -->
                            <div style="grid-column: span 12; margin-bottom: 10px;">
                                <p class="as-card__subtitle">Self Utilities</p>

                                <!-- Row 1 -->
                                <button class="as-chip as-chip--self" data-qa="self" data-id="heal">
                                    Heal
                                </button>
                                <button class="as-chip as-chip--self" data-qa="self" data-id="revive">
                                    Revive
                                </button>
                                <button class="as-chip as-chip--self" data-qa="self" data-id="god-mode">
                                    God Mode
                                </button>

                                <!-- Row 2 -->
                                <button class="as-chip as-chip--self" data-qa="self" data-id="super-jump">
                                    Super Jump
                                </button>
                                <button class="as-chip as-chip--self" data-qa="self" data-id="fast-run">
                                    Fast Run
                                </button>
                                <button class="as-chip as-chip--self" data-qa="self" data-id="infinite-stamina">
                                    Infinite Stamina
                                </button>

                                <!-- Row 3 -->
                                <button class="as-chip as-chip--self" data-qa="self" data-id="clear-blood">
                                    Clear Blood
                                </button>
                                <button class="as-chip as-chip--self" data-qa="self" data-id="wet-clothes">
                                    Wet Clothes
                                </button>
                                <button class="as-chip as-chip--self" data-qa="self" data-id="dry-clothes">
                                    Dry Clothes
                                </button>
                            </div>

                            <!-- Developer Tools: copy helpers -->
                            <button class="as-chip as-chip--dev" data-qa="dev" data-id="copy-v3">
                                Copy vector3 coords
                            </button>
                            <button class="as-chip as-chip--dev" data-qa="dev" data-id="copy-v4">
                                Copy vector4 coords
                            </button>
                            <button class="as-chip as-chip--dev" data-qa="dev" data-id="copy-heading">
                                Copy heading
                            </button>
                            <button class="as-chip as-chip--dev" data-qa="dev" data-id="copy-cam-rot">
                                Copy camera rotation
                            </button>
                            <button class="as-chip as-chip--dev" data-qa="dev" data-id="copy-entity-model">
                                Copy entity model/hash
                            </button>

                            <!-- Developer Tools: toggles -->
                            <button class="as-chip as-chip--dev" data-qa="dev" data-id="toggle-dev-overlay">
                                Toggle dev overlay
                            </button>
                            <button class="as-chip as-chip--dev" data-qa="dev" data-id="toggle-entity-info">
                                Toggle entity info
                            </button>

                            <!-- Vehicle Tools -->
                            <div style="grid-column: span 12; margin-bottom: 10px;">
                                <p class="as-card__subtitle">Vehicle Tools</p>

                                <button class="as-chip as-chip--mgmt" data-qa="vehicle" data-id="spawn">
                                    Spawn default vehicle
                                </button>
                                <button class="as-chip as-chip--mgmt" data-qa="vehicle" data-id="fix">
                                    Repair vehicle
                                </button>
                                <button class="as-chip as-chip--mgmt" data-qa="vehicle" data-id="wash">
                                    Wash vehicle
                                </button>
                                <button class="as-chip as-chip--mgmt" data-qa="vehicle" data-id="refuel">
                                    Refuel vehicle
                                </button>
                                <button class="as-chip as-chip--mgmt" data-qa="vehicle" data-id="delete">
                                    Delete vehicle
                                </button>
                                <button class="as-chip as-chip--mgmt" data-qa="vehicle" data-id="seat-in">
                                    Seat in vehicle
                                </button>
                                <button class="as-chip as-chip--mgmt" data-qa="vehicle" data-id="seat-out">
                                    Seat out of vehicle
                                </button>
                            </div>

                            <!-- Management Tools -->
                            <button class="as-chip as-chip--mgmt" data-qa="mgmt" data-id="toggle-ids">
                                Toggle IDs
                            </button>
                            <button class="as-chip as-chip--mgmt" data-qa="mgmt" data-id="toggle-names">
                                Toggle Names
                            </button>
                            <button class="as-chip as-chip--mgmt" data-qa="mgmt" data-id="toggle-radar">
                                Toggle Radar
                            </button>
                        </div>
                    </div>
                </section>

                <!-- Row 3: Recent Actions -->
                <section class="as-card as-dash-card" id="as-dash-recent-card" style="grid-column: span 12;">
                    <header class="as-card__header">
                        <div>
                            <h2 class="as-card__title">Recent Actions</h2>
                            <p class="as-card__subtitle">Latest audit entries</p>
                        </div>
                        <div>
                            <button class="as-chip" id="as-dash-open-audit">Open Audit View</button>
                            <button
                                class="as-chip as-chip--danger"
                                id="as-dash-recent-clear"
                                style="display:none;"
                            >
                                Clear Recent Actions
                            </button>
                        </div>
                    </header>
                    <div class="as-card__body" id="as-dash-recent-body">
                        <p class="as-card__subtitle">No recent actions in audit log.</p>
                    </div>
                </section>

            </div>
        `;

        // Refresh summary
        const refreshBtn = root.querySelector("#as-dash-refresh");
        if (refreshBtn) {
            refreshBtn.addEventListener("click", () => {
                AdminSuite.utils.sendNuiCallback(
                    "as:nui:dashboard:getSummary",
                    {}
                );
            });
        }

        // Open audit panel → use router directly
        const openAudit = root.querySelector("#as-dash-open-audit");
        if (openAudit) {
            openAudit.addEventListener("click", () => {
                if (
                    window.AdminSuite &&
                    AdminSuite.router &&
                    typeof AdminSuite.router.navigate === "function"
                ) {
                    AdminSuite.router.navigate("audit");
                } else {
                    console.warn("[AdminSuite] router.navigate('audit') not available");
                }
            });
        }

        // Clear recent actions (NUI → Lua → server)
        const clearRecentBtn = root.querySelector("#as-dash-recent-clear");
        if (clearRecentBtn) {
            clearRecentBtn.addEventListener("click", () => {
                AdminSuite.utils.sendNuiCallback(
                    "as:nui:dashboard:clearRecent",
                    {}
                );
            });
        }

        // Apply RBAC hiding to Quick Actions BEFORE we wire up tabs
        applyRBACToQuickActions(root);

        // Quick Actions → Lua + auto-close
        root.querySelectorAll("[data-qa]").forEach((btn) => {
            btn.addEventListener("click", () => {
                // Ignore buttons that are hidden via RBAC
                if (btn.classList.contains("as-hidden-rbac")) return;

                const group = btn.getAttribute("data-qa");
                const id = btn.getAttribute("data-id");

                if (AdminSuite && AdminSuite.utils) {
                    AdminSuite.utils.sendNuiCallback(
                        "as:nui:dashboard:runQuickAction",
                        {
                            group,
                            id,
                        }
                    );

                    // Auto-close the main AdminSuite panel for all quick actions
                    AdminSuite.utils.sendNuiCallback(
                        "as:nui:panel:close",
                        {}
                    );
                }
            });
        });

        // Tabs: Self / Developer / Vehicle / Management
        const tabs = root.querySelectorAll(".as-qa-tab");
        const qaButtons = root.querySelectorAll(".as-qa-grid [data-qa]");

        function hasVisibleGroupButtons(group) {
            return Array.from(
                root.querySelectorAll(
                    `.as-qa-grid [data-qa="${group}"]:not(.as-hidden-rbac)`
                )
            ).length;
        }

        function setActiveTab(tab) {
            // If requested tab has no visible buttons, find first available group
            if (!hasVisibleGroupButtons(tab)) {
                const fallback = ["self", "dev", "vehicle", "mgmt"].find(
                    (g) =>
                        hasVisibleGroupButtons(g) &&
                        !root
                            .querySelector(
                                `.as-qa-tab[data-qa-tab="${g}"]`
                            )
                            ?.classList.contains("as-hidden-rbac")
                );
                if (fallback) {
                    tab = fallback;
                }
            }

            tabs.forEach((t) => {
                const name = t.getAttribute("data-qa-tab");
                const isActive = name === tab;
                t.classList.toggle("as-qa-tab--active", isActive);
            });

            qaButtons.forEach((btn) => {
                const group = btn.getAttribute("data-qa");
                const hidden = btn.classList.contains("as-hidden-rbac");
                if (hidden) {
                    btn.style.display = "none";
                    return;
                }
                btn.style.display = group === tab ? "" : "none";
            });
        }

        // Click handling for tabs
        tabs.forEach((tabBtn) => {
            if (tabBtn.classList.contains("as-hidden-rbac")) return;

            tabBtn.addEventListener("click", () => {
                const tab = tabBtn.getAttribute("data-qa-tab");
                setActiveTab(tab);
            });
        });

        // Initial tab: pick first tab that is not hidden & has visible actions
        let initialTab = "self";
        const candidate = ["self", "dev", "vehicle", "mgmt"].find((g) => {
            const tabEl = root.querySelector(
                `.as-qa-tab[data-qa-tab="${g}"]`
            );
            return (
                tabEl &&
                !tabEl.classList.contains("as-hidden-rbac") &&
                hasVisibleGroupButtons(g)
            );
        });
        if (candidate) {
            initialTab = candidate;
        }
        setActiveTab(initialTab);

        // Initial summary request
        AdminSuite.utils.sendNuiCallback("as:nui:dashboard:getSummary", {});
    };

    //===============================
    // SNAPSHOT UPDATE
    //===============================
    AS.dashboard.updateSummary = function (data) {
        const container = document.getElementById("as-dash-summary");
        if (!container) return;

        const {
            players,
            maxPlayers,
            staffOnline,
            openReports,
            recentAudit,
            canViewRecentActions,
            canClearRecentActions,
        } = data || {};

        container.innerHTML = `
            <div style="display:grid; grid-template-columns: repeat(3, minmax(0,1fr)); gap:8px;">
                <div class="as-metric-box">
                    <div class="as-metric-value">${players ?? 0} / ${maxPlayers ?? 0}</div>
                    <div class="as-metric-label">Players Online</div>
                </div>
                <div class="as-metric-box">
                    <div class="as-metric-value">${staffOnline ?? 0}</div>
                    <div class="as-metric-label">Staff On Duty</div>
                </div>
                <div class="as-metric-box">
                    <div class="as-metric-value">${openReports ?? 0}</div>
                    <div class="as-metric-label">Open Reports</div>
                </div>
            </div>
        `;

        // Update header counters if present
        if (
            AdminSuite.utils &&
            AdminSuite.utils.updateHeaderCounters
        ) {
            AdminSuite.utils.updateHeaderCounters({
                players,
                maxPlayers,
                staffOnline,
                openReports,
            });
        }

        // RBAC gating for Recent Actions card
        const recentCard = document.getElementById("as-dash-recent-card");
        const clearBtn = document.getElementById("as-dash-recent-clear");

        const canViewRecent = !!canViewRecentActions;
        const canClearRecent = !!canClearRecentActions;

        if (recentCard) {
            recentCard.style.display = canViewRecent ? "" : "none";
        }

        if (clearBtn) {
            clearBtn.style.display = canClearRecent ? "" : "none";
        }

        // Only update the list if the user can view it
        if (canViewRecent && Array.isArray(recentAudit)) {
            AS.dashboard.updateRecentActions(recentAudit);
        } else if (canViewRecent) {
            // Show "no recent actions" state for permitted roles
            AS.dashboard.updateRecentActions([]);
        } else {
            // If they can't view, clear any UI
            AS.dashboard.updateRecentActions([]);
        }
    };

    //===============================
    // RECENT ACTIONS CARD RENDERING
    //===============================
    function formatAuditTime(ts) {
        if (!ts) return "";
        try {
            const d = new Date(ts * 1000);
            const hh = String(d.getHours()).padStart(2, "0");
            const mm = String(d.getMinutes()).padStart(2, "0");
            return `${hh}:${mm}`;
        } catch (e) {
            return "";
        }
    }

    function formatAuditLabel(entry) {
        if (!entry) return "";

        const event = entry.event_name || entry.event || "unknown";
        const actor = entry.actor_identifier || entry.actor || "unknown";
        const target =
            entry.target_identifier || entry.target || null;

        let line = event;
        line += ` • ${actor}`;
        if (target) {
            line += ` → ${target}`;
        }

        return line;
    }

    AS.dashboard.updateRecentActions = function (entries) {
        const container = document.getElementById("as-dash-recent-body");
        if (!container) return;

        if (!entries || !entries.length) {
            container.innerHTML = `
                <p class="as-card__subtitle">No recent actions in audit log.</p>
            `;
            return;
        }

        const items = entries
            .slice(-10)
            .reverse()
            .map((entry) => {
                const timeLabel = formatAuditTime(
                    entry.created_at || entry.time
                );
                const label = formatAuditLabel(entry);

                return `
                <div class="as-recent-item">
                    <div class="as-recent-main">${label}</div>
                    ${
                        timeLabel
                            ? `<div class="as-recent-meta">${timeLabel}</div>`
                            : ""
                    }
                </div>
            `;
            });

        container.innerHTML = `
            <div class="as-recent-list">
                ${items.join("")}
            </div>
        `;
    };

    //===============================
    // ADMIN CHAT VIEW (two-card layout)
    //===============================
    AS.dashboard.renderAdminChat = function (root) {
        const enterToSendEnabled =
            AS.adminSettings && typeof AS.adminSettings.get === "function"
                ? AS.adminSettings.get().adminChatEnterToSend !== false
                : true;

        const hintText = enterToSendEnabled
            ? "Enter to send · Shift+Enter for newline"
            : "Click Send to send · Enter for newline";

        const helperText = enterToSendEnabled
            ? "Enter = Send · Shift+Enter = New line"
            : "Click Send to submit · Enter = New line";

        root.innerHTML = `
            <div class="as-grid as-grid--adminchat">
                <!-- Fixed-height Admin Chat window (scrollable) -->
                <section class="as-card as-adminchat-card as-adminchat-card--messages">
                    <header class="as-card__header">
                        <div>
                            <h2 class="as-card__title">Admin Chat</h2>
                            <p class="as-card__subtitle">Staff-only channel</p>
                        </div>
                        <button class="as-chip" id="as-adminchat-purge">Clear Admin Chat</button>
                    </header>

                    <div class="as-card__body as-adminchat-body-wrap">
                        <div class="as-adminchat-messages" id="as-adminchat-messages">
                            Loading history…
                        </div>
                    </div>
                </section>

                <!-- New Message composer card pinned just above the footer -->
                <section class="as-card as-adminchat-card as-adminchat-card--composer">
                    <header class="as-card__header as-adminchat-composer-header">
                        <div>
                            <h3 class="as-adminchat-composer-title">New Message</h3>
                            <p class="as-adminchat-hint">${hintText}</p>
                        </div>
                    </header>

                    <div class="as-card__body as-adminchat-composer">
                        <textarea
                            id="as-adminchat-input"
                            class="as-adminchat-input"
                            rows="2"
                            placeholder="Type a message to other staff…"
                        ></textarea>

                        <div class="as-adminchat-composer-footer">
                            <span class="as-adminchat-helper">
                                ${helperText}
                            </span>
                            <button class="as-chip" id="as-adminchat-send">Send</button>
                        </div>
                    </div>
                </section>
            </div>
        `;

        // Load existing history
        AdminSuite.utils.sendNuiCallback("as:nui:adminchat:loadHistory", {});

        const purge = root.querySelector("#as-adminchat-purge");
        const send  = root.querySelector("#as-adminchat-send");
        const input = root.querySelector("#as-adminchat-input");

        // Use the shared RBAC helper from this file
        const { ready, has } = makeRBACChecker();

        // Handle Purge visibility + click
        if (purge) {
            if (ready && !has("can_use_adminchat_purge")) {
                purge.classList.add("as-hidden-rbac");
            } else {
                purge.addEventListener("click", () => {
                    AdminSuite.utils.sendNuiCallback(
                        "as:nui:adminchat:purge",
                        {}
                    );
                });
            }
        }

        function sendMessage() {
            if (!input) return;
            const text = input.value.trim();
            if (!text) return;

            AdminSuite.utils.sendNuiCallback(
                "as:nui:adminchat:sendMessage",
                {
                    message: text,
                }
            );

            input.value = "";
            input.focus();
        }

        if (send && input) {
            // Click to send
            send.addEventListener("click", () => {
                sendMessage();
            });

            // Key handling depends on "Enter-to-Send" setting
            input.addEventListener("keydown", (ev) => {
                if (ev.key !== "Enter") return;

                if (!enterToSendEnabled) {
                    // Setting OFF: Enter always newline, never send.
                    return;
                }

                // Setting ON: Enter sends, Shift+Enter = newline
                if (ev.shiftKey) {
                    // allow newline
                    return;
                }

                ev.preventDefault();
                sendMessage();
            });
        }
    };

    function formatAdminChatTime(ts) {
        if (!ts) return "";
        try {
            // If your time is already ms, change this to `new Date(ts)`
            const d = new Date(ts * 1000);
            const hh = String(d.getHours()).padStart(2, "0");
            const mm = String(d.getMinutes()).padStart(2, "0");
            return `${hh}:${mm}`;
        } catch (e) {
            return "";
        }
    }

    AS.dashboard.updateAdminChatHistory = function (messages) {
        const container = document.getElementById(
            "as-adminchat-messages"
        );
        if (!container) return;

        if (!messages || !messages.length) {
            container.innerHTML =
                '<p class="as-card__subtitle">No admin chat messages yet.</p>';
            return;
        }

        const parts = messages.map((msg) => {
            const safeAuthor =
                msg.author || `ID ${msg.authorSrc || "?"}`;
            const safeMessage = msg.message || "";
            const labelTime = formatAdminChatTime(msg.time);

            return `
                <div class="as-adminchat-message">
                    <div class="as-adminchat-meta">
                        <span class="as-adminchat-author">${safeAuthor}</span>
                        ${
                            labelTime
                                ? `<span class="as-adminchat-time">${labelTime}</span>`
                                : ""
                        }
                    </div>
                    <div class="as-adminchat-body">${safeMessage}</div>
                </div>
            `;
        });

        container.innerHTML = `
            <div class="as-adminchat-list">
                ${parts.join("")}
            </div>
        `;

        // Always scroll to bottom of the fixed-height window
        container.scrollTop = container.scrollHeight || 0;
    };

    AS.dashboard.appendAdminChatMessage = function (entry) {
        const container = document.getElementById(
            "as-adminchat-messages"
        );
        if (!container || !entry) return;

        let list = container.querySelector(".as-adminchat-list");
        if (!list) {
            list = document.createElement("div");
            list.className = "as-adminchat-list";
            container.innerHTML = "";
            container.appendChild(list);
        }

        const safeAuthor =
            entry.author || `ID ${entry.authorSrc || "?"}`;
        const safeMessage = entry.message || "";
        const labelTime = formatAdminChatTime(entry.time);

        const wrapper = document.createElement("div");
        wrapper.className = "as-adminchat-message";
        wrapper.innerHTML = `
            <div class="as-adminchat-meta">
                <span class="as-adminchat-author">${safeAuthor}</span>
                ${
                    labelTime
                        ? `<span class="as-adminchat-time">${labelTime}</span>`
                        : ""
                }
            </div>
            <div class="as-adminchat-body">${safeMessage}</div>
        `;

        list.appendChild(wrapper);

        // Always scroll to bottom of the fixed-height window
        container.scrollTop = container.scrollHeight || 0;
    };

    //===============================
    // WORLD CONTROLS VIEW
    //===============================
    AS.dashboard.renderWorld = function (root) {
        // Track last world root so we can re-apply RBAC when RBAC updates
        lastWorldRoot = root;

        root.innerHTML = `
            <div class="as-grid">
                <!-- Time control -->
                <section class="as-card" style="grid-column: span 6;">
                    <header class="as-card__header">
                        <h2 class="as-card__title">Time</h2>
                    </header>
                    <div class="as-card__body">
                        <p class="as-card__subtitle">
                            Set the global server time. Use 24-hour format (HH:MM).
                        </p>
                        <div class="as-field-row">
                            <label class="as-field">
                                <span class="as-field__label">Time (HH:MM)</span>
                                <input
                                    id="as-world-time-input"
                                    type="text"
                                    class="as-input"
                                    maxlength="5"
                                    placeholder="12:00"
                                    autocomplete="off"
                                />
                            </label>
                            <button id="as-world-time-apply" class="as-btn">
                                Apply Time
                            </button>
                        </div>
                    </div>
                </section>

                <!-- Weather control -->
                <section class="as-card" style="grid-column: span 6;">
                    <header class="as-card__header">
                        <h2 class="as-card__title">Weather</h2>
                    </header>
                    <div class="as-card__body">
                        <p class="as-card__subtitle">
                            Choose a weather preset to apply globally.
                        </p>
                        <div class="as-field-row">
                            <label class="as-field">
                                <span class="as-field__label">Weather Preset</span>
                                <select id="as-world-weather-select" class="as-select">
                                    <option value="CLEAR">Clear</option>
                                    <option value="EXTRASUNNY">Extra Sunny</option>
                                    <option value="CLOUDS">Clouds</option>
                                    <option value="OVERCAST">Overcast</option>
                                    <option value="RAIN">Rain</option>
                                    <option value="THUNDER">Thunder</option>
                                    <option value="SMOG">Smog</option>
                                    <option value="FOGGY">Foggy</option>
                                    <option value="XMAS">Xmas</option>
                                    <option value="SNOW">Snow</option>
                                    <option value="BLIZZARD">Blizzard</option>
                                    <option value="SNOWLIGHT">Light Snow</option>
                                    <option value="HALLOWEEN">Halloween</option>
                                </select>
                            </label>
                            <button id="as-world-weather-apply" class="as-btn">
                                Apply Weather
                            </button>
                        </div>
                    </div>
                </section>
            </div>
        `;

        // Apply RBAC hiding to world controls
        applyRBACToWorld(root);

        const timeInput = root.querySelector("#as-world-time-input");
        const timeApply = root.querySelector("#as-world-time-apply");

        if (timeApply && timeInput) {
            timeApply.addEventListener("click", () => {
                if (timeApply.classList.contains("as-hidden-rbac")) return;

                const raw = (timeInput.value || "").trim();
                if (!raw) {
                    return;
                }

                AdminSuite.utils.sendNuiCallback(
                    "as:nui:world:applyTime",
                    {
                        time: raw,
                    }
                );

                if (
                    window.AdminSuite &&
                    AdminSuite.utils &&
                    typeof AdminSuite.utils.notify === "function"
                ) {
                    const msg = `Time Successfully set to: ${raw}.`;
                    AdminSuite.utils.notify(msg, { type: "success" });
                }
            });
        }

        const weatherSelect = root.querySelector(
            "#as-world-weather-select"
        );
        const weatherApply = root.querySelector(
            "#as-world-weather-apply"
        );

        if (weatherApply && weatherSelect) {
            weatherApply.addEventListener("click", () => {
                if (
                    weatherApply.classList.contains("as-hidden-rbac")
                )
                    return;

                const preset = weatherSelect.value || "CLEAR";
                AdminSuite.utils.sendNuiCallback(
                    "as:nui:world:applyWeather",
                    {
                        weather: preset,
                    }
                );

                if (
                    window.AdminSuite &&
                    AdminSuite.utils &&
                    typeof AdminSuite.utils.notify === "function"
                ) {
                    const selectedOption =
                        weatherSelect.options[weatherSelect.selectedIndex];
                    const label =
                        (selectedOption &&
                            selectedOption.textContent) ||
                        preset;
                    const msg = `Weather successfully changed to: ${label}.`;
                    AdminSuite.utils.notify(msg, { type: "success" });
                }
            });
        }

        // Ask Lua/server for latest world state (time/weather)
        AdminSuite.utils.sendNuiCallback(
            "as:nui:world:loadState",
            {}
        );
    };

    //===============================
    // RBAC update hook
    //===============================
    AS.dashboard.onRBACUpdate = function () {
        // Re-apply RBAC to any already-rendered views
        if (lastDashboardRoot) {
            applyRBACToQuickActions(lastDashboardRoot);
        }
        if (lastWorldRoot) {
            applyRBACToWorld(lastWorldRoot);
        }
    };
})();
