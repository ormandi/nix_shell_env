# Nix-based Environment

This describes a portable, preconfigured shell environment.
Supports Linux `x86_64` and MacOS `aarch64`.

## Install&configure `nixpkgs`

As a requirement `nix` pakcage manager has to be installed.

### MacOS

In a terminal, run the following command:

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
```

### Debian

```bash
sudo apt update
sudo apt install nix-setup-systemd
sudo adduser $(whoami) nix-users
```

### Configure `nix` flakes

On any platfrom please run the followings.

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

# Use the shell environment

```bash
nix develop github:ormandi/nix_shell_env --refresh
```

Or with CUDA runtime enabled:

```bash
ENABLE_CUDA=1 NIXPKGS_ALLOW_UNFREE=1 nix develop --impure
```
