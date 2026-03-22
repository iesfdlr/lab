# configuración lab ordenadores [REDACTED]

## instalación

1. descarga la iso de [nixos mínima](https://nixos.org/download/#nixos-iso) y arranca el ordenador desde ella
2. busca el disco duro en `lsblk`
3. `curl -fsSL https://raw.githubusercontent.com/iesfdlr/lab/main/install.sh | bash - /dev/sda` (reemplaza `/dev/sda` por el disco duro que corresponda)
4. sigue las instrucciones en pantalla