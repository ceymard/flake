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

      # Correct wrapper for nix-community/nixGL
      wrapWithNixGL = nixGL: pkg: 
        pkgs.symlinkJoin {
          name = "${pkg.pname or pkg.name}-nixgl";
          paths = [ pkg ];

          buildInputs = [ pkgs.makeWrapper ];

          postBuild = ''
            for b in $(ls $out/bin); do
              mv "$out/bin/$b" "$out/bin/$b-real"
              makeWrapper "$out/bin/$b-real" "$out/bin/$b" --run "exec ${nixGL}/bin/nixGLIntel $out/bin/$b-real"
            done
          '';
        };
      
      wrapIntel = wrapWithNixGL nixGLPkgs.nixGLIntel;





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
              openssh

              # Wrapped with nixGL
              (wrapIntel epiphany)
              (wrapIntel ungoogled-chromium)

              go rustc cargo
              goodvibes

              chezmoi helix
              fish
              meson cmake

              # Provide nixGL binaries
              nixGLPkgs.nixGLIntel
              nixGLPkgs.nixVulkanIntel
            ];

            programs.zsh.enable = true;
            programs.git.enable = true;

            home.sessionPath = [
              # optional
            ];
          }
        ];
      };
    };
}

