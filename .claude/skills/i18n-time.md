# Skill: i18n and Time

1. Manage user-facing text by message keys, not hardcoded display strings.
2. Keep error codes and internal identifiers language-neutral and stable.
3. Decide locale at the Presentation boundary from user preference, organization/region, request metadata, or system default.
4. Keep Domain and Application logic independent from a specific display language.
5. Store and exchange timestamps in UTC.
6. Convert UTC to the user's region/time zone only at UI or output-format boundaries.
7. Include time zone and locale cases in tests when behavior depends on display formatting.
