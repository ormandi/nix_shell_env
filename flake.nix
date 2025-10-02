{
  description = "My portable shell environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs }:
    let
      # Support ARM macOS and x86_64 Linux only
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          
          # Create wrapper scripts with custom configs
          wrapperScripts = pkgs.writeScriptBin "setup-wrappers" ''
            #!${pkgs.bash}/bin/bash
            mkdir -p $out/bin
            
            # Bash wrapper
            cat > $out/bin/bash << 'EOF'
            #!${pkgs.bash}/bin/bash
            exec ${pkgs.bash}/bin/bash --rcfile ${self}/bashrc "$@"
            EOF
            chmod +x $out/bin/bash
            
            # Tmux wrapper
            cat > $out/bin/tmux << 'EOF'
            #!${pkgs.bash}/bin/bash
            exec ${pkgs.tmux}/bin/tmux -f ${self}/tmux.conf "$@"
            EOF
            chmod +x $out/bin/tmux
            
            # Vim wrapper
            cat > $out/bin/vim << 'EOF'
            #!${pkgs.bash}/bin/bash
            export VIMINIT="source ${self}/vimrc"
            exec ${pkgs.vim}/bin/vim "$@"
            EOF
            chmod +x $out/bin/vim
          '';
          
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              # Core tools (wrapped)
              pkgs.bash
              pkgs.tmux
              pkgs.vim
              
              # Development tools
              # pkgs.pyenv
              # pkgs.uv
              # pkgs.zig
              # pkgs.llvm
              # pkgs.cmake
              # pkgs.ninja
              # pkgs.bazelisk
              # pkgs.jq
              # pkgs.nmap
              # pkgs.automake
              # pkgs.git
              
              # Wrapper scripts
              wrapperScripts
            ];
            
            shellHook = ''
              # Run the wrapper script setup
              ${wrapperScripts}/bin/setup-wrappers
              
              # Add wrappers to PATH first (so they override the originals)
              export PATH="$out/bin:$PATH"
              
              echo "Environment ready!"
              echo "All tools configured with custom configs"
              echo ""
              echo "Available tools:"
              echo "  bash, vim, tmux (with custom configs)"
              echo "  pyenv, uv, zig, llvm, cmake, ninja"
              echo "  bazelisk, jq, nmap, automake, git"
            '';
          };
        });
    };
}
