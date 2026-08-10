# SID Engineering Charter

SID — Selection & Inventory Discovery

This document defines the engineering principles that govern the development of SID.

These rules apply to the MVP as well as to later development. They are intended to
keep the system understandable, secure, maintainable, multilingual, and extensible.

When an implementation problem conflicts with one of these rules, the rule must not
be silently bypassed. The conflict should be identified explicitly and the
architecture or rule reconsidered deliberately.


## 1. Architecture Rule

Domain logic must remain independent of concrete external systems.

Catalogue APIs, currency services, document parsers, OCR engines, language models,
storage systems, and other external services must be accessed through explicit
interfaces, behaviours, or adapters.

The core SID domain must not depend directly on a particular catalogue, vendor,
file format, or AI provider.


## 2. Change Discipline Rule

Agreed architectural boundaries must not be bypassed silently.

If implementation reveals that an architectural decision is flawed, insufficient,
or unnecessarily restrictive, the issue must be surfaced explicitly.

The design may then be changed deliberately and documented before implementation
continues.


## 3. Code Quality Rule

Prefer simple, explicit, idiomatic Elixir over clever abstractions.

Code should optimize first for:

1. correctness,
2. readability,
3. maintainability,
4. testability,
5. performance where relevant.

New abstractions must solve a demonstrated problem. They should not be introduced
solely in anticipation of hypothetical future requirements.


## 4. Documentation Rule

All production code must be documented in English.

Public modules and functions should use `@moduledoc`, `@doc`, and typespecs where
they improve understanding.

Comments must primarily explain:

- intent,
- assumptions,
- domain reasoning,
- architectural boundaries,
- security considerations,
- non-obvious behavior.

Comments should not merely restate what the code already says syntactically.

Complex architectural decisions should additionally be documented under `docs/`.


## 5. Testing Rule

Every meaningful domain rule must be covered by automated tests.

Tests should cover:

- normal behavior,
- boundary conditions,
- invalid input,
- failure states,
- relevant Unicode and multiscript cases.

Bug fixes must include a regression test whenever reasonably possible.


## 6. Security Testing Rule

Security-sensitive surfaces must be covered by dedicated automated tests from the
MVP onward.

Uploaded documents and all data received from external systems must be treated as
untrusted input.

Security tests should be added whenever relevant for risks including:

- malicious file uploads,
- file-type spoofing,
- oversized files,
- decompression bombs,
- malformed documents,
- path traversal,
- CSV and spreadsheet formula injection,
- XML-related attacks,
- SSRF,
- injection attacks,
- resource exhaustion,
- unsafe Unicode handling,
- authorization bypasses,
- malicious LLM output,
- prompt injection contained in imported documents.

Every discovered security defect should receive a permanent regression test.


## 7. Data Integrity Rule

Original imported data must never be silently destroyed or overwritten.

Where provenance matters, SID must preserve the distinction between:

- original source data,
- parsed data,
- normalized data,
- manually corrected data,
- externally retrieved data,
- derived data.

SID should make it possible to understand where important bibliographic information
came from.


## 8. Migration Rule

Database migrations must preserve existing data and remain forward-safe.

Destructive schema changes require an explicit migration strategy.

Data migrations must not be hidden inside ordinary application logic.


## 9. Domain Modeling Rule

Business states must be represented explicitly.

Distinct states must not be collapsed into overloaded booleans or inferred from
unrelated fields.

For example, catalogue results such as:

- exact edition found,
- older edition found,
- ambiguous match,
- not found,
- lookup failed,

represent different domain states and must remain distinguishable.


## 10. Historical State Rule

Time-dependent facts must be recorded historically whenever their history is
relevant.

A later catalogue check must not overwrite the result of the original catalogue
check performed during selection.

This should allow SID to answer questions such as:

- What was known when this title was selected?
- Was the title absent from the catalogue at that time?
- When did a matching catalogue record later appear?


## 11. External API Rule

External APIs are unreliable by definition.

Every integration must define appropriate behavior for:

- connection timeouts,
- response timeouts,
- rate limits,
- retries,
- malformed responses,
- unavailable services,
- authentication failures,
- unexpected response formats.

An external service failure must never be interpreted as a valid negative result.

In particular:

    catalogue unavailable != title not held


## 12. Catalogue Independence Rule

SID must remain catalogue-agnostic.

No catalogue-specific identifier, query language, field name, record structure, or
response format may leak into the core domain.

Catalogue integrations must be implemented through provider adapters.

For example:

    SID Catalogue Domain
             |
             +-- StabiKat Provider
             +-- SRU Provider
             +-- K10plus Provider
             +-- Other Provider

Providers normalize external records into SID's internal catalogue representation.

The matching engine operates on that internal representation rather than directly
on external API responses.


## 13. Parser Boundary Rule

Document parsers are responsible for extracting and normalizing information.

They must not make acquisition decisions.

Python components, OCR systems, language models, or other parsing services must not
contain catalogue or ordering business logic.

The Elixir application remains authoritative for SID domain decisions.


## 14. LLM Safety Rule

Language-model output must always be treated as untrusted input.

LLM output must conform to an explicit structured schema and must be validated
before entering the SID domain.

Language models must never directly:

- trigger external actions,
- place orders,
- determine authoritative catalogue state,
- modify acquisition plans,
- bypass validation.

Text contained in imported documents must never be treated as trusted instructions
for a language model or for SID itself.


## 15. Determinism Rule

