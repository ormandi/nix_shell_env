{
  description = "My portable shell environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    tmux-mem-cpu-load = {
      url = "github:ormandi/tmux-mem-cpu-load/show_cpu_show_ram";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, tmux-mem-cpu-load }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # Check if CUDA should be enabled via environment variable
          enableCuda = builtins.getEnv "ENABLE_CUDA" == "1";

          # Conditional CUDA packages
          cudaPackages = if enableCuda then with pkgs.cudaPackages; [
            cudatoolkit
            cuda_nvcc
            cuda_cudart
            cuda_cccl
            libcublas
            libcurand
            libcusparse
            cudnn
          ] else [];
        in
        {
          default = (pkgs.mkShell.override {
            # Use LLVM 19 as the standard environment
            stdenv = pkgs.llvmPackages_19.stdenv;
          }) {
            # Currently fortification causes linking error with CUDA.
            hardeningDisable = [ "fortify" "fortify3" ];

            buildInputs = with pkgs; [
              bash
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
              util-linux
              tmux-mem-cpu-load.packages.${system}.default
            ] ++ cudaPackages;

            shellHook = ''
              # Export bash path for use in aliases
              export NIX_BASH="${pkgs.bash}/bin/bash"
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
              export CUDA_ROOT=$(dirname $(dirname $(which nvcc)))

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
                  exec ${pkgs.bash}/bin/bash --rcfile ${self}/bashrc
              fi
            '';
          };
        });
    };
}
