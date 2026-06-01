---
date: 2026-05-29
topic: small-screen-agent-status-wall
---

# Small Screen Agent Status Wall

## Summary

MacJarvis should shift from a desktop-style dashboard into a small-screen, always-on agent status wall. The primary surface should make installed large agents, currently OpenClaw and Hermes, readable at a glance; token consumption and local machine health remain visible as secondary status signals and rotate into detail pages.

---

## Problem Frame

MacJarvis is expected to run mostly on 5-inch or 7-inch external screens around 1024px or 1280px wide. On that class of display, a left/middle/right desktop layout spreads attention too thin and encourages controls that are not useful for a screen that is usually observed rather than operated.

The more useful product shape is an embedded status screen: when the user glances at it, they should immediately know whether the important agents are available, running, idle, stuck, or in error. Token usage and local CPU/memory/disk health still matter, but they should not compete with the agent health signal.

---

## Key Decisions

- **Agent health leads the interface.** The first visual read is whether the installed large agents are healthy and active; token and system metrics support that read instead of forming equal columns.
- **Large and small agents have different roles.** OpenClaw and Hermes are large agents with availability state and token consumption. Claude Code, Codex, and Gemini are small agents for this screen and only contribute consumption data for the first version.
- **Installed agents define the status surface.** Machines may have OpenClaw, Hermes, or both. Uninstalled large agents are hidden and do not count as unhealthy.
- **The screen is mostly passive.** Routine use should not require clicking tabs or controls. Page changes happen through timed rotation, while large-agent errors interrupt the rotation and stay visible.
- **Design language remains MacJarvis-native.** The redesign keeps the existing dark, neon, CRT/pixel-inspired identity, but changes the composition from a card dashboard into a status-wall layout with larger hierarchy and fewer controls.

---

## Actors

- A1. **Observer.** The person glancing at the small screen to understand whether the local AI setup is usable right now.
- A2. **Large agent.** OpenClaw or Hermes, when installed on the machine. Large agents expose availability/activity state and consumption data.
- A3. **Small agent.** Claude Code, Codex, or Gemini. Small agents expose consumption data only in this version.
- A4. **Local machine.** The Mac running MacJarvis and the monitored CPU, memory, and disk resources.

---

## Requirements

**Overall Layout**

- R1. The main screen must replace the current left/middle/right information layout with a status-wall composition centered on large-agent health.
- R2. The largest visual element on the main screen must be the global large-agent status, such as nominal, running, warning/stuck, or error.
- R3. The main screen must show only installed large agents. A missing OpenClaw or Hermes installation must not appear as a fault.
- R4. The main screen must keep token consumption and local system health visible as compact secondary summaries.
- R5. The layout must be optimized for 5-inch and 7-inch always-on displays around 1024px or 1280px wide, with text and numbers readable from a glance.

**Large-Agent Status**

- R6. OpenClaw and Hermes must each support a state model that can represent online, offline, running, idle, stuck/warning, error, and unknown.
- R7. The global status must be derived only from installed large agents.
- R8. A large agent that is online but has exceeded its expected heartbeat or activity interval must show as stuck/warning rather than normal.
- R9. A large agent with a clear failure condition must show as error and must dominate the screen until it recovers.
- R10. Large-agent status blocks must include enough context to explain the state at a glance, such as recent activity or heartbeat age.

**Consumption Display**

- R11. Large agents must display token or cost consumption alongside their status.
- R12. Small agents must display token or cost consumption without implying availability or runtime health.
- R13. Consumption summaries must distinguish large-agent consumption from small-agent consumption.
- R14. Consumption detail pages must provide more room for per-agent totals, costs, time buckets, and last-updated information than the compact main-screen summary.

**Local System Display**

- R15. The main screen must show compact local machine health, at minimum CPU and memory, with disk included where space allows.
- R16. A system detail page must show CPU, memory, and disk in a larger, scan-friendly form.
- R17. Local system warnings may visually raise attention but must not override a large-agent error unless a later requirement explicitly changes that priority.

**Page Rotation and Interaction**

- R18. The interface must support automatic rotation between the main status screen, consumption detail, and local system detail.
- R19. The main status screen must have the longest dwell time in the normal rotation.
- R20. When any installed large agent is in error or stuck/warning, the rotation must stop on an interrupting status screen until the condition recovers.
- R21. Routine operation must not depend on manual page switching.
- R22. The only required manual control in the first version is a subdued settings entry point.

**Visual Design**

- R23. The screen must read like an embedded operational panel, not a general desktop app.
- R24. State color and motion must reinforce status: stable for normal, active for running, warning for stuck, and urgent for error.
- R25. The design must avoid dense cards, nested panels, and competing decorative chrome where those reduce glanceability.
- R26. Existing MacJarvis visual identity may remain, including dark surfaces, neon accents, CRT/pixel effects, and Space Grotesk typography, but hierarchy and composition must change to support the new status-wall purpose.

---

## Key Flows

- F1. Normal glance
  - **Trigger:** The observer looks at the small screen during normal operation.
  - **Actors:** A1, A2, A3, A4
  - **Steps:** The main screen shows global large-agent health first, installed large-agent status second, and compact token/system summaries third.
  - **Outcome:** The observer can tell whether the installed large agents are available and whether consumption or local load looks abnormal without touching the screen.
  - **Covered by:** R1, R2, R3, R4, R5