Deterministic methods take precedence over probabilistic methods wherever they are
sufficiently reliable.

For example, a valid ISBN extracted directly from a structured spreadsheet should
not require an LLM interpretation step.

Language models should be used where ambiguity genuinely requires linguistic
interpretation, not as the default solution to structured problems.


## 16. Unicode Rule

SID is Unicode- and multiscript-native from the first release.

No application code may assume:

- Latin script,
- ASCII,
- Western personal-name order,
- whitespace-delimited writing systems,
- a single representation of a title or author name.

Original script must be preserved.

Transliteration, romanization, normalization, and alternative representations must
remain separate from the original value.


## 17. Normalization Rule

Normalization must be additive or reversible wherever bibliographic meaning could
otherwise be lost.

Original and normalized representations must not be conflated.

Normalization performed for matching must not silently alter the bibliographic
record shown to the user.


## 18. Money Rule

Monetary values must use decimal arithmetic.

Binary floating-point values must not be used for prices, budgets, totals, or
currency conversion.

Where currency conversion occurs, SID should preserve relevant information such as:

- original amount,
- original currency,
- conversion rate,
- conversion date,
- converted amount,
- budget currency.


## 19. Unknown Value Rule

Unknown, unavailable, zero, false, and failed are different states.

Missing information must never be represented using misleading defaults.

Examples:

    missing price != price of 0
    catalogue failure != title not found
    unknown edition != first edition
    missing ISBN != invalid ISBN


## 20. Background Job Rule

Long-running, retryable, or failure-prone operations should be performed as
resumable background jobs where appropriate.

Jobs should be idempotent whenever practical.

Retrying a job must not accidentally create duplicate domain records or repeat
irreversible actions.


## 21. Observability Rule

Important processing steps and failures must be observable.

Logs should contain:

- stable identifiers,
- relevant operation names,
- actionable error context.

Logs must not unnecessarily contain:

- document contents,
- credentials,
- secrets,
- sensitive user information.


## 22. Privacy Rule

SID should store only data required for its function.

Uploaded documents, user data, logs, bibliographic information, and model inputs
must not be sent to third parties unless that behavior is explicitly configured
and understood.

Local processing should remain possible where technically appropriate.


## 23. File Handling Rule

Uploaded files must be treated as hostile input until validated.

SID must constrain and validate relevant properties including:

- file size,
- detected file type,
- filename handling,
- archive expansion,
- document structure,
- parser resource consumption.

A filename supplied by a user must never determine an unrestricted filesystem path.


## 24. Export Safety Rule

Generated CSV and spreadsheet exports must be safe to open in common office
software.

User-controlled values capable of triggering spreadsheet formulas must be
neutralized appropriately.

Exported values must preserve Unicode correctly.


## 25. Authorization Rule

When multi-user functionality is introduced, authorization must be enforced in the
application/domain layer as well as in the UI.

Hiding a button is never an access-control mechanism.

Every operation that modifies or exposes protected data must independently enforce
the appropriate authorization rule.


## 26. Accessibility Rule

Meaningful UI state must never be communicated through color alone.

For example, catalogue states shown using green, red, or other colors must also use
text, icons, labels, or other accessible indicators.

The interface should remain keyboard- and screen-reader-friendly where practical.


## 27. Dependency Rule

Prefer mature, maintained dependencies with clear ownership and acceptable
licensing.

Every new dependency adds operational and security surface.

A dependency should therefore solve a meaningful problem that is not better handled
using the existing platform or standard library.


## 28. Configuration Rule

Environment-specific values belong in configuration rather than business logic.

Examples include:

- database credentials,
- catalogue endpoints,
- API credentials,
- timeout values,
- upload limits,
- enabled catalogue providers,
- model endpoints.

Development defaults may be provided for non-sensitive values where appropriate.


## 29. Secrets Rule

Secrets must never be committed to source control.

Secrets must also never appear in:

- fixtures,
- logs,
- generated exports,
- screenshots committed to the repository,
- documentation examples.

Local secrets should be provided through environment variables or another explicit
secret-management mechanism.


## 30. Performance Rule

Optimize after measuring, but design bulk workflows responsibly from the beginning.

A large import must not be able to monopolize the application or unintentionally
overwhelm an external catalogue service.

Bulk operations should support controlled concurrency, batching, and rate limiting
where appropriate.


## 31. Extension Safety Rule

MVP decisions must preserve the extension paths that have already been identified
for SID unless we consciously decide otherwise.

These include:

- additional library catalogue providers,
- multiple catalogue providers,
- collaborative order planning,
- multiple users and authorization,
- repeated catalogue checks,
- acquisition follow-up,
- acquisition-system integrations,
- additional document formats,
- alternative parsers,
- OCR,
- local language models,
- alternative model runtimes,
- multilingual and multiscript metadata,
- multiple currencies.

The MVP does not need to implement these features, but it should avoid architectural
decisions that make them unnecessarily difficult later.


## 32. Scope Rule

The MVP should implement the smallest coherent vertical workflow that provides
real value.

Temporary shortcuts are acceptable only when they do not violate important
architectural boundaries or compromise future data integrity.

"We will replace this later" is not sufficient justification for introducing a
known structural problem.


## 33. Review Rule

Before a major feature is considered complete, it should be reviewed against:

- domain correctness,
- automated tests,
- security,
- failure behavior,
- data integrity,
- Unicode and multiscript behavior,
- accessibility where relevant,
- observability,
- extension safety.

A feature is not complete merely because its happy path works.
