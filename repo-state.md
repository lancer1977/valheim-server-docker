# Repo State

- Primary working branch: `dev`
- Runtime: Docker image for Valheim dedicated server
- Fast validation: `./scripts/validate.sh`
- Full image workflow: `.github/workflows/docker-build.yml`
- Lightweight validation workflow: `.github/workflows/validate.yml`

## Current Stewardship Notes

- `scripts/validate.sh` covers Go and Python helper tests.
- The Docker workflow builds and tests the image matrix before publishing.
- `valheim.env.example` is the runtime configuration template; `.env.example` only documents local validation defaults.
