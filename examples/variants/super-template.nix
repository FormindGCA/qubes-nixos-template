{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    curl
    fd
    file
    gcc
    git
    gnumake
    home-manager
    jq
    pkg-config
    python3
    ripgrep
    tmux
    tree
    vim
  ];
}
