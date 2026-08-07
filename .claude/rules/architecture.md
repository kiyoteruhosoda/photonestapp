# Architecture Rules

- Keep dependencies directed inward: Presentation -> Application -> Domain; Infrastructure implements Domain interfaces.
- Domain must not depend on UI, framework, database, network, or serialization details.
- Application coordinates use cases and transactions; it must not contain UI or infrastructure details.
- Infrastructure contains adapters for external systems and must not contain business rules.
- Presentation handles input/output only and calls Application use cases.
- Prefer explicit interfaces, constructor injection, composition, and polymorphism over concrete coupling.
- Avoid vague names such as `Helper`, `Util`, `Manager`, and `Common` when a domain name exists.
