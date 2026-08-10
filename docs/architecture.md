# SID Architecture

## Status

Initial architecture for the SID MVP.

This document records the current architectural direction. It is expected to evolve
through explicit decisions as implementation progresses.

Major architectural changes should be deliberate and, where useful, documented as
Architecture Decision Records under `docs/decisions/`.


# 1. Purpose

SID — Selection & Inventory Discovery — is an acquisition-planning application for
libraries.

SID helps library staff process bookseller and vendor offers, identify the
bibliographic works and editions represented by those offers, compare them against
library catalogue holdings, select titles for acquisition, manage acquisition
budgets, and export resulting order lists.

The initial implementation is intended for one library environment, but the
architecture must allow SID to be reused by other libraries without rewriting the
core application.


# 2. Core Workflow

The intended workflow is:

    Acquisition planning
            |
            v
    Order plan
            |
            v
    Order list
            |
            v
    Vendor document import
            |
            v
    Bibliographic extraction
            |
            v
    Bibliographic normalization
            |
            v
    Catalogue lookup
            |
            v
    Matching
            |
            v
    Acquisition decision
            |
            v
    Budget calculation
            |
            v
    Order-list export

Not every stage will be implemented in the first development session.

In particular, document parsing will be designed only after representative real-world
vendor files have been examined.


# 3. Technology

The primary application stack is:

- Elixir
- Phoenix
- Phoenix LiveView
- Ecto
- PostgreSQL

Background processing will use Oban when asynchronous work is introduced.

Elixir/Phoenix owns the authoritative application domain.

Python may later be introduced behind a strict service boundary for document parsing,
OCR, machine-learning, or local language-model workloads where the Python ecosystem
provides a meaningful advantage.

Python must not become a second implementation of SID's business domain.


# 4. Initial Domain Boundaries

The current conceptual architecture contains the following domains:

    SID
    |
    +-- Planning
    |
    +-- Imports
    |
    +-- Bibliography
    |
    +-- Catalogue
    |
    +-- Selection
    |
    +-- Export

Additional boundaries may emerge as implementation progresses.

The boundaries represent responsibilities rather than a requirement that every
domain immediately become a separate OTP application or service.


# 5. Planning Domain

The Planning domain organizes acquisition activity.

The initial hierarchy is:

    OrderPlan
        |
        +-- OrderList
                |
                +-- future imported offers and selections

An `OrderPlan` represents a higher-level acquisition plan.

Example:

    Myanmar Annual Order 2026

Possible properties include:

- name,
- base currency,
- total budget,
- timestamps.

An `OrderList` represents a concrete list belonging to an order plan.

Examples:

    Myanmar 2026-1
    Myanmar 2026-2
    China 2027-1

A single order plan may contain multiple order lists.


# 6. Budget Model

Each order plan has a base currency.

Example:

    Order plan: Myanmar Annual Order 2026
    Base currency: EUR
    Budget: 900.00

Prices may later enter SID in currencies different from the plan's base currency.

SID must therefore distinguish between:

- original price,
- original currency,
- converted price,
- conversion rate,
- conversion date,
- plan base currency.

All monetary calculations use decimal arithmetic.

The dashboard will eventually derive values such as:

    total budget
    selected amount
    remaining budget

Derived totals should normally be calculated from authoritative underlying records
rather than stored redundantly without a clear reason.


# 7. Import Boundary

Vendor documents are external, untrusted input.

Expected formats may include:

- XLSX,
- CSV,
- PDF,
- potentially other formats later.

No assumptions about the actual structure of these files are part of the initial
architecture.

Representative vendor documents must be examined before the parsing architecture is
specified in detail.

An import should eventually be associated with an `OrderList`.

Conceptually:

    OrderPlan
        |
        +-- OrderList
                |
                +-- ImportBatch
                        |
                        +-- extracted offers

The exact `ImportBatch` and offer schemas will be designed after real input examples
have been studied.


