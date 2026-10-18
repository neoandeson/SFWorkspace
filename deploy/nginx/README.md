# Host nginx samples

Canonical VPS vhosts live in [`docs/examples/nginx-host-app-api.conf`](../../docs/examples/nginx-host-app-api.conf) (matches `SFBE/docker-compose.prod.yml` ports `3001`/`3002`).

Optional split files in this folder (`sf-app.conf`, `sf-api.conf`) are the same layout as separate site files under `/etc/nginx/sites-available/`.

After copy:

```bash
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d app.example.com -d api.example.com
```

**Blob / uploads:** Azure Blob was removed with the Restaurant legacy module (Phase E). Keep `client_max_body_size` aligned between host nginx and the FE image `SFFE/nginx.conf` if you add uploads later.
