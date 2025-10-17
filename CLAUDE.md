# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AshPhoenixTranslations is an Ash Framework extension that provides policy-aware translation capabilities for Phoenix applications with multi-backend support. The project enables seamless integration of translation functionality into Ash resources with support for multiple storage backends, lazy-loading, and LiveView integration.

## Commands

### Development Commands
```bash
# Install dependencies
mix deps.get
mix deps.compile

# Run tests
mix test                           # Run all tests
mix test test/cache_test.exs      # Run specific test file
mix test test/cache_test.exs:42   # Run specific test at line
mix test --failed                  # Run previously failed tests
mix test --trace                   # Run with detailed trace

# Interactive console
iex -S mix

# Format code
mix format                         # Format all files
mix format --check-formatted       # Check formatting without changing

# Quality checks
mix credo --strict                 # Run Credo linter
mix dialyzer                       # Run Dialyzer type checker
mix quality                        # Run all quality checks (format, credo, dialyzer)

# Compile
mix compile                        # Compile the project
MIX_NO_DEPS_CHECK=true mix compile --no-deps-check  # Compile without dependency checks
```

### Mix Tasks (This Package Provides)
```bash
# Installation
mix ash_phoenix_translations.install [--backend database|gettext|redis]

# Import/Export
mix ash_phoenix_translations.export products.csv --resource MyApp.Product
mix ash_phoenix_translations.import translations.csv --resource MyApp.Product --dry-run

# Redis-specific tasks (when using Redis backend)
mix ash_phoenix_translations.export.redis output.csv --resource MyApp.Product
mix ash_phoenix_translations.import.redis translations.csv
mix ash_phoenix_translations.sync.redis --from database --to redis
mix ash_phoenix_translations.clear.redis --resource MyApp.Product --confirm
mix ash_phoenix_translations.info.redis
mix ash_phoenix_translations.validate.redis --resource MyApp.Product

# Validation
mix ash_phoenix_translations.validate --resource MyApp.Product --locale es --strict

# Gettext extraction
mix ash_phoenix_translations.extract --domain MyApp.Shop --locales en,es,fr
```

### Ash-specific Generators
When implementing this library in a project, use:
```bash
mix ash.gen.resource       # Generate new Ash resource
mix ash.gen.domain         # Generate new Ash domain
mix igniter.install package_name  # Install new hex packages with Igniter
```

## Architecture & Code Structure

### Extension Architecture
The library follows Ash's extension pattern using Spark DSL transformers that modify resources sequentially:

1. **Entry Module** (`lib/ash_phoenix_translations.ex`): Main extension module declaring transformers and DSL sections
2. **Transformers** (`lib/ash_phoenix_translations/transformers/`): Execute in sequence to modify resource structure:
   - `AddTranslationStorage`: Adds JSONB/Map storage attributes based on backend
   - `AddTranslationRelationships`: Adds audit history relationships
   - `AddTranslationActions`: Creates update_translation, import_translations actions
   - `AddTranslationCalculations`: Adds locale-aware calculations for each translatable field
   - `AddTranslationChanges`: Adds validation and update changes
   - `SetupTranslationPolicies`: Configures policy-based access control

### Backend Architecture
Three storage backends with different strategies:
- **Database Backend**: Uses JSONB columns (PostgreSQL) - stores translations in `{field}_translations` columns as maps
- **Gettext Backend**: Integrates with Phoenix's Gettext - no storage needed, uses .po files
- **Redis Backend**: Uses Redis for distributed storage - requires optional Redix dependency, fully implemented but tests skipped by default

### Key Module Interactions
- `AshPhoenixTranslations.Info`: Introspection module to retrieve translation metadata from resources
- `AshPhoenixTranslations.TranslatableAttribute`: DSL entity struct for defining translatable fields
- `AshPhoenixTranslations.Calculations.DatabaseTranslation`: Calculation that fetches from JSONB storage
- `AshPhoenixTranslations.Calculations.GettextTranslation`: Calculation that fetches from Gettext
- `AshPhoenixTranslations.Calculations.RedisTranslation`: Calculation that fetches from Redis with local caching
- `AshPhoenixTranslations.Cache`: ETS-based caching layer with TTL support
- `AshPhoenixTranslations.Fallback`: Handles fallback chain for missing translations

### DSL Structure
Resources use the extension with a `translations do ... end` block:
```elixir
translations do
  translatable_attribute :name, :string,
    locales: [:en, :es, :fr],
    required: [:en]
  
  backend :database  # or :gettext or :redis
  cache_ttl 3600
  audit_changes true
end
```

### Transformer Pattern
Each transformer uses `Spark.Dsl.Transformer` behavior:
- Implements `transform/1` callback
- Uses `after?/1` to ensure proper execution order
- Modifies resources via `Ash.Resource.Builder` functions
- Storage attributes are `public?: false` to hide from API

### Phoenix Integration Points
- **Controllers**: Import `AshPhoenixTranslations.Controller` helpers
- **Views**: Import `AshPhoenixTranslations.Helpers` for `t/2` and `t/3` functions
- **LiveView**: Handle locale switching with `AshPhoenixTranslations.update_locale/2`
- **Router**: Add plugs `SetLocale` and `LoadTranslations`

### Translation Flow
1. User defines translatable attributes in resource DSL
2. Transformers add storage fields (e.g., `name_translations`) and calculations (e.g., `name`)
3. At runtime, calculations use locale from context to return translated value
4. Helper functions provide convenient access (`translate/2`, `t/2`)
5. Cache layer intercepts reads for performance

## Working with DSL State
When modifying transformers:
```elixir
# Get options from DSL
backend = Transformer.get_option(dsl_state, [:translations], :backend)

# Get entities (translatable attributes)
attrs = Transformer.get_entities(dsl_state, [:translations])

# Add new attributes/relationships/actions
{:ok, dsl_state} = Ash.Resource.Builder.add_new_attribute(dsl_state, name, type, opts)
```

## Testing Strategy
- Test resources use `Ash.DataLayer.Ets` for unit tests
- Each transformer tested independently
- DSL additions verified using `Ash.Resource.Info` functions
- Integration tests with mock Phoenix connections/sockets

## Important Notes
- Storage attributes should always be `public?: false`
- Transformers must use `after?/1` callbacks for proper ordering
- Use `Ash.Resource.Builder` functions to modify resources programmatically
- Follow Ash framework conventions from existing extensions
- Ensure compatibility with Ash's authorization, API extensions, and LiveView
- Redis backend was removed (deferred to future release) - only Database and Gettext are supported

## Common Patterns

### Adding a New Transformer
1. Create module in `lib/ash_phoenix_translations/transformers/`
2. Use `Spark.Dsl.Transformer` behavior
3. Implement `transform/1` callback
4. Add `after?/1` if order matters
5. Add to `@transformers` list in main extension module

### Handling Optional Dependencies
Always check if optional dependencies are loaded before use:
```elixir
if Code.ensure_loaded?(Phoenix.HTML) do
  Phoenix.HTML.raw(content)
else
  content
end
```

## Current Status
- Version 1.0.0 ready for release
- All three backends fully implemented (Database, Gettext, Redis)
- Redis backend requires optional Redix dependency
- Redis tests skipped by default (require running Redis instance)
- All compilation warnings fixed
- Comprehensive test suite: 262 tests passing, 0 failures
- All security vulnerabilities (VULN-001 to VULN-017) fixed and validated