# 8. Bibliographic Boundary

SID must distinguish vendor-provided information from SID's interpreted
bibliographic representation.

Potential bibliographic information includes:

- title,
- alternative title representations,
- contributors,
- ISBN and other identifiers,
- publisher,
- publication year,
- edition,
- language,
- material type.

The internal model must support multiple representations where appropriate.

Original source values must remain available when normalization or interpretation
takes place.


# 9. Unicode and Multiscript Architecture

Unicode and multiscript support are foundational requirements rather than later
internationalization features.

SID must correctly preserve and process bibliographic information written in, among
others:

- Latin scripts,
- Cyrillic,
- Greek,
- Arabic-derived scripts,
- Hebrew,
- Devanagari and other Indic scripts,
- Tibetan,
- Myanmar scripts,
- Thai,
- Khmer,
- Chinese characters,
- Japanese scripts,
- Korean Hangul.

The architecture must not assume that:

- names use Western given-name/family-name order,
- words are separated by spaces,
- every title has a useful Latin transliteration,
- a romanized title is more authoritative than the original title.

Where both original-script and transliterated values exist, they must remain
distinguishable.


# 10. Catalogue Boundary

SID must not depend directly on StabiKat.

The core application interacts with a catalogue provider abstraction.

Conceptually:

    SID Catalogue Domain
              |
              v
      Catalogue.Provider
              |
       +------+------+
       |             |
       v             v
    StabiKat      Future Provider

A provider is responsible for:

1. translating SID search requests into the external catalogue's query mechanism,
2. calling the external service,
3. validating its response,
4. translating records into SID's internal catalogue representation,
5. reporting failures explicitly.

The provider is not responsible for acquisition decisions.


# 11. Catalogue Provider Behaviour

The exact behaviour will be finalized during implementation, but conceptually a
provider should expose operations such as:

    search(candidate)

and return normalized catalogue records or an explicit error.

For example:

    {:ok, catalogue_records}

or:

    {:error, reason}

An empty successful result and a failed request must never be represented by the
same value.


# 12. Catalogue Record

External catalogue records are normalized before they reach the matching domain.

A conceptual internal record may contain:

    CatalogueRecord
      provider
      external_id
      titles
      contributors
      identifiers
      publisher
      publication_year
      edition
      languages
      material_type
      raw_record_reference

This model is intentionally independent of MARC, MARCXML, MODS, SRU, JSON APIs, or
other external representations.

The exact schema will be refined when the first catalogue provider is implemented.


# 13. Catalogue Matching

Catalogue retrieval and bibliographic matching are separate responsibilities.

A catalogue provider answers:

    "Which potentially relevant catalogue records can I retrieve?"

The SID matching domain answers:

    "What do these records mean for this acquisition candidate?"

Expected matching states include at least:

    exact_edition
    older_edition
    ambiguous
    not_found
    failed

Additional states may be introduced if real catalogue data demonstrates that they
are necessary.

A title may therefore be considered already represented in the collection even when
the catalogue contains an older edition, while SID still preserves the distinction
between an exact edition and an older edition.


# 14. Historical Catalogue Checks

Catalogue results are time-dependent facts.

SID should preserve catalogue checks historically rather than treating the current
catalogue result as the only truth.

Conceptually:

    Acquisition candidate
        |
        +-- CatalogueCheck
        |
        +-- CatalogueCheck
        |
        +-- CatalogueCheck

This supports future workflows in which SID can determine that a title:

1. was absent when selected for acquisition,
2. was ordered,
3. later appeared in the catalogue.

The MVP does not need to implement automated follow-up checks, but its data model
must not make them difficult to add.


# 15. Acquisition Follow-Up

A later SID version may re-check selected or ordered titles against configured
catalogue providers.

Initial follow-up semantics should remain conservative.

For example:

    now present in catalogue
    still not found
    ambiguous
    lookup failed

A later catalogue match must not automatically be interpreted as proof that SID's
specific order was successfully delivered.

