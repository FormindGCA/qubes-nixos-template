# Project Roadmap

This project currently targets personal use on Qubes OS 4.3 template VMs.

## Current Focus

Stabilize the Qubes/NixOS integration before doing larger cleanups. Prefer small commits that are easy to test and revert.

Near-term refactors should be minimal-risk cleanup only: documentation consistency, script hygiene, mechanical Nix cleanup, and small package/module cleanups that preserve behavior.

## Invariants

- `qubes.StartApp` must remain resolvable through `QREXEC_SERVICE_PATH`.
- Generic qrexec RPC services should come from the base `qubes-core-agent-linux` package.
- Networking services may use a networking-enabled `qubes-core-agent-linux` package, but enabling networking must not silently change generic RPC behavior.
- `qubes.StartApp` and `qubes.VMExec` must run with a Python environment that can import `qubesagent` and `qubesdb`.
- `qubes.VMExec` must execute updater-injected Python commands with the Nix Python, because dom0 calls `/usr/bin/python3` and injected scripts use `/usr/bin/python3` shebangs.
- Qubes Updater's injected agent does not support NixOS; `qubes.VMExec` must intercept that agent entrypoint and run `qubes-nixos-rebuild` instead.
- `qubes-nixos-rebuild` and update checks must use the same `services.qubes.updates.flakeConfiguration` target.
- The generated system must expose qrexec services through `/etc/qubes-rpc` for Qubes compatibility.
- `/usr/share` must resolve to the NixOS system profile because Qubes tools use hard-coded `/usr/share` paths.
- `/usr/lib/qubes/upgrades-status-notify` must resolve because the upstream VM update agent calls it directly.
- Qubes appmenu icon export must use NixOS paths instead of hard-coded `/usr/lib/qubes` and `/usr/share/icons` assumptions.
- Every refactor should be validated with a full system build and at least one targeted evaluation of the affected paths.

## Current Blocker

1. Keep legacy scripted initrd for now; systemd initrd currently breaks TemplateVM boot.

## Next Cleanup

1. Fix documentation and helper-script drift without changing runtime behavior.
2. Replace deprecated `substituteInPlace --replace` calls with explicit `--replace-fail` where the expected text must exist.
3. Continue reducing ad hoc `substituteInPlace` and `resholve` workarounds package by package, starting with smaller derivations before touching `qubes-core-agent-linux`.

## Validation Checklist

Run after each commit in the milestone:

```sh
docker compose build
docker compose run --rm nix nix --extra-experimental-features "nix-command flakes" eval --impure --raw .#nixosConfigurations.nixos.config.systemd.services.qubes-qrexec-agent.environment.QREXEC_SERVICE_PATH
docker compose run --rm nix nix --extra-experimental-features "nix-command flakes" build --no-link --impure .#nixosConfigurations.nixos.config.system.build.toplevel
```

Manual VM checks after rebuild:

```sh
qvm-run -a --service -- <template-name> qubes.StartApp+xfce4-terminal
```

Also verify:

- Qubes Updater / `qubes.VMExec`
- networking in an AppVM based on the template
- application shortcut sync from dom0
- basic qrexec command execution

## Later Work

1. Revisit systemd initrd later in an isolated boot-debug branch before NixOS 26.11.
2. Keep systemd initrd migration opt-in until first boot, reboot, qrexec, GUI, networking, and update checks pass in a real TemplateVM.

## Recently Completed

- Aligned Qubes 4.3 documentation, RPM metadata, and update helper defaults.
- Replaced remaining deprecated `substituteInPlace --replace` calls with `--replace-fail`.
- Cleaned package wrapper `rev` forwarding and made `build.sh` accept an explicit build target.
- Fixed `qubes-gui-agent-linux` build dependencies and systemd user unit relocation.
- Added Docker build workflow documentation.
- Added `system.stateVersion` to the example config.
- Made the default Qubes user configurable.
- Made Qubes update configuration directory and flake configuration configurable.
- Wrapped `qubes-vmexec` with a Python path containing `qubesagent`.
- Reverted the qrexec RPC path behavior that broke `qubes.StartApp` resolution.
- Exposed generated qrexec RPC services under `/etc/qubes-rpc`.
- Added `/usr/share -> /run/current-system/sw/share` compatibility for Qubes hard-coded paths.
- Wrapped `qubes.StartApp` and `qubes-vmexec` with Python/library paths for `qubesagent` and `qubesdb`.
- Added `services.qubes.core.basePackage` and `services.qubes.core.networkingPackage`.
- Removed the unused `services.qubes.core.networking` package-switch option.
- Documented the qrexec, `/etc/qubes-rpc`, `/usr/share`, and Python wrapper invariants in the README.
- Made `qubes.VMExec` run updater-injected `.py` commands with the Nix Python and exposed `/usr/lib/qubes/upgrades-status-notify`.
- Intercepted Qubes Updater's injected agent entrypoint and redirected it to `qubes-nixos-rebuild`.
- Made `qubes-nixos-rebuild` pass `--flake <configurationDirectory>#<flakeConfiguration>` instead of relying on the VM hostname.
- Validated Qubes Updater / `qubes.VMExec` in a real template VM.
- Replaced deprecated default `--update-input` flags with `services.qubes.updates.updateInputs` and `nix flake update`.
- Confirmed the remaining `system` renamed warning disappears when the legacy scripted initrd path is disabled, but systemd initrd broke real TemplateVM boot and was reverted.
- Removed stale module TODOs in `db.nix` and `qrexec.nix`.
- Cleaned `qubes-linux-utils` by replacing the `lib.extendDerivation` workaround with an explicit wrapper derivation that preserves the post-resholve udev rule fixups.
- Removed stale packaging comments from core qrexec, core agent, and GUI agent expressions.
- Implemented the NixOS side of application menu export by exposing `/etc/qubes`, fixing appmenu sync script paths, and wrapping `qubes.GetAppmenus` with the required PATH.
- Patched appmenu icon export so `qubes.GetImageRGBA` calls the packaged `xdg-icon`, has explicit image conversion tools in `PATH`, limits generated icons to 128px, and `xdg-icon` discovers icon themes through `XDG_DATA_DIRS` instead of requiring `/usr/share/icons` to exist.
- Validated appmenu icon sync in dom0; remaining icon warnings are limited to applications with missing or unusual icons.
- Registered the networking-enabled core agent package with udev when Qubes networking is enabled, so generated systems include `99-qubes-network.rules` without importing duplicate upstream systemd units.
- Validated networking in an AppVM based on the template.
- Reduced usb-proxy workaround by keeping the `udevadm` file-check instead of removing it entirely; replaced the path with the correct Nix store path.
- Cleaned stale/misleading FIXME comments in `qubes-gpg-split` to accurately describe the client-only GPG support status.
