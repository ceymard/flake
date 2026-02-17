{
  description = "My reproducible user environment";

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

  outputs = { self, nixpkgs, home-manager, dank-material-shell, nixgl, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

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

            home.packages = with pkgs; [
              git
              tmux
              fzf
              jq
              curl
              wget
              openssh # we want something modern

              epiphany # debug webkit
              ungoogled-chromium
              go rustc cargo
              goodvibes

              chezmoi helix
              fish
              meson cmake

              nixGLPkgs.nixGLIntel
              nixGLPkgs.nixVulkanIntel
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
