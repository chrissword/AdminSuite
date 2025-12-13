window.AdminSuite = window.AdminSuite || {};
(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});

    const STORAGE_KEY = "AdminSuite:adminSettings";

    const DEFAULTS = {
        confirmHighRisk: true,
        // Theme mode:
        // - "light"  : force light
        // - "dark"   : force dark
        // - "customize" : follow system preference (like old "auto"), but
        //                allow per-theme accent palettes.
        themeMode: "customize",
        autoOpenLastTab: true,
        showVehicleImages: true,
        showItemImages: true,
        adminChatEnterToSend: true,

        // Per-theme accent palettes (applied to CSS vars)
        // Stored as { accent: "#hex", soft: "#hex" }
        darkPalette: { accent: "#f97316", soft: "#38bdf8" },
        lightPalette: { accent: "#f97316", soft: "#38bdf8" },
    };

    const DARK_PALETTES = [
        { id: "ember", label: "Ember", accent: "#f97316", soft: "#38bdf8" },
        { id: "neon", label: "Neon", accent: "#22c55e", soft: "#a855f7" },
        { id: "rose", label: "Rose", accent: "#fb7185", soft: "#60a5fa" },
        { id: "electric", label: "Electric", accent: "#38bdf8", soft: "#fbbf24" },
        { id: "violet", label: "Violet", accent: "#a78bfa", soft: "#34d399" },
        { id: "crimson", label: "Crimson", accent: "#ef4444", soft: "#22c55e" },
        { id: "aqua",     label: "Aqua",     accent: "#06b6d4", soft: "#22c55e" },
        { id: "inferno",  label: "Inferno",  accent: "#ff3b30", soft: "#ff9500" },
        { id: "galaxy",   label: "Galaxy",   accent: "#7c3aed", soft: "#2dd4bf" },
        { id: "ice",      label: "Ice",      accent: "#38bdf8", soft: "#a7f3d0" },
        { id: "magenta",  label: "Magenta",  accent: "#ec4899", soft: "#a78bfa" },
        { id: "sunset",   label: "Sunset",   accent: "#f97316", soft: "#fb7185" },
        { id: "storm",    label: "Storm",    accent: "#60a5fa", soft: "#94a3b8" },
        { id: "toxic",    label: "Toxic",    accent: "#a3e635", soft: "#22c55e" },
    ];

    const LIGHT_PALETTES = [
        { id: "peach", label: "Peach", accent: "#fb7185", soft: "#fbbf24" },
        { id: "mint", label: "Mint", accent: "#34d399", soft: "#60a5fa" },
        { id: "lavender", label: "Lavender", accent: "#a78bfa", soft: "#f472b6" },
        { id: "sky", label: "Sky", accent: "#60a5fa", soft: "#34d399" },
        { id: "lemon", label: "Lemon", accent: "#fbbf24", soft: "#a78bfa" },
        { id: "coral", label: "Coral", accent: "#fda4af", soft: "#93c5fd" },
        // --- Additions (Light) ---
        { id: "blossom",  label: "Blossom",  accent: "#fb7185", soft: "#a78bfa" }, // rose + lavender
        { id: "seafoam",  label: "Seafoam",  accent: "#2dd4bf", soft: "#93c5fd" }, // teal + light blue
        { id: "butter",   label: "Butter",   accent: "#fde047", soft: "#fda4af" }, // yellow + coral
        { id: "cloud",    label: "Cloud",    accent: "#93c5fd", soft: "#c4b5fd" }, // blue + lilac
        { id: "spring",   label: "Spring",   accent: "#86efac", soft: "#60a5fa" }, // soft green + sky
        { id: "orchid",   label: "Orchid",   accent: "#f472b6", soft: "#93c5fd" }, // pink + blue
        { id: "citrus",   label: "Citrus",   accent: "#fbbf24", soft: "#34d399" }, // amber + mint
        { id: "glacier",  label: "Glacier",  accent: "#60a5fa", soft: "#a7f3d0" }, // sky + mint

    ];

    
