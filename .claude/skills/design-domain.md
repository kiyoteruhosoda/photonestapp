# Skill: Design Domain

1. Identify domain terms and invariants.
2. Use Entities for identity-bearing concepts.
3. Use Value Objects for immutable descriptive values.
4. Use Domain Services only when behavior does not belong to one entity.
5. Define Repository or Gateway interfaces in the Domain when persistence or external access is needed.
6. Express variant behavior with polymorphic interfaces or explicit sum types/enums.
7. Keep framework, database, network, and UI concerns out of Domain.
