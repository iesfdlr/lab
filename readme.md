# configuración lab ordenadores

## instalación

si el equipo que usas para instalar necesita Wi‑Fi corporativa antes de clonar este repo, conecta primero la ISO a `Andared_Corporativo` de forma temporal. en la guía adjunta aparecen los parámetros esperados para Linux/NetworkManager: SSID `Andared_Corporativo`, seguridad enterprise, autenticación con túnel y autenticación interna `GTC`, sin certificado CA.

1. descarga la iso de [nixos mínima](https://nixos.org/download/#nixos-iso) y arranca el ordenador desde ella
2. busca el disco duro en `lsblk`
3. `curl -fsSL https://raw.githubusercontent.com/iesfdlr/lab/main/install.sh | bash -s -- /dev/sda` (reemplaza `/dev/sda` por el disco duro que corresponda)
4. sigue las instrucciones en pantalla — el instalador pedirá las credenciales de Andared automáticamente y también te dará la opción de cambiar la contraseña de `root`. Pulsa Enter sin escribir nada para omitir cualquiera de esos pasos.

Para máquinas que no necesitan `Andared_Corporativo`, pasa `--no-andared` para omitir el mensaje directamente:

```
curl -fsSL ... | bash -s -- /dev/sda --no-andared
```

También es posible pasar las credenciales por línea de comandos para automatizar instalaciones (ojo: queda visible en el historial del shell):

```
curl -fsSL ... | bash -s -- /dev/sda --andared-username USUARIO --andared-password CLAVE
```

También se puede fijar la contraseña de `root` por línea de comandos para instalaciones automatizadas:

```
curl -fsSL ... | bash -s -- /dev/sda --root-password CLAVE_ROOT
```

## andared_corporativo

El sistema instalado deja preparada una conexión de NetworkManager para `Andared_Corporativo` sin usuario ni contraseña guardados en el repositorio.

- En Plasma, basta con abrir el selector de redes, pulsar `Andared_Corporativo` e introducir las credenciales del usuario.
- Alternativamente, desde terminal se puede usar `andared-connect` para que `nmcli` pida las credenciales de forma interactiva.
- Si `TTLS` no funciona en un centro concreto, prueba `andared-connect peap`.

## actualizaciones

- Se puede seguir lanzando la actualización manual con `su -c /etc/nixos/update.sh`. El script ahora guarda un registro en `/var/log/lab-updates` y envía la notificación final a la sesión activa de KDE.
- En el menú de aplicaciones de Plasma aparece `Actualizaciones de la distribución`.
- Si ya hay una actualización en marcha, el lanzador se engancha automáticamente a su registro activo.
- Si no hay ninguna en curso, el lanzador permite iniciar una nueva actualización y seguir el registro, ver el último registro o abrir la carpeta con el historial.

## instalar programas manualmente

La configuración habilita `Flatpak` a nivel de sistema y deja `Flathub` configurado automáticamente en el arranque. En Plasma, eso hace que `Discover` quede disponible como tienda gráfica para instalar aplicaciones sin tocar la configuración declarativa.

- El usuario `usuario` puede abrir `Discover`, buscar una aplicación y pulsar `Instalar`.
- Las aplicaciones instaladas así quedan fuera de NixOS declarativo: son cómodas para alumnado o personal no técnico, pero no quedan reflejadas en `configuration.nix`.
- Si se quiere revisar lo instalado por esa vía, se puede usar `flatpak list` o abrir la pestaña de instaladas en `Discover`.
