# Installation

!!! tip "Connectivity"
    A wired connection is recommended. If you need Wi-Fi, the NixOS GNOME ISO supports **Andared_Corporativo** - see the [Wi-Fi setup](#connecting-to-andared_corporativo) section below.

Unlike most Nix configurations, this one requires a dedicated install script rather than a plain `nixos-rebuild`.

## Steps

1. Download the **minimal NixOS ISO** from the [official website](https://nixos.org/download/#nixos-iso) and boot from it.

2. Identify your target drive:
```sh
lsblk
```

3. Run the install script, replacing `/dev/sda` with your drive:
```sh
curl -fsSL https://raw.githubusercontent.com/iesfdlr/lab/main/install.sh \
	| bash -s -- /dev/sda
```

4. Follow the on-screen prompts - the installer will ask for your **Andared credentials** and optionally let you set a custom `root` password.

---

## Options

All flags are appended after the drive argument.

=== "Skip Andared"

    For machines that don't need `Andared_Corporativo`:

    ```sh
    curl -fsSL https://raw.githubusercontent.com/iesfdlr/lab/main/install.sh \
      | bash -s -- /dev/sda --no-andared
    ```

=== "Automated install"

    Pass credentials and root password directly for unattended installs:

    !!! warning
        These values will be visible in your shell history, but this is on a live environment so it's not a big deal.

    ```sh
    curl -fsSL https://raw.githubusercontent.com/iesfdlr/lab/main/install.sh \
      | bash -s -- /dev/sda \
          --andared-username USER \
          --andared-password PASS \
          --root-password ROOT_PASS
    ```

---

## Connecting to Andared_Corporativo

If installing over Wi-Fi, connect manually in the NixOS GNOME ISO using these NetworkManager settings:

| Field                  | Value                  |
|------------------------|------------------------|
| SSID                   | `Andared_Corporativo`  |
| Security               | Enterprise             |
| Tunnel authentication  | -                      |