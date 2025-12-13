window.AdminSuite = window.AdminSuite || {};

(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});
    AS.vehicles = AS.vehicles || {};

    const state = {
        list: [],
        filtered: [],
        selectedIndex: -1,
        search: "",
        page: 1,
        perPage: 15,
    };

    let rootEl = null;

    // Shared prefs key – matches router.js & dashboard.js
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
    // Normalization
    //========================================
    function normalizeVehicle(entry) {
        if (!entry || typeof entry !== "object") return null;

        const model =
            (entry.model || entry.modelName || entry.spawn || entry.code || "")
                .toString()
                .toLowerCase();

        if (!model) return null;

        return {
            model,
            label:
                entry.label ||
                entry.name ||
                entry.displayName ||
                model.toUpperCase(),
            brand: entry.brand || "",
            classLabel:
                entry.classLabel ||
                entry.class ||
                entry.categoryLabel ||
                entry.category ||
                "",
            category: entry.category || entry.class || "",
            shop: entry.shop || "",
        };
    }

    //========================================
    // Filtering / Pagination
    //========================================
    function rebuildFiltered() {
        const q = (state.search || "").toLowerCase().trim();

        if (!q) {
            state.filtered = state.list.slice();
        } else {
            state.filtered = state.list.filter((v) => {
                const haystack = [
                    v.model,
                    v.label,
                    v.brand,
                    v.classLabel,
                    v.category,
                ]
                    .join(" ")
                    .toLowerCase();
                return haystack.includes(q);
            });
        }

        if (!state.filtered.length) {
            state.page = 1;
            state.selectedIndex = -1;
            return;
        }

        const perPage = state.perPage || 15;
        const maxPage = Math.max(1, Math.ceil(state.filtered.length / perPage));

        if (!state.page || state.page < 1) state.page = 1;
        if (state.page > maxPage) state.page = maxPage;

        if (
            state.selectedIndex < 0 ||
            state.selectedIndex >= state.filtered.length
        ) {
            state.selectedIndex = 0;
        }
    }

    function getSelectedVehicle() {
        if (
            state.selectedIndex < 0 ||
            state.selectedIndex >= state.filtered.length
        )
            return null;
        return state.filtered[state.selectedIndex] || null;
    }

    //========================================
    // Table Rendering
    //========================================
    function renderTable() {
        if (!rootEl) return;
        const tbody = rootEl.querySelector("#as-vehicles-tbody");
        if (!tbody) return;

        const total = state.filtered.length;
        const perPage = state.perPage || 15;
        const maxPage = total ? Math.max(1, Math.ceil(total / perPage)) : 1;

        if (!state.page || state.page < 1) state.page = 1;
        if (state.page > maxPage) state.page = maxPage;

        const startIndex = (state.page - 1) * perPage;
        const pageItems = state.filtered.slice(
            startIndex,
            startIndex + perPage
        );

        if (pageItems.length) {
            if (
                state.selectedIndex < startIndex ||
                state.selectedIndex >= startIndex + pageItems.length
            ) {
                state.selectedIndex = startIndex;
            }
        } else {
            state.selectedIndex = -1;
        }

        const rows = pageItems.map((veh, offset) => {
            const globalIdx = startIndex + offset;
            const selected =
                globalIdx === state.selectedIndex
                    ? " as-vehicles-row--selected"
                    : "";

            return `
                <tr class="as-table__row as-vehicles-row${selected}" data-index="${globalIdx}">
                    <td class="as-vehicles-cell as-vehicles-cell--model">
                        <code>${veh.model}</code>
                    </td>
                    <td class="as-vehicles-cell as-vehicles-cell--name">
                        <div class="as-vehicles-name">
                            <div class="as-vehicles-name__label">${veh.label}</div>
                            ${
                                veh.brand
                                    ? `<div class="as-vehicles-name__brand">${veh.brand}</div>`
                                    : ""
                            }
                        </div>
                    </td>
                    <td class="as-vehicles-cell as-vehicles-cell--class">
                        ${veh.classLabel || veh.category || ""}
                    </td>
                </tr>
            `;
        });

        tbody.innerHTML =
            rows.join("") ||
            `
            <tr class="as-table__row">
                <td colspan="3" class="as-vehicles-empty">
                    No vehicles found. Try a different search.
                </td>
            </tr>
        `;

        // Hover + click selects the row and updates the preview
        tbody.querySelectorAll(".as-vehicles-row").forEach((row) => {
            const idx = parseInt(row.getAttribute("data-index"), 10);
            if (Number.isNaN(idx)) return;

            row.addEventListener("mouseenter", () => {
                state.selectedIndex = idx;
                renderPreview();
            });

            row.addEventListener("click", () => {
                state.selectedIndex = idx;
                renderPreview();
            });
        });

        renderPaginationControls();
    }

    function renderPaginationControls() {
        if (!rootEl) return;
        const container = rootEl.querySelector("#as-vehicles-pagination");
        if (!container) return;

        const total = state.filtered.length;
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
                    class="as-btn as-btn--pill as-vehicles-page-btn as-vehicles-page-prev"
                    ${current <= 1 ? "disabled" : ""}
                >
                    Prev
                </button>
                <span class="as-vehicles-page-label">Page ${current} of ${maxPage}</span>
                <button
                    class="as-btn as-btn--pill as-vehicles-page-btn as-vehicles-page-next"
                    ${current >= maxPage ? "disabled" : ""}
                >
                    Next
                </button>
            </div>
        `;

        const prev = container.querySelector(".as-vehicles-page-prev");
        const next = container.querySelector(".as-vehicles-page-next");

        if (prev && current > 1) {
            prev.addEventListener("click", () => {
                state.page -= 1;
                renderTable();
                renderPreview();
            });
        }

        if (next && current < maxPage) {
            next.addEventListener("click", () => {
                state.page += 1;
                renderTable();
                renderPreview();
            });
        }
    }

    //========================================
    // Preview Rendering (with Show/Hide Images)
    //========================================
    function renderPreview() {
        if (!rootEl) return;
        const container = rootEl.querySelector("#as-vehicles-preview");
        if (!container) return;

        const veh = getSelectedVehicle();
        if (!veh) {
            container.innerHTML = `
                <div class="as-vehicles-preview__empty">
                    Hover or click a vehicle in the list to see its details.
                </div>
            `;
            return;
        }

        const showImages =
            AS.adminSettings && typeof AS.adminSettings.get === "function"
                ? AS.adminSettings.get().showVehicleImages !== false
                : true;

        const imgPath = `./img/vehicles/${veh.model}.png`;
        const fallbackPath = "./img/vehicle_fallback.png";

        const imageSection = showImages
            ? `
                <div class="as-vehicles-preview-image-wrap">
                    <img
                        src="${imgPath}"
                        onerror="this.onerror=null;this.src='${fallbackPath}';"
                        class="as-vehicles-preview-image"
                        alt="${veh.label}"
                    />
                </div>
            `
            : `
                <div class="as-vehicles-preview-image-wrap as-vehicles-preview-image-wrap--hidden">
                    <div class="as-vehicles-preview-image-placeholder">
                        Vehicle images are hidden (AdminSuite Settings).
                    </div>
                </div>
            `;

        container.innerHTML = `
            <div class="as-vehicles-preview-card">
                ${imageSection}
                <div class="as-vehicles-preview-meta">
                    <div class="as-vehicles-preview-heading">
                        <div class="as-vehicles-preview-title">${veh.label}</div>
                        ${
                            veh.brand
                                ? `<div class="as-vehicles-preview-brand">${veh.brand}</div>`
                                : ""
                        }
                    </div>
                    <div class="as-vehicles-preview-tags">
                        ${
                            veh.classLabel || veh.category
                                ? `<span class="as-tag">${veh.classLabel || veh.category}</span>`
                                : ""
                        }
                        ${
                            veh.shop
                                ? `<span class="as-tag">Shop: ${veh.shop}</span>`
                                : ""
                        }
                    </div>
                    <div class="as-vehicles-preview-model">
                        Spawn name: <code>${veh.model}</code>
                    </div>
                    <div class="as-vehicles-preview-actions">
                        <button
                            id="as-vehicles-preview-spawn"
                            class="as-btn as-btn--pill as-btn--primary"
                        >
                            Spawn Vehicle
                        </button>
                    </div>
                </div>
            </div>
        `;

        const spawnBtn = container.querySelector(
            "#as-vehicles-preview-spawn"
        );
        if (spawnBtn) {
            spawnBtn.addEventListener("click", (ev) => {
                ev.preventDefault();
                if (!veh) return;

                if (AdminSuite && AdminSuite.utils) {
                    AdminSuite.utils.sendNuiCallback(
                        "as:nui:vehicles:spawn",
                        { model: veh.model }
                    );
                }
            });
        }
    }

    //========================================
    // Search Handler
    //========================================
    function renderSearchHandlers() {
        if (!rootEl) return;
        const input = rootEl.querySelector("#as-vehicles-search");
        if (!input) return;

        input.value = state.search || "";

        input.addEventListener("input", (ev) => {
            state.search = ev.target.value || "";
            rebuildFiltered();
            renderTable();
            renderPreview();
        });
    }

    //========================================
    // Main Render
    //========================================
    AS.vehicles.render = function (root, viewState) {
        rootEl = root;
        rootEl.classList.add("as-view--vehicles");

        if (viewState && Array.isArray(viewState.vehicles)) {
            state.list = viewState.vehicles.map(normalizeVehicle).filter(Boolean);
            rebuildFiltered();
            state.selectedIndex =
                state.filtered.length > 0 ? 0 : -1;
        }

        rootEl.innerHTML = `
            <div class="as-card as-card--vehicles">
                <div class="as-card__header as-card__header--vehicles">
                    <div class="as-card__header-main">
                        <div class="as-card__label">Vehicle Navigation</div>
                        <div class="as-card__title">Browse & spawn vehicles</div>
                    </div>
                    <div class="as-card__header-tools">
                        <input
                            id="as-vehicles-search"
                            class="as-input as-input--search"
                            type="text"
                            placeholder="Search by spawn name, brand or class..."
                        />
                    </div>
                </div>

                <div class="as-vehicles-layout">
                    <div class="as-vehicles-list">
                        <div class="as-vehicles-list-inner">
                            <table class="as-table as-vehicles-table">
                                <thead>
                                    <tr>
                                        <th>Spawn</th>
                                        <th>Vehicle</th>
                                        <th>Class</th>
                                    </tr>
                                </thead>
                                <tbody id="as-vehicles-tbody"></tbody>
                            </table>
                        </div>
                        <div class="as-vehicles-pagination" id="as-vehicles-pagination"></div>
                    </div>
                    <div class="as-vehicles-preview" id="as-vehicles-preview">
                        <div class="as-vehicles-preview__empty">
                            Hover or click a vehicle in the list to see its details.
                        </div>
                    </div>
                </div>
            </div>
        `;

        renderSearchHandlers();
        rebuildFiltered();
        if (state.filtered.length > 0 && state.selectedIndex < 0) {
            state.selectedIndex = 0;
        }
        renderTable();
        renderPreview();
    };

    // Called by admin_settings.js when a relevant toggle changes.
    AS.vehicles.applyAdminSettings = function () {
        if (!rootEl) return;
        // Re-render preview so the image section can be shown/hidden.
        renderPreview();
    };

    //========================================
    // List Updater (called from main.js)
    //========================================
    AS.vehicles.setList = function (list) {
        state.list = (list || []).map(normalizeVehicle).filter(Boolean);
        rebuildFiltered();
        if (state.filtered.length > 0 && state.selectedIndex < 0) {
            state.selectedIndex = 0;
        }

        // If we are currently on the Vehicles view, refresh UI
        if (
            window.AdminSuite &&
            window.AdminSuite.router &&
            typeof window.AdminSuite.router.getCurrentView === "function" &&
            window.AdminSuite.router.getCurrentView() === "vehicles" &&
            rootEl
        ) {
            renderTable();
            renderPreview();
        }
    };
})();
