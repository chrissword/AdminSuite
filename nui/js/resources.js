window.AdminSuite = window.AdminSuite || {};

(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});
    AS.resources = AS.resources || {};

    const state = {
        list: [],
        search: "",
        page: 1,
        perPage: 15,
    };

    let rootEl = null;

    // -------------------------------------------------------------
    // Normalization + local state helper
    // -------------------------------------------------------------

    function normalizeResource(entry) {
        if (!entry) return null;

        const name =
            (typeof entry.name === "string" && entry.name) ||
            (Array.isArray(entry) && entry[0]) ||
            "";
        const rawState =
            (typeof entry.state === "string" && entry.state) ||
            (Array.isArray(entry) && entry[1]) ||
            "";

        if (!name) return null;

        const s = String(rawState || "unknown").toLowerCase();

        let statusLabel = "Unknown";
        let statusClass = "as-chip";

        if (s === "started") {
            statusLabel = "Started";
            statusClass += " as-chip--success";
        } else if (s === "stopped") {
            statusLabel = "Stopped";
            statusClass += " as-chip--danger";
        } else if (s === "starting") {
            statusLabel = "Starting…";
            statusClass += " as-chip--warning";
        } else if (s === "stopping") {
            statusLabel = "Stopping…";
            statusClass += " as-chip--warning";
        } else if (s === "restarting") {
            statusLabel = "Restarting…";
            statusClass += " as-chip--warning";
        } else {
            statusLabel = s || "Unknown";
            statusClass += " as-chip--neutral";
        }

        return {
            name,
            state: s,
            statusLabel,
            statusClass,
        };
    }

    // Used to update a single resource row locally to a "pending" state
    function setLocalResourceState(name, rawState) {
        if (!name || !rawState) return;

        const normalized = normalizeResource({
            name,
            state: rawState,
        });
        if (!normalized) return;

        let changed = false;

        state.list = state.list.map((r) => {
            if (r.name !== name) return r;
            changed = true;
            return normalized;
        });

        if (changed && rootEl) {
            renderTable();
        }
    }

    // -------------------------------------------------------------
    // Filtering / NUI calls
    // -------------------------------------------------------------

    function getFiltered() {
        const q = (state.search || "").trim().toLowerCase();
        if (!q) return state.list.slice();

        return state.list.filter((r) =>
            String(r.name || "").toLowerCase().includes(q)
        );
    }

    function sendResourceAction(resource, action) {
        if (!resource || !action) return;

        if (window.AdminSuite && window.AdminSuite.utils) {
            window.AdminSuite.utils.sendNuiCallback(
                "as:nui:resources:action",
                {
                    resource,
                    action,
                }
            );
        }
    }

    function requestRefresh() {
        if (window.AdminSuite && window.AdminSuite.utils) {
            window.AdminSuite.utils.sendNuiCallback(
                "as:nui:resources:refresh",
                {}
            );
        }
    }

    // -------------------------------------------------------------
    // UI binding
    // -------------------------------------------------------------

    function bindHandlers() {
        if (!rootEl) return;

        const searchInput = rootEl.querySelector("#as-resources-search");
        if (searchInput) {
            searchInput.value = state.search || "";
            searchInput.addEventListener("input", (ev) => {
                state.search = ev.target.value || "";
                state.page = 1;
                renderTable();
            });
        }

        const clearBtn = rootEl.querySelector("#as-resources-clear");
        if (clearBtn) {
            clearBtn.addEventListener("click", () => {
                state.search = "";
                state.page = 1;
                if (searchInput) {
                    searchInput.value = "";
                }
                renderTable();
            });
        }

        const refreshBtn = rootEl.querySelector("#as-resources-refresh");
        if (refreshBtn) {
            refreshBtn.addEventListener("click", (ev) => {
                ev.preventDefault();
                requestRefresh();
            });
        }

        const tbody = rootEl.querySelector("#as-resources-tbody");
        if (tbody && !tbody._asResourcesBound) {
            tbody._asResourcesBound = true;
            tbody.addEventListener("click", (ev) => {
                const btn = ev.target.closest("[data-resource][data-action]");
                if (!btn) return;

                const resource = btn.getAttribute("data-resource");
                const action = (btn.getAttribute("data-action") || "").toLowerCase();
                if (!resource || !action) return;

                const current = state.list.find((r) => r.name === resource);

                const utils =
                    window.AdminSuite && window.AdminSuite.utils
                        ? window.AdminSuite.utils
                        : null;
                const notify =
                    utils && typeof utils.notify === "function"
                        ? utils.notify.bind(utils)
                        : (msg, level) => {
                              console.warn(
                                  `[AdminSuite] ${level || "info"}: ${msg}`
                              );
                          };

                // START guard: already started
                if (action === "start") {
                    if (current && current.state === "started") {
                        notify(
                            `Resource "${resource}" is already started.`,
                            "error"
                        );
                        return;
                    }
                }

                // RESTART guard: only allow restart when resource is started
                if (action === "restart") {
                    if (!current || current.state !== "started") {
                        notify(
                            `Resource "${resource}" is not started.`,
                            "error"
                        );
                        return;
                    }
                }

                // Set a temporary UI state while the server processes
                if (action === "start") {
                    setLocalResourceState(resource, "starting");
                } else if (action === "stop") {
                    setLocalResourceState(resource, "stopping");
                } else if (action === "restart") {
                    setLocalResourceState(resource, "restarting");
                }

                // Send the action to Lua
                sendResourceAction(resource, action);
            });
        }
    }

    // -------------------------------------------------------------
    // Pagination + table render
    // -------------------------------------------------------------

    function renderPagination(total) {
        if (!rootEl) return;

        const container = rootEl.querySelector("#as-resources-pagination");
        if (!container) return;

        if (!total) {
            container.innerHTML = "";
            return;
        }

        const perPage = state.perPage || 15;
        const maxPage = Math.max(1, Math.ceil(total / perPage));
        const current = state.page || 1;

        container.innerHTML = `
            <div class="as-vehicles-pagination-inner">
                <button
                    class="as-btn as-btn--pill as-vehicles-page-btn as-resources-page-prev"
                    ${current <= 1 ? "disabled" : ""}
                >
                    Prev
                </button>
                <span class="as-vehicles-page-label">
                    Page ${current} of ${maxPage}
                </span>
                <button
                    class="as-btn as-btn--pill as-vehicles-page-btn as-resources-page-next"
                    ${current >= maxPage ? "disabled" : ""}
                >
                    Next
                </button>
            </div>
        `;

        const prev = container.querySelector(".as-resources-page-prev");
        const next = container.querySelector(".as-resources-page-next");

        if (prev && current > 1) {
            prev.addEventListener("click", () => {
                state.page -= 1;
                renderTable();
            });
        }

        if (next && current < maxPage) {
            next.addEventListener("click", () => {
                state.page += 1;
                renderTable();
            });
        }
    }

    function renderTable() {
        if (!rootEl) return;

        const tbody = rootEl.querySelector("#as-resources-tbody");
        const empty = rootEl.querySelector("#as-resources-empty");

        if (!tbody || !empty) return;

        const rows = getFiltered();
        const total = rows.length;

        if (!total) {
            tbody.innerHTML = "";
            empty.classList.remove("as-hidden");
            renderPagination(0);
            return;
        }

        empty.classList.add("as-hidden");

        const perPage = state.perPage || 15;
        const maxPage = Math.max(1, Math.ceil(total / perPage));

        if (!state.page || state.page < 1) state.page = 1;
        if (state.page > maxPage) state.page = maxPage;

        const startIndex = (state.page - 1) * perPage;
        const visible = rows.slice(startIndex, startIndex + perPage);

        tbody.innerHTML = visible
            .map((r) => {
                return `
                    <tr>
                        <td>
                            <span class="as-text-strong">${r.name}</span>
                        </td>
                        <td>
                            <span class="${r.statusClass}">${r.statusLabel}</span>
                        </td>
                        <td class="as-resources-actions">
                            <button
                                class="as-chip as-chip--sm"
                                data-resource="${r.name}"
                                data-action="start"
                            >
                                Start
                            </button>
                            <button
                                class="as-chip as-chip--sm"
                                data-resource="${r.name}"
                                data-action="stop"
                            >
                                Stop
                            </button>
                            <button
                                class="as-chip as-chip--sm"
                                data-resource="${r.name}"
                                data-action="restart"
                            >
                                Restart
                            </button>
                        </td>
                    </tr>
                `;
            })
            .join("");

        renderPagination(total);
    }

    // -------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------

    // Main render entrypoint for router
    AS.resources.render = function (root) {
        rootEl = root;

        root.innerHTML = `
            <div class="as-grid">
                <section class="as-card" style="grid-column: span 12;">
                    <header class="as-card__header as-card__header--row">
                        <div>
                            <h2 class="as-card__title">Resources</h2>
                            <span class="as-card__subtitle">
                                View running resources and perform basic start / stop / restart actions.
                            </span>
                        </div>
                        <div class="as-card__actions">
                            <button class="as-chip" id="as-resources-refresh">
                                Refresh
                            </button>
                        </div>
                    </header>
                    <div class="as-card__body">
                        <div class="as-toolbar">
                            <input
                                id="as-resources-search"
                                class="as-input"
                                placeholder="Search resources…"
                                autocomplete="off"
                            />
                            <button class="as-chip as-chip--sm" id="as-resources-clear">
                                Clear
                            </button>
                        </div>

                        <div class="as-table as-table--resources">
                            <table>
                                <thead>
                                    <tr>
                                        <th>Name</th>
                                        <th>Status</th>
                                        <th style="width: 260px;">Actions</th>
                                    </tr>
                                </thead>
                                <tbody id="as-resources-tbody"></tbody>
                            </table>
                            <div
                                id="as-resources-empty"
                                class="as-empty as-hidden"
                            >
                                <p>No resources found or you do not have permission to view them.</p>
                            </div>
                            <div class="as-vehicles-pagination as-resources-pagination" id="as-resources-pagination"></div>
                        </div>
                    </div>
                </section>
            </div>
        `;

        bindHandlers();
        renderTable();
    };

    // Called from main.js when Lua pushes resource data
    AS.resources.setList = function (list) {
        state.list = (list || []).map(normalizeResource).filter(Boolean);
        state.page = 1;

        // If we're currently on the Resources view, update the UI
        if (
            window.AdminSuite &&
            window.AdminSuite.router &&
            typeof window.AdminSuite.router.getCurrentView === "function" &&
            window.AdminSuite.router.getCurrentView() === "resources" &&
            rootEl
        ) {
            renderTable();
        }
    };
})();
