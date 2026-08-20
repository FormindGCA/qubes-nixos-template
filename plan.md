# Project Roadmap

This project currently targets personal use on Qubes OS 4.3 template VMs.

## Current Focus

Validate the remaining Qubes-specific runtime paths in real VMs. Prefer small commits that are easy to test and revert.

Further package cleanup should be driven by a concrete build or runtime problem rather than line-count reduction alone.

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
- The updates proxy must remain scoped to Nix and update services; ordinary commands must not inherit it globally.
- Automatic root filesystem resizing must run after normal boot and must not delay `multi-user.target`.
- Version-specific package wrappers remain separate from generic derivations so Qubes release versions can be selected without duplicating packaging logic.
- Every refactor should be validated with a full system build and at least one targeted evaluation of the affected paths.

## Current Blocker

1. Keep the NixOS initrd disabled; enabling the systemd initrd currently breaks TemplateVM boot.

## Next Work

1. Validate Split GPG between separate client and key-holder qubes, including dom0 qrexec policy, key import, signing, and the key-access confirmation dialog.
2. Validate delayed automatic root filesystem growth in a resized TemplateVM.
3. Validate QubesDB keyboard-layout synchronization across graphical sessions.
4. Design optional Split SSH agent forwarding without making `nix-daemon` depend on an unavailable vault.
5. Continue reducing package fixups only where a focused build or runtime test demonstrates they are unnecessary.

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
- keyboard-layout changes from dom0 across active X displays
- basic qrexec command execution
- Nix update proxying without proxy variables in unrelated shell commands
- SSH Git cloning through the optional `qubes.SshProxy` transport
- delayed root filesystem resize
- Split GPG client and key-holder flows when enabled

## Later Work

1. Revisit an enabled systemd initrd in an isolated boot-debug branch before NixOS 26.11.
2. Keep the NixOS initrd disabled until first boot, reboot, qrexec, GUI, networking, and update checks pass in a real TemplateVM.
