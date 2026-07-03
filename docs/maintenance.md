# Maintenance

## Validation Contract

Use `./scripts/validate.sh` for routine local validation.

The script verifies:

- `valheim-logfilter` Go tests
- `env2cfg` Python tests

The Docker image workflow performs the heavier container build and runtime checks.

## Dependency Notes

Go dependencies are tracked under `valheim-logfilter/go.mod` and `go.sum`.

Before dependency maintenance, run:

```bash
cd valheim-logfilter
go list -m -u all
```

Python helper dependencies are managed by `env2cfg/setup.py`, `setup.cfg`, and `tox.ini`.

## Release Notes

Image publishing happens through `.github/workflows/docker-build.yml`. Keep GHCR/Docker Hub credentials out of local files and repository content.

Do not commit generated worlds, backups, local env files, webhook URLs, or Steam credentials.
