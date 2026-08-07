# Skill: Configuration

1. Provide safe development defaults so the app can start with minimal setup.
2. Use this precedence unless the project defines otherwise: built-in defaults -> env file -> environment variables -> persistent/manual settings -> automated migration/seed values.
3. Access settings through a configuration module/service, not scattered raw reads.
4. Document operator-facing keys in `docs/OPERATIONS.md`.
5. Log effective non-secret settings at startup; never log secrets.
