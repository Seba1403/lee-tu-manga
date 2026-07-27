# Lee tu manga

Lector de manga/cómics personal y self-hosted. Lee tomos `.cbz` y `.cbr` desde una carpeta local.

## Estructura de la biblioteca

Una carpeta por serie, con los tomos adentro. El nombre de la carpeta es el título que se muestra:

```
mangas/
  Magi/
    Magi 01.cbz
    Magi 02.cbz
  One Piece/
    One Piece 01.cbz
    One Piece 02.cbz
    ...
```

## Uso local

```
MANGA_LIBRARY_PATH=/ruta/a/tus/mangas bin/setup
```

Abrí http://localhost:3000, iniciá sesión y tocá "Actualizar biblioteca" para escanear esa carpeta.

## Desplegar con Docker

La imagen se publica sola en GHCR (`ghcr.io/<usuario>/lee-tu-manga:latest`) vía GitHub Actions cada vez que se pushea a `main`. Para levantarla en un servidor (Raspberry Pi u otro):

1. Crear una carpeta para el stack con esta estructura:

   ```
   lee-tu-manga-stack/
     docker-compose.yml  (el de este repo)
     .env                (copiar de .env.example y completar, no se commitea)
     mangas/             tu biblioteca (ver estructura arriba)
     storage/            se crea sola: base de datos SQLite + portadas generadas
     backups/            opcional, ver script/backup_database.sh
   ```

2. En `docker-compose.yml`, reemplazar `<tu-usuario-github>` por el usuario/organización real de GitHub.

3. Completar `.env` (plantilla en `.env.example`):
   - `SECRET_KEY_BASE`: generar con `bin/rails secret`
   - `APP_PORT`: puerto donde va a quedar escuchando la app (por defecto 3050)
   - `OWNER_USERNAME` / `OWNER_PASSWORD`: el único usuario que puede iniciar sesión (protege "Actualizar biblioteca" y el progreso de lectura; **leer manga nunca requiere login**). Tienen que estar completos antes del primer arranque: se crean solos leyendo estas variables la primera vez que levanta el contenedor, y no se vuelven a aplicar automáticamente después. Para cambiar la contraseña más adelante: editar acá y correr `docker compose exec web bin/rails db:seed`.

4. Levantar:

   ```
   docker compose up -d
   ```

5. Entrar a `http://<ip-del-servidor>:APP_PORT`, iniciar sesión y tocar "Actualizar biblioteca" para indexar `mangas/` la primera vez. Después se reindexa sola cada 3 horas, y también manualmente con ese mismo botón.

6. La app solo escucha en ese puerto, sin nada de TLS/dominio propio. Exponerla afuera de tu red (dominio, HTTPS) es responsabilidad de lo que pongas delante — Cloudflare Tunnel, un reverse proxy, etc. — apuntando a `APP_PORT`.

Para actualizar a la última imagen:

```
docker compose pull && docker compose up -d
```

### Backups

`storage/` es lo único que no se puede regenerar (progreso de lectura, usuario, portadas). `script/backup_database.sh` hace un backup consistente de la base con `sqlite3 .backup`, dejando copias en `backups/daily/` y `backups/last/`.
