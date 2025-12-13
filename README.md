# AdminSuite  
### Administration & Moderation Suite for QBCore  
**Version:** 1.0  
**Namespace:** `as:`  
**Author:** WingedDevotee19
**Copyright** ©2025

---

## 📌 Overview

AdminSuite is a fully modular, role-based administration & moderation suite designed for **QBCore**.  
It provides a clean, modern, NUI-driven interface with:

- Staff moderation tools  
- Audit-logged actions  
- Role-Based Access Control (RBAC)  
- Reports & Staff Chat  
- World controls  
- Vehicles panel (read-only)  
- Google Docs integration  
- Strong event naming consistency under the `as:` namespace  

Every action is **server-authoritative**, **audited**, and **role-restricted**.

---

## 📦 Features

- 🔒 RBAC system with shared role → color mapping  
- 🎛️ Modular panels (Moderation, World Controls, Reports, Vehicles, Docs)  
- 📝 Google Docs & Sheets viewing with role-gated editing  
- 📚 Server-side migrations managed via `migrations.lua`  
- 🧪 Debug mode for development environments  
- 🎨 Built-in Dark/Light themes  
- 🧩 Zero dependencies beyond QBCore + oxmysql  
- 🎯 Namespaced events: `as:*`  
- 📕 Fully documented internal APIs (EVENTS.md)

---

## 🧰 Requirements

- QBCore (latest stable)
- oxmysql
- Any screenshot tool (screenshots only used for punishments)

---

## 📂 Installation

1. **Place the folder** into your server resources:  

2. **Ensure it loads after QBCore**  
```lua
ensure qb-core
ensure AdminSuite
