window.AdminSuite = window.AdminSuite || {};

(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});
    AS.googleDocs = AS.googleDocs || {};

       AS.googleDocs.render = function (root) {
        root.innerHTML = `
            <div class="as-docs-layout">
                <section class="as-card as-docs-list-card">
                    <header class="as-card__header">
                        <h2 class="as-card__title">Documents</h2>
                        <button class="as-chip" id="as-docs-refresh">Refresh</button>
                    </header>
                    <div class="as-card__body" id="as-docs-list">
                        Loading document list…
                    </div>
                </section>

                <section class="as-card as-docs-preview-card">
                    <header class="as-card__header">
                        <h2 class="as-card__title">Preview</h2>
                        <span class="as-card__subtitle" id="as-docs-selected-label">
                            No document selected
                        </span>
                    </header>
                    <div class="as-card__body as-docs-preview-body">
                        <iframe
                            id="as-docs-iframe"
                            src="about:blank"
                            sandbox="allow-scripts allow-same-origin allow-forms"
                        ></iframe>
                    </div>
                </section>
            </div>
        `;


        const refresh = root.querySelector("#as-docs-refresh");
        if (refresh) {
            refresh.addEventListener("click", () => {
                AdminSuite.utils.sendNuiCallback("as:nui:docs:list", {});
            });
        }

        // Initial load
        AdminSuite.utils.sendNuiCallback("as:nui:docs:list", {});
    };

    AS.googleDocs.updateList = function (docs) {
        const list = document.getElementById("as-docs-list");
        if (!list) return;

        if (!docs || !docs.length) {
            list.innerHTML = "<p>No documents available or permission denied.</p>";
            return;
        }

        const ul = document.createElement("ul");
        ul.style.listStyle = "none";
        ul.style.paddingLeft = "0";
        ul.style.margin = "0";
        ul.style.display = "grid";
        ul.style.gap = "4px";

        docs.forEach((d) => {
            const li = document.createElement("li");
            const label = d.title || d.name || d.id || "Untitled";
            const icon = d.icon || "📄";

            li.innerHTML = `
                <button class="as-chip" data-doc-id="${d.id}">
                    ${icon} ${label}
                </button>
            `;
            ul.appendChild(li);
        });

        list.innerHTML = "";
        list.appendChild(ul);

        list.querySelectorAll("[data-doc-id]").forEach((btn) => {
            btn.addEventListener("click", () => {
                const id = btn.getAttribute("data-doc-id");
                AdminSuite.utils.sendNuiCallback("as:nui:docs:open", { id });
            });
        });
    };

    AS.googleDocs.open = function (doc) {
        const label = document.getElementById("as-docs-selected-label");
        const iframe = document.getElementById("as-docs-iframe");

        if (label) {
            label.textContent = doc
                ? (doc.title || doc.name || doc.id)
                : "No document selected";
        }

        if (iframe) {
            iframe.src = doc && doc.url ? doc.url : "about:blank";
        }
    };
})();
