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
  };

  outputs = { self, nixpkgs, home-manager, nixgl, ... }:
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
            home.stateVersion = "25.11";

            home.packages = with pkgs; [
              git
              tmux
              fzf
              jq
              curl
              wget
              openssh # we want something modern

              chezmoi helix

              # nixGL launchers (NOT functions)
              nixGLPkgs.nixGLIntel
              nixGLPkgs.nixGLNvidia
              nixGLPkgs.nixVulkanIntel
              nixGLPkgs.nixVulkanNvidia
            ];

            programs.zsh.enable = true;
            programs.git.enable = true;

            # Make nixGL launchers available in PATH
            home.sessionPath = [
              "${nixGLPkgs.nixGLIntel}/bin"
              "${nixGLPkgs.nixGLNvidia}/bin"
            ];
          }
        ];
      };
    };
}
