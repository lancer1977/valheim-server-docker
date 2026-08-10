# QA Runbook — valheim-server-docker

The shared procedure lives in the project hub and is the canonical copy:

**`~/projects/game-runtimes/docs/QA-RUNBOOK.md`**

It covers image-digest verification, the deploy/teardown checks, save
persistence, idempotent re-apply, and the physical-host smoke checklist for
every runtime in the hub. Do not fork the procedure into this file — update
the canonical copy instead.

## Values for this repo

| | |
| --- | --- |
| Image | `ghcr.io/lancer1977/valheim-server-docker` |
| Deploy branch | `dev` (this fork has no `main`) |
| Publishing workflow | `.github/workflows/docker-build.yml` |
| Stack (prod) | `alienware/valheim8`, also `r620/valheim8` |
| Stack (dev) | `alienware/valheim8-dev` |
| Game container | `valheim-server` |
| Sidecar | `valheim8-wg` |
| Host data | `/home/lancer1977/game_servers/valheim8` |
| Player ports | `2456-2457/udp` |

## Repo-specific notes

- `latest` is produced from **`dev`**. It was previously gated on
  `refs/heads/main`, a branch that does not exist here, so the tag the stack
  deploys could never be built.
- The three-leg test matrix (`default`, `valheim_plus`, `bepinex`) gates the
  publish job. A green matrix is a build gate, not a deploy proof.
- The pushed digest is printed to the workflow run summary — use it for
  step 1.1 of the canonical runbook.
