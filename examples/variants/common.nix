{lib, ...}: {
  # Older published revisions of the minimal example did not set this yet.
  system.stateVersion = lib.mkDefault "26.05";
}
