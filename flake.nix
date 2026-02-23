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
      wrapWithNixGL = nixGL: pkg: executables:
        pkgs.symlinkJoin {
          name = "${pkg.pname or pkg.name}-nixgl";
          paths = [ pkg ];

          buildInputs = [ pkgs.makeWrapper ];

          postBuild = ''
            for b in ${executables}; do
              mv "$out/bin/$b" "$out/bin/$b-real"
              cat > "$out/bin/$b" <<EOF 
#!/usr/bin/env sh
exec ${nixGL}/bin/nixGLIntel $out/bin/$b-real "\$@"
EOF
            chmod +x "$out/bin/$b"
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

              nodejs_24
              # Wrapped with nixGL
              (wrapIntel epiphany "epiphany")
              (wrapIntel ungoogled-chromium "chromium")
              (wrapIntel niri "niri")
              (wrapIntel alacritty "alacritty")
              (wrapIntel brave "brave")
              #(wrapIntel microsoft-edge "microsoft-edge")
              (wrapIntel code-cursor "cursor")
              cursor-cli
              xwayland-satellite
              
              # Add DankMaterialShell package
              (wrapIntel dank-material-shell.packages.${system}.default "dms")
              dank-material-shell.packages.${system}.quickshell

              go rustc cargo
              goodvibes
              pgcli

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
            
            home.activation.syncUserUnits = {
  after = [ "writeBoundary" ];
  before = [ "reloadSystemd" ];
  data = ''
    src="$HOME/.nix-profile/lib/systemd/user"
    dst="$HOME/.config/systemd/user"

    mkdir -p "$dst"

    # Remove broken symlinks in target
    find "$dst" -xtype l -delete

    # Create/update symlinks
    if [ -d "$src" ]; then
      for unit in "$src"/*; do
        ln -sf "$unit" "$dst/$(basename "$unit")"
      done
    fi

  '';
};
          }
        ];
      };
    };
}

