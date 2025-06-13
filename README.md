# inception.nvim
**Pre-Alpha**

**Inception.nvim** is an experimental Neovim plugin that introduces a modular, flexible, and dynamic *workspace* system. Unlike conventional project or workspace managers that tie your workflow to specific directories, **Inception** allows you to define, attach, split, merge, and persist workspaces that are decoupled from file system layout.

Its goal is to give Neovim users powerful tools for organizing tabs, windows, and buffers into logical units — supporting advanced use cases like cross-workspace visibility, dynamic scoping, and external plugin integration.

## ✨ Why use Inception.nvim?
- **Workspaces without directory boundaries** — organize buffers and views however you want.
- **Dynamic scoping** — workspaces that adjust scope as you attach or detach components (global, tab, window).
- **Cross-workspace visibility** — see into other workspaces via *Portals* or *Singularities*.
- **Powerful workflow control** — split, merge, detach, and persist your workspace structures.
- **Extensible API** — integrate with statuslines, fuzzy finders, or your custom tooling.

---

## 🚧 Roadmap

### 🗂 Workspaces
- **Split**
  - ➡ *Planned*: Split a tab or window into a new transient workspace (e.g. from a global workspace into its own transient workspace).
  - Guarantee exclusive membership of tabs/windows within workspaces.

- **Merge**
  - ➡ *Planned*: Merge components of a source workspace into a user-specified target workspace, then cleanly close the source.

- **Attach / Detach**
  - ✅ *Complete*: Attach or detach workspaces dynamically at the global, tab, or window level. Supports attachment modes for flexible default behaviors.

- **Persistent vs. Transient**
  - ➡ *Planned*: Persistent workspaces can be saved to disk and auto-loaded. Transient workspaces live only for the current session but can be saved.
  - Include modification tracking with optional autosave.

- **Dynamic Scoping**
  - ✅ *Complete*: Workspaces automatically shift scope (window → tab → global) as components are added or removed.

---

### 🌌 Portals
- ➡ *Planned*: Floating window per workspace displaying a shared, unlisted portal buffer (read-only by default).
- Pulling a buffer converts it into a normal buffer for the active workspace.
- Visual indicators and write mode toggles per portal window.

---

### 🔗 Singularities
- ➡ *Planned*: Cross-workspace linked windows that synchronize view and option states.
- Managed by a singularity manager that handles state syncing on tab transitions.
- Buffers are not tied to the linkage — only window states are mirrored.

---

### 📝 Work Queue / Draft Queue
- ➡ *Planned*: Workspace-scoped task markers or queues, potentially based on Neovim marks, to help manage in-progress or TODO workflows.

---

### 🔌 External Plugin Support
- ➡ *Planned*: Extend integration beyond lualine.
- Provide robust API and hooks for popular Neovim plugins and custom tooling.

---

### 💾 State Management
- ➡ *Planned*: Save all necessary state to restore workspaces fully on relaunch.
- Simple overwrite model for now, with potential future refinements.

