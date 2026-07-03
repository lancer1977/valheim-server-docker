# Agent Notes

## Purpose

This repository builds and documents a Docker image for running a Valheim dedicated server with update, backup, status, log filtering, BepInEx, and ValheimPlus support.

## Validation

Run the fast local validation path before handoff:

```bash
./scripts/validate.sh
```

The script runs `go test ./...` for `valheim-logfilter` and the `env2cfg` Python tests. The full GitHub workflow also builds and exercises the Docker image.

## Stewardship

- Keep user-facing runtime behavior documented in `README.md`.
- Keep deployment examples aligned with `docker-compose.yaml`, `valheim.env.example`, and `valheim.nomad`.
- Do not commit server worlds, backups, tokens, Discord webhooks, Steam credentials, or local `valheim.env` files.
- Treat Docker image publishing as a separate release path; local validation should stay fast enough for routine maintenance.