- F2. Normal rotation
  - **Trigger:** No installed large agent is stuck or in error.
  - **Actors:** A1, A2, A3, A4
  - **Steps:** The screen spends most of its time on the main status screen, briefly rotates to consumption details, briefly rotates to local system details, then returns to main status.
  - **Outcome:** Secondary information remains discoverable without turning the product back into a manually operated tabbed dashboard.
  - **Covered by:** R14, R16, R18, R19, R21

- F3. Large-agent fault interrupt
  - **Trigger:** An installed OpenClaw or Hermes instance becomes stuck/warning or enters error.
  - **Actors:** A1, A2
  - **Steps:** The normal rotation stops, the affected large agent and failure state become the screen focus, and the interrupt remains until the condition recovers.
  - **Outcome:** A serious agent problem cannot be hidden behind token or system pages.
  - **Covered by:** R8, R9, R20, R24

- F4. Mixed installation
  - **Trigger:** MacJarvis runs on a machine with only OpenClaw, only Hermes, or both installed.
  - **Actors:** A1, A2
  - **Steps:** The main screen includes installed large agents only and derives global health from that installed set.
  - **Outcome:** A machine is not shown as degraded merely because it does not use the other large agent.
  - **Covered by:** R3, R7

---

## Acceptance Examples

- AE1. **Covers R3, R7.** Given a machine with OpenClaw installed and Hermes absent, when MacJarvis renders the main status screen, then OpenClaw appears as the large-agent status source and Hermes does not appear as an offline or missing fault.
- AE2. **Covers R8, R20.** Given an installed large agent is online but heartbeat or activity has exceeded the stuck threshold, when the condition is detected, then the screen shows warning/stuck and pauses normal rotation.
- AE3. **Covers R9, R20.** Given an installed large agent enters error, when token or system pages would normally rotate in, then the error status remains on screen instead.
- AE4. **Covers R12, R17.** Given Codex token data is missing or local CPU is high, when large agents are healthy, then the global status remains based on large-agent health while the related auxiliary summary shows the warning or missing data.
- AE5. **Covers R21, R22.** Given the screen is running unattended, when the user does not click anything, then main status, consumption detail, and local system detail remain available through automatic rotation.

---

## Success Criteria

- The main screen can be understood in one glance on a 5-inch or 7-inch display.
- A healthy installed large-agent setup reads as normal without requiring the observer to parse token cards, logs, or navigation tabs.
- A stuck or failed large agent is impossible to miss because it interrupts the normal rotation.
- Machines with different large-agent installations do not show false failures for absent tools.
- Token consumption and local CPU/memory state remain visible, but they no longer compete with large-agent health as the primary message.

---

## Scope Boundaries

- Full agent control actions such as reconnect, pause, wake, or restart are not part of the first version's main screen.
- Small-agent runtime health is not part of the first version; Claude Code, Codex, and Gemini are consumption-only.
- Manual tab navigation is not required for the first version.
- Full log browsing is not part of the primary status-wall experience.
- Exact heartbeat thresholds, rotation timings, and status wording are deferred to planning.

---

## Dependencies / Assumptions

- Hermes is assumed to expose a local service or health interface comparable enough to OpenClaw for status monitoring.
- OpenClaw already has status and consumption concepts in the project; Hermes status and consumption are new product capabilities for this redesign.
- Token and cost availability may vary by agent and mode; missing small-agent consumption data should not affect global health.
- The existing MacJarvis visual identity is still desirable, but the current information architecture is not.

---

## Outstanding Questions

### Deferred to Planning

- [Affects R6, R8] Define the exact heartbeat or activity timeout that moves a large agent from idle/running to stuck/warning.
- [Affects R18, R19] Define exact dwell times for main status, consumption detail, and local system detail.
- [Affects R23, R24] Define the final status wording and motion treatment for normal, running, warning/stuck, and error.
- [Affects R11, R14] Confirm how Hermes consumption data is exposed and whether it uses the same token/cost model as OpenClaw.

---

## Sources / Research

- `CLAUDE.md` describes MacJarvis as a macOS SwiftUI dashboard for local AI tool usage, OpenClaw status, and machine state on small external screens.
- `docs/brainstorms/2026-04-08-responsive-display-layout-requirements.md` covers screen-size adaptation but intentionally kept the old layout structure; this brainstorm changes the information architecture.
- `docs/brainstorms/2026-04-08-api-mode-token-cost-tracking-requirements.md` defines prior token/cost display expectations that remain relevant to the consumption pages.
- `MacJarvis/Views/DashboardView.swift` currently uses a header, left/middle/right content area, and bottom tab navigation.
- `MacJarvis/Views/CoreStatusView.swift`, `MacJarvis/Views/TokenColumnView.swift`, and `MacJarvis/Views/HardwareStatsView.swift` show that OpenClaw status, token usage, and local CPU/memory/disk data already exist as separate UI concerns.
- `MacJarvis/Services/OpenClawService.swift`, `MacJarvis/Services/TokenService.swift`, and `MacJarvis/Services/SystemMonitorService.swift` show the current service boundaries for OpenClaw status, token collection, and system monitoring.
