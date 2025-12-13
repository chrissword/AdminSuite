window.AdminSuite = window.AdminSuite || {};

(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});
    AS.audit = AS.audit || {};

    const AUDIT_ENTRIES_EVENT = "as:nui:audit:entries";

    // Listen for server → client → NUI audit entries
    window.addEventListener("message", (event) => {
        const data = event.data || {};
        const evt = data.event;
        if (!evt) return;

        if (evt === AUDIT_ENTRIES_EVENT) {
            const payload = data.payload || data;
            const entries = payload.entries || payload.data || payload || [];
            AS.audit.updateEntries(entries);
        }
    });

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

    AS.audit.render = function (root) {
        root.innerHTML = `
            <div class="as-grid">
                <section class="as-card" style="grid-column: span 12;">
                    <header class="as-card__header">
                        <div>
                            <h2 class="as-card__title">Audit Log</h2>
                            <p class="as-card__subtitle">
                                Full list of recent administrative actions
                            </p>
                        </div>
                        <div>
                            <button class="as-chip" id="as-audit-refresh">
                                Refresh
                            </button>
                        </div>
                    </header>
                    <div class="as-card__body" id="as-audit-list">
                        <p class="as-card__subtitle">Loading audit entries…</p>
                    </div>
                </section>
            </div>
        `;

        const refresh = root.querySelector("#as-audit-refresh");
        if (refresh) {
            refresh.addEventListener("click", () => {
                AS.audit.requestEntries(100);
            });
        }

        // Initial load
        AS.audit.requestEntries(100);
    };

    AS.audit.requestEntries = function (limit) {
        limit = limit || 100;

        if (!AdminSuite.utils || !AdminSuite.utils.sendNuiCallback) {
            console.warn("[AdminSuite] audit.requestEntries: NUI utils missing");
            return;
        }

        AdminSuite.utils.sendNuiCallback("as:nui:audit:getEntries", {
            limit,
        });
    };

    AS.audit.updateEntries = function (entries) {
        const container = document.getElementById("as-audit-list");
        if (!container) return;

        if (!entries || !entries.length) {
            container.innerHTML = `
                <p class="as-card__subtitle">No audit entries available.</p>
            `;
            return;
        }

        const parts = entries
            .slice() // copy
            .reverse()
            .map((entry) => {
                const timeLabel = formatAuditTime(
                    entry.created_at || entry.time
                );
                const label = formatAuditLabel(entry);

                const payloadPreview = entry.payload
                    ? `<pre class="as-audit-payload">${JSON.stringify(entry.payload, null, 2)}</pre>`
                    : "";

                return `
                    <div class="as-audit-item">
                        <div class="as-audit-main">
                            <div class="as-audit-label">${label}</div>
                            ${
                                timeLabel
                                    ? `<div class="as-audit-meta">${timeLabel}</div>`
                                    : ""
                            }
                        </div>
                        ${payloadPreview}
                    </div>
                `;
            });

        container.innerHTML = `
            <div class="as-audit-list">
                ${parts.join("")}
            </div>
        `;
    };
})();
