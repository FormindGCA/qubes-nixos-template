{
  lib,
  fetchFromGitHub ? null,
}: {
  fetchFromQubes = {
    repo,
    version,
    hash,
    rev ? null,
  }:
    fetchFromGitHub {
      owner = "QubesOS";
      inherit repo hash;
      rev = if rev != null then rev else "v${version}";
    };

  meta = description:
    with lib; {
      inherit description;
      homepage = "https://qubes-os.org";
      license = licenses.gpl2Plus;
      maintainers = [];
      platforms = platforms.linux;
    };
}
