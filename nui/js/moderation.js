window.AdminSuite = window.AdminSuite || {};

(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});
    AS.moderation = AS.moderation || {};

    const state = {
        players: [],
        selectedId: null,
        inventory: null,
        spectate: {
            active: false,
            targetSrc: null,
            targetName: null,
            cursorEnabled: false, // F2 hint from Lua
        },
    };

    //------------------------------------------------------------------
    // RBAC helpers
    //------------------------------------------------------------------

    function getRBACFlags() {
        const ASGlobal = window.AdminSuite || {};
        const rbac = ASGlobal.rbac || {};

        // If we don't yet know the role, don't filter anything (avoid
        // hiding everything before RBAC is loaded from Lua).
        if (!rbac.role) return null;

        return rbac.flags || {};
    }

    function applyRBACToModeration(root) {
        if (!root) return;

        const flags = getRBACFlags();
        if (!flags) {
            // RBAC not loaded yet; don't hide anything.
            return;
        }

        const hasFullAccess = !!flags.full_access;

        // Map NUI actions -> RBAC flag(s)
        const requirements = {
            // Session
            kick: "can_kick",
            warn: "can_warn",
            ban: ["can_ban_perm", "can_ban_temp"],
            unban: ["can_ban_perm", "can_ban_temp"],

            // Health & Control
            heal: "can_heal_revive",
            revive: "can_heal_revive",
            freeze: "can_freeze",
            unfreeze: "can_freeze",

            // Teleport
            bring: "can_teleport",
            goto: "can_teleport",
            sendBack: "can_teleport",

            // Spectate
            "spectate:start": "can_spectate",

            // Inventory / Items
            viewInventory: "can_view_inv",
            giveItem: "can_give_item",
            removeItem: "can_take_item",

            //Screenshot Player
            screenshot: "can_screenshot_player",


            // Economy
            giveMoney: "can_give_money",
            takeMoney: "can_take_money",
        };

        const hasFlag = (name) =>
            hasFullAccess || (name && flags && !!flags[name]);

        // Hide disallowed buttons
        root.querySelectorAll("[data-action]").forEach((btn) => {
            const action = btn.getAttribute("data-action");
            const requirement = requirements[action];

            let allowed = true;

            if (Array.isArray(requirement)) {
                allowed = requirement.some((flag) => hasFlag(flag));
            } else if (typeof requirement === "string") {
                allowed = hasFlag(requirement);
            }

            if (!allowed) {
                btn.classList.add("as-hidden-rbac");
            }
        });

        // Hide entire groups that have no visible buttons
        root.querySelectorAll(".as-moderation__group").forEach((group) => {
            const buttons = Array.from(
                group.querySelectorAll("[data-action]")
            );
            if (buttons.length === 0) return;

            const anyVisible = buttons.some(
                (btn) => !btn.classList.contains("as-hidden-rbac")
            );

            if (!anyVisible) {
                group.classList.add("as-hidden-rbac");
            }
        });
    }

    //------------------------------------------------------------------
    // Ban presets
    //------------------------------------------------------------------

    const BAN_REASON_PRESETS = {
        "24h": [
            "RDM (first offense)",
            "VDM (first offense)",
            "Powergaming",
            "Metagaming (minor)",
            "Fail RP (scene disruption)",
        ],
        "48h": [
            "Repeated RDM/VDM",
            "Combat logging",
            "Minor exploiting / glitch abuse",
            "Toxic behavior",
            "Staff disrespect",
        ],
        "72h": [
            "Severe fail RP",
            "Harassment / targeting",
            "Ban evasion attempt",
            "Suspicious third-party tools",
            "Economy harm / duping (minor)",
        ],
        perm: [
            "Cheating / Mod menu",
            "IRL threats / doxxing",
            "Chargeback / fraud",
            "Severe exploitation / duping",
            "Mass griefing / raiding",
        ],
    };

    //------------------------------------------------------------------
    // Cached DOM nodes
    //------------------------------------------------------------------

    let mainGridEl = null;
    let tableEl = null;
    let tbodyEl = null;
    let searchInput = null;
    let refreshBtn = null;
    let actionsRoot = null;

    // Inventory overlay cached nodes
    let inventoryOverlayEl = null;
    let inventoryTitleEl = null;
    let inventorySubtitleEl = null;
    let inventorySearchEl = null;
    let inventoryTbodyEl = null;
    let inventoryCloseBtn = null;

    // Spectate floating overlay
    let spectateOverlayEl = null;
    let spectateNameEl = null;

    //------------------------------------------------------------------
    // Helpers
    //------------------------------------------------------------------

    function resetCachedElements() {
        mainGridEl = null;
        tableEl = null;
        tbodyEl = null;
        searchInput = null;
        refreshBtn = null;
        actionsRoot = null;

        inventoryOverlayEl = null;
        inventoryTitleEl = null;
        inventorySubtitleEl = null;
        inventorySearchEl = null;
        inventoryTbodyEl = null;
        inventoryCloseBtn = null;
        // Spectate overlay is global and kept
    }

    function ensureElements() {
        if (!mainGridEl) {
            mainGridEl = document.getElementById("as-moderation-main");
        }

        if (!tableEl) {
            tableEl = document.getElementById("as-moderation-table");
        }
        if (tableEl && !tbodyEl) {
            tbodyEl = tableEl.querySelector("tbody");
            if (!tbodyEl) {
                tbodyEl = document.createElement("tbody");
                tableEl.appendChild(tbodyEl);
            }
        }
        if (!searchInput) {
            searchInput = document.getElementById("as-moderation-search");
        }
        if (!refreshBtn) {
            refreshBtn = document.getElementById("as-moderation-refresh");
        }
        if (!actionsRoot) {
            actionsRoot = document.getElementById("as-moderation-actions");
        }

        if (!inventoryOverlayEl) {
            inventoryOverlayEl = document.getElementById(
                "as-moderation-inventory-overlay"
            );
        }
        if (!inventoryTitleEl) {
            inventoryTitleEl = document.getElementById("as-inventory-title");
        }
        if (!inventorySubtitleEl) {
            inventorySubtitleEl = document.getElementById(
                "as-inventory-subtitle"
            );
        }
        if (!inventorySearchEl) {
            inventorySearchEl = document.getElementById("as-inventory-search");
        }
        if (!inventoryTbodyEl) {
            inventoryTbodyEl = document.getElementById("as-inventory-rows");
        }
        if (!inventoryCloseBtn) {
            inventoryCloseBtn = document.getElementById("as-inventory-close");
        }

        if (tableEl) {
            const thead = tableEl.querySelector("thead");
            if (thead) {
                thead.innerHTML = `
                    <tr>
                        <th>ID</th>
                        <th>Player</th>
                        <th>Job</th>
                        <th>Bank</th>
                        <th>Cash</th>
                        <th>Ping</th>
                    </tr>
                `;
            }
        }
    }

    function formatMoney(value) {
        const num = Number(value) || 0;
        return "$" + num.toLocaleString();
    }

    function matchesSearch(player, term) {
        if (!term) return true;
        term = term.toLowerCase();

        const id = String(player.id || player.src || "");
        const name = String(player.name || "");
        const job = String(player.job || "");

        return (
            id.toLowerCase().includes(term) ||
            name.toLowerCase().includes(term) ||
            job.toLowerCase().includes(term)
        );
    }

    function getSelectedPlayer() {
        if (!state.selectedId) return null;
        return state.players.find(
            (p) => String(p.id || p.src) === String(state.selectedId)
        );
    }

    function getSpectatePlayer() {
        if (!state.spectate.active || !state.spectate.targetSrc) return null;
        return {
            id: state.spectate.targetSrc,
            src: state.spectate.targetSrc,
            name: state.spectate.targetName || "Unknown",
        };
    }

    function applyRowSelection() {
        ensureElements();
        if (!tbodyEl) return;

        const rows = tbodyEl.querySelectorAll("tr[data-player-id]");
        rows.forEach((row) => {
            if (row.dataset.playerId === String(state.selectedId)) {
                row.classList.add("as-table__row--selected");
            } else {
                row.classList.remove("as-table__row--selected");
            }
        });
    }

    //------------------------------------------------------------------
    // Inline dialog
    //------------------------------------------------------------------

    function openInlineDialog(options) {
        const {
            title = "AdminSuite",
            description = "",
            fields = [],
            confirmLabel = "Confirm",
            cancelLabel = "Cancel",
        } = options || {};

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
            card.style.maxWidth = "420px";
            card.style.width = "100%";
            card.style.padding = "16px";
            card.style.boxSizing = "border-box";

            card.innerHTML = `
                <header class="as-card__header">
                    <h2 class="as-card__title">${title}</h2>
                    <p class="as-card__subtitle">${description}</p>
                </header>
                <div class="as-card__body"></div>
                <footer class="as-card__footer" style="display:flex; justify-content:flex-end; gap:8px; margin-top:12px;">
                    <button class="as-btn as-btn--ghost" data-role="cancel">${cancelLabel}</button>
                    <button class="as-btn as-btn--primary" data-role="confirm">${confirmLabel}</button>
                </footer>
            `;

            const body = card.querySelector(".as-card__body") || card;
            const inputs = {};
            const context = { overlay, card, body };

            fields.forEach((field) => {
                const wrapper = document.createElement("div");
                wrapper.style.marginBottom = "8px";

                if (field.name) {
                    wrapper.dataset.fieldName = field.name;
                }

                if (field.label) {
                    const labelEl = document.createElement("label");
                    labelEl.textContent = field.label;
                    labelEl.style.display = "block";
                    labelEl.style.marginBottom = "4px";
                    wrapper.appendChild(labelEl);
                }

                let inputEl;

                if (field.type === "textarea") {
                    inputEl = document.createElement("textarea");
                    inputEl.rows = field.rows || 3;
                    inputEl.className = "as-input";
                } else if (field.type === "select") {
                    inputEl = document.createElement("select");
                    inputEl.className = "as-input";
                    const options = field.options || [];
                    options.forEach((opt) => {
                        const optEl = document.createElement("option");
                        optEl.value = opt.value;
                        optEl.textContent = opt.label;
                        if (
                            field.defaultValue !== undefined &&
                            field.defaultValue === opt.value
                        ) {
                            optEl.selected = true;
                        }
                        inputEl.appendChild(optEl);
                    });
                } else {
                    inputEl = document.createElement("input");
                    inputEl.type = field.type || "text";
                    inputEl.className = "as-input";
                    if (
                        field.defaultValue !== undefined &&
                        field.defaultValue !== null
                    ) {
                        inputEl.value = String(field.defaultValue);
                    }
                }

                if (field.placeholder) {
                    inputEl.placeholder = field.placeholder;
                }

                wrapper.appendChild(inputEl);
                body.appendChild(wrapper);

                if (field.name) {
                    inputs[field.name] = inputEl;
                }
            });

            // Optional hooks
            fields.forEach((field) => {
                if (!field.name) return;
                const inputEl = inputs[field.name];
                if (!inputEl) return;

                if (typeof field.onInit === "function") {
                    try {
                        field.onInit(inputEl, inputs, context);
                    } catch (e) {
                        console.warn(
                            "AdminSuite moderation: field.onInit error",
                            e
                        );
                    }
                }

                if (typeof field.onChange === "function") {
                    const eventName =
                        field.changeEvent ||
                        (field.type === "select" ? "change" : "input");
                    inputEl.addEventListener(eventName, () => {
                        try {
                            field.onChange(inputEl, inputs, context);
                        } catch (e) {
                            console.warn(
                                "AdminSuite moderation: field.onChange error",
                                e
                            );
                        }
                    });
                }
            });

            overlay.addEventListener("click", (ev) => {
                if (ev.target === overlay) {
                    cleanup(null);
                }
            });

            card.addEventListener("click", (ev) => {
                ev.stopPropagation();
            });

            const cancelBtn = card.querySelector('[data-role="cancel"]');
            const confirmBtn = card.querySelector('[data-role="confirm"]');

            function cleanup(result) {
                if (overlay.parentNode) {
                    overlay.parentNode.removeChild(overlay);
                }
                resolve(result);
            }

            if (cancelBtn) {
                cancelBtn.addEventListener("click", () => cleanup(null));
            }
            if (confirmBtn) {
                confirmBtn.addEventListener("click", () => {
                    const result = {};
                    Object.keys(inputs).forEach((key) => {
                        result[key] = inputs[key].value;
                    });
                    cleanup(result);
                });
            }

            overlay.appendChild(card);
            document.body.appendChild(overlay);

            const firstInput = card.querySelector("input, textarea, select");
            if (firstInput) firstInput.focus();
        });
    }

    function populateBanReasons(selectEl, durationKey) {
        if (!selectEl) return;
        const presets = BAN_REASON_PRESETS[durationKey] || [];
        selectEl.innerHTML = "";
        if (!presets.length) {
            const opt = document.createElement("option");
            opt.value = "";
            opt.textContent = "No presets available";
            selectEl.appendChild(opt);
            return;
        }
        presets.forEach((label) => {
            const opt = document.createElement("option");
            opt.value = label;
            opt.textContent = label;
            selectEl.appendChild(opt);
        });
    }

    //------------------------------------------------------------------
    // Spectate floating overlay
    //------------------------------------------------------------------

    function ensureSpectateOverlay() {
        if (spectateOverlayEl) return;

        const wrapper = document.createElement("div");
        wrapper.id = "as-spectate-overlay";
        wrapper.className = "as-spectate-overlay as-spectate-overlay--hidden";

        wrapper.innerHTML = `
            <div class="as-spectate-card">
                <div class="as-spectate-lines">
                    <span class="as-spectate-hint">Using &larr; / &rarr; to cycle players</span>
                    <span class="as-spectate-hint">F2 to toggle Cursor</span>
                </div>

                <div class="as-spectate-main">
                    <span class="as-spectate-label">Spectating:</span>
                    <span class="as-spectate-name" id="as-spectate-name">Unknown</span>
                </div>

                <div class="as-spectate-divider"></div>

                <div class="as-spectate-actions">
                    <button class="as-spectate-action-btn" data-spectate-action="kick">Kick</button>
                    <button class="as-spectate-action-btn" data-spectate-action="warn">Warn</button>
                    <button class="as-spectate-action-btn" data-spectate-action="ban">Ban</button>
                    <button class="as-spectate-action-btn as-spectate-action-btn--primary" data-spectate-action="stop">
                        Stop Spectate
                    </button>
                </div>
            </div>
        `;

        document.body.appendChild(wrapper);

        spectateOverlayEl = wrapper;
        spectateNameEl = wrapper.querySelector("#as-spectate-name");

        // Button wiring
        wrapper
            .querySelectorAll("[data-spectate-action]")
            .forEach((btn) => {
                btn.addEventListener("click", () => {
                    const type = btn.getAttribute("data-spectate-action");
                    const spectatePlayer = getSpectatePlayer();
                    if (!spectatePlayer) return;

                    if (type === "stop") {
                        handleActionClick("spectate:stop", spectatePlayer);
                        return;
                    }

                    if (type === "kick") {
                        handleActionClick("kick", spectatePlayer);
                    } else if (type === "warn") {
                        handleActionClick("warn", spectatePlayer);
                    } else if (type === "ban") {
                        handleActionClick("ban", spectatePlayer);
                    }
                });
            });
    }

    function updateSpectateOverlay() {
        ensureSpectateOverlay();

        if (!spectateOverlayEl) return;

        if (state.spectate.active) {
            spectateOverlayEl.classList.remove(
                "as-spectate-overlay--hidden"
            );

            if (spectateNameEl) {
                spectateNameEl.textContent =
                    state.spectate.targetName ||
                    (state.spectate.targetSrc
                        ? `ID ${state.spectate.targetSrc}`
                        : "Unknown");
            }
        } else {
            spectateOverlayEl.classList.add(
                "as-spectate-overlay--hidden"
            );
        }

        spectateOverlayEl.classList.toggle(
            "as-spectate-overlay--cursor",
            !!state.spectate.cursorEnabled
        );
    }

    //------------------------------------------------------------------
    // Action Panel
    //------------------------------------------------------------------

    function renderActionPanel(player) {
        ensureElements();
        if (!actionsRoot) return;

        if (!player) {
            actionsRoot.innerHTML = `
                <div class="as-empty">
                    <p class="as-empty__title">No player selected</p>
                    <p class="as-empty__subtitle">
                        Click a player on the left to open moderation tools.
                    </p>
                </div>
            `;
            return;
        }

        const id = player.id || player.src || "-";
        const name = player.name || "Unknown";
        const job = player.job || "-";
        const bank = formatMoney(player.bank);
        const cash = formatMoney(player.cash);
        const ping =
            player.ping !== undefined && player.ping !== null
                ? player.ping
                : "-";

        actionsRoot.innerHTML = `
            <div class="as-stack" style="gap: 1rem;">
                <div class="as-moderation__summary">
                    <div class="as-moderation__summary-main">
                        <h3 class="as-card__title">${name}</h3>
                        <p class="as-card__subtitle">
                            ID: ${id} • Job: ${job} • Ping: ${ping}
                        </p>
                    </div>
                    <div class="as-moderation__summary-money">
                        <span>Bank: <strong>${bank}</strong></span><br />
                        <span>Cash: <strong>${cash}</strong></span>
                    </div>
                </div>

                <div class="as-moderation__group">
                    <h4 class="as-moderation__group-title">Session</h4>
                    <div class="as-moderation__actions">
                        <button class="as-btn as-btn--danger" data-action="kick">Kick</button>
                        <button class="as-btn as-btn--danger" data-action="warn">Warn</button>
                        <button class="as-btn as-btn--danger" data-action="ban">Ban</button>                        
                    </div>
                </div>

                <div class="as-moderation__group">
                    <h4 class="as-moderation__group-title">Health & Control</h4>
                    <div class="as-moderation__actions">
                        <button class="as-btn" data-action="heal">Heal</button>
                        <button class="as-btn" data-action="revive">Revive</button>
                        <button class="as-btn as-btn--outline" data-action="freeze">Freeze</button>
                        <button class="as-btn as-btn--outline" data-action="unfreeze">Unfreeze</button>
                    </div>
                </div>

                <div class="as-moderation__group">
                    <h4 class="as-moderation__group-title">Teleport</h4>
                    <div class="as-moderation__actions">
                        <button class="as-btn" data-action="bring">Bring</button>
                        <button class="as-btn" data-action="goto">Goto</button>
                        <button class="as-btn" data-action="sendBack">Send Back</button>
                    </div>
                </div>

                <div class="as-moderation__group">
                    <h4 class="as-moderation__group-title">Spectate</h4>
                    <div class="as-moderation__actions">
                        <button class="as-btn as-btn--outline" data-action="spectate:start">Start</button>
                    </div>
                </div>

                <div class="as-moderation__group">
                    <h4 class="as-moderation__group-title">Messaging</h4>
                    <div class="as-moderation__actions">
                        <button class="as-btn" data-action="message">Message Player</button>
                    </div>
                </div>

                <div class="as-moderation__group">
                    <h4 class="as-moderation__group-title">Economy</h4>
                    <div class="as-moderation__actions">
                        <button class="as-btn" data-action="giveMoney">Give Money</button>
                        <button class="as-btn" data-action="takeMoney">Take Money</button>
                    </div>
                </div>

<div class="as-moderation__group">
    <h4 class="as-moderation__group-title">Inventory</h4>
    <div class="as-moderation__actions">
        <button class="as-btn" data-action="viewInventory">View Inventory</button>
        <!-- Give / Remove Item actions are now handled in the Items view -->
    </div>
</div>

            </div>
        `;

        // Apply RBAC hiding
        applyRBACToModeration(actionsRoot);

        actionsRoot.querySelectorAll("[data-action]").forEach((btn) => {
            btn.addEventListener("click", () => {
                const action = btn.getAttribute("data-action");
                handleActionClick(action, player);
            });
        });
    }

    //------------------------------------------------------------------
    // Action Handling
    //------------------------------------------------------------------

    async function handleActionClick(action, player) {
        if (!player) {
            console.warn(
                "[AdminSuite] No player selected for moderation action:",
                action
            );
            return;
        }

        const targetId = player.id || player.src;
        if (!targetId) {
            console.warn(
                "[AdminSuite] Unable to resolve player ID for moderation action:",
                action
            );
            return;
        }

        let extra = {};

        switch (action) {
            case "kick": {
                const result = await openInlineDialog({
                    title: "Kick Player",
                    description: `Provide a reason for kicking ${
                        player.name || "this player"
                    }.`,
                    fields: [
                        {
                            name: "reason",
                            label: "Reason",
                            type: "text",
                            placeholder: "Rule violation, fail RP, etc.",
                            defaultValue: "Rule violation",
                        },
                    ],
                    confirmLabel: "Kick",
                    cancelLabel: "Cancel",
                });
                if (!result) return;
                extra.reason = result.reason || "Rule violation";
                break;
            }

            case "warn": {
                const result = await openInlineDialog({
                    title: "Warn Player",
                    description: `Provide a reason for warning ${
                        player.name || "this player"
                    }.`,
                    fields: [
                        {
                            name: "reason",
                            label: "Reason",
                            type: "text",
                            placeholder: "Explain the warning to the player.",
                            defaultValue: "Please follow the rules",
                        },
                    ],
                    confirmLabel: "Warn",
                    cancelLabel: "Cancel",
                });
                if (!result) return;
                extra.reason = result.reason || "Please follow the rules";
                break;
            }

            case "ban": {
                const result = await openInlineDialog({
                    title: "Ban Player",
                    description:
                        "Select a preset duration and a common reason, or choose Custom to enter your own duration and reason.",
                    fields: [
                        {
                            name: "preset",
                            label: "Ban Duration",
                            type: "select",
                            defaultValue: "24h",
                            options: [
                                { value: "24h", label: "24 hours" },
                                { value: "48h", label: "48 hours" },
                                { value: "72h", label: "72 hours" },
                                { value: "perm", label: "Permanent" },
                                { value: "custom", label: "Custom" },
                            ],
                            onInit: (inputEl, inputs, context) => {
                                try {
                                    const flags = getRBACFlags();
                                    let canPermBan = true;

                                    if (flags) {
                                        canPermBan = !!(
                                            flags.full_access ||
                                            flags.can_ban_perm
                                        );
                                    }

                                    const allowedValues = canPermBan
                                        ? ["24h", "48h", "72h", "perm", "custom"]
                                        : ["24h", "48h", "72h"];

                                    const existingOptions = Array.from(
                                        inputEl.options || []
                                    );
                                    const currentValue =
                                        inputEl.value || "24h";

                                    inputEl.innerHTML = "";

                                    existingOptions.forEach((opt) => {
                                        if (
                                            allowedValues.indexOf(opt.value) !==
                                            -1
                                        ) {
                                            const o =
                                                document.createElement(
                                                    "option"
                                                );
                                            o.value = opt.value;
                                            o.textContent = opt.textContent;
                                            inputEl.appendChild(o);
                                        }
                                    });

                                    if (
                                        allowedValues.indexOf(currentValue) !==
                                        -1
                                    ) {
                                        inputEl.value = currentValue;
                                    } else if (allowedValues.length > 0) {
                                        inputEl.value = allowedValues[0];
                                    }
                                } catch (e) {
                                    console.warn(
                                        "[AdminSuite] Failed to apply RBAC to ban durations",
                                        e
                                    );
                                }

                                const reasonSelect = inputs["reasonPreset"];
                                if (reasonSelect) {
                                    populateBanReasons(
                                        reasonSelect,
                                        inputEl.value || "24h"
                                    );
                                }

                                if (context && context.card) {
                                    const customDurationWrapper =
                                        context.card.querySelector(
                                            '[data-field-name="customDuration"]'
                                        );
                                    const customReasonWrapper =
                                        context.card.querySelector(
                                            '[data-field-name="customReason"]'
                                        );
                                    if (customDurationWrapper)
                                        customDurationWrapper.style.display =
                                            "none";
                                    if (customReasonWrapper)
                                        customReasonWrapper.style.display =
                                            "none";
                                }
                            },
                            onChange: (inputEl, inputs, context) => {
                                const durationKey =
                                    inputEl.value || "24h";
                                const reasonSelect =
                                    inputs["reasonPreset"];

                                if (reasonSelect) {
                                    if (durationKey === "custom") {
                                        reasonSelect.innerHTML = "";
                                        const opt =
                                            document.createElement(
                                                "option"
                                            );
                                        opt.value = "";
                                        opt.textContent =
                                            "Custom reason (use field below)";
                                        reasonSelect.appendChild(opt);
                                        reasonSelect.disabled = true;
                                    } else {
                                        reasonSelect.disabled = false;
                                        populateBanReasons(
                                            reasonSelect,
                                            durationKey
                                        );
                                    }
                                }

                                if (context && context.card) {
                                    const customDurationWrapper =
                                        context.card.querySelector(
                                            '[data-field-name="customDuration"]'
                                        );
                                    const customReasonWrapper =
                                        context.card.querySelector(
                                            '[data-field-name="customReason"]'
                                        );

                                    const showCustom =
                                        durationKey === "custom";
                                    if (customDurationWrapper) {
                                        customDurationWrapper.style.display =
                                            showCustom ? "block" : "none";
                                    }
                                    if (customReasonWrapper) {
                                        customReasonWrapper.style.display =
                                            showCustom ? "block" : "none";
                                    }
                                }
                            },
                        },
                        {
                            name: "reasonPreset",
                            label: "Ban Reason",
                            type: "select",
                            options: [],
                        },
                        {
                            name: "customDuration",
                            label: "Custom Duration",
                            type: "text",
                            placeholder: "e.g. 1h, 6h, 3d, 999d",
                            defaultValue: "",
                        },
                        {
                            name: "customReason",
                            label: "Custom Reason",
                            type: "text",
                            placeholder: "Describe the rule violation",
                            defaultValue: "",
                        },
                    ],
                    confirmLabel: "Ban",
                    cancelLabel: "Cancel",
                });
                if (!result) return;

                const preset = result.preset || "24h";
                const reasonPreset = result.reasonPreset || "";
                const customDuration = result.customDuration || "";
                const customReason = result.customReason || "";

                let durationStr;
                switch (preset) {
                    case "24h":
                        durationStr = "24h";
                        break;
                    case "48h":
                        durationStr = "48h";
                        break;
                    case "72h":
                        durationStr = "72h";
                        break;
                    case "perm":
                        durationStr = "perm";
                        break;
                    case "custom":
                        durationStr = customDuration || "0";
                        break;
                    default:
                        durationStr = "24h";
                        break;
                }

                let reasonStr;
                if (preset === "custom") {
                    reasonStr =
                        customReason && customReason.trim().length > 0
                            ? customReason.trim()
                            : "Custom ban (no reason provided)";
                } else {
                    reasonStr =
                        reasonPreset && reasonPreset.trim().length > 0
                            ? reasonPreset.trim()
                            : "Serious rule violation";
                }

                extra.reason = reasonStr;
                extra.duration = durationStr;
                break;
            }

            case "unban": {
                const result = await openInlineDialog({
                    title: "Unban Player",
                    description:
                        "Are you sure you want to unban this player? This action will be logged in the audit trail.",
                    fields: [],
                    confirmLabel: "Unban",
                    cancelLabel: "Cancel",
                });
                if (!result) return;
                break;
            }

            case "heal":
            case "revive":
            case "freeze":
            case "unfreeze":
            case "bring":
            case "goto":
            case "sendBack":
            case "spectate:start":
            case "spectate:stop": {
                // No extra UI
                break;
            }

            case "message": {
                const result = await openInlineDialog({
                    title: "Message Player",
                    description: `Send a staff message to ${
                        player.name || "this player"
                    }.`,
                    fields: [
                        {
                            name: "message",
                            label: "Message",
                            type: "textarea",
                            rows: 3,
                            placeholder: "Type your message here...",
                        },
                    ],
                    confirmLabel: "Send",
                    cancelLabel: "Cancel",
                });
                if (!result) return;
                extra.message = result.message || "";
                break;
            }

            case "giveMoney":
            case "takeMoney": {
                const result = await openInlineDialog({
                    title: action === "giveMoney" ? "Give Money" : "Take Money",
                    description: `Specify the account type and amount for ${
                        player.name || "this player"
                    }.`,
                    fields: [
                        {
                            name: "account",
                            label: "Account",
                            type: "select",
                            defaultValue: "bank",
                            options: [
                                { value: "bank", label: "Bank" },
                                { value: "cash", label: "Cash" },
                            ],
                        },
                        {
                            name: "amount",
                            label: "Amount",
                            type: "number",
                            placeholder: "e.g. 1000",
                            defaultValue: "0",
                        },
                    ],
                    confirmLabel:
                        action === "giveMoney" ? "Give" : "Take",
                    cancelLabel: "Cancel",
                });
                if (!result) return;

                const amountNum = Number(result.amount || 0);
                if (!amountNum || isNaN(amountNum) || amountNum <= 0) {
                    alert("Please enter a valid amount greater than 0.");
                    return;
                }
                extra.account = result.account || "bank";
                extra.amount = amountNum;
                break;
            }

            case "viewInventory": {
                // No extra fields; click simply tells Lua to fetch & send snapshot
                break;
            }

            case "giveItem":
            case "removeItem": {
                const result = await openInlineDialog({
                    title: action === "giveItem" ? "Give Item" : "Remove Item",
                    description: `Specify the item and amount for ${
                        player.name || "this player"
                    }.`,
                    fields: [
                        {
                            name: "item",
                            label: "Item Name",
                            type: "text",
                            placeholder:
                                "e.g. bread, water, weapon_pistol",
                        },
                        {
                            name: "amount",
                            label: "Amount",
                            type: "number",
                            placeholder: "e.g. 1, 5, 10",
                            defaultValue: "1",
                        },
                    ],
                    confirmLabel:
                        action === "giveItem" ? "Give" : "Remove",
                    cancelLabel: "Cancel",
                });
                if (!result) return;

                const amountNum = Number(result.amount || 0);
                if (!amountNum || isNaN(amountNum) || amountNum <= 0) {
                    alert("Please enter a valid amount greater than 0.");
                    return;
                }
                extra.item = result.item || "";
                extra.amount = amountNum;
                break;
            }

            default:
                console.warn(
                    "[AdminSuite] Unknown moderation action:",
                    action
                );
                return;
        }

        // High-risk confirmations (optional via AdminSuite Settings)
        const confirmHighRisk =
            window.AdminSuite &&
            window.AdminSuite.adminSettings &&
            typeof window.AdminSuite.adminSettings.get === "function"
                ? window.AdminSuite.adminSettings.get().confirmHighRisk !== false
                : true;

        const HIGH_RISK_ACTIONS = new Set(["bring", "goto", "sendBack", "removeItem"]);
        if (confirmHighRisk && HIGH_RISK_ACTIONS.has(action)) {
            const titleMap = {
                bring: "Bring Player",
                goto: "Go To Player",
                sendBack: "Send Back Player",
                removeItem: "Remove Item",
            };
            const title = titleMap[action] || "Confirm Action";
            const who = player.name || `ID ${targetId}`;
            const description =
                action === "removeItem"
                    ? `Are you sure you want to remove item(s) from ${who}?`
                    : `Are you sure you want to ${action} ${who}?`;

            const ok = await openInlineDialog({
                title,
                description,
                fields: [],
                confirmLabel: "Confirm",
                cancelLabel: "Cancel",
            });
            if (!ok) return;
        }

        if (window.AdminSuite && AdminSuite.utils) {
            AdminSuite.utils.sendNuiCallback(
                "as:nui:moderation:executeAction",
                {
                    action,
                    target: targetId,
                    extra,
                }
            );

            // Actions that should auto-close the main panel
            const CLOSE_PANEL_ACTIONS = new Set([
                "kick",
                "warn",
                "ban",
                "unban",
                "bring",
                "goto",
                "sendBack",
                "heal",
                "revive",
                "freeze",
                "unfreeze",
                "giveItem",
                "removeItem",
                "giveMoney",
                "takeMoney",
                "spectate:start",
                "spectate:stop",
            ]);

            if (CLOSE_PANEL_ACTIONS.has(action)) {
                AdminSuite.utils.sendNuiCallback("as:nui:panel:close", {});
            }

            // Customized moderation notifications
            if (typeof AdminSuite.utils.notify === "function") {
                const displayName =
                    (player && player.name) ||
                    (player &&
                        (player.id || player.src) &&
                        `ID ${player.id || player.src}`) ||
                    "player";

                // No success toast for these actions; only errors if any
                if (
                    action === "bring" ||
                    action === "goto" ||
                    action === "sendBack" ||
                    action === "spectate:start"
                ) {
                    // Intentionally no notification
                } else {
                    let msg;

                    switch (action) {
                        // Core moderation
                        case "kick":
                            // "Playername has been Kicked"
                            msg = `${displayName} has been Kicked`;
                            break;
                        case "warn":
                            // "You have warned "Playername""
                            msg = `You have warned "${displayName}"`;
                            break;
                        case "ban":
                            // "playername has been banned!!"
                            msg = `${displayName} has been banned!!`;
                            break;
                        case "unban":
                            msg = `You have unbanned "${displayName}"`;
                            break;

                        // Health & Control
                        case "heal":
                            // "Playername has been healed"
                            msg = `${displayName} has been healed`;
                            break;
                        case "revive":
                            // "You have revived "playername""
                            msg = `You have revived "${displayName}"`;
                            break;
                        case "freeze":
                            // "You have Froze "playername""
                            msg = `You have Froze "${displayName}"`;
                            break;
                        case "unfreeze":
                            // "You have Unfroze "playername""
                            msg = `You have Unfroze "${displayName}"`;
                            break;

                        // Economy (money)
                        case "giveMoney":
                        case "takeMoney": {
                            const amount =
                                extra && typeof extra.amount !== "undefined"
                                    ? extra.amount
                                    : undefined;

                            if (amount !== undefined) {
                                msg =
                                    action === "giveMoney"
                                        ? `You have given ${amount} to "${displayName}"`
                                        : `You have taken ${amount} from "${displayName}"`;
                            } else {
                                msg =
                                    action === "giveMoney"
                                        ? `You have given money to "${displayName}"`
                                        : `You have taken money from "${displayName}"`;
                            }
                            break;
                        }

                        // Spectate stop still gets a toast
                        case "spectate:stop":
                            msg = `Stopped spectating ${displayName}.`;
                            break;

                        // Items and misc
                        case "giveItem":
                            msg = `You have given items to "${displayName}"`;
                            break;
                        case "removeItem":
                            msg = `You have removed items from "${displayName}"`;
                            break;

                        default:
                            msg = `Requested action for ${displayName}.`;
                            break;
                    }

                    if (msg) {
                        AdminSuite.utils.notify(msg, { type: "info" });
                    }
                }
            }
        }
    }

    //------------------------------------------------------------------
    // Table rendering
    //------------------------------------------------------------------

    function renderTable() {
        ensureElements();
        if (!tbodyEl) return;

        const searchTerm = searchInput ? searchInput.value.trim() : "";
        const filtered = state.players.filter((p) =>
            matchesSearch(p, searchTerm)
        );

        tbodyEl.innerHTML = "";

        if (!filtered.length) {
            tbodyEl.innerHTML = `
                <tr>
                    <td colspan="6">No players online.</td>
                </tr>
            `;
            renderActionPanel(null);
            return;
        }

        filtered.forEach((p) => {
            const id = p.id || p.src || 0;
            const name = p.name || "-";
            const job = p.job || "-";
            const bank = formatMoney(p.bank);
            const cash = formatMoney(p.cash);
            const ping =
                p.ping !== undefined && p.ping !== null ? p.ping : "-";

            const roleColor = p.roleColor || null;
            const isStaff = !!p.isStaff;

            const staffStyle = roleColor
                ? `style="color: ${roleColor};"`
                : "";
            const staffClass = isStaff ? "as-table__row--staff" : "";

            const tr = document.createElement("tr");
            tr.className = staffClass;
            tr.dataset.playerId = String(id);
            tr.innerHTML = `
                <td>${id}</td>
                <td ${staffStyle}>${name}</td>
                <td>${job}</td>
                <td>${bank}</td>
                <td>${cash}</td>
                <td>${ping}</td>
            `;

            tr.addEventListener("click", () => {
                state.selectedId = String(id);
                applyRowSelection();

                const player = state.players.find(
                    (pl) => String(pl.id || pl.src) === String(id)
                );

                if (
                    window.AdminSuite &&
                    AdminSuite.moderation &&
                    typeof AdminSuite.moderation.onSelectPlayer === "function"
                ) {
                    AdminSuite.moderation.onSelectPlayer(player || null);
                } else {
                    renderActionPanel(player || null);
                }

                if (window.AdminSuite && AdminSuite.utils) {
                    AdminSuite.utils.sendNuiCallback(
                        "as:nui:moderation:selectPlayer",
                        { targetId: id }
                    );
                }
            });

            tbodyEl.appendChild(tr);
        });

        applyRowSelection();
        renderActionPanel(getSelectedPlayer());
    }

    //------------------------------------------------------------------
    // Inventory overlay rendering
    //------------------------------------------------------------------

    function renderInventoryRows() {
        ensureElements();
        if (!inventoryTbodyEl) return;

        const data = state.inventory || {};
        let items = Array.isArray(data.items) ? data.items.slice() : [];

        const query =
            (inventorySearchEl &&
                inventorySearchEl.value &&
                inventorySearchEl.value.trim().toLowerCase()) ||
            "";

        if (query.length > 0) {
            items = items.filter((item) => {
                const name = (item.name || "").toLowerCase();
                const label = (item.label || "").toLowerCase();
                const meta = (item.meta || "").toLowerCase();
                return (
                    name.includes(query) ||
                    label.includes(query) ||
                    meta.includes(query)
                );
            });
        }

        if (!items.length) {
            inventoryTbodyEl.innerHTML = `
                <tr>
                    <td colspan="5" style="text-align:center; opacity:0.7;">
                        No items found.
                    </td>
                </tr>
            `;
            return;
        }

        const rowsHtml = items
            .map((item) => {
                const slot = item.slot ?? "";
                const label = item.label || item.name || "Unknown";
                const count = item.count ?? 0;
                const weight =
                    item.weight != null && item.weight !== ""
                        ? item.weight
                        : "";
                const meta = item.meta || "";

                return `
                    <tr>
                        <td>${slot}</td>
                        <td>${label}</td>
                        <td>${count}</td>
                        <td>${weight}</td>
                        <td>${meta}</td>
                    </tr>
                `;
            })
            .join("");

        inventoryTbodyEl.innerHTML = rowsHtml;
    }

    //------------------------------------------------------------------
    // Public API
    //------------------------------------------------------------------

    AS.moderation.updatePlayers = function (players) {
        state.players = Array.isArray(players) ? players : [];

        if (
            state.selectedId &&
            !state.players.find(
                (p) => String(p.id || p.src) === String(state.selectedId)
            )
        ) {
            state.selectedId = null;
        }

        renderTable();
    };

    AS.moderation.setPlayers = AS.moderation.updatePlayers;

