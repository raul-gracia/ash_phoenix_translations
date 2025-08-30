# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AshPhoenixTranslations is an Ash Framework extension that provides policy-aware translation capabilities for Phoenix applications with multi-backend support. The project aims to seamlessly integrate translation functionality into Ash resources with support for multiple storage backends, lazy-loading, and LiveView integration.

## Project Setup & Development Commands

### Initial Setup
```bash
# Install dependencies
mix deps.get
mix deps.compile

# Generate initial configuration (when implemented)
mix ash_phoenix_translations.install

# If using database backend
mix ecto.create
mix ecto.migrate
```

### Development Commands
```bash
# Run tests
mix test

# Run specific test file
mix test test/ash_phoenix_translations_test.exs

# Interactive console
iex -S mix

# Compile the project
mix compile

# Format code
mix format

# Check formatting
mix format --check-format
```

### Key Dependencies to Install
When implementing this library, use Igniter to install new hex packages:
```bash
mix igniter.install package_name
```

For Ash-specific generators:
```bash
# Use ash.gen commands for creating new Ash resources, domains, etc.
mix ash.gen.resource
mix ash.gen.domain
```

## Architecture & Code Structure

### Extension Architecture
The library follows Ash's extension pattern using Spark DSL transformers:

1. **Entry Module** (`lib/ash_phoenix_translations.ex`): Main extension module that declares transformers
2. **Transformers** (`lib/ash_phoenix_translations/transformers/`): Sequential transformers that modify resource structure:
   - `AddTranslationStorage`: Adds storage attributes based on backend
   - `AddTranslationRelationships`: Adds audit history relationships
   - `AddTranslationActions`: Creates translation management actions
   - `AddTranslationCalculations`: Adds locale-aware calculations
   - `AddTranslationChanges`: Adds validation changes
   - `SetupTranslationPolicies`: Configures policy-based access control

### Core Components

#### Translation Storage Backends
- **Database**: Uses JSONB columns for PostgreSQL (default)
- **Gettext**: Integrates with Phoenix's Gettext
- **Redis**: Key-value storage for translations
- Each backend has different storage strategies implemented in transformers

#### Key Modules to Implement
- `AshPhoenixTranslations.TranslatableAttribute`: DSL entity for defining translatable fields
- `AshPhoenixTranslations.Info`: Introspection module for translation metadata
- `AshPhoenixTranslations.LocaleResolver`: Strategies for determining current locale
- `AshPhoenixTranslations.Cache`: Caching layer for translation performance
- `AshPhoenixTranslations.Plug`: Phoenix plug modules for locale handling

### DSL Structure
Resources use the extension with a `translations do ... end` block containing:
- `translatable_attribute`: Define translatable fields with locales and validation
- `backend`: Choose storage backend
- `policy`: Define who can view/edit translations
- `cache_ttl`: Set caching duration
- `audit_changes`: Enable translation history

## Implementation Guidelines

### When Adding New Features
1. Follow the transformer pattern - each major feature should be a separate transformer
2. Transformers should use `after?/1` callbacks to ensure proper execution order
3. Use `Ash.Resource.Builder` functions to modify resources programmatically
4. All storage attributes should be `public?: false` to hide from API

### Testing Strategy
- Create test resources using `Ash.DataLayer.Ets` for unit tests
- Test each transformer independently
- Verify that DSL additions work correctly using `Ash.Resource.Info` functions
- Test the full integration with mock Phoenix connections/sockets

### Phoenix Integration Points
- Controllers: Add `import AshPhoenixTranslations.Controller` helpers
- Views: Add `import AshPhoenixTranslations.Helpers` for `t/2` and `t/3` functions
- LiveView: Handle locale switching with `AshPhoenixTranslations.update_locale/2`
- Router: Add plugs for `SetLocale` and `LoadTranslations`

### Policy Integration
Leverage Ash's policy engine for translation access control:
- View permissions per locale
- Edit permissions based on roles (translator, admin)
- Approval workflows for translation changes

## Common Patterns

### Adding a New Transformer
1. Create module in `lib/ash_phoenix_translations/transformers/`
2. Use `Spark.Dsl.Transformer` behavior
3. Implement `transform/1` callback
4. Add `after?/1` if order matters
5. Add to `@transformers` list in main extension module

### Working with DSL State
```elixir
# Get options from DSL
backend = Transformer.get_option(dsl_state, [:translations], :backend)

# Get entities (like translatable attributes)
attrs = Transformer.get_entities(dsl_state, [:translations])

# Add new attributes/relationships/actions
{:ok, dsl_state} = Ash.Resource.Builder.add_new_attribute(dsl_state, name, type, opts)
```

### Translation Flow
1. User defines translatable attributes in resource
2. Transformers add storage fields and calculations
3. At runtime, calculations use locale from context
4. Helper functions provide convenient access (`translate/2`)

## Important Notes
- This is a design/prototype phase - the actual hex package doesn't exist yet
- Follow Ash framework conventions and patterns from existing extensions
- Prioritize developer experience with clean, declarative syntax
- Ensure compatibility with Ash's authorization, API extensions, and LiveView