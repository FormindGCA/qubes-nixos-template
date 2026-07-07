{lib}: {
  meta = description:
    with lib; {
      inherit description;
      homepage = "https://qubes-os.org";
      license = licenses.gpl2Plus;
      maintainers = [];
      platforms = platforms.linux;
    };
}
