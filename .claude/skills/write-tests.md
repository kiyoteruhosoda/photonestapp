# Skill: Write Tests

## Where tests live

`test/` mirrors `lib/`. A test for `lib/application/usecases/theme/x.dart`
belongs at `test/application/usecases/theme/x_test.dart`.

Shared test doubles live in `test/support/`:

- `fakes.dart` — in-memory repository fakes. Each records what was written
  (`saved`, `savedLogLevels`, …) and can be told to fail (`failOnSave`).
- `recording_app_logger.dart` — a recording double for the `AppLogger` port.
  Use `reset()` to clear the entries the ViewModels log while wiring up.
- `test_harness.dart` — `pumpInScope` (full `AppScope` + theme + i18n, for
  pages) and `pumpComponent` (theme + i18n only, for leaf widgets), plus
  `RouteRecorder` for asserting navigation.

## What to test

1. Domain: entity state transitions and value-object rejection of invalid
   values. Domain is pure Dart — no Flutter binding needed.
2. Application: every use case, both the success and the failure path.
   Assert on the outbound calls (repository writes, logger calls), not only
   on the return value.
3. Infrastructure: adapters, mappers, migrations. Stub the platform channel
   rather than skipping the test — see
   `test/infrastructure/logging/persistent_app_logger_test.dart`.
4. Presentation: ViewModel state transitions, and widget tests for the
   loading, empty, error and normal states.

## Rules

- Keep time, randomness and external systems injectable. Domain must not call
  `DateTime.now()` — `tool/check_architecture.dart` rejects it.
- A `const` expression is evaluated by the compiler, so its constructor never
  runs under coverage. Build the object at runtime when the constructor is
  what you are testing.
- `pumpAndSettle` never returns while a continuous animation is on screen.
  Pass `settle: false` to `pumpComponent` when a spinner is visible.
- Adding a file under `lib/` means adding an import to
  `test/coverage_surface_test.dart`. The test names the exact line to add.

## Coverage floors

Domain 90%, Application 85%, overall 80%. Enforced by
`dart run tool/check_coverage.dart`; `--verbose` lists the least-covered
files when a floor is missed.

## Before committing

```bash
./scripts/ci.sh --fast
```
