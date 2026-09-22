# Evolution API local (pruebas gratuitas)

```bash
cp .env.example .env
# Cambia AUTHENTICATION_API_KEY por una clave local larga
docker compose up -d
curl http://localhost:8080
```

Esta instalación usa el DNS actual de Docker y del equipo; no fije una IP de una red Wi-Fi anterior.
Es para pruebas: la computadora debe permanecer encendida. Para que Supabase pueda
llamar a Evolution API necesitaremos un túnel público temporal (Cloudflare Tunnel).

## Túnel Cloudflare temporal

Desde esta carpeta, con Evolution API ya levantado, ejecute:

```bash
docker rm -f dental-cloudflared 2>/dev/null || true
docker run -d --name dental-cloudflared --restart unless-stopped --network host \
  cloudflare/cloudflared:latest tunnel --no-autoupdate --url http://127.0.0.1:8080
docker logs dental-cloudflared 2>&1 | grep -A2 'quick Tunnel has been created'
```

Copie la URL `https://...trycloudflare.com` que aparece en los logs y actualice el secreto remoto:

```bash
npx supabase secrets set EVOLUTION_API_URL=https://<URL_DEL_TUNEL>
```

La URL cambia cada vez que se crea un Quick Tunnel. Para producción use un túnel nombrado con dominio
propio; este túnel temporal solo sirve para pruebas y requiere mantener el equipo encendido.
