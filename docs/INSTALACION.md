# Instalación paso a paso (Windows)

Solo hay que hacerlo una vez. Si algo falla, copia el mensaje de error en el chat.

## 1. Git
1. Descarga e instala Git: https://git-scm.com/download/win (opciones por defecto).
2. Abre **PowerShell** y escribe `git --version` para comprobarlo.

## 2. Descargar el proyecto
```powershell
cd $HOME\Documents
git clone https://github.com/migalp090-arch/Roblox-claude.git
cd Roblox-claude
```

## 3. Rokit (instala Rojo y las demás herramientas)
1. Descarga `rokit-...-windows-x86_64.zip` desde https://github.com/rojo-rbx/rokit/releases (la versión más reciente).
2. Descomprímelo, abre PowerShell en esa carpeta y ejecuta: `.\rokit.exe self-install`
3. **Cierra y vuelve a abrir PowerShell**, vuelve a la carpeta del proyecto y ejecuta:
```powershell
rokit install
rojo --version
```

## 4. Plugin de Rojo en Studio
```powershell
rojo plugin install
```
Abre (o reinicia) Roblox Studio: verás la pestaña/botón **Rojo** en la barra de Plugins.

## 5. Editor de código (recomendado)
1. Instala **Visual Studio Code**: https://code.visualstudio.com
2. Abre la carpeta `Roblox-claude` en VS Code. Te pedirá instalar las extensiones recomendadas: acepta.

## 6. Conectar el código con Studio (cada vez que trabajes)
1. En PowerShell, dentro de la carpeta del proyecto: `rojo serve`
   (déjalo abierto; debe decir que escucha en el puerto 34872).
2. En Studio abre tu juego (o uno nuevo con la plantilla **Baseplate**).
3. Pulsa **Rojo → Connect**. El código aparecerá en `ServerScriptService.Server`, `ReplicatedStorage.Shared` y `StarterPlayerScripts.Client`.
4. Desde ahora, los cambios en los archivos se copian solos a Studio. **No edites esos scripts dentro de Studio**: se sobrescriben.

## 7. Comprobar que funciona
1. Pulsa **Play** en Studio.
2. En la ventana **Output** no debe haber errores rojos. Si el juego no está publicado verás un aviso amarillo de DataService: es normal (usa datos temporales).
3. Para probar el guardado de verdad: publica el juego (File → Publish to Roblox) y activa
   **Game Settings → Security → Enable Studio Access to API Services**.

## 8. Guardar tu trabajo en GitHub
```powershell
git pull            # trae los cambios que haya subido Claude
git add .
git commit -m "Describe el cambio"
git push
```
