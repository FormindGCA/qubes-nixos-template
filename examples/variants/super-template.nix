{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Add the tools you use the most here
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
