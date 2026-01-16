# users/TEMPLATE-USER/default.nix
# Template for creating a new laptop user
#
# HOW TO USE THIS TEMPLATE:
# 1. Copy this directory: cp -r users/TEMPLATE-USER users/USERNAME
# 2. Edit this file to configure the user's apps and desktop
# 3. Add user to host configuration (see docs/MULTI-USER-GUIDE.md)
# 4. Create system user in hosts/HOSTNAME/configuration.nix

{ pkgs, ... }: {
  # Basic user info
  home.username = "USERNAME";  # CHANGE THIS!
  home.homeDirectory = "/home/USERNAME";  # CHANGE THIS!
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # ========================================
  # GIT Configuration (optional)
  # ========================================
  programs.git = {
    enable = true;
    settings = {
      user.name = "User Name";
      user.email = "user@example.com";
      init.defaultBranch = "main";
    };
  };

  # ========================================
  # DESKTOP ENVIRONMENT
  # ========================================
  # GNOME is configured at system level in modules/system/gnome.nix
  # You can add user-specific GNOME settings here:
  
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      # Example: Set color scheme
      # color-scheme = "prefer-dark";
    };
  };

  # ========================================
  # USER PACKAGES
  # ========================================
  home.packages = with pkgs; [
    # Example packages - customize for this user:
    firefox
    libreoffice-fresh
    thunderbird
    vlc
    
    # Add more packages as needed
  ];

  # ========================================
  # BASH Configuration (optional)
  # ========================================
  programs.bash = {
    enable = true;
    shellAliases = {
      # Add user-specific aliases
      ll = "ls -la";
    };
  };
}
