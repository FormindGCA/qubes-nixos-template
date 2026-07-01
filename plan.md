# Project Roadmap

This project currently targets personal use on Qubes OS 4.3 template VMs.

## Current Focus

Stabilize the Qubes/NixOS integration before doing larger cleanups. Prefer small commits that are easy to test and revert.

## Invariants

- `qubes.StartApp` must remain resolvable through `QREXEC_SERVICE_PATH`.
- Generic qrexec RPC services should come from the base `qubes-core-agent-linux` package.
- Networking services may use a networking-enabled `qubes-core-agent-linux` package, but enabling networking must not silently change generic RPC behavior.
- `qubes.VMExec` must run with a Python environment that can import `qubesagent`.
- Every refactor should be validated with a full system build and at least one targeted evaluation of the affected paths.

## Next Milestone: Split Core Agent Package Roles

1. Add explicit package options under `services.qubes.core`:
   - `basePackage = pkgs.qubes-core-agent-linux`
   - `networkingPackage = pkgs.qubes-core-agent-linux.override { enableNetworking = true; }`
2. Keep `services.qubes.core.package` temporarily for compatibility or internal use.
3. Make qrexec use `config.services.qubes.core.basePackage` for generic RPC services.
4. Make networking use `config.services.qubes.core.networkingPackage` for networking scripts and services.
5. Stop making `services.qubes.core.networking` replace the package used by all core services.

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
