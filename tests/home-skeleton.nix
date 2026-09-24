{ pkgs }:
let
  agent = pkgs.qubes-core-agent-linux.override {
    skeletonDirectory = "/etc/qubes-home-skel";
  };
in
pkgs.runCommand "qubes-home-skeleton-check" { } ''
  # Exercise the packaged initializer, substituting only the host account
  # database and /etc path so the check runs without root or a Qubes guest.
  cp ${agent}/lib/qubes/init/functions ./functions
  substituteInPlace ./functions \
    --replace-fail '${pkgs.getent}/bin/getent' 'test_getent' \
    --replace-fail '/etc/qubes-home-skel' "$PWD/skeleton"
  test_getent() { printf 'user:x:%s:%s::/home/user:/bin/sh\n' "$(id -u)" "$(id -g)"; }
  source ./functions

  mkdir -p home-files/.config
  printf 'managed\n' > managed-file
  ln -s "$PWD/managed-file" home-files/.config/example
  chmod 0555 home-files home-files/.config
  ln -s "$PWD/home-files" skeleton
  initialize_home "$PWD/homes" ifneeded
  test -d homes/user
  test ! -L homes/user
  test -w homes/user/.config
  test -L homes/user/.config/example
  cmp homes/user/.config/example managed-file
  printf 'private history\n' > homes/user/.zsh_history
  printf 'local preferences\n' > homes/user/.config/local
  initialize_home "$PWD/homes" ifneeded
  test "$(cat homes/user/.zsh_history)" = 'private history'
  test "$(cat homes/user/.config/local)" = 'local preferences'
  touch "$out"
''
