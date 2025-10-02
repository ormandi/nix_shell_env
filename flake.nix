{
  description = "My portable shell environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-darwin" ];
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
            buildInputs = [
              pkgs.bash
              pkgs.tmux
              pkgs.vim
              
              # LLVM 21 development tools
              pkgs.llvmPackages_21.clang-tools  # clang-format, clang-tidy, clangd
              pkgs.llvmPackages_21.lldb         # Debugger
              pkgs.llvmPackages_21.lld          # Linker
              
              # Build tools that will use LLVM 21
              pkgs.cmake
              pkgs.ninja
            ];

            shellHook = ''
              # Export bash path for use in aliases
              export NIX_BASH="${pkgs.bash}/bin/bash"
              export NIX_BASHRC="${self}/bashrc"

              echo "Development Environment"
              echo "======================="
              echo "NIX_BASH is: $NIX_BASH"
              echo "Bash: $($NIX_BASH --version | head -n 1)"
              echo "Compiler: $(clang++ --version | head -n 1)"
              echo "CMake: $(cmake --version | head -n 1)"
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
