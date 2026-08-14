# Extended configuration examples

These examples are intentionally separate from `../flake.nix` and
`../configuration.nix`. The RPM continues to install only that minimal
configuration. Use this directory from a repository checkout when creating a
larger TemplateVM and a dedicated cache StandaloneVM.

## Architecture

- `nix-template` is a larger TemplateVM with common tools and a local Nix
  substituter endpoint.
- `nix-cache` is a configuration for a StandaloneVM. It serves its persistent
  Nix store on loopback only.
- `qubes.NixCache` carries the HTTP connection between the client loopback
  proxy and the cache VM. No inter-VM IP connectivity is required.
- `mission-flake` is a small example of a tool that can be built in the cache
  VM and used temporarily in an AppVM.

The qrexec service exposes only `nix-serve`. It does not provide a shell or a
write interface to the cache VM.

## Build the TemplateVM configuration

By default the example uses the published `qubes-nixos-template` repository.
From this directory, override that input to test changes from a local checkout:

```sh
nix build \
  --override-input qubes-nixos-template path:../.. \
  .#nixosConfigurations.nix-template.config.system.build.toplevel
```

Replace `REPLACE_WITH_THE_CACHE_PUBLIC_KEY` in
`qrexec-cache-client.nix` before deploying this configuration. Do not put the
private key in this repository or in a TemplateVM.

## Create the cache VM

Create the cache from the minimal installed template. It must be a
StandaloneVM so changes to its Nix store survive a restart:

```sh
qvm-create --class StandaloneVM --template nixos --label orange nix-cache
qvm-volume list nix-cache
qvm-volume resize nix-cache:root 40G
```

Start the VM, check out the complete repository, and switch it to the cache
configuration. Override the input when the checkout contains repository changes
that are not yet published:

```sh
sudo nixos-rebuild switch \
  --override-input qubes-nixos-template \
  path:/etc/nixos/qubes-nixos-template \
  --flake /etc/nixos/qubes-nixos-template/examples/variants#nix-cache
```

The configuration deliberately keeps `nix-serve` stopped until its signing
key exists. Generate the key inside `nix-cache`:

```sh
sudo install -d -m 0700 -o root -g root /var/lib/nix-cache
sudo nix-store --generate-binary-cache-key \
  qubes-nix-cache-1 \
  /var/lib/nix-cache/cache-secret-key.pem \
  /var/lib/nix-cache/cache-public-key.pem
sudo chown root:root /var/lib/nix-cache/cache-secret-key.pem
sudo chmod 0400 /var/lib/nix-cache/cache-secret-key.pem
sudo systemctl start nix-serve
cat /var/lib/nix-cache/cache-public-key.pem
```

Copy the printed public key into `qrexec-cache-client.nix`.

## Deploy the TemplateVM

Clone the minimal installed template in dom0 so it remains available as a
recovery baseline:

```sh
qvm-clone nixos nix-template
```

Start `nix-template`, check out the complete repository under
`/etc/nixos/qubes-nixos-template`, and deploy the larger configuration:

```sh
sudo nixos-rebuild switch \
  --override-input qubes-nixos-template \
  path:/etc/nixos/qubes-nixos-template \
  --flake /etc/nixos/qubes-nixos-template/examples/variants#nix-template
```

Shut down and restart AppVMs after changing them to use `nix-template`.

## Add the dom0 policy

Tag only the AppVMs that should read from the cache:

```sh
qvm-tags mission-app add nix-cache-client
```

Tag `nix-template` too if Nix commands run inside the TemplateVM should use the
cache. Every VM whose Nix configuration contains `qrexec-cache-client.nix`
will try the local endpoint; an untagged VM is denied by qrexec policy and
falls back to its next substituter.

Create `/etc/qubes/policy.d/30-user-nix-cache.policy` in dom0 with:

```text
qubes.NixCache * @tag:nix-cache-client nix-cache allow
qubes.NixCache * @anyvm @anyvm deny
```

The first rule fixes the destination to `nix-cache`; clients cannot select a
different service VM. The final rule denies every source that was not
explicitly tagged. Policy changes belong in dom0 and cannot be supplied by
this NixOS repository.

Test the transport from a tagged AppVM:

```sh
curl --fail http://127.0.0.1:5000/nix-cache-info
```

## Populate the cache

`nix-serve` exposes paths already present in the cache VM. It does not receive
paths built by AppVMs automatically. Build mission tools in `nix-cache` and
keep a GC root for each closure that should remain available:

```sh
sudo install -d /var/lib/nix-cache/roots
sudo nix build \
  --out-link /var/lib/nix-cache/roots/mission-hash \
  ./mission-flake#mission-hash
```

An AppVM can then use the cached tool without adding it to the TemplateVM:

```sh
nix run ./mission-flake#mission-hash -- document.pdf
```

The AppVM still needs the flake source to evaluate the command. A binary cache
serves build outputs, not Git repositories or arbitrary flake source archives.

## Security and persistence

The cache signing key is trusted by every configured client. Treat `nix-cache`
as a high-trust VM, restrict its network access, and do not use it for browsing
or unrelated work.

Packages fetched into an AppVM remain in that AppVM's non-persistent root and
will normally be fetched again after reboot. The qrexec cache makes that fetch
local, but it does not make the AppVM Nix store persistent.

Home Manager has the same limitation: its files usually link to Nix store
paths. Use it in an AppVM only with a deliberately persistent store or with a
Home Manager closure already included in the TemplateVM.
