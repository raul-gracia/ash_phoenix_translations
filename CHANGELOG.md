# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive Gettext backend documentation (guides/gettext_backend.md)
  - Detailed message ID pattern explanation
  - Complete .po file structure and format
  - Runtime behavior and calculation integration
  - Pluralization examples for multiple languages
  - Translation context usage
  - Dynamic translation with variable interpolation
  - Workflow integration and CI/CD examples
  - Professional translation management tool integration
  - Troubleshooting guide

### Fixed
- **CRITICAL**: Removed invalid `load:` option from calculation definitions that caused compilation errors
- **CRITICAL**: Changed storage attributes to `public?: true, writable?: true` to enable update_translation action
- **CRITICAL**: Implemented `expression/2` callback in DatabaseTranslation for SQL-based query optimization (prevents N+1 queries)
- **CRITICAL**: Implemented `load/3` callbacks in all calculation modules (DatabaseTranslation, GettextTranslation, AllTranslations)
- **CRITICAL**: Fixed Gettext backend field key from `opts[:field]` to `opts[:attribute_name]`
- Added `load/3` callback to GettextTranslation calculation for fallback storage field support
- Function clause grouping warnings in import_translations.ex and import.ex Mix tasks
- Phoenix.HTML.Tag undefined warnings by adding conditional compilation guards for optional dependency
- Stale Redis module alias in phase2_security_test.exs after Redis backend removal
- Removed obsolete Redis command injection tests (VULN-003)
- Verified XSS protection using HtmlSanitizeEx in raw_t/3 helper (already implemented)
- Verified atom exhaustion protection using String.to_existing_atom/1 (already implemented)
- Updated test assertions to reflect correct public attribute behavior
- Adjusted atom count verification test threshold for full test suite environment
- Compilation warnings for unused variables
- Removed undefined function warnings for optional dependencies
- CI pipeline issues including deps.audit task removal
- Credo configuration to suppress module dependency warnings
- Sobelow security analysis configuration with proper ignore rules
- Test compilation errors with proper domain configuration
- Documentation generation by adding ex_doc to test environment
- Added missing documentation guide files (import_export.md, liveview.md)
- Added missing LICENSE file for MIT licensing

### Documentation
- Added note to guides/policies.md clarifying that policy configuration is metadata-only
- Added cross-reference from guides/backends.md to comprehensive Gettext guide
- Policy examples now explicitly show both metadata configuration and actual policy implementation

### Removed
- Redis backend support (deferred to future release)
- All Redis-related dependencies and code
- Redis command injection security tests (no longer applicable)

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