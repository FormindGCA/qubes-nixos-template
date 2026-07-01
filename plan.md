# Project Roadmap

This project currently targets personal use on Qubes OS 4.3 template VMs.

## Current Focus

Stabilize the Qubes/NixOS integration before doing larger cleanups. Prefer small commits that are easy to test and revert.

## Invariants

- `qubes.StartApp` must remain resolvable through `QREXEC_SERVICE_PATH`.
- Generic qrexec RPC services should come from the base `qubes-core-agent-linux` package.
- Networking services may use a networking-enabled `qubes-core-agent-linux` package, but enabling networking must not silently change generic RPC behavior.
- `qubes.StartApp` and `qubes.VMExec` must run with a Python environment that can import `qubesagent` and `qubesdb`.
- `qubes.VMExec` must execute updater-injected Python commands with the Nix Python, because dom0 calls `/usr/bin/python3` and injected scripts use `/usr/bin/python3` shebangs.
- Qubes Updater's injected agent does not support NixOS; `qubes.VMExec` must intercept that agent entrypoint and run `qubes-nixos-rebuild` instead.
- The generated system must expose qrexec services through `/etc/qubes-rpc` for Qubes compatibility.
- `/usr/share` must resolve to the NixOS system profile because Qubes tools use hard-coded `/usr/share` paths.
- `/usr/lib/qubes/upgrades-status-notify` must resolve because the upstream VM update agent calls it directly.
- Every refactor should be validated with a full system build and at least one targeted evaluation of the affected paths.

## Next Milestone: Split Core Agent Package Roles

1. Re-test Qubes Updater / `qubes.VMExec` in a real template VM.
2. Re-test networking in an AppVM based on the template.

## Validation For Package Role Refactor

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
- basic qrexec command execution

## Later Cleanup

1. Clean `qubes-linux-utils` and investigate the `extendDerivation` workaround.
2. Clean remaining module TODOs in `db.nix` and `qrexec.nix`.
3. Investigate the `Scripted initrd is deprecated` warning before NixOS 26.11.
4. Document qrexec/RPC package invariants in the README once they are stable.
5. Continue reducing ad hoc `substituteInPlace` and `resholve` workarounds package by package.

## Recently Completed

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
