# Skill: Create PR

1. Review `git status` and `git diff`.
2. Run the quality gate: `./scripts/ci.sh`. It is the same script CI runs, so
   a green run here means a green run there. Use `--fast` to skip the APK
   build while iterating, but run it in full before opening the PR.
3. Commit only intended files with `<type>(<scope>): <summary>`.
4. Prepare the PR body with summary, rationale, and how it was tested.
5. Mention docs or migration impacts when applicable. If the change touches
   layering, configuration, startup, logging, or operations, update the
   matching file under `docs/` in the same PR.
6. If a check in `scripts/ci.sh` had to be relaxed, say so explicitly and
   record the reason in `docs/adr/`. Silently lowering a threshold is worse
   than not having it.
