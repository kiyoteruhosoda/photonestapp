# Skill: Add Repository or Gateway

1. Define a narrow Domain interface using Domain types.
2. Keep storage/network types out of the interface.
3. Implement the interface in Infrastructure.
4. Add mappers between external records and Domain models.
5. Add migrations or schema changes only through the project migration mechanism.
6. Register the implementation in DI.
7. Test mapping, persistence behavior, and error translation.
