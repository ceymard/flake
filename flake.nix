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

  };

  outputs = { self, nixpkgs, home-manager, nixgl, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        #overlays = [nixgl.overlay];
      };

      nixGLPkgs = nixgl.packages.${system};

      # Correct wrapper for nix-community/nixGL
      wrapWithNixGL = nixGL: pkg: executables:
        let
          nixGLExec = builtins.elemAt (builtins.attrNames (builtins.readDir "${nixGL}/bin")) 0;
        in
        pkgs.symlinkJoin {
          name = "${pkg.pname or pkg.name}-nixgl";
          paths = [ pkg ];

          buildInputs = [ pkgs.makeWrapper ];

          postBuild = ''
            for b in ${executables}; do
              mv "$out/bin/$b" "$out/bin/$b-real"
              cat > "$out/bin/$b" <<EOF 
#!/usr/bin/env sh
unset LD_LIBRARY_PATH # just in case
exec ${nixGL}/bin/${nixGLExec} $out/bin/$b-real "\$@"
EOF
            chmod +x "$out/bin/$b"
            done
            
          '';
        };
      
      wrapIntel = wrapWithNixGL nixGLPkgs.nixGLIntel;
      wrapNvidia = wrapWithNixGL nixGLPkgs.nixGLNvidia;
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

              # To just have a somewhat recent version for those
              git
              tmux # Terminal multiplexer
              foot # Wayland terminal
              fzf # Fuzzy finder, used by fish in ctrl+R
              jq # JSON parsing
              curl
              wget
              gawk
              btop
              uv # Python env management
              just # Task runner
              starship # Nice prompt machine

              # Wrapped with nixGL
              #(wrapIntel brave "brave")
              #(wrapIntel microsoft-edge "microsoft-edge")
              (wrapIntel epiphany "epiphany")
              (wrapIntel signal-desktop "signal-desktop")
              (wrapIntel ungoogled-chromium "chromium")
              (wrapIntel flameshot "flameshot")
              (wrapIntel grim "grim")
              (wrapIntel satty "satty")
              (wrapIntel slurp "slurp")
              firefox
              goodvibes
              cursor-cli
              (wrapIntel inkscape "inkscape")
                           
              # The following is for niri and dank material shell.
              xwayland
              (wrapIntel dms-shell "dms")
              (wrapIntel xwayland-satellite "xwayland-satellite") # compilé à la main finalement
              (wrapIntel quickshell "quickshell")
              cava # audio visualization
              matugen # auto theme

              # General dev tools
              fuzzel
              go
              nodejs_24
              rustc
              cargo
              pgcli
              ripgrep-all
              ripgrep
              meson
              cmake

              chezmoi

              # LSP for markdown
              marksman


              # Provide nixGL binaries
              nixGLPkgs.nixGLIntel
              nixGLPkgs.nixVulkanIntel
              #nixGLPkgs.nixGLNvidia
              #nixGLPkgs.nixVulkanNvidia
            ];

            programs.zsh.enable = true;
            programs.git.enable = true;

            fonts.fontconfig = {
              enable = true;
            };
            
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

