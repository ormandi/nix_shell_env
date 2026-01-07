{
  description = "My portable shell environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/01be09e86dd0d9924afab31f6a68a0045bcade04";
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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

  outputs = { self, nixpkgs, fenix, tmux-mem-cpu-load, zig-overlay }:
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
        in
        {
          default = (pkgs.mkShell.override {
            # Use LLVM 19 as the standard environment
            stdenv = pkgs.llvmPackages_19.stdenv;
          }) {
            # Currently fortification causes linking error with CUDA.
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
              eza
              bat
              gawk
              gnused
              mdcat
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