AS.moderation.getSelectedPlayerId = function () {
    return state.selectedId;
};

AS.moderation.getSelectedPlayer = function () {
    // Use the internal helper defined earlier in this file
    return getSelectedPlayer();
};

// Clears the selected player so that the actions panel returns
// to the "No player selected" state. Used when the panel closes.
AS.moderation.clearSelection = function () {
    state.selectedId = null;
    applyRowSelection();
    renderActionPanel(null);
};

AS.moderation.requestPlayers = function () {
    if (window.AdminSuite && AdminSuite.utils) {
        AdminSuite.utils.sendNuiCallback(
            "as:nui:moderation:loadPlayers",
            {}
        );
    }
};


    AS.moderation.requestPlayers = function () {
        if (window.AdminSuite && AdminSuite.utils) {
            AdminSuite.utils.sendNuiCallback(
                "as:nui:moderation:loadPlayers",
                {}
            );
        }
    };

    AS.moderation.onSelectPlayer = function (player) {
        if (player && (player.id || player.src)) {
            state.selectedId = String(player.id || player.src);
        }
        applyRowSelection();
        renderActionPanel(player || getSelectedPlayer());
    };

    // Inventory hooks
    AS.moderation.openInventory = function (payload) {
        ensureElements();
        if (!inventoryOverlayEl) return;

        state.inventory = payload || {};

        const targetName =
            payload.targetName ||
            (payload.targetCitizen &&
                `CID ${String(payload.targetCitizen)}`) ||
            (payload.target && `ID ${String(payload.target)}`) ||
            "Unknown player";

        if (inventoryTitleEl) {
            inventoryTitleEl.textContent = `Inventory – ${targetName}`;
        }

        if (inventorySubtitleEl) {
            const idPart = payload.target
                ? `player ID ${payload.target}`
                : "player";
            inventorySubtitleEl.textContent = `Read-only snapshot for ${idPart}`;
        }

        if (inventorySearchEl) {
            inventorySearchEl.value = "";
        }

        inventoryOverlayEl.classList.remove(
            "as-inventory-overlay--hidden"
        );
        renderInventoryRows();
    };

    AS.moderation.closeInventory = function () {
        ensureElements();
        if (!inventoryOverlayEl) return;
        inventoryOverlayEl.classList.add("as-inventory-overlay--hidden");
        state.inventory = null;
    };

    // Spectate hooks (Lua -> NUI)
    AS.moderation.onSpectateStart = function (payload) {
        payload = payload || {};
        state.spectate.active = true;
        state.spectate.targetSrc = payload.targetSrc || payload.target || null;
        state.spectate.targetName =
            payload.targetName || payload.playerName || null;
        updateSpectateOverlay();
    };

    AS.moderation.onSpectateUpdate = function (payload) {
        payload = payload || {};
        if (!state.spectate.active) return;
        state.spectate.targetSrc =
            payload.targetSrc || payload.target || state.spectate.targetSrc;
        state.spectate.targetName =
            payload.targetName ||
            payload.playerName ||
            state.spectate.targetName;
        updateSpectateOverlay();
    };

    AS.moderation.onSpectateStop = function () {
        state.spectate.active = false;
        state.spectate.targetSrc = null;
        state.spectate.targetName = null;
        updateSpectateOverlay();
    };

    //------------------------------------------------------------------
    // NUI message listener
    //------------------------------------------------------------------

    window.addEventListener("message", function (event) {
        const data = event.data || {};
        const action = data.action || data.event;

        // From AS.ClientUtils.SendNUI in client/player_moderation.lua
        if (action === "as:nui:moderation:spectate:start") {
            const payload = data.payload || data.data || data;
            AS.moderation.onSpectateStart(payload);
            return;
        }

        if (action === "as:nui:moderation:spectate:update") {
            const payload = data.payload || data.data || data;
            AS.moderation.onSpectateUpdate(payload);
            return;
        }

        if (action === "as:nui:moderation:spectate:stop") {
            AS.moderation.onSpectateStop();
            return;
        }

        // From SendNUIMessage({ type = 'as:spectate:...' })
        if (data.type === "as:spectate:enter") {
            document.body.classList.add("as-spectate-mode");
            return;
        }

        if (data.type === "as:spectate:exit") {
            document.body.classList.remove("as-spectate-mode");
            AS.moderation.onSpectateStop();
            return;
        }

        if (data.type === "as:spectate:cursor") {
            state.spectate.cursorEnabled = !!data.enabled;
            updateSpectateOverlay();
            return;
        }
    });

    //------------------------------------------------------------------
    // View render
    //------------------------------------------------------------------

    AS.moderation.render = function (root) {
        resetCachedElements();

        root.innerHTML = `
            <div id="as-moderation-main" class="as-grid">
                <!-- Player list -->
                <section class="as-card" style="grid-column: span 7;">
                    <header class="as-card__header">
                        <div>
                            <h2 class="as-card__title">Player Moderation</h2>
                            <p class="as-card__subtitle">
                                Live player list with staff highlighting
                            </p>
                        </div>
                        <div style="display:flex; gap:8px; align-items:center;">
                            <input
                                id="as-moderation-search"
                                type="text"
                                placeholder="Search by ID, name, or job"
                                class="as-input"
                                style="min-width:220px;"
                            />
                            <button class="as-chip" id="as-moderation-refresh">
                                Refresh
                            </button>
                        </div>
                    </header>
                    <div class="as-card__body">
                        <table class="as-table" id="as-moderation-table">
                            <thead></thead>
                            <tbody>
                                <tr>
                                    <td colspan="6">Loading players…</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </section>

                <!-- Action panel -->
                <section class="as-card" style="grid-column: span 5;">
                    <header class="as-card__header">
                        <h2 class="as-card__title">Moderation Actions</h2>
                        <p class="as-card__subtitle">
                            Apply actions to the selected player.
                        </p>
                    </header>
                    <div class="as-card__body" id="as-moderation-actions">
                        <div class="as-empty">
                            <p class="as-empty__title">No player selected</p>
                            <p class="as-empty__subtitle">
                                Click a player on the left to open moderation tools.
                            </p>
                        </div>
                    </div>
                </section>
            </div>

            <!-- Inventory overlay (hidden by default) -->
            <div id="as-moderation-inventory-overlay" class="as-inventory-overlay as-inventory-overlay--hidden">
                <div class="as-inventory-window as-card">
                    <header class="as-card__header">
                        <div>
                            <h3 class="as-card__title" id="as-inventory-title">
                                Inventory
                            </h3>
                            <p class="as-card__subtitle" id="as-inventory-subtitle">
                                Read-only snapshot of the player inventory.
                            </p>
                        </div>
                        <button
                            class="as-btn as-btn--ghost"
                            type="button"
                            id="as-inventory-close"
                        >
                            Close
                        </button>
                    </header>
                    <div class="as-card__body">
                        <div class="as-inventory-toolbar">
                            <input
                                type="text"
                                id="as-inventory-search"
                                class="as-input"
                                placeholder="Search by item or metadata..."
                            />
                        </div>
                        <div class="as-inventory-table-wrap">
                            <table class="as-table">
                                <thead>
                                    <tr>
                                        <th>Slot</th>
                                        <th>Item</th>
                                        <th>Count</th>
                                        <th>Weight</th>
                                        <th>Details</th>
                                    </tr>
                                </thead>
                                <tbody id="as-inventory-rows"></tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        `;

        ensureElements();

        // Player list interactions
        if (searchInput) {
            searchInput.addEventListener("input", () => {
                renderTable();
            });
        }

        if (refreshBtn) {
            refreshBtn.addEventListener("click", () => {
                AS.moderation.requestPlayers();
            });
        }

        // Inventory overlay interactions
        if (inventoryCloseBtn && inventoryOverlayEl) {
            inventoryCloseBtn.addEventListener("click", () => {
                AS.moderation.closeInventory();
            });
        }

        if (inventoryOverlayEl) {
            inventoryOverlayEl.addEventListener("click", (ev) => {
                if (ev.target === inventoryOverlayEl) {
                    AS.moderation.closeInventory();
                }
            });
        }

        if (inventorySearchEl) {
            inventorySearchEl.addEventListener("input", () => {
                renderInventoryRows();
            });
        }

        // Spectate overlay if already active
        updateSpectateOverlay();

        AS.moderation.requestPlayers();
    };
})();
