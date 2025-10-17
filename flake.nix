{
  description = "My portable shell environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
        in
        {
          default = (pkgs.mkShell.override {
            # Use LLVM 21 as the standard environment
            stdenv = pkgs.llvmPackages_21.stdenv;
          }) {
            buildInputs = with pkgs; [
              bash
              bash-completion
              pkg-config
              tmux
              vim
              git

              # LLVM 21 development tools
              llvmPackages_21.clang-tools  # clang-format, clang-tidy, clangd
              llvmPackages_21.lldb         # Debugger
              llvmPackages_21.lld          # Linker

              # Build tools that will use LLVM 21
              cmake
              ninja
              gnumake

              # Libraries.
              bzip2.dev
              curl.dev
              libffi.dev
              ncurses.dev
              libxml2.dev
              openssl.dev
              readline.dev
              sqlite.dev
              tk.dev
              wget.dev
              xmlsec.dev
              xz.dev  # provides liblzma
              zlib.dev

              # Python
              pyenv
              ruff
              ty
              uv

              # Other tools
              eza
              bat
              gawk
              gnused
              util-linux
              tmux-mem-cpu-load.packages.${system}.default
            ];

            shellHook = ''
              # Export bash path for use in aliases
              export NIX_BASH="${pkgs.bash}/bin/bash"
              export NIX_BASHRC="${self}/bashrc"

              # Export tmux path.
              export NIX_TMUX="${pkgs.tmux}/bin/tmux"
              export NIX_TMUX_CONF="${self}/tmux.conf"

              # Export vim path.
              export NIX_VIM="${pkgs.vim}/bin/vim"
              export NIX_VIMRC="${self}/vimrc"

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
