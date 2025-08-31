# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-31

### Added
- Initial release of AshPhoenixTranslations
- Multi-backend support (Database/JSONB, Gettext, Redis)
- Policy-aware translation access control
- DSL for defining translatable attributes
- Automatic storage attribute generation
- Translation calculations for locale-aware access
- Validation changes for required locales
- Audit trail support for translation changes
- Phoenix integration with plugs and helpers
- LiveView support with real-time locale switching
- ETS-based caching with TTL and invalidation
- Mix tasks for installation, import/export, and validation
- Support for CSV, JSON, and XLIFF formats
- Comprehensive locale resolution strategies
- Translation completeness tracking
- Bulk translation operations
- Example blog application

### Features
- **Translatable Attributes**: Define fields that can be translated with locale constraints
- **Multiple Storage Backends**: Choose between database, gettext, or redis storage
- **Policy Integration**: Leverage Ash policies for translation access control
- **Caching Layer**: Built-in caching with automatic invalidation
- **Import/Export**: Bulk translation management via CSV, JSON, or XLIFF
- **Validation**: Quality checks and completeness validation
- **Phoenix Helpers**: Template helpers for easy translation rendering
- **LiveView Components**: Real-time translation management components
- **Locale Detection**: Multiple strategies for determining user locale
- **Audit Trail**: Track translation changes with actor information

### Documentation
- Comprehensive README with examples
- Getting Started guide
- Integration test suite
- Example blog application demonstrating features

## [Unreleased]

### Planned
- Admin UI package (ash_phoenix_translations_admin)
- Machine translation integration
- Translation workflow management
- Collaborative translation features
- WebSocket-based real-time translation updates
- GraphQL support via AshGraphql
- Additional storage backends (MongoDB, DynamoDB)
- Translation memory and glossary support
- A/B testing for translations
- Analytics and translation performance metrics