True acquisition states such as:

    ordered
    received
    cancelled
    catalogued

may eventually require information from users or from an external acquisition
system.

The architecture must preserve this distinction.


# 16. Parser Architecture

Parsing is intentionally not specified in detail yet.

SID should prefer deterministic extraction when reliable structured information is
available.

A future parsing pipeline may conceptually look like:

    source document
          |
          v
    deterministic parser
          |
          +-- sufficient result --> validation
          |
          +-- ambiguous result
                    |
                    v
              OCR / language model
                    |
                    v
                 validation
                    |
                    v
          bibliographic candidate

Language models are therefore optional interpretation components rather than
authoritative domain engines.


# 17. Language Models

If language models are introduced, SID should support local models where practical.

A model receives constrained input and must return structured output matching an
explicit schema.

Model output is treated as untrusted.

The model must not:

- call catalogue services directly,
- make authoritative acquisition decisions,
- modify budgets,
- place orders,
- bypass application validation.

This boundary allows model implementations to change without affecting SID's core
domain.


# 18. Background Processing

Potential background operations include:

- large document imports,
- OCR,
- language-model processing,
- catalogue lookups,
- repeated catalogue checks,
- batch currency conversion,
- later acquisition follow-up.

These operations should use resumable, retryable jobs where appropriate.

Oban is the intended job-processing mechanism.

Background jobs must respect catalogue rate limits and should be idempotent wherever
practical.


# 19. Dashboard

The MVP includes a small acquisition-planning dashboard.

The initial dashboard should allow users to work with order plans and their order
lists.

A conceptual view might be:

    Myanmar Annual Order 2026

    Budget              900.00 EUR
    Selected              0.00 EUR
    Remaining           900.00 EUR

    Order Lists
    --------------------------------
    Myanmar 2026-1
    Myanmar 2026-2

As acquisition items are introduced, the dashboard can derive selected and remaining
amounts from the underlying selections.

Color must not be the sole representation of state.


# 20. Multi-User Extension

The MVP does not initially require collaborative editing.

However, the architecture should allow later introduction of:

- users,
- organizations or library contexts if needed,
- ownership,
- membership,
- permissions,
- concurrent work on order plans,
- audit information.

Authorization must be enforced below the UI layer when introduced.

The MVP should avoid assumptions such as "there can only ever be one user" in domain
structures where that assumption would later require destructive redesign.


# 21. Extension Strategy

The initial architecture explicitly aims to preserve the following extension paths:

    SID
    |
    +-- additional catalogue providers
    |
    +-- additional vendor formats
    |
    +-- additional parser implementations
    |
    +-- OCR
    |
    +-- local or remote language models
    |
    +-- multiple currencies
    |
    +-- collaborative planning
    |
    +-- acquisition follow-up
    |
    +-- acquisition-system integrations
    |
    +-- additional exports

These capabilities should be enabled through explicit boundaries rather than
implemented prematurely.


# 22. MVP Boundary

The MVP is intended to establish a coherent workflow around:

    order planning
        ->
    order lists
        ->
    vendor imports
        ->
    bibliographic identification
        ->
    catalogue checking
        ->
    selection
        ->
    budget management
        ->
    export

The first development phase intentionally begins with the parts that do not depend
on representative vendor files:

- project foundation,
- planning domain,
- order plans,
- order lists,
- budget rules,
- dashboard,
- catalogue abstraction,
- tests,
- security foundations.

Import parsing will be designed after representative vendor documents are available.


# 23. Architectural Principle

SID should be small before it is large, but open before it is extended.

The MVP should not implement speculative functionality.

At the same time, early implementation decisions must avoid unnecessarily coupling
the system to:

- one library,
- one catalogue,
- one vendor,
- one file format,
- one language,
- one writing system,
- one currency,
- one parser,
- one language model,
- one user.

When those goals conflict, the trade-off should be made explicit and documented.
