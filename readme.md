# configuración lab ordenadores [REDACTED]

## instalación

Si el equipo que usas para instalar necesita Wi‑Fi corporativa antes de clonar este repo, conecta primero la ISO a `Andared_Corporativo` de forma temporal. En la guía adjunta aparecen los parámetros esperados para Linux/NetworkManager: SSID `Andared_Corporativo`, seguridad enterprise, autenticación con túnel y autenticación interna `GTC`, sin certificado CA.

1. descarga la iso de [nixos mínima](https://nixos.org/download/#nixos-iso) y arranca el ordenador desde ella
2. busca el disco duro en `lsblk`
3. `curl -fsSL https://raw.githubusercontent.com/iesfdlr/lab/main/install.sh | bash -s -- /dev/sda` (reemplaza `/dev/sda` por el disco duro que corresponda)
4. sigue las instrucciones en pantalla — el instalador pedirá las credenciales de Andared automáticamente. Pulsa Enter sin escribir nada para omitir este paso.

Para máquinas que no necesitan `Andared_Corporativo`, pasa `--no-andared` para omitir el mensaje directamente:

```
curl -fsSL ... | bash -s -- /dev/sda --no-andared
```

También es posible pasar las credenciales por línea de comandos para automatizar instalaciones (ojo: queda visible en el historial del shell):

```
curl -fsSL ... | bash -s -- /dev/sda --andared-username USUARIO --andared-password CLAVE
```

## andared_corporativo

El sistema instalado deja preparada una conexión de NetworkManager para `Andared_Corporativo` sin usuario ni contraseña guardados en el repositorio.

- En Plasma, basta con abrir el selector de redes, pulsar `Andared_Corporativo` e introducir las credenciales del usuario.
- Alternativamente, desde terminal se puede usar `andared-connect` para que `nmcli` pida las credenciales de forma interactiva.
- Si `TTLS` no funciona en un centro concreto, prueba `andared-connect peap`.