function hexToRgbTuple(hex) {
    if (typeof hex !== "string") return null;
    let h = hex.trim();
    if (h[0] === "#") h = h.slice(1);
    if (h.length === 3) {
        h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    }
    if (h.length !== 6) return null;
    const num = parseInt(h, 16);
    if (!Number.isFinite(num)) return null;
    const r = (num >> 16) & 255;
    const g = (num >> 8) & 255;
    const b = num & 255;
    return [r, g, b];
}

function setAccentCssVars(el, accentHex, softHex) {
    if (!el) return;
    if (accentHex) el.style.setProperty("--as-accent", accentHex);
    if (softHex) el.style.setProperty("--as-accent-soft", softHex);

    // Also set rgb variants so CSS can safely do rgba(var(--as-accent-rgb), <alpha>)
    const a = hexToRgbTuple(accentHex);
    const s = hexToRgbTuple(softHex);

    if (a) el.style.setProperty("--as-accent-rgb", `${a[0]}, ${a[1]}, ${a[2]}`);
    if (s) el.style.setProperty("--as-accent-soft-rgb", `${s[0]}, ${s[1]}, ${s[2]}`);
}

function loadSettings() {
        let stored = null;

        try {
            const raw = window.localStorage.getItem(STORAGE_KEY);
            if (raw) {
                stored = JSON.parse(raw);
            }
        } catch (e) {
            stored = null;
        }

        const s = Object.assign({}, DEFAULTS, stored || {});

        if (["light", "dark", "customize"].indexOf(s.themeMode) === -1) {
            // Back-compat: old "auto" becomes "customize"
            s.themeMode = s.themeMode === "auto" ? "customize" : DEFAULTS.themeMode;
        }

        s.confirmHighRisk = !!s.confirmHighRisk;
        s.autoOpenLastTab = !!s.autoOpenLastTab;
        s.showVehicleImages = s.showVehicleImages !== false;
        s.showItemImages = s.showItemImages !== false;
        s.adminChatEnterToSend = s.adminChatEnterToSend !== false;

        // Palettes
        const sanitizePalette = (p, fallback) => {
            if (!p || typeof p !== "object") return fallback;
            const accent = typeof p.accent === "string" ? p.accent : fallback.accent;
            const soft = typeof p.soft === "string" ? p.soft : fallback.soft;
            return { accent, soft };
        };
        s.darkPalette = sanitizePalette(s.darkPalette, DEFAULTS.darkPalette);
        s.lightPalette = sanitizePalette(s.lightPalette, DEFAULTS.lightPalette);

        return s;
    }

    function saveSettings(state) {
        try {
            window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
        } catch (e) {
            // ignore
        }
    }

    function applyTheme(state) {
        if (!AS.utils || typeof AS.utils.setTheme !== "function") return;

        const mode = state.themeMode || "customize";

        if (mode === "customize") {
            if (window.matchMedia) {
                const prefersDark = window
                    .matchMedia("(prefers-color-scheme: dark)")
                    .matches;
                AS.utils.setTheme(prefersDark ? "dark" : "light");
            } else {
                AS.utils.setTheme("dark");
            }
        } else {
            AS.utils.setTheme(mode);
        }
    }

    function getActiveThemeName() {
        const body = document.body;
        if (!body) return "dark";
        return body.classList.contains("theme-light") ? "light" : "dark";
    }

    
