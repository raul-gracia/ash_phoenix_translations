# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed
- Redis backend support (deferred to future release)
- All Redis-related dependencies and code

### Fixed
- Compilation warnings for unused variables
- Removed undefined function warnings for optional dependencies

## [1.0.0] - 2024-09-01

### Added
- Initial release of AshPhoenixTranslations
- Multi-locale support for unlimited locales per field
- Policy-aware translations leveraging Ash policies
- Multiple storage backends:
  - Database backend with JSONB storage (PostgreSQL)
  - Gettext backend integration
- Automatic DSL transformers for translation management
- Translation calculations for locale-aware field access
- Fallback chain support for missing translations
- Error handling with custom exception types
- Basic caching layer with ETS backend
- Phoenix integration helpers
- LiveView support for real-time locale switching
- GraphQL field generation (basic support)
- JSON:API integration
- Embedded schema support
- Mix tasks for import/export (basic implementation)
- Comprehensive test suite foundation

### Security
- Input sanitization for translations
- Policy-based access control for view/edit permissions
- Secure locale resolution strategies

### Performance
- Built-in caching with configurable TTL
- Efficient JSONB queries for PostgreSQL backend
- Lazy loading of translations

### Documentation
- Comprehensive README with examples
- API documentation with ExDoc
- Installation and configuration guides

[Unreleased]: https://github.com/raul-gracia/ash_phoenix_translations/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/raul-gracia/ash_phoenix_translations/releases/tag/v1.0.0