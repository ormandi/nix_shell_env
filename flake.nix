{
  description = "My portable shell environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/01be09e86dd0d9924afab31f6a68a0045bcade04";
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # k9s past 0.32.5 needs Go >= 1.24, which the pinned nixpkgs above lacks
    # (it caps at Go 1.23). A separate, recent nixpkgs supplies a current k9s
    # and its matching toolchain (plus gke-gcloud-auth-plugin) without
    # unpinning the rest of the environment.
    nixpkgs-k9s.url = "github:NixOS/nixpkgs/nixos-25.11";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tmux-mem-cpu-load = {
      url = "github:ormandi/tmux-mem-cpu-load/show_cpu_show_ram";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs"; # Ensure consistency
    };
  };

  outputs = { self, nixpkgs, nixpkgs-k9s, fenix, tmux-mem-cpu-load, zig-overlay }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              fenix.overlays.default
              zig-overlay.overlays.default
            ];
          };

          # Recent nixpkgs used solely for k9s + its GKE auth plugin (see the
          # nixpkgs-k9s input). Everything else stays on the pin above.
          pkgsK9s = import nixpkgs-k9s { inherit system; };

          staticPkgs = pkgs.pkgsStatic;
          staticTarget = staticPkgs.stdenv.hostPlatform.rust.rustcTarget;
          staticRust = pkgs.fenix.combine [
            pkgs.fenix.complete.cargo
            pkgs.fenix.complete.rustc
            pkgs.fenix.targets.${staticTarget}.latest.rust-std
          ];

          # pkgs.mdcat is 2.3.1, which predates table support (added in 2.4.0).
          # This fork took over the crate after upstream was archived.
          mdcatWithTables = (staticPkgs.makeRustPlatform {
            cargo = staticRust;
            rustc = staticRust;
          }).buildRustPackage {
            pname = "mdcat";
            version = "2.15.0";
            src = pkgs.fetchFromGitHub {
              owner = "BIRSAx2";
              repo = "mdcat";
              rev = "mdcat-2.15.0";
              hash = "sha256-wXj5UmOZCI1zSLNwGNBicKsapGq60pyqENzFrUEj2kw=";
            };
            cargoHash = "sha256-5KzLHg7TJPalxqd+EqUhOiCTDMbEk/MrRYJOg39PgWk=";
            # Every library links statically out of this pinned nixpkgs.
            nativeBuildInputs = [ pkgs.pkg-config ];
            # libcurl.pc lists these under Requires, and pkg-config refuses to
            # answer unless every one resolves (Linux). On Darwin they supply
            # the -L paths that RUSTFLAGS' -l flags resolve against.
            buildInputs = (with staticPkgs; [
              curl openssl zlib zstd libidn2 libunistring libpsl libssh2 nghttp2
            ])
              # It is needed for static `libcurl`.
              ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin
                (with pkgs.darwin.apple_sdk.frameworks; [
                  CoreFoundation
                  CoreServices
                  Security
                  SystemConfiguration
                ]);
            env = {
              # buildInputs only contributes -L paths, and on Darwin curl-sys
              # emits a bare `-l curl` without consulting pkg-config, so name
              # the rest of libcurl.pc's Libs by hand or they go unresolved.
              RUSTFLAGS = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin
                ("-l nghttp2 -l idn2 -l unistring -l ssh2 -l psl "
                + "-l ssl -l crypto -l zstd -l z "
                + "-l framework=SystemConfiguration");
              PKG_CONFIG_ALL_STATIC = "1";
              OPENSSL_STATIC = "1";
              OPENSSL_NO_VENDOR = "1";
              OPENSSL_LIB_DIR = "${pkgs.lib.getLib staticPkgs.openssl}/lib";
              OPENSSL_INCLUDE_DIR = "${pkgs.lib.getDev staticPkgs.openssl}/include";
            };
            auditable = false;  # this nixpkgs' cargo-auditable rejects edition 2024
            doCheck = false;    # upstream tests need network and a real terminal
          };

          # k9s' in-process client-go execs the GKE credential plugin named in
          # the kubeconfig's user.exec block to mint tokens, so the plugin must
          # be on k9s' PATH. It ships only as a google-cloud-sdk component (no
          # standalone attr); that also puts gcloud on PATH, which the plugin
          # uses to refresh credentials.
          gkeAuthPlugin = pkgsK9s.google-cloud-sdk.withExtraComponents [
            pkgsK9s.google-cloud-sdk.components.gke-gcloud-auth-plugin
          ];

          # Drop cgo so Go uses its own DNS resolver; glibc's dlopens the
          # host's libnss_*.so. netgo replaces the package's netcgo tag.
          # (CGO_ENABLED lives in `env` for this nixpkgs' buildGoModule.)
          k9sHermetic = pkgsK9s.k9s.overrideAttrs (old: {
            env = (old.env or { }) // { CGO_ENABLED = 0; };
            tags = [ "netgo" ];
            nativeBuildInputs = old.nativeBuildInputs ++ [ pkgsK9s.makeBinaryWrapper ];
            # k9s execs kubectl to attach, exec and edit, and (via client-go)
            # the GKE credential plugin from the kubeconfig; kubectl execs
            # $KUBE_EDITOR, falling back to vi, which vim provides.
            postInstall = old.postInstall + ''
              wrapProgram $out/bin/k9s \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgsK9s.kubectl pkgs.vim gkeAuthPlugin ]}
            '';
          });
        in
        {
          default = (pkgs.mkShell.override {
            # Use LLVM 19 as the standard environment
            stdenv = pkgs.llvmPackages_19.stdenv;
          }) {
            hardeningDisable = [ "fortify" "fortify3" ];

            buildInputs = with pkgs; [
              bashInteractive
              bash-completion
              pkg-config
              tmux
              vim
              git
              wget

              # LLVM 19 development tools - CUDA toolkit compatible
              llvmPackages_19.clang-tools  # clang-format, clang-tidy, clangd
              llvmPackages_19.lldb         # Debugger
              llvmPackages_19.lld          # Linker
              llvmPackages_19.openmp       # OpenMP support for Clang
              llvmPackages_19.stdenv.cc.cc.lib
              llvmPackages_19.libcxx
              llvmPackages_19.libcxxStdenv
              llvmPackages_19.libcxxClang

              # Build tools
              bazelisk
              cmake
              ninja
              gnumake

              # Libraries
              bzip2.dev
              curl.dev
              libffi.dev
              ncurses.dev
              libxml2.dev
              openssl.dev
              readline.dev
              sqlite.dev
              tk.dev
              xmlsec.dev
              xz.dev  # provides liblzma
              zlib.dev

              # Python
              pyenv
              ruff
              uv

              # Other tools
              direnv
              nix-direnv
              eza
              bat
              gawk
              gnused
              graphviz
              k9sHermetic
              mdcatWithTables
              util-linux
              tmux-mem-cpu-load.packages.${system}.default

              # Zig
              zig     # The Zig compiler (latest version from the overlay)
              zls     # The Zig Language Server

              # Rust
              (pkgs.fenix.complete.withComponents [
                "cargo"
                "clippy"
                "rust-analyzer"
                "rust-src"
                "rustc"
                "rustfmt"
              ])
              cargo-edit
              cargo-expand
              cargo-generate
              cargo-watch
            ];

            shellHook = ''
              # Export bash path for use in aliases
              export NIX_BASH="${pkgs.bashInteractive}/bin/bash"
              export NIX_BASHRC="${self}/bashrc"
              export NIX_BASH_COMPLETION="${pkgs.bash-completion}/share/bash-completion/bash_completion"

              # Generate bazel completion
              BAZEL_COMPLETION="$HOME/.cache/nix-shell/bazel-complete.bash"
              mkdir -p "$(dirname "$BAZEL_COMPLETION")"
              if [ ! -f "$BAZEL_COMPLETION" ] || [ ! -s "$BAZEL_COMPLETION" ]; then
                  ${pkgs.bazelisk}/bin/bazelisk help completion bash > "$BAZEL_COMPLETION" 2>/dev/null || true
              fi
              export NIX_BAZEL_COMPLETION="$BAZEL_COMPLETION"

              # Export tmux path.
              export NIX_TMUX="${pkgs.tmux}/bin/tmux"
              export NIX_TMUX_CONF="${self}/tmux.conf"

              # Export vim path.
              export NIX_VIM="${pkgs.vim}/bin/vim"
              export NIX_VIM_DIFF="${pkgs.vim}/bin/vimdiff"
              export NIX_VIMRC="${self}/vimrc"

              # Set the location of CUDA toolkit.
              NVCC_PATH=$(which nvcc)
              if [ -f "$NVCC_PATH" ] && [ -s "$NVCC_PATH" ]; then
                  export CUDA_HOME=$(dirname $(dirname $NVCC_PATH))
              fi

              echo "Development Environment"
              echo "======================="
              echo "NIX_BASH is: $NIX_BASH"
              echo "Bash: $($NIX_BASH --version | head -n 1)"
              echo "NIX_TMUX is: $NIX_TMUX"
              echo "Tmux: $($NIX_TMUX -V | head -n 1)"
              echo "NIX_VIM is: $NIX_VIM"
              echo "Vim: $($NIX_VIM --version | head -n 1)"
              echo "Compiler: $(clang++ --version | head -n 1)"
              echo "CMake: $(cmake --version | head -n 1)"
              echo "Pyenv: $(pyenv --version | head -n 1)"
              echo ""

              # Launch bash with custom bashrc
              if [ -z "$NIX_SHELL_BASH_LOADED" ]; then
                  export NIX_SHELL_BASH_LOADED=1
                  exec ${pkgs.bashInteractive}/bin/bash --rcfile ${self}/bashrc
              fi
            '';
          };
        });
    };
}
