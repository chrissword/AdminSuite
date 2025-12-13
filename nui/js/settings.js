window.AdminSuite = window.AdminSuite || {};

(function () {
    const AS = (window.AdminSuite = window.AdminSuite || {});
    AS.settings = AS.settings || {};

function updateAdminCardVisibility() {
    const ASGlobal = window.AdminSuite || {};
    const rbac = ASGlobal.rbac || {};

    // If RBAC isn't loaded yet, DO NOT change visibility.
    // This keeps the card visible by default on first open.
    if (!rbac.role) return;

    const flags = rbac.flags || {};
    const hasFullAccess = !!flags.full_access;
    const canManageStaff =
        hasFullAccess || !!flags.can_manage_staff_roles;

    const card = document.getElementById("as-settings-admin-card");
    if (!card) return;

    if (!canManageStaff) {
        card.classList.add("as-hidden-rbac");
    } else {
        card.classList.remove("as-hidden-rbac");
    }
}


    // Render shell (search + empty settings panel)
    AS.settings.render = function (root) {
        root.innerHTML = `
            <div class="as-grid">
                <section class="as-card" style="grid-column: span 4;">
                    <header class="as-card__header">
                        <h2 class="as-card__title">Player Search</h2>
                    </header>
                    <div class="as-card__body">
                        <input id="as-settings-search-id" placeholder="Server ID…" style="width:100%; margin-bottom:6px;" />
                        <button class="as-chip" id="as-settings-load">Load Player Settings</button>
                    </div>
                </section>

                <section class="as-card" style="grid-column: span 8;">
                    <header class="as-card__header">
                        <h2 class="as-card__title">Settings</h2>
                        <span class="as-card__subtitle" id="as-settings-player-label">No player loaded</span>
                    </header>
                    <div class="as-card__body" id="as-settings-form">
                        Load a player to manage job, job grade, gang, gang grade, admin role, and clothing.
                    </div>
                </section>
            </div>
        `;

        const loadBtn = root.querySelector("#as-settings-load");
        if (loadBtn) {
            loadBtn.addEventListener("click", () => {
                const idInput = document.getElementById("as-settings-search-id");
                const target = idInput ? parseInt(idInput.value, 10) : null;
                if (!target) return;

                AdminSuite.utils.sendNuiCallback("as:nui:settings:load", {
                    target,
                });
            });
        }

        // Allow pressing Enter in the search box to load player settings
const searchInput = root.querySelector("#as-settings-search-id");
if (searchInput) {
    searchInput.addEventListener("keydown", (ev) => {
        if (ev.key === "Enter") {
            ev.preventDefault();
            const value = parseInt(searchInput.value, 10);
            if (!value) return;

            if (window.AdminSuite && AdminSuite.utils) {
                AdminSuite.utils.sendNuiCallback("as:nui:settings:load", {
                    target: value,
                });
            }
        }
    });
}

    };

    // Populate settings for a specific player payload
    // payload shape (from Lua):
    // {
    //   id, name,
    //   job, jobLabel, jobGrade,
    //   gang, gangLabel, gangGrade,
    //   whitelisted
    // }
    AS.settings.populate = function (data) {
        const label = document.getElementById("as-settings-player-label");
        const form  = document.getElementById("as-settings-form");
        if (!label || !form) return;

        const p = data || {};
        label.textContent = `Editing: [${p.id}] ${p.name || "Unknown"}`;
        const playerName = p.name || "Unknown";

 const jobGrade  = typeof p.jobGrade === "number" ? p.jobGrade : (parseInt(p.jobGrade, 10) || 0);
const gangGrade = typeof p.gangGrade === "number" ? p.gangGrade : (parseInt(p.gangGrade, 10) || 0);

const jobs       = Array.isArray(p.jobs) ? p.jobs : [];
const gangs      = Array.isArray(p.gangs) ? p.gangs : [];
const staffRoles = Array.isArray(p.staffRoles) ? p.staffRoles : [];
const currentRole = p.staffRole || "";
const currentJobLabel  = p.jobLabel || p.job || "";
const currentGangLabel = p.gangLabel || p.gang || "";


        form.innerHTML = `
<div class="as-card" style="grid-column: span 6;">
    <header class="as-card__header">
        <h3 class="as-card__title">Job</h3>
        ${
            currentJobLabel
                ? `<p class="as-card__subtitle">Current Job: ${currentJobLabel}</p>`
                : `<p class="as-card__subtitle">This player currently has no job set.</p>`
        }
    </header>

                    <div class="as-card__body">
                        <div class="as-grid" style="gap: 6px;">
                            <div style="grid-column: span 8;">
                                <select
                                    id="as-settings-job"
                                    style="width:100%; margin-bottom:4px;"
                                ></select>
                            </div>
                            <div style="grid-column: span 4;">
                                <select
                                    id="as-settings-job-grade"
                                    style="width:100%; margin-bottom:4px;"
                                ></select>
                            </div>
                        </div>
                        <button class="as-chip" id="as-settings-save-job">Save Job</button>
                    </div>
                </div>

<div class="as-card" style="grid-column: span 6;">
    <header class="as-card__header">
        <h3 class="as-card__title">Gang</h3>
        ${
            currentGangLabel
                ? `<p class="as-card__subtitle">Current gang: ${currentGangLabel}</p>`
                : `<p class="as-card__subtitle">This player is not currently in a gang.</p>`
        }
    </header>

                    <div class="as-card__body">
                        <div class="as-grid" style="gap: 6px;">
                            <div style="grid-column: span 8;">
                                <select
                                    id="as-settings-gang"
                                    style="width:100%; margin-bottom:4px;"
                                ></select>
                            </div>
                            <div style="grid-column: span 4;">
                                <select
                                    id="as-settings-gang-grade"
                                    style="width:100%; margin-bottom:4px;"
                                ></select>
                            </div>
                        </div>
                        <button class="as-chip" id="as-settings-save-gang">Save Gang</button>
                    </div>
                </div>

                <div
                    class="as-card"
                    id="as-settings-admin-card"
                    style="grid-column: span 6;"
                >
                    <header class="as-card__header">
                        <h3 class="as-card__title">Admin Management</h3>
                        ${
                            currentRole
                                ? `<p class="as-card__subtitle">Current role: ${currentRole}</p>`
                                : `<p class="as-card__subtitle">This player is not currently an admin.</p>`
                        }
                    </header>
                    <div class="as-card__body">
                        <div class="as-grid" style="gap: 6px; align-items: center;">
                            <div style="grid-column: span 8;">
                                <select
                                    id="as-settings-admin-role"
                                    style="width:100%; margin-bottom:4px;"
                                ></select>
                            </div>
                            <div style="grid-column: span 4; display:flex; gap:4px; justify-content:flex-end; flex-wrap:wrap;">
                                <button class="as-chip" id="as-settings-add-admin">
                                    ${currentRole ? "Update Role" : "Add Admin"}
                                </button>
                                ${
                                    currentRole
                                        ? `<button class="as-chip as-chip--danger" id="as-settings-remove-admin">Remove Admin</button>`
                                        : ""
                                }
                            </div>
                        </div>
                    </div>
                </div>

                <div class="as-card" style="grid-column: span 6;">
                    <header class="as-card__header">
                        <h3 class="as-card__title">Clothing</h3>
                    </header>
                    <div class="as-card__body">
                        <button class="as-chip" id="as-settings-open-clothing">Open Clothing</button>
                    </div>
                </div>
            </div>
        `;

        const playerId        = p.id;
        const jobSelect       = document.getElementById("as-settings-job");
        const jobGradeSelect  = document.getElementById("as-settings-job-grade");
        const gangSelect      = document.getElementById("as-settings-gang");
        const gangGradeSelect = document.getElementById("as-settings-gang-grade");
        const roleSelect      = document.getElementById("as-settings-admin-role");

        const jobBtn    = document.getElementById("as-settings-save-job");
        const gangBtn   = document.getElementById("as-settings-save-gang");
        const addBtn    = document.getElementById("as-settings-add-admin");
        const removeBtn = document.getElementById("as-settings-remove-admin");
        const clothBtn  = document.getElementById("as-settings-open-clothing");

        const currentJob  = p.job || "";
        const currentGang = p.gang || "";

        function populateSelectWithPlaceholder(selectEl, placeholderText) {
            if (!selectEl) return;
            selectEl.innerHTML = "";
            const opt = document.createElement("option");
            opt.value = "";
            opt.textContent = placeholderText;
            selectEl.appendChild(opt);
        }

        // Jobs
        if (jobSelect) {
            populateSelectWithPlaceholder(jobSelect, "Select job…");
            jobs.forEach((job) => {
                const opt = document.createElement("option");
                opt.value = job.name;
                opt.textContent = job.label || job.name;
            
                jobSelect.appendChild(opt);
            });
        }

function refreshJobGrades(selectedJobName) {
    if (!jobGradeSelect) return;

    // Start with placeholder so behavior matches job / gang selects
    populateSelectWithPlaceholder(jobGradeSelect, "Select Grade...");

    // If no job selected yet, just leave the placeholder
    if (!selectedJobName) return;

    const job = jobs.find((j) => j.name === selectedJobName);
    const grades = (job && Array.isArray(job.grades)) ? job.grades.slice() : [];
    grades.sort((a, b) => (a.id || 0) - (b.id || 0));

    grades.forEach((g) => {
        const opt = document.createElement("option");
        opt.value = g.id;
        opt.textContent = g.label || `Grade ${g.id}`;
        // No auto-selected grade — user must pick one
        jobGradeSelect.appendChild(opt);
    });
}


        if (jobSelect) {
            jobSelect.addEventListener("change", () => {
                refreshJobGrades(jobSelect.value);
            });
            refreshJobGrades(jobSelect.value || currentJob);
        }

        // Gangs
        if (gangSelect) {
            populateSelectWithPlaceholder(gangSelect, "Select gang…");
            gangs.forEach((gang) => {
                const opt = document.createElement("option");
                opt.value = gang.name;
                opt.textContent = gang.label || gang.name;
                
                gangSelect.appendChild(opt);
            });
        }

function refreshGangGrades(selectedGangName) {
    if (!gangGradeSelect) return;

    // Start with placeholder so behavior matches job / gang selects
    populateSelectWithPlaceholder(gangGradeSelect, "Select Grade...");

    // If no gang selected yet, just leave the placeholder
    if (!selectedGangName) return;

    const gang = gangs.find((g) => g.name === selectedGangName);
    const grades = (gang && Array.isArray(gang.grades)) ? gang.grades.slice() : [];
    grades.sort((a, b) => (a.id || 0) - (b.id || 0));

    grades.forEach((g) => {
        const opt = document.createElement("option");
        opt.value = g.id;
        opt.textContent = g.label || `Grade ${g.id}`;
        // No auto-selected grade — user must pick one
        gangGradeSelect.appendChild(opt);
    });
}


        if (gangSelect) {
            gangSelect.addEventListener("change", () => {
                refreshGangGrades(gangSelect.value);
            });
            refreshGangGrades(gangSelect.value || currentGang);
        }

        // Staff roles for Add Admin
        if (roleSelect) {
            populateSelectWithPlaceholder(roleSelect, "Select staff role…");
            const sortedRoles = staffRoles.slice().sort((a, b) => (b.priority || 0) - (a.priority || 0));
            sortedRoles.forEach((role) => {
                const opt = document.createElement("option");
                opt.value = role.id;
                opt.textContent = role.label || role.id;
                
                roleSelect.appendChild(opt);
            });
        }

        // Save Job
        if (jobBtn && jobSelect && jobGradeSelect) {
            jobBtn.addEventListener("click", () => {
                const jobVal = jobSelect.value;
                if (!jobVal) return;
                const rawGrade = parseInt(jobGradeSelect.value, 10);
                const grade = Number.isNaN(rawGrade) ? 0 : rawGrade;

                AdminSuite.utils.sendNuiCallback("as:nui:settings:saveJob", {
                    target: playerId,
                    job: jobVal,
                    grade: grade,
                });

                if (window.AdminSuite && AdminSuite.utils && typeof AdminSuite.utils.notify === "function") {
                    const jobOption   = jobSelect.options[jobSelect.selectedIndex];
                    const gradeOption = jobGradeSelect.options[jobGradeSelect.selectedIndex];
                    const jobLabel    = (jobOption && jobOption.textContent) || jobVal;
                    const gradeLabel  = (gradeOption && gradeOption.textContent) || String(grade);
                    const msg = `${playerName}'s job successfully set to ${jobLabel} ${gradeLabel}.`;
                    AdminSuite.utils.notify(msg, { type: "success" });
                }
            });
        }

        // Save Gang
        if (gangBtn && gangSelect && gangGradeSelect) {
            gangBtn.addEventListener("click", () => {
                const gangVal = gangSelect.value;
                if (!gangVal) return;
                const rawGrade = parseInt(gangGradeSelect.value, 10);
                const grade = Number.isNaN(rawGrade) ? 0 : rawGrade;

                AdminSuite.utils.sendNuiCallback("as:nui:settings:saveGang", {
                    target: playerId,
                    gang: gangVal,
                    grade: grade,
                });

                if (window.AdminSuite && AdminSuite.utils && typeof AdminSuite.utils.notify === "function") {
                    const gangOption  = gangSelect.options[gangSelect.selectedIndex];
                    const gradeOption = gangGradeSelect.options[gangGradeSelect.selectedIndex];
                    const gangLabel   = (gangOption && gangOption.textContent) || gangVal;
                    const gradeLabel  = (gradeOption && gradeOption.textContent) || String(grade);
                    const msg = `${playerName}'s gang successfully set to ${gangLabel} ${gradeLabel}.`;
                    AdminSuite.utils.notify(msg, { type: "success" });
                }
            });
        }

        // Add / Update Admin
        if (addBtn && roleSelect) {
            addBtn.addEventListener("click", () => {
                const roleVal = roleSelect.value;
                if (!roleVal) return;

                AdminSuite.utils.sendNuiCallback("as:nui:settings:saveStaffRole", {
                    target: playerId,
                    role: roleVal,
                });

                if (window.AdminSuite && AdminSuite.utils && typeof AdminSuite.utils.notify === "function") {
                    const roleOption = roleSelect.options[roleSelect.selectedIndex];
                    const roleLabel  = (roleOption && roleOption.textContent) || roleVal;
                    const verb       = currentRole ? "updated to" : "added as";
                    const msg = `${playerName} ${verb} ${roleLabel}.`;
                    AdminSuite.utils.notify(msg, { type: "success" });
                }
            });
        }

        // Remove Admin
        if (removeBtn) {
            removeBtn.addEventListener("click", () => {
                AdminSuite.utils.sendNuiCallback("as:nui:settings:removeAdmin", {
                    target: playerId,
                });

                if (window.AdminSuite && AdminSuite.utils && typeof AdminSuite.utils.notify === "function") {
                    const msg = `${playerName} removed from staff.`;
                    AdminSuite.utils.notify(msg, { type: "success" });
                }
            });
        }

        // Clothing
        if (clothBtn) {
            clothBtn.addEventListener("click", () => {
                AdminSuite.utils.sendNuiCallback("as:nui:settings:openClothing", {
                    target: playerId,
                });
            });
        }

        // Apply RBAC visibility to Admin Management card on populate
        updateAdminCardVisibility();
    };

    // Called from main.js when RBAC payload updates
    AS.settings.setRBAC = function (rbac) {
        // We always read from window.AdminSuite.rbac inside updateAdminCardVisibility
        updateAdminCardVisibility();
    };
})();
