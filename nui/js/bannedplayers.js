window.AdminSuite = window.AdminSuite || {};

(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});
    AS.bannedPlayers = AS.bannedPlayers || {};

    const state = {
        bans: [],
        selectedId: null, // internal "ban key" (id or target_identifier)
    };

    let tableEl = null;
    let tbodyEl = null;
    let searchInput = null;
    let refreshBtn = null;
    let actionsRoot = null;

    //-------------------------------------------------------
    // Helpers
    //-------------------------------------------------------

    function resetCached() {
        tableEl = null;
        tbodyEl = null;
        searchInput = null;
        refreshBtn = null;
        actionsRoot = null;
    }

    function ensureElements() {
        if (!tableEl)
            tableEl = document.getElementById("as-banned-table");

        if (tableEl && !tbodyEl) {
            tbodyEl = tableEl.querySelector("tbody");
            if (!tbodyEl) {
                tbodyEl = document.createElement("tbody");
                tableEl.appendChild(tbodyEl);
            }
        }

        if (!searchInput)
            searchInput = document.getElementById("as-banned-search");

        if (!refreshBtn)
            refreshBtn = document.getElementById("as-banned-refresh");

        if (!actionsRoot)
            actionsRoot = document.getElementById("as-banned-actions");
    }

    function matchesSearch(entry, term) {
        if (!term) return true;
        term = term.toLowerCase();

        const name    = String(entry.name || "");
        const reason  = String(entry.reason || "");
        const banId   = String(entry.id || "");
        const ident   = String(entry.target_identifier || "");
        const license = String(entry.license || "");
        const discord = String(entry.discord || "");
        const ip      = String(entry.ip || "");
        const bannedBy = String(entry.bannedby || entry.bannedBy || "");

        return (
            name.toLowerCase().includes(term) ||
            reason.toLowerCase().includes(term) ||
            banId.toLowerCase().includes(term) ||
            ident.toLowerCase().includes(term) ||
            license.toLowerCase().includes(term) ||
            discord.toLowerCase().includes(term) ||
            ip.toLowerCase().includes(term) ||
            bannedBy.toLowerCase().includes(term)
        );
    }

    function formatTime(ts) {
        if (!ts) return "-";

        let n = Number(ts);
        if (!Number.isFinite(n) || n <= 0) return "-";

        // If this looks like a Unix seconds timestamp (e.g. 1713123456),
        // convert to milliseconds for JS Date.
        if (n < 10000000000) {
            n *= 1000;
        }

        const d = new Date(n);
        return d.toLocaleString();
    }

    //-------------------------------------------------------
    // Unban dialog
    //-------------------------------------------------------

    function openConfirmUnban(playerName) {
        return new Promise((resolve) => {
            const overlay = document.createElement("div");
            overlay.className = "as-modal-overlay";
            overlay.style.position = "fixed";
            overlay.style.inset = "0";
            overlay.style.background = "rgba(0,0,0,0.45)";
            overlay.style.display = "flex";
            overlay.style.alignItems = "center";
            overlay.style.justifyContent = "center";
            overlay.style.zIndex = "9999";

            const card = document.createElement("div");
            card.className = "as-card";
            card.style.maxWidth = "400px";
            card.style.width = "100%";
            card.style.padding = "16px";

            card.innerHTML = `
                <header class="as-card__header">
                    <h2 class="as-card__title">Unban Player</h2>
                    <p class="as-card__subtitle">Are you sure you want to unban ${playerName}?</p>
                </header>
                <footer class="as-card__footer" style="display:flex; justify-content:flex-end; gap:8px; margin-top:12px;">
                    <button class="as-btn as-btn--ghost" data-role="cancel">Cancel</button>
                    <button class="as-btn as-btn--primary" data-role="confirm">Unban</button>
                </footer>
            `;

            overlay.appendChild(card);
            document.body.appendChild(overlay);

            overlay.addEventListener("click", (ev) => {
                if (ev.target === overlay) cleanup(null);
            });

            card.addEventListener("click", (ev) => ev.stopPropagation());

            const cancelBtn = card.querySelector('[data-role="cancel"]');
            const confirmBtn = card.querySelector('[data-role="confirm"]');

            function cleanup(result) {
                if (overlay.parentNode) overlay.parentNode.removeChild(overlay);
                resolve(result);
            }

            cancelBtn.addEventListener("click", () => cleanup(null));
            confirmBtn.addEventListener("click", () => cleanup(true));
        });
    }

    //-------------------------------------------------------
    // Render action panel
    //-------------------------------------------------------

    function renderActions(entry) {
        ensureElements();

        if (!actionsRoot) return;

        if (!entry) {
            actionsRoot.innerHTML = `
                <div class="as-empty">
                    <p class="as-empty__title">No ban selected</p>
                    <p class="as-empty__subtitle">Click a banned player to view options.</p>
                </div>
            `;
            return;
        }

        const name      = entry.name || "Unknown";
        const banKey    = entry.id || entry.target_identifier || "-";
        const idLabel   = entry.target_identifier || String(entry.id || "-");
        const reason    = entry.reason || "-";
        const bannedAt  = entry.time ? formatTime(entry.time) : "-";
        const expires   = entry.expires ? formatTime(entry.expires) : "Permanent";

        actionsRoot.innerHTML = `
            <div class="as-stack" style="gap:1rem;">
                <div class="as-moderation__summary">
                    <div class="as-moderation__summary-main">
                        <h3 class="as-card__title">${name}</h3>
                        <p class="as-card__subtitle">ID: ${idLabel}</p>
                    </div>
                </div>

                <div class="as-moderation__group">
                    <h4 class="as-moderation__group-title">Ban Details</h4>
                    <p><strong>Reason:</strong> ${reason}</p>
                    <p><strong>Banned At:</strong> ${bannedAt}</p>
                    <p><strong>Expires:</strong> ${expires}</p>
                </div>

                <div class="as-moderation__group">
                    <h4 class="as-moderation__group-title">Actions</h4>
                    <button class="as-btn as-btn--primary" id="as-banned-unban">Unban</button>
                </div>
            </div>
        `;

        const unbanBtn = document.getElementById("as-banned-unban");
        if (unbanBtn) {
            unbanBtn.addEventListener("click", async () => {
                const confirm = await openConfirmUnban(name);
                if (!confirm) return;

                if (window.AdminSuite && AdminSuite.utils) {
                    AdminSuite.utils.sendNuiCallback("as:nui:bannedplayers:unban", {
                        target: banKey,
                    });
                }
            });
        }
    }

    //-------------------------------------------------------
    // Render table
    //-------------------------------------------------------

    function renderTable() {
        ensureElements();
        if (!tbodyEl) return;

        const term = searchInput ? searchInput.value.trim().toLowerCase() : "";
        const filtered = state.bans.filter((b) => matchesSearch(b, term));

        tbodyEl.innerHTML = "";

        if (!filtered.length) {
            tbodyEl.innerHTML = `
                <tr><td colspan="5">No banned players found.</td></tr>
            `;
            renderActions(null);
            return;
        }

        filtered.forEach((entry) => {
            const banKey   = entry.id || entry.target_identifier;
            const idLabel  = entry.target_identifier || String(entry.id || "-");
            const name     = entry.name || "Unknown";
            const reason   = entry.reason || "-";
            const bannedAt = entry.time ? formatTime(entry.time) : "-";
            const expires  = entry.expires ? formatTime(entry.expires) : "Permanent";

            const tr = document.createElement("tr");
            tr.dataset.bannedId = banKey ? String(banKey) : "";

            tr.innerHTML = `
                <td>${idLabel}</td>
                <td>${name}</td>
                <td>${reason}</td>
                <td>${bannedAt}</td>
                <td>${expires}</td>
            `;

            tr.addEventListener("click", () => {
                if (!banKey) return;

                state.selectedId = String(banKey);
                renderActions(entry);

                if (window.AdminSuite && AdminSuite.utils) {
                    AdminSuite.utils.sendNuiCallback("as:nui:bannedplayers:select", {
                        targetId: banKey,
                    });
                }
            });

            tbodyEl.appendChild(tr);
        });

        const selected = state.bans.find((b) => {
            const key = b.id || b.target_identifier;
            return key && String(key) === String(state.selectedId);
        });

        renderActions(selected || null);
    }

    //-------------------------------------------------------
    // Public API
    //-------------------------------------------------------

    AS.bannedPlayers.updateList = function (list) {
        state.bans = Array.isArray(list) ? list : [];

        // If the previously selected ban is no longer present, clear selection
        if (
            state.selectedId &&
            !state.bans.find((b) => {
                const key = b.id || b.target_identifier;
                return key && String(key) === String(state.selectedId);
            })
        ) {
            state.selectedId = null;
        }

        renderTable();
    };

    AS.bannedPlayers.requestList = function () {
        if (window.AdminSuite && AdminSuite.utils) {
            AdminSuite.utils.sendNuiCallback("as:nui:bannedplayers:load", {});
        }
    };

    //-------------------------------------------------------
    // View render
    //-------------------------------------------------------

    AS.bannedPlayers.render = function (root) {
        resetCached();

        root.innerHTML = `
            <div id="as-banned-main" class="as-grid">
                <!-- Banned list -->
                <section class="as-card" style="grid-column: span 7;">
                    <header class="as-card__header">
                        <div>
                            <h2 class="as-card__title">Banned Players</h2>
                            <p class="as-card__subtitle">List of all banned players</p>
                        </div>
                        <div style="display:flex; gap:8px; align-items:center;">
                            <input id="as-banned-search" class="as-input" placeholder="Search by name, ID, or reason" />
                            <button class="as-chip" id="as-banned-refresh">Refresh</button>
                        </div>
                    </header>

                    <div class="as-card__body">
                        <table class="as-table" id="as-banned-table">
                            <thead>
                                <tr>
                                    <th>ID</th>
                                    <th>Player</th>
                                    <th>Reason</th>
                                    <th>Banned At</th>
                                    <th>Expires</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr><td colspan="5">Loading…</td></tr>
                            </tbody>
                        </table>
                    </div>
                </section>

                <!-- Actions -->
                <section class="as-card" style="grid-column: span 5;">
                    <header class="as-card__header">
                        <h2 class="as-card__title">Ban Details</h2>
                        <p class="as-card__subtitle">Select a banned player to view info</p>
                    </header>
                    <div class="as-card__body" id="as-banned-actions">
                        <div class="as-empty">
                            <p class="as-empty__title">No ban selected</p>
                            <p class="as-empty__subtitle">Click a banned player to view details.</p>
                        </div>
                    </div>
                </section>
            </div>
        `;

        ensureElements();

        if (searchInput) {
            searchInput.addEventListener("input", () => renderTable());
        }
        if (refreshBtn) {
            refreshBtn.addEventListener("click", () => AS.bannedPlayers.requestList());
        }

        AS.bannedPlayers.requestList();
    };
})();
