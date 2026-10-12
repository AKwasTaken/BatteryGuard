<p align="center">
  <img src="/BatteryGuardIcon.png" alt="BGuard Logo" width="128" height="128">
</p>

<div align='center'>
<h1>Battery Guard</h1>
<img src='https://img.shields.io/badge/Swift-6.3-blue'></img>
<img src='https://img.shields.io/badge/License-MIT-yellow'></img>
<a href="https://www.codefactor.io/repository/github/akwastaken/batteryguard"><img src="https://www.codefactor.io/repository/github/akwastaken/batteryguard/badge" alt="CodeFactor" /></a>
<br><br><br>
</div>

# BatteryGuard

A lightweight, zero-bloat menu bar utility for Apple Silicon that manages battery charging thresholds without manual polling or background battery drain.

## What it does

- **Custom Charge Limits**: Holds the battery at your chosen upper ceiling (50–100%) directly via native Apple Silicon top-off protection—running entirely off the power adapter without trickle charging.
- **Sailing Mode**: Allows the battery to float down to an idle floor percentage before resuming charging back up to your limit, reducing cycle stress.
- **Event-Driven**: Hooks directly into `IOKit` power notifications rather than waking up CPU timers to poll battery levels.
- **Thermal Cycle (Ant Purge)**: A short, 3-minute controlled multi-core SIMD load designed to safely bring system thermals up when needed.

## Setup

1. Build or download `BatteryGuard.app`.
2. Move it to `/Applications` and launch.
3. When prompted, allow background execution in **System Settings → General → Login Items & Extensions** to authorize the lightweight helper daemon.

## License

MIT
