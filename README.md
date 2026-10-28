<p align="center">
  <img src="/BatteryGuardIcon.png" alt="BGuard Logo" width="128" height="128">
</p>

<div align='center'>
<h1>Battery Guard</h1>
<img src='https://img.shields.io/badge/Status-Deprecated-red'></img>
<img src='https://img.shields.io/badge/Swift-6.3-blue'></img>
<img src='https://img.shields.io/badge/License-MIT-yellow'></img>
<br><br><br>
</div>

> **This project is deprecated and no longer maintained.**
>
> On Apple Silicon Macs running recent versions of macOS, Apple restricts the system interface that controls charging to its own software. Third-party apps can't reliably enforce a custom charge limit or sailing mode, so BatteryGuard can't deliver what it was built for. The repository is archived: it remains readable, but no issues or pull requests are accepted.
>
> **For a working alternative, use [AlDente](https://apphousekit.com/aldente/).**
>
> If you installed BatteryGuard, see [Uninstalling](#uninstalling) below to remove its helper and restore your charge limit.

## What it was meant to do

- **Custom charge limits**: hold the battery at a chosen ceiling (50–100%) while plugged in.
- **Sailing mode**: let the battery drift down to a floor percentage before charging back up to the limit.
- **Event-driven design**: react to `IOKit` power notifications, with a periodic backstop check.

These features worked only intermittently on the hardware this was tested on, and the charge-stop control they depend on isn't available to third-party apps on current macOS.

## Uninstalling

1. Quit BatteryGuard from its menu bar icon. This hands the charge limit back to macOS.
2. Remove the helper daemon:
   ```
   sudo launchctl bootout system/ak.BatteryGuard.helper
   ```
3. Delete `BatteryGuard.app` from `/Applications`.
4. In **System Settings → General → Login Items & Extensions**, remove any remaining BatteryGuard entry.
5. Set your charge limit in **System Settings → Battery**.
6. Optional: remove the logs with `sudo rm -rf /Library/Logs/BatteryGuard`.

## License

MIT