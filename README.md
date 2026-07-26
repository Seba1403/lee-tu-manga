# Lee tu manga

Lector de manga/cómics personal y self-hosted. Lee tomos `.cbz` desde una carpeta local.

## Uso local

```
MANGA_LIBRARY_PATH=/ruta/a/tus/mangas bin/setup
```

Abrí http://localhost:3000, iniciá sesión y tocá "Actualizar biblioteca" para escanear esa carpeta.

## Despliegue (Raspberry Pi, Docker)

El stack vive en `/opt/stacks/projects/lee-tu-manga-stack/`, con esta carpeta junto al `docker-compose.yml` del repo:

```
lee-tu-manga-stack/
  docker-compose.yml
  .env               (no se commitea, ver .env.example)
  mangas/            tus archivos .cbz
  storage/           base de datos SQLite + portadas generadas
  backups/           backups locales de storage/, ver script/backup_database.sh
```

`docker-compose.yml` monta `mangas/` de solo lectura (la app nunca escribe ahí, solo lee) y `storage/` con permiso de escritura (ahí vive todo lo que no se puede perder: progreso de lectura, usuario, portadas). Si `storage/` se pierde sin backup, se pierde el progreso de lectura.

La imagen se construye sola vía GitHub Actions al pushear a `main` y queda en GHCR. Variables de entorno necesarias (`.env`, plantilla en `.env.example`):

- `SECRET_KEY_BASE`: generar con `bin/rails secret`
- `APP_PORT`: puerto local al que apunta Cloudflare Tunnel
- `OWNER_USERNAME` / `OWNER_PASSWORD`: el único usuario que puede iniciar sesión (protege solo "Actualizar biblioteca"; leer manga no requiere login)

Para levantar o actualizar a la última imagen:

```
docker compose pull && docker compose up -d
```
