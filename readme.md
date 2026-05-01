# Lab

A NixOS configuration for eth0's school computer lab. It provides a reproducible
desktop setup for classroom machines, with KDE Plasma, a curated software set,
Spanish defaults, privacy-focused browser settings, rootless Docker, Flatpak,
auto-updates, and maintenance tools.

Full documentation: <https://nixlab.srizan.dev/>

## Install

Boot a NixOS ISO (preferibly GNOME), identify the target disk with `lsblk`, then run:

```sh
curl -fsSL https://raw.githubusercontent.com/iesfdlr/lab/main/install.sh \
  | bash -s -- /dev/sda
```

Write a root password if asked (the prompt is in Spanish, sorry)

Replace `/dev/sda` with the correct drive. The installer can also skip
`Andared_Corporativo` wifi setup with `--no-andared` (you probably want this on a VM environment).
