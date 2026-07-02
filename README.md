# nix expressions for creating a qubes templatevm

This repository currently targets Qubes OS 4.3 template VMs.

## getting started

*warning*: proceed at your own risk, this involves copying files to dom0 and installing a template
without gpg signature verification

1. download the template rpm from github releases or build it yourself via `nix build .#rpm` ( preferred )
2. copy the template rpm to dom0
```
qvm-run --pass-io <YOUR_DOWNLOAD_VM> 'cat <FULL_RPM_PATH>' > qubes-template-nixos-4.2.0-unavailable.noarch.rpm
```
3. install the template
```
qvm-template install qubes-template-nixos-4.2.0-unavailable.noarch.rpm --nogpgcheck
```
4. start the template and wait about 30s ( see qrexec notes. )
```
qvm-start nixos
```
5. start a terminal in the template
```
qvm-run nixos xterm
```

at this point you can customize the template and use it like any other NixOS install. the example config has been copied to `/etc/nixos`.

## local development with docker

The included compose setup runs Nix in a container and keeps the Nix store in a Docker volume.

Rebuild the image after changing files, because the Dockerfile copies the repository into `/workspace`:

```sh
docker compose build
```

Build a focused package while iterating:

```sh
docker compose run --rm nix nix --extra-experimental-features "nix-command flakes" build --no-link --impure .#qubes-gui-agent-linux
docker compose run --rm nix nix --extra-experimental-features "nix-command flakes" build --no-link --impure .#qubes-core-agent-linux
```

Build the full example system closure:

```sh
docker compose run --rm nix nix --extra-experimental-features "nix-command flakes" build --no-link --impure .#nixosConfigurations.nixos.config.system.build.toplevel
```

Network timeouts while fetching Qubes or nixpkgs sources can fail an otherwise valid build. Retrying the same command is usually enough once the source has been fetched into the Docker volume.

## qrexec / RPC notes

Qubes expects RPC services under `/etc/qubes-rpc`, so the NixOS module generates that directory from the configured qrexec service packages. The qrexec service path also keeps `/etc/qubes-rpc` first for compatibility.

Generic RPC services such as `qubes.StartApp` come from `services.qubes.core.basePackage`. Networking scripts such as `setup-ip` come from `services.qubes.core.networkingPackage`, so enabling networking does not change the package that provides generic RPCs.

Some upstream Qubes tools still use hard-coded `/usr/share` paths. The core module creates `/usr/share -> /run/current-system/sw/share` so those tools can find desktop files and Qubes XDG override data on NixOS.

The Python RPC entry points are wrapped with explicit `PYTHONPATH` and library paths. In particular, `qubes.StartApp` and `qubes.VMExec` need to import `qubesagent` and `qubesdb` outside a normal Python package entry point.

When using Qubes OS Updater on a cloned or renamed template, set `services.qubes.updates.flakeConfiguration` to the flake configuration name to build. By default the updater uses the VM hostname, so a template named `formol` will look for `nixosConfigurations.formol`. If the flake only defines `nixosConfigurations.nixos`, configure:

```nix
services.qubes.updates.flakeConfiguration = "nixos";
```

By default the updater refreshes the `nixpkgs` and `qubes-nixos-template` flake inputs before checking and applying updates. Override `services.qubes.updates.updateInputs` to change that list, or set it to `[]` to use the existing lock file unchanged.

## alternative install via iso

for those that want to avoid installing anything in dom0, these instructions will allow you to install to
a fresh hvm template.

1. download the custom installer iso from github releases
2. create a new qube, select type "TemplateVM", template "(none)", name "nixos", networking "(none)", tick "Launch settings after creation", press "OK" button
3. in the settings for the new qube, go to the advanced tab, change the kernel to "(provided by qube)" and virtualization mode to "HVM", press "Apply" button
4. click the "boot qube from CD-ROM" button, click the "from file in qube" option and browse for the downloaded iso. press "OK" button, the qube will launch a boot console
5. wait for about 15s then press enter to begin the install ( the boot console will say "Press Enter to continue" )
6. the system will auto shutdown on successful install
7. open the settings for the qube, go to the advanced tab, change the kernel to "default (...)" and virtualization mode to "default (PVH)"
8. start the template and wait about 30s ( see qrexec notes. )
```
qvm-start nixos
```
9. start a terminal in the template
```
qvm-run nixos xterm
```

## issues with the qubes updates proxy

by default a qubes template does not have direct internet access and instead uses the qubes updates proxy
over qrpc. nix does not have a concept of a global proxy setting and as such is tricky to correctly 
configure in a way that doesn't involve simply setting `all_proxy` everywhere. 

as a compromise the packaging sets `all_proxy` for nix-daemon but not all downloads go through nix-daemon. the qubes packaging in this repo creates aliases for interactive shells that wrap a few of the common nix programs to pass proxy info. however this leaves various edge cases, a few of which are noted below. remember that you can always set `all_proxy` in your environment manually or in the worst case, switch to giving the template direct internet access.

### issues with sudo nix commands

due to the above, you're likely to run into issues when running `sudo nix...` - in these cases you can instead first get an interactive root shell e.g. via `sudo su`.

### issues with remote nix configs on github

you may run into issues if you pull a remote nix config over ssh from github. to workaround
you can add the following to `~/.ssh/config` ( the host and port overrides are necessary since these
qubes updates proxy filters port 22. ):
```
Host github.com
  HostName ssh.github.com
  Port 443
  ProxyCommand nc -X connect -x 127.0.0.1:8082 %h %p
```

## notes

### what works
- qrexec eventually works
- appvm networking
- xorg
- copy / paste
- qvm-copy
- ssh over qrexec ( handy for using --target-host with nixos-rebuild )
- memory reporting / ballooning
- qubes update checks
- qubes update triggers ( requires unmerged upstream changes )
- usb proxy
- building an rpm for the templatevm
- update proxy

### what doesn't work / untested
- qrexec startup isn't clean, commands can fail initially
- populating application shortcuts
- using a non-xen provided kernel
- using as netvm or usbvm
- time sync via rpc ( currently handled is systemd-timesyncd, but per vm ntp sync creates more attack surface area? )
- audio
- grow root fs

### bugs
- memory resizing seems to cause crashes in ff

### todo
- deal with substituteInPlace deprecation
- clean up package fixups and resholve configuration
