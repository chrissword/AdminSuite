window.AdminSuite = window.AdminSuite || {};

(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});
    AS.items = AS.items || {};

    // Base path for item icons.
    // For qb-inventory default: nui://qb-inventory/html/images
    // If a server uses a different inventory resource, change only this value.
    const IMAGE_BASE = "nui://qb-inventory/html/images";

    const state = {
        list: [],
        filtered: [],
        search: "",
        page: 1,
        perPage: 8, // fits the container nicely
    };

    let rootEl = null;

    // Tracks items given via AdminSuite in this NUI session:
    // { [targetId]: { [itemName]: totalAmountGiven } }
    const givenTracker = {};

    function recordGiven(targetId, itemName, amount) {
        if (!targetId || !itemName) return;
        const tid = String(targetId);
        const code = String(itemName);
        const amt = Math.max(0, Number(amount) || 0);
        if (amt <= 0) return;

        if (!givenTracker[tid]) givenTracker[tid] = {};
        givenTracker[tid][code] = (givenTracker[tid][code] || 0) + amt;
    }

    function wasGivenViaAdminSuite(targetId, itemName) {
        if (!targetId || !itemName) return false;
        const tid = String(targetId);
        const code = String(itemName);
        return !!(givenTracker[tid] && givenTracker[tid][code] > 0);
    }

    // Normalize item entries pushed from Lua
    function normalizeItem(entry) {
        if (!entry) return null;

        const name = (entry.name || entry.item || "").toString();
        if (!name) return null;

        return {
            name,
            label: entry.label || entry.name || name,
            weight: entry.weight || null,
            type: entry.type || entry.category || "",
            image: entry.image || entry.icon || null,
        };
    }

    function rebuildFiltered() {
        const s = (state.search || "").toLowerCase();
        state.filtered = state.list.filter((it) => {
            if (!s) return true;
            return (
                (it.name || "").toLowerCase().includes(s) ||
                (it.label || "").toLowerCase().includes(s)
            );
        });
    }

    function paginate() {
        const total = state.filtered.length;
        const perPage = state.perPage || 8;
        const maxPage = Math.max(1, Math.ceil(total / perPage));
        const current = Math.min(Math.max(state.page || 1, 1), maxPage);

        state.page = current;

        const start = (current - 1) * perPage;
        return state.filtered.slice(start, start + perPage);
    }

    // Pagination controls, modeled after Vehicles
    function renderPagination() {
        if (!rootEl) return;

        const container = rootEl.querySelector("#as-items-pagination");
        if (!container) return;

        const total = state.filtered.length;
        const perPage = state.perPage || 8;
        const maxPage = Math.max(1, Math.ceil(total / perPage));
        const current = state.page || 1;

        // Debug: JSON so F8 shows real numbers
        console.log(
            "[Items] Pagination: " +
                JSON.stringify({ total, perPage, maxPage, current })
        );

        if (!total) {
            container.innerHTML = "";
            return;
        }

        container.innerHTML = `
            <div class="as-vehicles-pagination-inner">
                <button
                    class="as-btn as-btn--pill as-vehicles-page-btn as-items-page-prev"
                    ${current <= 1 ? "disabled" : ""}
                >
                    Prev
                </button>
                <span class="as-vehicles-page-label">
                    Page ${current} of ${maxPage}
                </span>
                <button
                    class="as-btn as-btn--pill as-vehicles-page-btn as-items-page-next"
                    ${current >= maxPage ? "disabled" : ""}
                >
                    Next
                </button>
            </div>
        `;

        const prev = container.querySelector(".as-items-page-prev");
        const next = container.querySelector(".as-items-page-next");

        if (prev && current > 1) {
            prev.addEventListener("click", () => {
                state.page = Math.max(1, state.page - 1);
                renderTable();
            });
        }

        if (next && current < maxPage) {
            next.addEventListener("click", () => {
                state.page = Math.min(maxPage, state.page + 1);
                renderTable();
            });
        }
    }

    function renderTargetPlayer() {
        if (!rootEl) return;

        const container = rootEl.querySelector("#as-items-target");
        if (!container) return;

        let html = `
            <div class="as-no-player">
                <h3>Target Player</h3>
                <p>No player selected.</p>
                <p>Select a player in <strong>Player Moderation</strong> first.</p>
            </div>
        `;

        const mod = window.AdminSuite && AdminSuite.moderation;

        if (mod) {
            let player = null;

            if (typeof mod.getSelectedPlayer === "function") {
                player = mod.getSelectedPlayer();
            }

            let id = null;
            let name = null;

            if (player) {
                id = player.id || player.src || null;
                name =
                    player.name ||
                    player.charName ||
                    player.playerName ||
                    null;
            } else if (typeof mod.getSelectedPlayerId === "function") {
                // Fallback: only ID is available
                id = mod.getSelectedPlayerId();
            }

            if (id || name) {
                const displayName = name || `ID ${id}`;

                html = `
                    <div class="as-target-player">
                        <h3>Target Player</h3>
                        <p>Name: <strong>${displayName}</strong></p>
                        ${
                            id
                                ? `<p>Server ID: <span>#${id}</span></p>`
                                : ""
                        }
                        <p>Selected in Player Moderation.</p>
                    </div>
                `;
            }
        }

        container.innerHTML = html;
    }

    function renderTable() {
        if (!rootEl) return;

        const tbody = rootEl.querySelector("#as-items-tbody");
        if (!tbody) return;

        const pageItems = paginate();

        if (!pageItems.length) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="3">
                        <div class="as-empty">
                            <p class="as-empty__title">No items found</p>
                            <p class="as-empty__subtitle">
                                Check your inventory configuration or try refreshing the list.
                            </p>
                        </div>
                    </td>
                </tr>
            `;
            renderPagination();
            renderTargetPlayer();
            return;
        }

        const showImages =
            window.AdminSuite &&
            window.AdminSuite.adminSettings &&
            typeof window.AdminSuite.adminSettings.get === "function"
                ? window.AdminSuite.adminSettings.get().showItemImages !== false
                : true;

        tbody.innerHTML = pageItems
            .map(
                (it) => `
                <tr class="as-items-row">
                    <td>
                        <div class="as-item-main">
                            <div class="as-item-icon">
                                ${
                                    showImages && it.image
                                        ? `<img src="${IMAGE_BASE}/${it.image}" alt="${it.label}" />`
                                        : `<div class="as-item-placeholder">${it.label
                                              .charAt(0)
                                              .toUpperCase()}</div>`
                                }
                            </div>
                            <div class="as-item-text">
                                <div class="as-item-label">${it.label}</div>
                                <div class="as-item-name">${it.name}</div>
                            </div>
                        </div>
                    </td>

                    <td>
                        <div class="as-item-meta">
                            <span class="as-chip">${it.type || "item"}</span>
                            <span class="as-chip">Weight: ${
                                it.weight != null ? it.weight : "—"
                            }</span>
                        </div>
                    </td>

                    <td>
                        <div class="as-item-actions">
                            <button 
                                class="as-btn as-btn--pill as-btn--primary"
                                data-role="give"
                                data-item="${it.name}"
                                data-label="${it.label}"
                            >Give</button>

                            <button 
                                class="as-btn as-btn--pill as-btn--danger"
                                data-role="take"
                                data-item="${it.name}"
                                data-label="${it.label}"
                            >Take</button>
                        </div>
                    </td>
                </tr>
            `
            )
            .join("");

        renderPagination();

        const mod = window.AdminSuite && AdminSuite.moderation;
        const utils = window.AdminSuite && AdminSuite.utils;

        function getTargetId() {
            if (!mod || typeof mod.getSelectedPlayerId !== "function") return null;
            return mod.getSelectedPlayerId();
        }

        function getTargetLabel() {
            if (!mod) return "";

            if (typeof mod.getSelectedPlayer === "function") {
                const p = mod.getSelectedPlayer();
                if (p) {
                    const id = p.id || p.src || null;
                    const name =
                        p.name ||
                        p.charName ||
                        p.playerName ||
                        null;

                    if (name && id) return `${name} (#${id})`;
                    if (name) return name;
                    if (id) return `ID ${id}`;
                }
            }

            if (typeof mod.getSelectedPlayerId === "function") {
                const id = mod.getSelectedPlayerId();
                return id ? `ID ${id}` : "";
            }

            return "";
        }

        function notify(message, type) {
            if (utils && typeof utils.notify === "function") {
                utils.notify(message, { type: type || "info" });
            } else {
                console.log("[AdminSuite:Items:Notify]", type, message);
            }
        }

        // Mini "How Many?" overlay
        function openQuantityPrompt(actionLabel, displayName, onConfirm) {
            if (!rootEl) return;

            // Remove any existing prompt
            const existing = rootEl.querySelector(".as-items-qty-overlay");
            if (existing && existing.parentNode) {
                existing.parentNode.removeChild(existing);
            }

            const overlay = document.createElement("div");
            overlay.className = "as-items-qty-overlay";

            Object.assign(overlay.style, {
                position: "absolute",
                inset: "0",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                background: "rgba(0, 0, 0, 0.45)",
                zIndex: "50",
            });

            overlay.innerHTML = `
                <div class="as-card" style="min-width:260px; padding:16px;">
                    <h3 style="margin-top:0; margin-bottom:8px;">
                        ${actionLabel === "give" ? "Give Item" : "Take Item"}
                    </h3>
                    <p style="margin:0 0 8px 0;">
                        How Many <strong>${displayName}</strong>?
                    </p>
                    <div style="margin-bottom:12px;">
                        <input
                            id="as-items-qty-input"
                            type="number"
                            min="1"
                            step="1"
                            value="1"
                            class="as-input"
                            style="width:100%;"
                        />
                    </div>
                    <div style="display:flex; justify-content:flex-end; gap:8px;">
                        <button class="as-btn as-btn--secondary" data-role="cancel">
                            Cancel
                        </button>
                        <button class="as-btn as-btn--primary" data-role="confirm">
                            Confirm</button>
                    </div>
                </div>
            `;

            rootEl.appendChild(overlay);

            const input = overlay.querySelector("#as-items-qty-input");
            const cancelBtn = overlay.querySelector('[data-role="cancel"]');
            const confirmBtn = overlay.querySelector('[data-role="confirm"]');

            function close() {
                if (overlay && overlay.parentNode) {
                    overlay.parentNode.removeChild(overlay);
                }
            }

            if (cancelBtn) {
                cancelBtn.addEventListener("click", () => {
                    close();
                });
            }

            if (confirmBtn) {
                confirmBtn.addEventListener("click", () => {
                    if (!input) {
                        close();
                        return;
                    }

                    const raw = String(input.value || "").trim();
                    const amount = parseInt(raw, 10);

                    if (!Number.isFinite(amount) || amount <= 0) {
                        notify("Please enter a valid quantity of 1 or more.", "error");
                        return;
                    }

                    close();
                    onConfirm(amount);
                });
            }

            if (input) {
                input.focus();
                input.select();

                input.addEventListener("keydown", (ev) => {
                    if (ev.key === "Enter") {
                        ev.preventDefault();
                        if (confirmBtn) confirmBtn.click();
                    } else if (ev.key === "Escape") {
                        ev.preventDefault();
                        close();
                    }
                });
            }
        }

        // Confirmation for removing items not given via AdminSuite
        function openNotGivenConfirm(displayName, amount, targetText, onDecision) {
            if (!rootEl) {
                onDecision(false);
                return;
            }

            const existing = rootEl.querySelector(".as-items-confirm-overlay");
            if (existing && existing.parentNode) {
                existing.parentNode.removeChild(existing);
            }

            const overlay = document.createElement("div");
            overlay.className = "as-items-confirm-overlay";

            Object.assign(overlay.style, {
                position: "absolute",
                inset: "0",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                background: "rgba(0, 0, 0, 0.45)",
                zIndex: "60",
            });

            overlay.innerHTML = `
                <div class="as-card" style="min-width:280px; padding:16px;">
                    <h3 style="margin-top:0; margin-bottom:8px;">Are you sure?</h3>
                    <p style="margin:0 0 8px 0;">
                        Item <strong>${displayName}</strong> (x${amount}) does not appear
                        to have been given through <strong>AdminSuite</strong>.
                    </p>
                    <p style="margin:0 0 12px 0;">
                        This may be an investigative removal.
                    </p>
                    ${
                        targetText
                            ? `<p style="margin:0 0 12px 0;">Target: <strong>${targetText}</strong></p>`
                            : ""
                    }
                    <div style="display:flex; justify-content:flex-end; gap:8px;">
                        <button class="as-btn as-btn--secondary" data-role="no">
                            No
                        </button>
                        <button class="as-btn as-btn--danger" data-role="yes">
                            Yes, remove
                        </button>
                    </div>
                </div>
            `;

            rootEl.appendChild(overlay);

            const noBtn = overlay.querySelector('[data-role="no"]');
            const yesBtn = overlay.querySelector('[data-role="yes"]');

            function close() {
                if (overlay && overlay.parentNode) {
                    overlay.parentNode.removeChild(overlay);
                }
            }

            if (noBtn) {
                noBtn.addEventListener("click", () => {
                    close();
                    onDecision(false);
                });
            }

            if (yesBtn) {
                yesBtn.addEventListener("click", () => {
                    close();
                    onDecision(true);
                });
            }
        }

        function openRemoveConfirm(displayName, amount, targetText, onDecision) {
            if (!rootEl) {
                onDecision(false);
                return;
            }

            const existing = rootEl.querySelector(".as-items-confirm-overlay");
            if (existing && existing.parentNode) {
                existing.parentNode.removeChild(existing);
            }

            const overlay = document.createElement("div");
            overlay.className = "as-items-confirm-overlay";

            Object.assign(overlay.style, {
                position: "absolute",
                inset: "0",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                background: "rgba(0, 0, 0, 0.45)",
                zIndex: "60",
            });

            overlay.innerHTML = `
                <div class="as-card" style="min-width:280px; padding:16px;">
                    <h3 style="margin-top:0; margin-bottom:8px;">Confirm removal</h3>
                    <p style="margin:0 0 12px 0;">
                        Remove <strong>${displayName}</strong> (x${amount})?
                    </p>
                    ${
                        targetText
                            ? `<p style="margin:0 0 12px 0;">Target: <strong>${targetText}</strong></p>`
                            : ""
                    }
                    <div style="display:flex; justify-content:flex-end; gap:8px;">
                        <button class="as-btn as-btn--secondary" data-role="no">Cancel</button>
                        <button class="as-btn as-btn--danger" data-role="yes">Remove</button>
                    </div>
                </div>
            `;

            overlay.addEventListener("click", (ev) => {
                const role = ev.target && ev.target.getAttribute
                    ? ev.target.getAttribute("data-role")
                    : null;
                if (role === "yes") {
                    overlay.remove();
                    onDecision(true);
                } else if (role === "no") {
                    overlay.remove();
                    onDecision(false);
                }
            });

            rootEl.appendChild(overlay);
        }

        // Wire buttons with proper behavior
        tbody.querySelectorAll('[data-role="give"]').forEach((btn) => {
            btn.addEventListener("click", () => {
                const targetId = getTargetId();
                const itemName = btn.dataset.item;             // spawncode
                const itemLabel = btn.dataset.label || itemName; // pretty name

                if (!targetId) {
                    notify("Please select a player first", "error");
                    console.warn(
                        "[AdminSuite:Items] Give clicked with no player selected."
                    );
                    return;
                }

                openQuantityPrompt("give", itemLabel, (amount) => {
                    console.log(
                        "[AdminSuite:Items] Give",
                        itemName,
                        "x",
                        amount,
                        "-> target",
                        targetId
                    );

                    // Record that this item was given via AdminSuite
                    recordGiven(targetId, itemName, amount);

                    if (utils && typeof utils.sendNuiCallback === "function") {
                        utils.sendNuiCallback("as:nui:moderation:executeAction", {
                            action: "giveItem",
                            target: targetId,
                            extra: {
                                item: itemName,  // spawncode
                                amount: amount,
                            },
                        });
                    }

                    const targetLabel = getTargetLabel();
                    notify(
                        `Requested to give ${amount}x ${itemLabel} to ${
                            targetLabel || `player ID ${targetId}`
                        }.`,
                        "info"
                    );
                });
            });
        });

        tbody.querySelectorAll('[data-role="take"]').forEach((btn) => {
            btn.addEventListener("click", () => {
                const targetId = getTargetId();
                const itemName = btn.dataset.item;             // spawncode
                const itemLabel = btn.dataset.label || itemName; // pretty name

                if (!targetId) {
                    notify("Please select a player first", "error");
                    console.warn(
                        "[AdminSuite:Items] Take clicked with no player selected."
                    );
                    return;
                }

                openQuantityPrompt("take", itemLabel, (amount) => {
                    const targetText = getTargetLabel();
                    const wasGiven = wasGivenViaAdminSuite(targetId, itemName);
                    const confirmHighRisk =
                        window.AdminSuite &&
                        window.AdminSuite.adminSettings &&
                        typeof window.AdminSuite.adminSettings.get === "function"
                            ? window.AdminSuite.adminSettings.get().confirmHighRisk !== false
                            : true;

                    const performRemove = () => {
                        console.log(
                            "[AdminSuite:Items] Take",
                            itemName,
                            "x",
                            amount,
                            "-> target",
                            targetId
                        );

                        if (utils && typeof utils.sendNuiCallback === "function") {
                            utils.sendNuiCallback("as:nui:moderation:executeAction", {
                                action: "removeItem",
                                target: targetId,
                                extra: {
                                    item: itemName,  // spawncode
                                    amount: amount,
                                },
                            });
                        }

                        notify(
                            `Requested to remove ${amount}x ${itemLabel} from ${
                                targetText || `player ID ${targetId}`
                            }.`,
                            "info"
                        );
                    };

                    // Confirm behavior depends on settings:
                    // - confirmHighRisk ON: always confirm before removal
                    // - confirmHighRisk OFF: never prompt (even for investigative removals)
                    if (confirmHighRisk) {
                        const fn = !wasGiven ? openNotGivenConfirm : openRemoveConfirm;
                        fn(itemLabel, amount, targetText, (confirmed) => {
                            if (confirmed) performRemove();
                            else notify("Removal cancelled.", "info");
                        });
                    } else {
                        performRemove();
                    }
                });
            });
        });

        // Keep the target player panel in sync whenever we render
        renderTargetPlayer();
    }

    // Called from main.js when Lua sends as:nui:items:load / refresh
    AS.items.setList = function (list) {
        state.list = (Array.isArray(list) ? list : [])
            .map(normalizeItem)
            .filter(Boolean);

        rebuildFiltered();
        state.page = 1;

        if (rootEl) {
            renderTable();
        }
    };

    // Main render for the Items view (called by router.js)
    AS.items.render = function (root, payload) {
        rootEl = root;
        rootEl.classList.add("as-view--items");

        rootEl.innerHTML = `
            <div class="as-section">
                <div class="as-section-header">
                    <div>
                        <h2>Items Navigation</h2>
                        <p>BROWSE SERVER ITEMS</p>
                    </div>

                    <input 
                        id="as-items-search"
                        class="as-input"
                        placeholder="Search items by name/label..."
                    />
                </div>

                <div class="as-section-body">
                    <!-- LEFT: item list -->
                    <div class="as-table-container" style="width: 100%; max-width: 1100px; position: relative;">
                        <table class="as-table">
                            <thead>
                                <tr>
                                    <th>ITEM</th>
                                    <th>META</th>
                                    <th>ACTIONS</th>
                                </tr>
                            </thead>
                            <tbody id="as-items-tbody"></tbody>
                        </table>

                        <div id="as-items-pagination"></div>
                    </div>

                    <!-- RIGHT: target player -->
                    <div class="as-details-container" id="as-items-target">
                        <div class="as-no-player">
                            <h3>Target Player</h3>
                            <p>No player selected.</p>
                            <p>Select a player in <strong>Player Moderation</strong> first.</p>
                        </div>
                    </div>
                </div>
            </div>
        `;

        const incoming =
            (payload && (payload.items || payload.list)) || state.list || [];
        state.list = (Array.isArray(incoming) ? incoming : [])
            .map(normalizeItem)
            .filter(Boolean);

        rebuildFiltered();
        renderTable();

        const search = rootEl.querySelector("#as-items-search");
        if (search) {
            search.value = state.search;
            search.addEventListener("input", () => {
                state.search = search.value;
                rebuildFiltered();
                state.page = 1;
                renderTable();
            });
        }
    };

    // Called by admin_settings.js when a relevant toggle changes.
    AS.items.applyAdminSettings = function () {
        if (!rootEl) return;
        renderTable();
    };
})();
