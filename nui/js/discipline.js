window.AdminSuite = window.AdminSuite || {};

(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});
    AS.discipline = AS.discipline || {};

    const state = {
        players: [],
        selectedIndex: null,
        history: [],
        loadingPlayers: false,
        loadingHistory: false,
        submitting: false,
    };

    let elements = {
        root: null,
        playerSelect: null,
        playerSummary: null,
        refreshPlayersBtn: null,
        reasonInput: null,
        statusInput: null,
        notesInput: null,
        submitBtn: null,
        historyRoot: null,
        historyEmpty: null,
        refreshHistoryBtn: null,
    };

    function safeText(v, fallback) {
        if (v === null || v === undefined) return fallback || "";
        return String(v);
    }

    // Handle ISO strings OR UNIX timestamps in seconds
    function formatDateTime(isoOrTs) {
        if (!isoOrTs && isoOrTs !== 0) return "";
        try {
            let value = isoOrTs;

            // Turn numeric-looking strings into actual numbers
            if (typeof value === "string") {
                const trimmed = value.trim();
                if (trimmed !== "" && !Number.isNaN(Number(trimmed))) {
                    value = Number(trimmed);
                }
            }

            // If it's a number, decide whether it's seconds or ms
            if (typeof value === "number") {
                // Treat smallish positive values as UNIX seconds
                // (DB is returning UNIX_TIMESTAMP(created_at))
                if (value > 0 && value < 1e12) {
                    value = value * 1000;
                }
                const d = new Date(value);
                if (!Number.isNaN(d.getTime())) {
                    return d.toLocaleString();
                }
            } else {
                const d = new Date(value);
                if (!Number.isNaN(d.getTime())) {
                    return d.toLocaleString();
                }
            }

            return safeText(isoOrTs, "");
        } catch (e) {
            return safeText(isoOrTs, "");
        }
    }

    function formatPlayerLabel(p) {
        if (!p) return "No player selected";
        const name = safeText(p.name || p.charName || "Unknown", "Unknown");
        const id = p.serverId != null ? `ID ${p.serverId}` : "";
        const cid = p.citizenid ? `CID ${p.citizenid}` : "";
        const license = p.license || p.identifier || "";

        const parts = [id, cid].filter(Boolean).join(" • ");

        return parts ? `${name} (${parts})` : name;
    }

    // RBAC helper: can the current staff delete discipline entries?
    function canDeleteDiscipline() {
        const ASGlobal = window.AdminSuite || {};
        const rbac = ASGlobal.rbac || {};
        const flags = rbac.flags || {};
        return !!(flags.full_access || flags.can_delete_discipline);
    }

    // Local helper: call a NUI callback and read JSON response
    async function callNui(name, data) {
        const resource =
            (AS.utils && AS.utils.resourceName) || "AdminSuite";

        const res = await fetch(`https://${resource}/${name}`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json; charset=utf-8",
            },
            body: JSON.stringify(data || {}),
        });

        let json = {};
        try {
            json = await res.json();
        } catch (e) {
            json = {};
        }
        return json || {};
    }

    async function loadPlayers() {
        if (state.loadingPlayers) return;
        state.loadingPlayers = true;
        updatePlayersLoadingState();

        try {
            const result = await callNui(
                "as:nui:discipline:getOnlinePlayers",
                {}
            );

            if (!result || result.ok === false) {
                if (AS.utils && AS.utils.notify) {
                    AS.utils.notify(
                        result.error || "Failed to load online players.",
                        "error"
                    );
                }
                state.players = [];
                state.selectedIndex = null;
            } else {
                state.players = Array.isArray(result.players)
                    ? result.players
                    : [];
                // Auto-select first if nothing selected
                if (
                    state.players.length > 0 &&
                    (state.selectedIndex === null ||
                        state.selectedIndex >= state.players.length)
                ) {
                    state.selectedIndex = 0;
                }
            }
        } catch (e) {
            console.error("[AdminSuite:discipline] loadPlayers error:", e);
            state.players = [];
            state.selectedIndex = null;
            if (AS.utils && AS.utils.notify) {
                AS.utils.notify(
                    "Error loading online players.",
                    "error"
                );
            }
        }

        state.loadingPlayers = false;
        updatePlayersLoadingState();
        renderPlayerSelect();
        renderPlayerSummary();
    }

    async function loadHistory() {
        if (state.loadingHistory) return;
        state.loadingHistory = true;
        updateHistoryLoadingState();

        try {
            const result = await callNui(
                "as:nui:discipline:getHistory",
                {}
            );

            if (!result || result.ok === false) {
                if (AS.utils && AS.utils.notify) {
                    AS.utils.notify(
                        result.error ||
                            "Failed to load discipline history.",
                        "error"
                    );
                }
                state.history = [];
            } else {
                state.history = Array.isArray(result.rows)
                    ? result.rows
                    : [];
            }
        } catch (e) {
            console.error("[AdminSuite:discipline] loadHistory error:", e);
            state.history = [];
        }

        state.loadingHistory = false;
        updateHistoryLoadingState();
        renderHistoryTable();
    }

    function updatePlayersLoadingState() {
        if (!elements.refreshPlayersBtn) return;
        elements.refreshPlayersBtn.disabled = !!state.loadingPlayers;
        elements.refreshPlayersBtn.textContent = state.loadingPlayers
            ? "Loading..."
            : "Refresh";
    }

    function updateHistoryLoadingState() {
        if (elements.refreshHistoryBtn) {
            elements.refreshHistoryBtn.disabled = !!state.loadingHistory;
            elements.refreshHistoryBtn.textContent = state.loadingHistory
                ? "Loading..."
                : "Refresh";
        }

        if (!elements.historyRoot) return;
        if (state.loadingHistory) {
            elements.historyRoot.classList.add("as-table--loading");
        } else {
            elements.historyRoot.classList.remove("as-table--loading");
        }
    }

    function getSelectedPlayer() {
        if (state.selectedIndex === null) return null;
        return state.players[state.selectedIndex] || null;
    }

    function renderPlayerSelect() {
        const select = elements.playerSelect;
        if (!select) return;

        select.innerHTML = "";

        if (!state.players.length) {
            const opt = document.createElement("option");
            opt.value = "";
            opt.textContent = "No players online";
            select.appendChild(opt);
            select.disabled = true;
            return;
        }

        state.players.forEach((p, idx) => {
            const opt = document.createElement("option");
            opt.value = String(idx);
            const id = p.serverId != null ? `ID ${p.serverId}` : "";
            const cid = p.citizenid ? `CID ${p.citizenid}` : "";
            const suffix = [id, cid].filter(Boolean).join(" • ");
            opt.textContent = suffix
                ? `${p.name || "Unknown"} (${suffix})`
                : p.name || "Unknown";

            if (state.selectedIndex === idx) {
                opt.selected = true;
            }
            select.appendChild(opt);
        });

        select.disabled = false;
    }

    function renderPlayerSummary() {
        const label = elements.playerSummary;
        if (!label) return;

        const player = getSelectedPlayer();
        if (!player) {
            label.innerHTML =
                '<p class="as-muted">Select an online player from the list to create a discipline entry.</p>';
            return;
        }

        const name = formatPlayerLabel(player);
        const license = safeText(player.license || "", "");
        const cid = safeText(player.citizenid || "", "");
        const id = player.serverId != null ? player.serverId : null;

        label.innerHTML = `
            <div class="as-discipline-target">
                <h3 class="as-card__title">${name}</h3>
                <p class="as-card__subtitle">
                    ${
                        id !== null
                            ? `Server ID: <strong>${id}</strong> • `
                            : ""
                    }
                    ${
                        cid
                            ? `CID: <strong>${cid}</strong> • `
                            : ""
                    }
                    ${
                        license
                            ? `License: <code>${license}</code>`
                            : "License not available"
                    }
                </p>
                <p class="as-muted">
                    Discipline entries will be stored against this character / license
                    so you can see their history across sessions.
                </p>
            </div>
        `;
    }

    async function handleSubmit(e) {
        if (e) e.preventDefault();
        if (state.submitting) return;

        const player = getSelectedPlayer();
        if (!player) {
            if (AS.utils && AS.utils.notify) {
                AS.utils.notify(
                    "Select a player before creating a discipline entry.",
                    "error"
                );
            }
            return;
        }

        const reason = elements.reasonInput
            ? elements.reasonInput.value.trim()
            : "";
        const status = elements.statusInput
            ? elements.statusInput.value.trim()
            : "";
        const notes = elements.notesInput
            ? elements.notesInput.value.trim()
            : "";

        if (!reason) {
            if (AS.utils && AS.utils.notify) {
                AS.utils.notify(
                    "Please select a reason for this discipline action.",
                    "error"
                );
            }
            if (elements.reasonInput) {
                elements.reasonInput.focus();
            }
            return;
        }

        if (!status) {
            if (AS.utils && AS.utils.notify) {
                AS.utils.notify(
                    "Please select a status for this discipline action.",
                    "error"
                );
            }
            if (elements.statusInput) {
                elements.statusInput.focus();
            }
            return;
        }

        state.submitting = true;
        if (elements.submitBtn) {
            elements.submitBtn.disabled = true;
            elements.submitBtn.textContent = "Saving...";
        }

        const payload = {
            targetName: player.name || "Unknown",
            targetCID: player.citizenid || null,
            targetLicense: player.license || null,
            reason,
            status,
            notes,
        };

        try {
            const result = await callNui("as:nui:discipline:add", payload);

            if (result && result.ok === false) {
                if (AS.utils && AS.utils.notify) {
                    AS.utils.notify(
                        result.error ||
                            "Failed to record discipline entry.",
                        "error"
                    );
                }
            } else {
                if (AS.utils && AS.utils.notify) {
                    AS.utils.notify("Discipline entry recorded.", "success");
                }
                if (elements.reasonInput) elements.reasonInput.value = "";
                if (elements.statusInput) elements.statusInput.value = "";
                if (elements.notesInput) elements.notesInput.value = "";
                // Refresh history so the new entry appears
                loadHistory();
            }
        } catch (e2) {
            console.error("[AdminSuite:discipline] submit error:", e2);
            if (AS.utils && AS.utils.notify) {
                AS.utils.notify(
                    "Error while saving discipline entry.",
                    "error"
                );
            }
        }

        state.submitting = false;
        if (elements.submitBtn) {
            elements.submitBtn.disabled = false;
            elements.submitBtn.textContent = "Save Entry";
        }
    }

    function renderHistoryTable() {
        const root = elements.historyRoot;
        const empty = elements.historyEmpty;
        if (!root) return;

        const rows = state.history || [];

        if (!rows.length) {
            root.innerHTML = "";
            if (empty) empty.classList.remove("hidden");
            return;
        }

        if (empty) empty.classList.add("hidden");

        const canDelete = canDeleteDiscipline();

        const table = document.createElement("table");
        table.className = "as-table as-table--compact";

        table.innerHTML = `
            <thead>
                <tr>
                    <th>When</th>
                    <th>Staff</th>
                    <th>Target</th>
                    <th>Reason</th>
                    <th>Status</th>
                    <th>Notes</th>
                    ${
                        canDelete
                            ? '<th style="width: 80px; text-align: right;">Actions</th>'
                            : ""
                    }
                </tr>
            </thead>
            <tbody></tbody>
        `;

        const tbody = table.querySelector("tbody");

        rows.forEach((row) => {
            const tr = document.createElement("tr");

            const entryId = row.id;
            const created =
                row.created_at || row.createdAt || row.timestamp;
            const staffName = safeText(row.staff_name || row.staffName, "");
            const targetName = safeText(
                row.target_name || row.targetName,
                ""
            );
            const reason = safeText(row.reason, "");
            const status = safeText(row.status, "");
            const notes = safeText(row.notes, "");

            const shortReason =
                reason.length > 120
                    ? reason.slice(0, 117) + "..."
                    : reason;
            const shortStatus =
                status.length > 80
                    ? status.slice(0, 77) + "..."
                    : status;
            const shortNotes =
                notes.length > 120 ? notes.slice(0, 117) + "..." : notes;

            tr.innerHTML = `
                <td>${formatDateTime(created)}</td>
                <td>${staffName}</td>
                <td>${targetName}</td>
                <td title="${reason.replace(/"/g, "&quot;")}">${shortReason}</td>
                <td title="${status.replace(/"/g, "&quot;")}">${shortStatus}</td>
                <td title="${notes.replace(/"/g, "&quot;")}">${shortNotes}</td>
                ${
                    canDelete && entryId
                        ? `<td class="as-text-right">
                               <button class="as-chip as-chip--danger as-discipline-delete" data-entry-id="${entryId}">
                                   Delete Entry
                               </button>
                           </td>`
                        : ""
                }
            `;

            tbody.appendChild(tr);
        });

        // Delegate delete clicks (non-blocking two-click confirm)
        if (canDelete) {
            tbody.addEventListener("click", async (evt) => {
                const btn = evt.target.closest(".as-discipline-delete");
                if (!btn) return;

                const id = parseInt(
                    btn.getAttribute("data-entry-id"),
                    10
                );
                if (!id) return;

                const isConfirm = btn.getAttribute("data-confirm") === "1";

                if (!isConfirm) {
                    // First click -> ask for confirmation
                    btn.setAttribute("data-confirm", "1");
                    const originalText = btn.textContent;
                    btn.dataset.originalText = originalText;
                    btn.textContent = "Confirm?";

                    // Auto-reset after 2.5s if they don't click again
                    setTimeout(() => {
                        if (btn.getAttribute("data-confirm") === "1") {
                            btn.removeAttribute("data-confirm");
                            btn.textContent =
                                btn.dataset.originalText || originalText;
                        }
                    }, 2500);

                    return;
                }

                // Second click -> actually delete
                btn.removeAttribute("data-confirm");
                const originalText = btn.dataset.originalText || btn.textContent;
                btn.textContent = "Deleting...";
                btn.disabled = true;

                try {
                    const result = await callNui(
                        "as:nui:discipline:delete",
                        { id }
                    );

                    if (result && result.ok === false) {
                        if (AS.utils && AS.utils.notify) {
                            AS.utils.notify(
                                result.error ||
                                    "Failed to delete discipline entry.",
                                "error"
                            );
                        }
                    } else {
                        if (AS.utils && AS.utils.notify) {
                            AS.utils.notify(
                                "Discipline entry deleted.",
                                "success"
                            );
                        }
                        // Reload history to reflect removal
                        loadHistory();
                    }
                } catch (e) {
                    console.error(
                        "[AdminSuite:discipline] delete error:",
                        e
                    );
                    if (AS.utils && AS.utils.notify) {
                        AS.utils.notify(
                            "Error deleting discipline entry.",
                            "error"
                        );
                    }
                } finally {
                    btn.disabled = false;
                    btn.textContent = originalText;
                }
            });
        }

        root.innerHTML = "";
        root.appendChild(table);
    }

    // Public render entrypoint for router
    AS.discipline.render = function (root) {
        if (!root) return;
        elements.root = root;

        root.innerHTML = `
            <div class="as-grid as-view--discipline">
                <!-- Header -->
                <section class="as-card" style="grid-column: span 12;">
                    <div class="as-card__body">
                        <h1 class="as-card__title">Discipline Center</h1>
                        <p class="as-card__subtitle">
                            Record and review staff discipline actions. Entries are stored in your server database and linked to player characters / licenses.
                        </p>
                    </div>
                </section>

                <!-- Main two-column layout -->
                <section class="as-card" style="grid-column: span 12;">
                    <div class="as-discipline-layout" style="display: grid; grid-template-columns: minmax(0, 4fr) minmax(0, 8fr); gap: 1.5rem;">
                        <!-- LEFT: player selection -->
                        <div class="as-discipline-sidebar">
                            <header class="as-card__header">
                                <h2 class="as-card__title">Select Player</h2>
                                <p class="as-card__subtitle">Choose an online player to attach this discipline entry to.</p>
                            </header>
                            <div class="as-card__body">
                                <div class="as-field">
                                    <label class="as-label" for="as-discipline-player-select">
                                        Online Players
                                    </label>
                                    <div style="display:flex; gap:0.5rem; align-items:center;">
                                        <select id="as-discipline-player-select" class="as-input" style="flex:1;">
                                            <option>Loading...</option>
                                        </select>
                                        <button class="as-chip" id="as-discipline-refresh-players">
                                            Refresh
                                        </button>
                                    </div>
                                </div>
                                <div id="as-discipline-player-summary" class="as-discipline-player-summary" style="margin-top: 0.75rem;">
                                    <p class="as-muted">Loading player list…</p>
                                </div>
                            </div>
                        </div>

                        <!-- RIGHT: form -->
                        <div class="as-discipline-form">
                            <header class="as-card__header">
                                <h2 class="as-card__title">New Discipline Entry</h2>
                                <p class="as-card__subtitle">
                                    Provide a clear reason and any internal notes. This does not automatically kick/ban; it is for record-keeping.
                                </p>
                            </header>
                            <div class="as-card__body">
                                <form id="as-discipline-form" class="as-stack" style="gap: 0.75rem;">

                                    <!-- Reason + Status row -->
                                    <div
                                        class="as-field-row"
                                        style="display:grid;grid-template-columns:minmax(0,4fr) minmax(0,3fr);gap:0.75rem;"
                                    >
                                        <div class="as-field">
                                            <label class="as-label" for="as-discipline-reason">Reason</label>
                                            <select
                                                id="as-discipline-reason"
                                                class="as-input"
                                            >
                                                <option value="">Select a reason…</option>
                                                <option value="FailRP">FailRP</option>
                                                <option value="Toxic Behavior">Toxic Behavior</option>
                                                <option value="Lying to Staff">Lying to Staff</option>
                                                <option value="Hacking">Hacking</option>
                                                <option value="Zero Tolerance">Zero Tolerance</option>
                                                <option value="Disrespecting of Founders">Disrespecting of Founders</option>
                                                <option value="Attacking in Green Zone">Attacking in Green Zone</option>
                                            </select>
                                        </div>

                                        <div class="as-field">
                                            <label class="as-label" for="as-discipline-status">Status</label>
                                            <select
                                                id="as-discipline-status"
                                                class="as-input"
                                            >
                                                <option value="">Select status…</option>
                                                <option value="Permanently Banned">Permanently Banned</option>
                                                <option value="Coached">Coached</option>
                                                <option value="Warned">Warned</option>
                                                <option value="Suspended">Suspended</option>
                                            </select>
                                        </div>
                                    </div>

                                    <!-- Notes full width -->
                                    <div class="as-field">
                                        <label class="as-label" for="as-discipline-notes">
                                            Internal Notes
                                            <span class="as-label__hint">(optional)</span>
                                        </label>
                                        <textarea
                                            id="as-discipline-notes"
                                            class="as-input"
                                            rows="4"
                                            placeholder="Any internal notes, links to clips, staff discussion context, etc."
                                        ></textarea>
                                    </div>

                                    <div>
                                        <button
                                            type="submit"
                                            id="as-discipline-submit"
                                            class="as-btn as-btn--primary"
                                        >
                                            Save Entry
                                        </button>
                                    </div>
                                </form>
                            </div>
                        </div>
                    </div>
                </section>

                <!-- History -->
                <section class="as-card" style="grid-column: span 12;">
                    <header
                        class="as-card__header"
                        style="display:flex;align-items:center;justify-content:space-between;gap:0.75rem;"
                    >
                        <div>
                            <h2 class="as-card__title">Discipline History</h2>
                            <p class="as-card__subtitle">
                                Recent discipline entries across all staff. Use this to review prior actions for repeat offenders.
                            </p>
                        </div>
                        <button id="as-discipline-history-refresh" class="as-chip">
                            Refresh
                        </button>
                    </header>
                    <div class="as-card__body">
                        <p id="as-discipline-history-empty" class="as-muted">
                            No discipline entries have been recorded yet.
                        </p>
                        <div id="as-discipline-history" class="as-discipline-history-table" style="margin-top: 0.5rem;"></div>
                    </div>
                </section>
            </div>
        `;

        // Cache DOM elements
        elements.playerSelect = root.querySelector("#as-discipline-player-select");
        elements.playerSummary = root.querySelector("#as-discipline-player-summary");
        elements.refreshPlayersBtn = root.querySelector("#as-discipline-refresh-players");
        elements.reasonInput = root.querySelector("#as-discipline-reason");
        elements.statusInput = root.querySelector("#as-discipline-status");
        elements.notesInput = root.querySelector("#as-discipline-notes");
        elements.submitBtn = root.querySelector("#as-discipline-submit");
        elements.historyRoot = root.querySelector("#as-discipline-history");
        elements.historyEmpty = root.querySelector("#as-discipline-history-empty");
        elements.refreshHistoryBtn = root.querySelector("#as-discipline-history-refresh");

        if (elements.playerSelect) {
            elements.playerSelect.addEventListener("change", () => {
                const val = elements.playerSelect.value;
                if (val === "" || isNaN(Number(val))) {
                    state.selectedIndex = null;
                } else {
                    state.selectedIndex = Number(val);
                }
                renderPlayerSummary();
            });
        }

        if (elements.refreshPlayersBtn) {
            elements.refreshPlayersBtn.addEventListener("click", () => {
                loadPlayers();
            });
        }

        if (elements.refreshHistoryBtn) {
            elements.refreshHistoryBtn.addEventListener("click", () => {
                loadHistory();
            });
        }

        const form = root.querySelector("#as-discipline-form");
        if (form) {
            form.addEventListener("submit", handleSubmit);
        }

        // Initial load
        loadPlayers();
        loadHistory();
    };
})();
