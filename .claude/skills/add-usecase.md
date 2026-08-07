# Skill: Add UseCase

1. Name the use case as one business operation: `<Verb><Noun>`.
2. Define input/output DTOs when crossing layer boundaries.
3. Inject Domain interfaces through the constructor.
4. Keep orchestration in Application; keep rules in Domain.
5. Return results/errors that Presentation can map without knowing Infrastructure details.
6. Add tests for success, expected domain errors, and unexpected adapter failures.
