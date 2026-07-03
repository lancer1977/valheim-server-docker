# valheim-server-docker

`valheim-server-docker` builds a Docker image for running a Valheim dedicated server with update, backup, status, and mod-support helpers.

## Repository Layout

- `Dockerfile` builds the runtime image.
- `valheim-*`, `bootstrap`, `common`, and `defaults` contain runtime scripts and configuration defaults.
- `valheim-logfilter/` contains the Go log filter utility.
- `env2cfg/` contains the Python environment-to-config helper.
- `docker-compose.yaml`, `valheim.nomad`, and `valheim.service` provide deployment examples.
- `scripts/validate.sh` runs the fast local validation path.

## Validation

```bash
./scripts/validate.sh
```

The full Docker image build and container test matrix runs in `.github/workflows/docker-build.yml`.
