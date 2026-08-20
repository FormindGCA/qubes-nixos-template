# Qubes NixOS Template

Build a NixOS TemplateVM for Qubes OS 4.3 as an RPM or unattended installer ISO.

> [!WARNING]
> Installing the RPM copies files into dom0 and currently requires `--nogpgcheck`.
> Review the build and proceed at your own risk.

## Installation

### Template RPM

1. Download the template RPM from GitHub Releases or build it with `nix build .#rpm`.
2. Copy it from a download qube to dom0:

   ```sh
   qvm-run --pass-io <download-qube> 'cat <full-rpm-path>' > qubes-template-nixos.rpm
   ```

3. Install it in dom0:

   ```sh
   qvm-template install qubes-template-nixos.rpm --nogpgcheck
   ```

4. Start the template, wait about 30 seconds for the Qubes services, then open a terminal:

   ```sh
   qvm-start nixos
   qvm-run nixos xterm
   ```

The example NixOS configuration is copied to `/etc/nixos` for further customization.

### Installer ISO

The ISO installs into a fresh HVM TemplateVM without first installing an RPM in dom0.

1. Download the installer ISO from GitHub Releases.
2. Create a TemplateVM with no template or networking and open its settings.
3. Set its kernel to `provided by qube` and virtualization mode to `HVM`.
4. Boot the qube from the ISO; installation starts automatically after root autologin.
5. Wait for the successful installation to reboot the qube, then shut it down.
6. Restore the default kernel and `PVH` virtualization mode.
7. Start the template and open a terminal as shown above.

## Configuration

The minimal RPM configuration is in `examples/`. Larger TemplateVM, qrexec Nix cache, and mission-specific flake examples are documented in `examples/variants/README.md`.

### Qubes Updater

The updater uses the VM hostname as the flake configuration name. Set an explicit name when a cloned or renamed template does not match the flake output:

```nix
services.qubes.updates.flakeConfiguration = "nixos";
```

By default, update checks refresh the `nixpkgs` and `qubes-nixos-template` inputs. Change `services.qubes.updates.updateInputs`, or set it to `[]` to keep the existing lock file unchanged.

### Split GPG

Enable the client in a qube that delegates GPG operations:

```nix
services.qubes.gpgSplit.enable = true;
```

Enable the RPC services in the isolated key-holder qube:

```nix
services.qubes.gpgSplit = {
  enable = true;
  server = true;
};
```

Dom0 policy must allow the client to call `qubes.Gpg` and `qubes.GpgImportKey` in the key-holder qube. Select the target through `/rw/config/gpg-split-domain` or through the dom0 policy default.

### SSH Git Proxy

The standard Qubes updates proxy does not allow HTTP CONNECT to SSH ports. A dedicated proxy qube can expose `qubes.SshProxy` through tinyproxy configured with `ConnectPort 22` and any other required SSH ports.

Configure the TemplateVM side:

```nix
services.qubes.sshProxy = {
  enable = true;
  target = "sys-firewall-vpn";
  # port = 8083;
};
```

Enable the `ssh-proxy-setup` Qubes service for the TemplateVM or derived qube. The module starts `qubes-nixos-ssh-proxy.socket` on `127.0.0.1:8083` and forwards connections over qrexec.

Point SSH at the local HTTP CONNECT endpoint:

```sshconfig
Host github.com
  ProxyCommand socat STDIO PROXY:127.0.0.1:%h:%p,proxyport=8083
```

The proxy-qube RPC implementation, tinyproxy changes, and dom0 policy are external prerequisites and are not installed by this repository.

## Integration Notes

### qrexec and RPC Paths

Qubes expects RPC services under `/etc/qubes-rpc`. The module assembles that directory from configured qrexec packages and keeps it first in `QREXEC_SERVICE_PATH`.

Generic services such as `qubes.StartApp` come from `services.qubes.core.basePackage`. Networking scripts such as `setup-ip` come from `services.qubes.core.networkingPackage`, so enabling networking does not change the package providing generic RPC services.

Python RPC entry points use explicit Python and library paths so `qubes.StartApp` and `qubes.VMExec` can import `qubesagent` and `qubesdb`. A compatibility link from `/usr/share` to `/run/current-system/sw/share` supports upstream tools with hard-coded paths.

### Updates Proxy

The networking module sets `all_proxy=http://127.0.0.1:8082` only for `nix-daemon` and `qubes-update-check`. Interactive `nix`, `nix-shell`, and `nixos-rebuild` aliases read the same value from `nix-daemon`; unrelated commands and login sessions are not proxied.

`sudo` may discard the proxy used by an interactive Nix alias. Enter an interactive root shell with `sudo su` when a client-side Nix fetch needs the updates proxy.

### Boot and Storage

The profile disables the NixOS initrd because Qubes supplies the guest kernel and the systemd initrd currently prevents a TemplateVM from booting.

Automatic root filesystem growth runs from `qubes-rootfs-resize.timer`, 30 seconds after boot and after `multi-user.target`. Its service has a 10-second timeout so resize failures cannot delay normal boot.

## Development

The Compose environment runs Nix in a container and keeps the Nix store in a Docker volume. Rebuild the image after source changes because the Dockerfile copies the repository into `/workspace`:

```sh
docker compose build
```

Refresh the pinned Qubes package versions and source hashes with:

```sh
./update.sh
```

The script leaves unchanged pins alone and reports them as `[-] No update`. When a version or branch hash changes, it prints `[+] Update available`, shows the old and new hash, and updates the package's `default.nix` pin in place. Set `QUBES_BRANCH` to an empty value to hash release tags instead of the configured Qubes release branch.

Build focused packages:

```sh
docker compose run --rm nix nix --extra-experimental-features "nix-command flakes" build --no-link --impure .#qubes-gui-agent-linux
docker compose run --rm nix nix --extra-experimental-features "nix-command flakes" build --no-link --impure .#qubes-core-agent-linux
```

Build the complete example system:

```sh
docker compose run --rm nix nix --extra-experimental-features "nix-command flakes" build --no-link --impure .#nixosConfigurations.nixos.config.system.build.toplevel
```

Transient network failures may require retrying after sources have entered the Docker-backed Nix store.

## Project Status

Working:

- AppVM networking and qrexec
- Xorg, clipboard, and file copy
- Application menu and icon export
- Memory reporting and ballooning
- Qubes update checks and update proxy
- SSH over qrexec
- USB proxy
- Template RPM and installer ISO builds

Needs real-VM validation or further work:

- qrexec commands may fail during early startup
- Automatic root filesystem growth on the delayed timer
- Split GPG client and key-holder flows
- SSH Git proxy with the external proxy-qube setup
- Non-Xen kernels and NetVM or USBVM roles
- RPC time synchronization and audio
- Applications with missing or unusual icons may emit appmenu warnings
- Memory resizing may cause Firefox crashes
- Systemd initrd migration

See `plan.md` for current invariants, validation steps, and remaining work.
