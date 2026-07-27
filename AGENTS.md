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

<!-- dev-forge:low-interruption:start version=1 -->
## Low-Interruption Execution

- Treat explicit outcome requests such as "fix," "build," "complete," and
  "finish" as continuing authorization for bounded work toward that outcome.
- Continue through diagnosis, implementation, tests, commits, pushes, review
  feedback, and CI repair without renewed confirmation.
- New defects discovered within the same task or pull request remain in scope
  when the repair is reversible, clearly supported, and consistent with the
  existing architecture.
- Progress updates are informational and do not pause execution.
- Do not request confirmation when the only realistic alternatives are the
  clearly supported action and inaction.
- Use a blocking checkpoint only at a genuine impasse. Present two or three
  materially different choices as **A**, **B**, and optionally **C**; recommend
  one and ask for a one-letter reply.
- Do not use "Done — continue" as a generic permission gate.
- Preserve explicit approval boundaries for merge, deploy, destructive work,
  secret or access changes, material cost, external communication, and credible
  downtime or data-loss risk.
<!-- dev-forge:low-interruption:end -->
