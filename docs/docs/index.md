# About

A NixOS configuration for the computer lab of eth0's school. Currently unused, but it may be perfect for those who are interested in setting up a similar environment.

<iframe width="560" height="315" src="https://www.youtube-nocookie.com/embed/6n2w8a-OPeA?si=MuE81gyMvVmq7o30" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## Install

For the installation guide, go to [Installation](/installation)

## Reviewing the flake

To check that the flake evaluates without installing or switching the system:

```sh
nix --extra-experimental-features "nix-command flakes" flake metadata --no-write-lock-file .
nix --extra-experimental-features "nix-command flakes" flake show --no-write-lock-file .
nix --extra-experimental-features "nix-command flakes" flake check --no-build --no-write-lock-file .
```

For a deeper no-install check of what the NixOS system build would need, run:

```sh
nix --extra-experimental-features "nix-command flakes" build --dry-run --no-link --no-write-lock-file .#nixosConfigurations.nixos.config.system.build.toplevel
```

This prints the store paths that would be built or downloaded. That output is
expected; it is not installing or switching the system.

The machine-specific `hardware-configuration.nix` and `install-local.nix` files
are generated during installation. They are not required for the no-install
review commands above, but activation will fail with a clear message if someone
tries to install or switch without them.

## Why Nix?

NixOS is a Linux distribution that uses the Nix package manager to provide a declarative and reproducible configuration system. This means that you can define your entire system configuration in a single file, and Nix will take care of installing and configuring everything for you.

This makes it easy to set up and maintain a consistent environment across multiple machines, which is ideal for a computer lab setting, where not always you want to install programs on every machine manually.
