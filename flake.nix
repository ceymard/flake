{
  description = "My reproducible user environment with nixGL (Intel + NVIDIA)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dank-material-shell = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixgl, dank-material-shell, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # nixGL derivations (launchers)
      nixGLPkgs = nixgl.packages.${system};

      username = builtins.getEnv "USER";
    in {
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          {
            home.username = username;
            home.homeDirectory = "/home/" + username;
            home.stateVersion = "26.05";

            
# Create a symlink so systemd can find the units
  home.activation.linkSystemdUnits = home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD mkdir -p $HOME/.config/systemd/user
    $DRY_RUN_CMD ln -sf $HOME/.nix-profile/lib/systemd/user/* $HOME/.config/systemd/user/
  '';

            home.packages = with pkgs; [
              git
              tmux
              fzf
              jq
              curl
              wget
              openssh # we want something modern

              chezmoi helix
              fish

              alacritty

              # graphical stuff
              niri xdg-desktop-portal-gnome 
              
              # nixGL launchers (NOT functions)
              nixGLPkgs.nixGLIntel
              # nixGLPkgs.nixGLNvidia
              nixGLPkgs.nixVulkanIntel
              # nixGLPkgs.nixVulkanNvidia

              # Add DankMaterialShell package
              dank-material-shell.packages.${system}.default
              dank-material-shell.packages.${system}.quickshell
            ];

            programs.zsh.enable = true;
            programs.git.enable = true;

            # Make nixGL launchers available in PATH
            home.sessionPath = [
              # "${nixGLPkgs.nixGLIntel}/bin"
              # "${nixGLPkgs.nixGLNvidia}/bin"
            ];
          }
        ];
      };
    };

  
}