function applyAccent(state) {
    const body = document.body;
    if (!body) return;

    const activeTheme = getActiveThemeName();
    const p =
        activeTheme === "light"
            ? state.lightPalette || DEFAULTS.lightPalette
            : state.darkPalette || DEFAULTS.darkPalette;

    setAccentCssVars(body, p && p.accent, p && p.soft);
}

    function applyVehicles(state) {
        if (
            AS.vehicles &&
            typeof AS.vehicles.applyAdminSettings === "function"
        ) {
            AS.vehicles.applyAdminSettings(state);
        }
    }

    function applyItems(state) {
        if (AS.items && typeof AS.items.applyAdminSettings === "function") {
            AS.items.applyAdminSettings(state);
        }
    }

    function applyAll(state) {
        applyTheme(state);
        applyAccent(state);
        applyVehicles(state);
        applyItems(state);
        // Admin Chat setting is read on render; no global apply needed.
    }

    AS.adminSettings = {
        _state: loadSettings(),

        init() {
            this._state = loadSettings();
            applyAll(this._state);
        },

        get() {
            return Object.assign({}, this._state);
        },

        save(patch) {
            this._state = Object.assign({}, this._state, patch || {});
            saveSettings(this._state);
            applyAll(this._state);
        },

        shouldAutoOpenLastTab() {
            return !!this._state.autoOpenLastTab;
        },

        render(root) {
            if (!root) return;

            const state = this.get();

            root.innerHTML = `
                <section class="as-view as-view--settings">
                    <header class="as-view__header">
                        <h1 class="as-view__title">AdminSuite Settings</h1>
                        <p class="as-view__subtitle">
                            Customize how the AdminSuite panel behaves just for you.
                        </p>
                    </header>

                    <div class="as-settings-grid">
                        <!-- Behavior -->
                        <section class="as-card">
                            <header class="as-card__header">
                                <div>
                                    <h2 class="as-card__title">Behavior</h2>
                                    <p class="as-card__subtitle">
                                        Safety prompts and Admin Chat behavior.
                                    </p>
                                </div>
                            </header>
                            <div class="as-card__body">
                                <div class="as-settings-row">
                                    <div class="as-settings-row-text">
                                        <div class="as-settings-row-label">
                                            Confirm high-risk actions
                                        </div>
                                        <div class="as-settings-row-help">
                                            Ask for confirmation before Kick, Ban, Teleport and item removal.
                                        </div>
                                    </div>
                                    <div class="as-settings-row-control">
                                        <label class="as-toggle">
                                            <input type="checkbox" id="as-setting-confirm-highrisk" />
                                            <span class="as-toggle__slider"></span>
                                        </label>
                                    </div>
                                </div>

                                <div class="as-settings-row">
                                    <div class="as-settings-row-text">
                                        <div class="as-settings-row-label">
                                            Enter-to-send in Admin Chat
                                        </div>
                                        <div class="as-settings-row-help">
                                            When enabled, Enter sends and Shift+Enter adds a new line.
                                        </div>
                                    </div>
                                    <div class="as-settings-row-control">
                                        <label class="as-toggle">
                                            <input type="checkbox" id="as-setting-adminchat-enter" />
                                            <span class="as-toggle__slider"></span>
                                        </label>
                                    </div>
                                </div>
                            </div>
                        </section>

                        <!-- Appearance -->
                        <section class="as-card">
                            <header class="as-card__header">
                                <div>
                                    <h2 class="as-card__title">Appearance</h2>
                                    <p class="as-card__subtitle">
                                        Theme, scaling and compact layout.
                                    </p>
                                </div>
                            </header>
                            <div class="as-card__body">
                                <div class="as-settings-row">
                                    <div class="as-settings-row-text">
                                        <div class="as-settings-row-label">
                                            Theme
                                        </div>
                                        <div class="as-settings-row-help">
                                            Use light, dark, or follow your system preference.
                                        </div>
                                    </div>
                                    <div class="as-settings-row-control">
                                        <div class="as-settings-pill-group" id="as-setting-theme-group">
                          
                                            <button type="button" data-theme="light" id="as-setting-theme-light" class="as-chip as-settings-pill">
                                                Light
                                            </button>
                                            <button type="button" data-theme="dark" id="as-setting-theme-dark" class="as-chip as-settings-pill">
                                                Dark
                                            </button>
                                        </div>
                                    </div>
                                </div>

                                <div class="as-settings-row">
                                    <div class="as-settings-row-text">
                                        <div class="as-settings-row-label">
                                            Accent palette
                                        </div>
                                        <div class="as-settings-row-help" id="as-setting-palette-help">
                                            Pick an accent set. Dark uses vibrant palettes, light uses pastel palettes.
                                        </div>
                                    </div>
                                    <div class="as-settings-row-control">
                                        <div class="as-settings-palette" id="as-setting-palette"></div>
                                    </div>
                                </div>
                            </div>
                        </section>

                        <!-- Navigation & Data -->
                        <section class="as-card">
                            <header class="as-card__header">
                                <div>
                                    <h2 class="as-card__title">Navigation & Data</h2>
                                    <p class="as-card__subtitle">
                                        Remember your view and control extra visuals.
                                    </p>
                                </div>
                            </header>
                            <div class="as-card__body">
                                <div class="as-settings-row">
                                    <div class="as-settings-row-text">
                                        <div class="as-settings-row-label">
                                            Auto-open last tab
                                        </div>
                                        <div class="as-settings-row-help">
                                            When you open AdminSuite, jump back to the last view you used.
                                        </div>
                                    </div>
                                    <div class="as-settings-row-control">
                                        <label class="as-toggle">
                                            <input type="checkbox" id="as-setting-auto-open-last" />
                                            <span class="as-toggle__slider"></span>
                                        </label>
                                    </div>
                                </div>

                                <div class="as-settings-row">
                                    <div class="as-settings-row-text">
                                        <div class="as-settings-row-label">
                                            Show vehicle images
                                        </div>
                                        <div class="as-settings-row-help">
                                            Toggle preview images in the Vehicles view.
                                        </div>
                                    </div>
                                    <div class="as-settings-row-control">
                                        <label class="as-toggle">
                                            <input type="checkbox" id="as-setting-veh-images" />
                                            <span class="as-toggle__slider"></span>
                                        </label>
                                    </div>
                                </div>

                                <div class="as-settings-row">
                                    <div class="as-settings-row-text">
                                        <div class="as-settings-row-label">
                                            Show item images
                                        </div>
                                        <div class="as-settings-row-help">
                                            Toggle item icons in the Items view.
                                        </div>
                                    </div>
                                    <div class="as-settings-row-control">
                                        <label class="as-toggle">
                                            <input type="checkbox" id="as-setting-item-images" />
                                            <span class="as-toggle__slider"></span>
                                        </label>
                                    </div>
                                </div>

                                <div class="as-settings-row as-settings-row--footer">
                                    <button type="button" id="as-setting-reset" class="as-chip as-chip--soft">
                                        Reset to defaults
                                    </button>
                                </div>
                            </div>
                        </section>
                    </div>
                </section>
            `;

            // Wire up fields
            const confirmHighRisk = document.getElementById(
                "as-setting-confirm-highrisk"
            );
            const adminChatEnter = document.getElementById(
                "as-setting-adminchat-enter"
            );
            const autoOpen = document.getElementById(
                "as-setting-auto-open-last"
            );
            const vehImages = document.getElementById("as-setting-veh-images");
            const itemImages = document.getElementById("as-setting-item-images");
            const resetBtn = document.getElementById("as-setting-reset");

            const paletteWrap = document.getElementById("as-setting-palette");

            const themeButtons = {
                customize: document.getElementById("as-setting-theme-customize"),
                light: document.getElementById("as-setting-theme-light"),
                dark: document.getElementById("as-setting-theme-dark"),
            };

            // Initial values
            if (confirmHighRisk) {
                confirmHighRisk.checked = !!state.confirmHighRisk;
            }
            if (adminChatEnter) {
                adminChatEnter.checked = !!state.adminChatEnterToSend;
            }
            if (autoOpen) {
                autoOpen.checked = !!state.autoOpenLastTab;
            }
            if (vehImages) {
                vehImages.checked = !!state.showVehicleImages;
            }
            if (itemImages) {
                itemImages.checked = !!state.showItemImages;
            }

            Object.keys(themeButtons).forEach((key) => {
                const btn = themeButtons[key];
                if (!btn) return;
                btn.classList.toggle(
                    "as-settings-pill--active",
                    state.themeMode === key
                );
            });

            function renderPalette() {
                if (!paletteWrap) return;

                // Which palette list should we show? If user forces light/dark,
                // use that; otherwise use the currently active theme.
                const activeTheme =
                    state.themeMode === "light" || state.themeMode === "dark"
                        ? state.themeMode
                        : getActiveThemeName();

                const list = activeTheme === "light" ? LIGHT_PALETTES : DARK_PALETTES;
                const current =
                    activeTheme === "light"
                        ? state.lightPalette || DEFAULTS.lightPalette
                        : state.darkPalette || DEFAULTS.darkPalette;

                paletteWrap.innerHTML = list
                    .map((p) => {
                        const isActive =
                            current &&
                            current.accent === p.accent &&
                            current.soft === p.soft;

                        return `
                            <button
                                type="button"
                                class="as-palette-swatch ${isActive ? "as-palette-swatch--active" : ""}"
                                data-theme="${activeTheme}"
                                data-accent="${p.accent}"
                                data-soft="${p.soft}"
                                title="${p.label}"
                            >
                                <span class="as-palette-dot" style="background:${p.accent}"></span>
                                <span class="as-palette-dot" style="background:${p.soft}"></span>
                            </button>
                        `;
                    })
                    .join("");

                paletteWrap
                    .querySelectorAll(".as-palette-swatch")
                    .forEach((btn) => {
                        btn.addEventListener("click", () => {
                            const t = btn.getAttribute("data-theme") || "dark";
                            const accent = btn.getAttribute("data-accent") || DEFAULTS.darkPalette.accent;
                            const soft = btn.getAttribute("data-soft") || DEFAULTS.darkPalette.soft;

                            if (t === "light") {
                                AS.adminSettings.save({
                                    lightPalette: { accent, soft },
                                });
                            } else {
                                AS.adminSettings.save({
                                    darkPalette: { accent, soft },
                                });
                            }

                            // refresh UI state highlight
                            const refreshed = AS.adminSettings.get();
                            state.lightPalette = refreshed.lightPalette;
                            state.darkPalette = refreshed.darkPalette;
                            renderPalette();
                        });
                    });
            }

            renderPalette();

            // Event bindings
            if (confirmHighRisk) {
                confirmHighRisk.addEventListener("change", (ev) => {
                    AS.adminSettings.save({
                        confirmHighRisk: !!ev.target.checked,
                    });
                });
            }

            if (adminChatEnter) {
                adminChatEnter.addEventListener("change", (ev) => {
                    AS.adminSettings.save({
                        adminChatEnterToSend: !!ev.target.checked,
                    });
                });
            }

            if (autoOpen) {
                autoOpen.addEventListener("change", (ev) => {
                    AS.adminSettings.save({
                        autoOpenLastTab: !!ev.target.checked,
                    });
                });
            }

            if (vehImages) {
                vehImages.addEventListener("change", (ev) => {
                    AS.adminSettings.save({
                        showVehicleImages: !!ev.target.checked,
                    });
                });
            }

            if (itemImages) {
                itemImages.addEventListener("change", (ev) => {
                    AS.adminSettings.save({
                        showItemImages: !!ev.target.checked,
                    });
                });
            }

            Object.keys(themeButtons).forEach((key) => {
                const btn = themeButtons[key];
                if (!btn) return;

                btn.addEventListener("click", () => {
                    AS.adminSettings.save({ themeMode: key });
                    Object.keys(themeButtons).forEach((otherKey) => {
                        const otherBtn = themeButtons[otherKey];
                        if (!otherBtn) return;
                        otherBtn.classList.toggle(
                            "as-settings-pill--active",
                            otherKey === key
                        );
                    });

                    // Palette list may change when forcing light/dark.
                    const refreshed = AS.adminSettings.get();
                    state.themeMode = refreshed.themeMode;
                    state.darkPalette = refreshed.darkPalette;
                    state.lightPalette = refreshed.lightPalette;
                    renderPalette();
                });
            });

            if (resetBtn) {
                resetBtn.addEventListener("click", () => {
                    AS.adminSettings.save(Object.assign({}, DEFAULTS));
                });
            }
        },
    };
})();
