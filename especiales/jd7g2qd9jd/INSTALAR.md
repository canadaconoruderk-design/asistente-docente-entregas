# Activar las actualizaciones automáticas (instrucciones para el agente)

Esto es para vos, el agente. Seguilo al pie de la letra. La maestra no tiene que hacer nada técnico.

**Qué no se toca:**
- sus documentos;
- su bibliografía;
- lo ya escrito en `REGISTRO.md`;
- sus carpetas de solo lectura.

Solo se actualizan las reglas y las skills, y antes se guarda una copia.

## 1. Avisarle

Decíselo en una línea: *"Me estoy actualizando, tardo unos minutos. No tenés que hacer nada."*

## 2. Guardar la llave

- **RAIZ** es la carpeta raíz de este proyecto, la que tiene `AGENTS.md`.
- **LLAVE** es el código que vino en el mensaje, después de "Llave:".

Creá el archivo `RAIZ\actualizacion\licencia.json` con este contenido exacto, reemplazando solo LLAVE:

```json
{ "id": "jd7g2qd9jd", "secreto": "LLAVE", "repo": "canadaconoruderk-design/asistente-docente-entregas" }
```

Este archivo no se muestra, no se copia a ningún lado y no se borra.

## 3. Instalar la última versión

```powershell
$d = Join-Path $env:TEMP 'act-especial'; New-Item -ItemType Directory -Force $d | Out-Null
[Net.ServicePointManager]::SecurityProtocol = 3072
(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/canadaconoruderk-design/asistente-docente-entregas/main/especiales/jd7g2qd9jd/actualizar.ps1', "$d\actualizar.ps1")
powershell -NoProfile -ExecutionPolicy Bypass -File "$d\actualizar.ps1" -Raiz "RAIZ" -Instalar
```

Tarda de 1 a 5 minutos. Si la terminal corta por tiempo, volvé a leer la salida hasta ver `RESULTADO=`.

- `RESULTADO=OK`: seguí con el paso 4.
- `RESULTADO=YA_ESTABA_ACTUALIZADO`: ya está activado. Seguí con el paso 5.
- `ERROR_NO_HABILITADA` o `ERROR_LLAVE_INVALIDA`: revisá que la llave del paso 2 esté copiada igual que en el mensaje, con los guiones, y probá una vez más.
- Cualquier otro error: probá una vez más. Si sigue, decile que no se pudo, que todo sigue funcionando como antes, y que le avise a quien se lo armó.

## 4. Terminar

Ahora existe la skill `.agents\skills\actualizar\`. Leé su `SKILL.md` y hacé el **paso 4** completo:
- fusionar cada línea `FUSIONAR=`;
- revisar la prueba;
- anotarlo en `REGISTRO.md`;
- contarle lo nuevo;
- reiniciar si hace falta;
- abrir una conversación nueva.

Esta primera vez la actualización es grande. Contale las novedades con tus palabras, mirando qué cambió: las líneas `CAMBIO=` y los archivos nuevos.

## 5. Comprobar

1. Corré `.agents\skills\actualizar\scripts\actualizar.ps1 -Revisar -Forzar`. Tiene que decir `HAY_ACTUALIZACION=0`.
2. Revisá que `AGENTS.md` tenga la regla de **actualizaciones**: en el primer mensaje de cada conversación hay que revisar si hay versión nueva. Si no la tiene, agregala tal como viene en la versión nueva.

Desde ahora las actualizaciones llegan solas: en cada conversación revisás, le avisás y, con su "sí", las instalás vos.
