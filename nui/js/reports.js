window.AdminSuite = window.AdminSuite || {};

(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});
    AS.reports = AS.reports || {};

    const state = {
        reports: [],
        activeTab: "open", // 'open' | 'in-progress' | 'closed'
        selectedId: null,
        searchQuery: "",
    };

    // Cached DOM refs (set in render)
    let elements = {
        root: null,
        list: null,
        detailLabel: null,
        detailBody: null,
        searchInput: null,
        tabButtons: {},
    };

    function getRBACFlags() {
        const rbac = (AdminSuite && AdminSuite.rbac) || {};
        return rbac.flags || {};
    }

    function normalizeStatusKey(report) {
        const raw = (report && report.status) ? String(report.status).toLowerCase() : "open";

        if (raw === "closed") {
            return "closed";
        }

        if (raw === "claimed" || raw === "in_progress" || raw === "in-progress" || report.claimedBy) {
            return "in-progress";
        }

        return "open";
    }

    function getStatusPillClass(report) {
        const key = normalizeStatusKey(report);
        if (key === "closed") return "as-report-status--closed";
        if (key === "in-progress") return "as-report-status--claimed";
        return "as-report-status--open";
    }

    function getStatusLabel(report) {
        const key = normalizeStatusKey(report);
        if (key === "closed") return "CLOSED";
        if (key === "in-progress") return "IN PROGRESS";
        return "OPEN";
    }

    function formatTimestamp(ts) {
        if (!ts) return "Unknown time";
        // ts is typically an ISO string from DB; keep it simple for now
        return ts;
    }

    function safeText(value, fallback) {
        if (value === null || value === undefined) return fallback || "";
        const str = String(value);
        return str.trim() === "" ? (fallback || "") : str;
    }

    function filterReportsForActiveTab() {
        const active = state.activeTab;
        const query = state.searchQuery.toLowerCase().trim();

        let counts = {
            open: 0,
            "in-progress": 0,
            closed: 0,
        };

        const filtered = [];

        (state.reports || []).forEach((r) => {
            const key = normalizeStatusKey(r);
            if (counts[key] !== undefined) counts[key]++;

            // Search filter (simple: reporter + message)
            if (query) {
                const haystack = [
                    safeText(r.sourceName, ""),
                    safeText(r.message, ""),
                    safeText(r.claimedBy, ""),
                ]
                    .join(" ")
                    .toLowerCase();

                if (!haystack.includes(query)) {
                    return;
                }
            }

            if (key === active) {
                filtered.push(r);
            }
        });

        return { filtered, counts };
    }

    function updateTabVisuals(counts) {
        if (!elements.root) return;
        const buttons = elements.tabButtons || {};

        Object.keys(buttons).forEach((tabKey) => {
            const btn = buttons[tabKey];
            if (!btn) return;

            if (tabKey === state.activeTab) {
                btn.classList.add("as-tab--active");
            } else {
                btn.classList.remove("as-tab--active");
            }

            const badge = btn.querySelector("[data-reports-tab-count]");
            if (badge) {
                const c =
                    tabKey === "open"
                        ? counts.open
                        : tabKey === "in-progress"
                        ? counts["in-progress"]
                        : counts.closed;
                badge.textContent = c.toString();
            }
        });
    }

    function renderList() {
        const list = elements.list;
        if (!list) return;

        const { filtered, counts } = filterReportsForActiveTab();

        if (!filtered.length) {
            list.innerHTML = `<p class="as-muted">No reports in this view.</p>`;
        } else {
            list.innerHTML = "";
            filtered.forEach((r) => {
                const item = document.createElement("div");
                item.className = "as-reports-list-item";
                item.dataset.reportId = String(r.id);

                if (String(state.selectedId) === String(r.id)) {
                    item.classList.add("as-reports-list-item--active");
                }

                const statusClass = getStatusPillClass(r);
                const statusText = getStatusLabel(r);

                item.innerHTML = `
                    <div class="as-reports-list-item__meta">
                        <span class="as-reports-list-item__title">
                            #${r.id} · ${safeText(r.sourceName, "Unknown")}
                        </span>
                        <span class="as-reports-list-item__subtitle">
                            ${safeText(r.message, "")}
                        </span>
                        <span class="as-reports-list-item__subtitle">
                            ${safeText(r.created_at, "")}
                        </span>
                    </div>
                    <div class="as-reports-list-item__right">
                        <span class="as-report-status ${statusClass}">
                            ${statusText}
                        </span>
                        <span class="as-reports-list-item__subtitle">
                            ${
                                r.claimedBy
                                    ? `Claimed by ${safeText(r.claimedBy, "Unknown")}`
                                    : "Unclaimed"
                            }
                        </span>
                    </div>
                `;

                item.addEventListener("click", () => {
                    AS.reports.select(r);
                });

                list.appendChild(item);
            });
        }

        updateTabVisuals(counts);
    }

    function highlightSelectedRow() {
        const list = elements.list;
        if (!list) return;

        const rows = list.querySelectorAll(".as-reports-list-item");
        rows.forEach((row) => {
            if (row.dataset.reportId === String(state.selectedId)) {
                row.classList.add("as-reports-list-item--active");
            } else {
                row.classList.remove("as-reports-list-item--active");
            }
        });
    }

    function renderEmptyDetail() {
        if (!elements.detailLabel || !elements.detailBody) return;
        elements.detailLabel.textContent = "No report selected.";
        elements.detailBody.innerHTML =
            `<p class="as-muted">Select a report on the left to view details, claim, or close.</p>`;
    }

    function renderDetail(report) {
        const labelEl = elements.detailLabel;
        const detail = elements.detailBody;
        if (!labelEl || !detail) return;

        if (!report) {
            renderEmptyDetail();
            return;
        }

        const statusClass = getStatusPillClass(report);
        const statusText = getStatusLabel(report);

        const flags = getRBACFlags();
        const canViewReports = !!flags.can_view_reports;
        const canHandleReports = !!flags.can_handle_reports;
        const canTeleport = !!flags.can_teleport;

        const hasTarget = !!report.target_identifier;
        const createdAt = formatTimestamp(report.created_at);
        const updatedAt = formatTimestamp(report.updated_at);

        labelEl.textContent = `Report #${report.id} from ${safeText(
            report.sourceName,
            "Unknown"
        )}`;

        // Decide which action buttons to show
        const statusKey = normalizeStatusKey(report);
        const showClaim = canHandleReports && statusKey === "open" && !report.claimedBy;
        const showUnclaim =
            canHandleReports && statusKey !== "closed" && !!report.claimedBy;
        const showClose = canHandleReports && statusKey !== "closed";
        const showReopen = canHandleReports && statusKey === "closed";

        // Teleport buttons are rendered but disabled for now until wired server-side
        const canShowTeleport = canTeleport;

        detail.innerHTML = `
            <div class="as-reports-detail__header">
                <div>
                    <div class="as-report-status ${statusClass}" style="margin-bottom:4px;">
                        ${statusText}
                    </div>
                    <p class="as-card__subtitle">
                        Handler: ${safeText(report.claimedBy, "Unclaimed")}
                    </p>
                    <p class="as-card__subtitle">
                        Created: ${createdAt}
                        ${
                            updatedAt && updatedAt !== createdAt
                                ? `<br/>Updated: ${updatedAt}`
                                : ""
                        }
                    </p>
                </div>
                <div class="as-reports-detail__actions">
                    ${
                        canViewReports
                            ? `
                        ${
                            showClaim
                                ? `<button class="as-chip" data-report-action="claim">Claim</button>`
                                : ""
                        }
                        ${
                            showUnclaim
                                ? `<button class="as-chip" data-report-action="unclaim">Unclaim</button>`
                                : ""
                        }
                        ${
                            showClose
                                ? `<button class="as-chip as-chip--danger" data-report-action="close">Close</button>`
                                : ""
                        }
                        ${
                            showReopen
                                ? `<button class="as-chip" data-report-action="reopen">Reopen</button>`
                                : ""
                        }
                        ${
                            canShowTeleport
                                ? `
                            <button class="as-chip" data-report-action="tp-reporter" disabled title="Teleport wiring coming soon">
                                TP to Reporter
                            </button>
                            ${
                                hasTarget
                                    ? `<button class="as-chip" data-report-action="tp-target" disabled title="Teleport wiring coming soon">
                                            TP to Reported
                                       </button>`
                                    : ""
                            }
                            `
                                : ""
                        }
                    `
                            : `<span class="as-card__subtitle as-muted">You can view reports but do not have permission to handle them.</span>`
                    }
                </div>
            </div>

            <div class="as-reports-detail__meta">
                <div class="as-reports-detail__meta-block">
                    <h3 class="as-reports-detail__meta-label">Reporter</h3>
                    <p class="as-reports-detail__meta-value">
                        ${safeText(report.sourceName, "Unknown")}
                    </p>
                </div>
                <div class="as-reports-detail__meta-block">
                    <h3 class="as-reports-detail__meta-label">Reported Player</h3>
                    <p class="as-reports-detail__meta-value">
                        ${
                            hasTarget
                                ? safeText(report.target_identifier, "Unknown")
                                : "N/A"
                        }
                    </p>
                </div>
                <div class="as-reports-detail__meta-block">
                    <h3 class="as-reports-detail__meta-label">Category</h3>
                    <p class="as-reports-detail__meta-value">
                        ${safeText(report.category, "General")}
                    </p>
                </div>
            </div>

            <div class="as-reports-detail__body">
                <h3 class="as-reports-detail__section-title">Reason / Details</h3>
                <p class="as-reports-detail__message">
                    ${safeText(report.message, "No description provided.")}
                </p>
            </div>
        `;

        // Wire buttons
        detail.querySelectorAll("[data-report-action]").forEach((btn) => {
            const action = btn.getAttribute("data-report-action");
            if (!action) return;

            if (action === "tp-reporter" || action === "tp-target") {
                // Future: hook up teleport actions via moderation / world controls
                return;
            }

            btn.addEventListener("click", () => {
                const mapping = {
                    claim: "as:nui:reports:claim",
                    unclaim: "as:nui:reports:unclaim",
                    close: "as:nui:reports:close",
                    reopen: "as:nui:reports:reopen",
                };

                const cb = mapping[action];
                if (!cb) return;

                AdminSuite.utils.sendNuiCallback(cb, { id: report.id });

                // Let Lua/server push back updated lists; we clear selection to avoid stale view
                state.selectedId = null;
                renderEmptyDetail();
            });
        });
    }

    /**
     * Render staff Reports view
     * - Header card (info only, no submit)
     * - Two-column layout: list (left) + details (right)
     * - Tabs for Open / In-Progress / Closed
     */
    AS.reports.render = function (root) {
        if (!root) return;
        elements.root = root;

        root.innerHTML = `
            <div class="as-grid as-view--reports">
                <!-- Header: informational only -->
                <section class="as-card as-card--reports-header" style="grid-column: span 12;">
                    <div class="as-reports-header-band">Reports</div>
                    <div class="as-card__body">
                        <p class="as-card__subtitle">
                            View and manage player reports. New reports are submitted by players using the
                            <strong>/report</strong> command.
                        </p>
                    </div>
                </section>

                <!-- Main two-panel layout -->
                <section class="as-card as-card--reports-main" style="grid-column: span 12;">
                    <div class="as-reports-layout">
                        <!-- LEFT: list + filters -->
                        <div class="as-reports-sidebar">
                            <header class="as-card__header as-reports-sidebar__header">
                                <div>
                                    <h2 class="as-card__title">Reports</h2>
                                    <p class="as-card__subtitle">Open, in-progress &amp; closed</p>
                                </div>
                                <div class="as-reports-toolbar">
                                    <input
                                        id="as-reports-search"
                                        type="text"
                                        class="as-input"
                                        placeholder="Search by reporter, handler, or text..."
                                    />
                                    <button class="as-chip" id="as-reports-refresh">Refresh</button>
                                </div>
                            </header>

                            <div class="as-reports-tabs">
                                <button class="as-tab" data-reports-tab="open">
                                    <span>Open</span>
                                    <span class="as-tab__badge" data-reports-tab-count="open">0</span>
                                </button>
                                <button class="as-tab" data-reports-tab="in-progress">
                                    <span>In Progress</span>
                                    <span class="as-tab__badge" data-reports-tab-count="in-progress">0</span>
                                </button>
                                <button class="as-tab" data-reports-tab="closed">
                                    <span>Closed</span>
                                    <span class="as-tab__badge" data-reports-tab-count="closed">0</span>
                                </button>
                            </div>

                            <div class="as-card__body as-reports-list-wrapper">
                                <div class="as-reports-list" id="as-reports-list"></div>
                            </div>
                        </div>

                        <!-- RIGHT: detail view -->
                        <div class="as-reports-detail" aria-label="Report details">
                            <header class="as-card__header as-reports-detail__header-main">
                                <h2 class="as-card__title">Details</h2>
                                <span class="as-card__subtitle" id="as-reports-detail-label">
                                    No report selected.
                                </span>
                            </header>
                            <div class="as-card__body as-reports-detail__body" id="as-reports-detail">
                                <p class="as-muted">
                                    Select a report on the left to view details, claim, or close.
                                </p>
                            </div>
                        </div>
                    </div>
                </section>
            </div>
        `;

        // Cache elements
        elements.list = root.querySelector("#as-reports-list");
        elements.detailLabel = root.querySelector("#as-reports-detail-label");
        elements.detailBody = root.querySelector("#as-reports-detail");
        elements.searchInput = root.querySelector("#as-reports-search");

        elements.tabButtons = {
            open: root.querySelector('.as-tab[data-reports-tab="open"]'),
            "in-progress": root.querySelector(
                '.as-tab[data-reports-tab="in-progress"]'
            ),
            closed: root.querySelector('.as-tab[data-reports-tab="closed"]'),
        };

        // Refresh button → ask Lua to load ALL reports (open/in-progress/closed)
        const refresh = root.querySelector("#as-reports-refresh");
        if (refresh) {
            refresh.addEventListener("click", () => {
                AdminSuite.utils.sendNuiCallback("as:nui:reports:loadAll", {});
            });
        }

        // Tabs
        Object.keys(elements.tabButtons).forEach((key) => {
            const btn = elements.tabButtons[key];
            if (!btn) return;

            btn.addEventListener("click", () => {
                state.activeTab = key;
                renderList();
                // If current selected report is not in this tab, clear details
                const current = state.reports.find(
                    (r) => String(r.id) === String(state.selectedId)
                );
                if (!current || normalizeStatusKey(current) !== state.activeTab) {
                    state.selectedId = null;
                    renderEmptyDetail();
                } else {
                    renderDetail(current);
                }
                highlightSelectedRow();
            });
        });

        // Search
        if (elements.searchInput) {
            elements.searchInput.addEventListener("input", (e) => {
                state.searchQuery = e.target.value || "";
                renderList();
                highlightSelectedRow();
            });
        }

        // Initial request: load ALL reports
        AdminSuite.utils.sendNuiCallback("as:nui:reports:loadAll", {});
    };

    /**
     * Update the list of reports.
     * Called from Lua via:
     *   - as:nui:reports:loadOpen
     *   - as:nui:reports:loadMine
     *   - as:nui:reports:loadAll
     *   - as:nui:reports:updateStatus (when payload.reports is present)
     */
    AS.reports.updateList = function (reports) {
        if (!Array.isArray(reports)) {
            state.reports = [];
        } else {
            state.reports = reports;
        }

        // Keep the same selection if possible
        const current =
            state.selectedId != null
                ? state.reports.find(
                      (r) => String(r.id) === String(state.selectedId)
                  )
                : null;

        if (!elements.list) {
            // View not rendered yet; nothing more to do
            return;
        }

        renderList();

        if (current) {
            AS.reports.select(current);
        } else {
            highlightSelectedRow();
            // Don't forcibly clear detail; leave it as-is unless selected report disappeared
        }
    };

    /**
     * Populate the Details panel for a selected report.
     * Also highlights the selected row in the left list.
     */
    AS.reports.select = function (report) {
        if (!report) {
            state.selectedId = null;
            renderEmptyDetail();
            highlightSelectedRow();
            return;
        }

        state.selectedId = report.id;
        renderDetail(report);
        highlightSelectedRow();
    };
})();
