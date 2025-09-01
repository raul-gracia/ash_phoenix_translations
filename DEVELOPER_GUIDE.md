# Developer Guide

## Table of Contents

1. [Quick Setup](#quick-setup)
2. [Development Workflow](#development-workflow)
3. [Quality Assurance](#quality-assurance)
4. [CI/CD Pipeline](#cicd-pipeline)
5. [Security Guidelines](#security-guidelines)
6. [Troubleshooting](#troubleshooting)
7. [Performance Guidelines](#performance-guidelines)
8. [Best Practices](#best-practices)

## Quick Setup

### Prerequisites

- Elixir 1.14+ and OTP 25+
- PostgreSQL 13+ (for testing database backend)
- Git

### Environment Setup

```bash
# Clone and setup
git clone https://github.com/raul-gracia/ash_phoenix_translations.git
cd ash_phoenix_translations

# Install dependencies
mix deps.get
mix deps.compile

# Verify setup
mix test
mix quality
```

### Development Dependencies

```elixir
# Quality and security tools (already in mix.exs)
{:credo, "~> 1.7", only: [:dev, :test], runtime: false}
{:sobelow, "~> 0.14", only: [:dev, :test], runtime: false}
{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
{:excoveralls, "~> 0.16", only: :test}
{:mix_test_watch, "~> 1.1", only: :dev, runtime: false}
```

## Development Workflow

### 1. Feature Development Process

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make changes with TDD approach
mix test.watch  # Run tests in watch mode during development

# Run quality checks frequently
mix quality     # Full quality suite
```

### 2. Pre-Commit Checklist

```bash
# Required checks before committing
mix test                        # All tests pass
mix format --check-formatted   # Code properly formatted
mix credo --strict             # No quality issues
mix sobelow --config           # No security vulnerabilities
mix dialyzer                   # No type errors
```

### 3. Commit Standards

```bash
# Good commit message format
git commit -m "Add feature: translation completeness validation

- Implement translation_completeness/2 helper function
- Add percentage calculation for locale coverage
- Include comprehensive test suite with 95% coverage
- Update documentation with usage examples
- Add security validation for input parameters

Fixes #123"
```

## Quality Assurance

### 1. Code Quality Tools

#### Credo (Code Quality)

**Purpose**: Static code analysis and style enforcement

```bash
# Run Credo checks
mix credo                 # Standard check
mix credo --strict        # Strict mode (required for CI)
mix credo --explain       # Detailed explanations
mix credo list            # List all available checks

# Check specific files
mix credo lib/ash_phoenix_translations/helpers.ex

# Custom configuration in .credo.exs
```

**Key Quality Rules**:
- Module documentation required (priority: high)
- Line length max: 120 characters
- Function complexity max: 50 (ABC complexity)
- Nesting depth max: 3 levels
- TODO comments cause exit status 2

#### Dialyzer (Type Analysis)

**Purpose**: Static type analysis and bug detection

```bash
# Initial PLT building (takes time)
mix dialyzer

# Check specific files
mix dialyzer lib/ash_phoenix_translations/helpers.ex

# Configuration in mix.exs
dialyzer: [
  plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
]
```

#### ExCoveralls (Test Coverage)

**Purpose**: Test coverage analysis and reporting

```bash
# Generate coverage report
mix test --cover
mix coveralls             # Text report
mix coveralls.html        # HTML report
mix coveralls.json        # JSON report

# Coverage requirements: 90%+ for library code
```

### 2. Security Tools

#### Sobelow (Security Analysis)

**Purpose**: Security-focused static analysis for Phoenix applications

```bash
# Run security analysis
mix sobelow --config      # Use .sobelow-conf configuration
mix sobelow --verbose     # Detailed output
mix sobelow --private     # Include private findings

# Custom configuration in .sobelow-conf
```

**Security Checks**:
- XSS vulnerability detection
- SQL injection prevention  
- Unsafe atom creation
- Directory traversal prevention
- Configuration security

#### Dependency Auditing

```bash
# Check for vulnerabilities
mix deps.audit           # Known vulnerabilities
mix hex.audit            # Retired packages

# License compliance
mix archive.install hex licensir --force
mix licensir
```

### 3. Formatting and Style

```bash
# Format code
mix format               # Format all files
mix format --check-formatted  # Check without changing

# Configuration in .formatter.exs
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 120,
  locals_without_parens: [
    translatable_attribute: 2,
    translatable_attribute: 3
  ]
]
```

## CI/CD Pipeline

### 1. GitHub Actions Configuration

Our CI/CD pipeline includes multiple jobs for comprehensive quality assurance:

#### Test Matrix
```yaml
# Tests run on multiple Elixir/OTP versions
strategy:
  matrix:
    include:
      - elixir: "1.14.5"  # Minimum supported
        otp: "25.0"
      - elixir: "1.17.3"  # Current stable
        otp: "27.0"
      - elixir: "1.18.0"  # Upcoming (experimental)
        otp: "27.1"
```

#### Quality Pipeline
```yaml
# Quality checks (runs in parallel with tests)
- name: Check formatting
  run: mix format --check-formatted

- name: Run Credo
  run: mix credo --strict

- name: Run Sobelow security analysis  
  run: mix sobelow --config

- name: Check dependencies
  run: mix deps.audit

- name: Run Dialyzer
  run: mix dialyzer
```

#### Security Pipeline
```yaml
# Security-focused checks
- name: Check for retired dependencies
  run: mix hex.audit

- name: Security vulnerability scan
  run: mix sobelow --exit || true

- name: License compliance
  run: mix licensir
```

### 2. Local CI Simulation

Run the same checks locally before pushing:

```bash
# Simulate the full CI pipeline
mix quality.ci          # CI-compatible quality checks

# Individual CI checks
mix format --check-formatted
mix credo --strict
mix sobelow --exit
mix deps.audit
mix dialyzer
```

### 3. Pre-commit Hooks

Set up pre-commit hooks to ensure quality:

```bash
# Create .git/hooks/pre-commit
#!/bin/sh
mix format --check-formatted && \
mix credo --strict && \
mix test && \
mix sobelow --config
```

## Security Guidelines

### 1. Secure Coding Practices

#### Input Validation
```elixir
# ✅ GOOD: Validate all inputs
def process_translation(content) when is_binary(content) and byte_size(content) < 10_000 do
  with {:ok, sanitized} <- sanitize_content(content),
       {:ok, validated} <- validate_format(sanitized) do
    store_translation(validated)
  end
end

# ❌ BAD: No validation
def process_translation(content) do
  store_translation(content)  # Could be anything!
end
```

#### Atom Safety
```elixir
# ✅ GOOD: Use existing atoms only
defp safe_locale(locale_string) do
  String.to_existing_atom(locale_string)
rescue
  ArgumentError -> :en  # Safe fallback
end

# ❌ BAD: Create atoms from user input
defp unsafe_locale(user_input) do
  String.to_atom(user_input)  # Atom exhaustion attack!
end
```

#### XSS Prevention
```elixir
# ✅ GOOD: Default HTML escaping
def safe_render(translation) do
  Phoenix.HTML.html_escape(translation)
end

# ⚠️  CAUTION: Document when bypassing escaping
def raw_render(trusted_translation) do
  # SECURITY WARNING: Only use with trusted content!
  Phoenix.HTML.raw(trusted_translation)
end
```

### 2. Security Testing

```bash
# Run security-focused tests
MIX_ENV=test mix test --only security

# Test with malicious inputs
mix test test/security_test.exs

# Vulnerability scanning
mix sobelow --config --exit
```

### 3. Security Documentation

Always document security considerations:

```elixir
@doc """
Renders raw translation content without HTML escaping.

## Security Warning

⚠️  This function bypasses HTML escaping and can introduce XSS vulnerabilities.
Only use with translation content that you trust and control.

## Safe Usage

    # ✅ Safe: Trusted content from your translation team
    <%= raw_t(@product, :html_description) %>

## Unsafe Usage  

    # ❌ Dangerous: User-generated content
    <%= raw_t(@user_comment, :content) %>  # XSS risk!

## Alternatives

Consider using the safe `t/3` function instead:

    <%= t(@product, :description) %>  # Automatically HTML-escaped
"""
def raw_t(resource, field, opts \\ [])
```

## Troubleshooting

### 1. Common Credo Issues

#### Module Documentation Missing
```elixir
# Error: Credo.Check.Readability.ModuleDoc
# Fix: Add @moduledoc to all public modules
defmodule MyModule do
  @moduledoc """
  Brief description of module purpose.
  """
end
```

#### Line Too Long
```elixir
# Error: Credo.Check.Readability.MaxLineLength
# Fix: Break long lines (max 120 chars)

# Bad
very_long_function_name_with_many_parameters(param1, param2, param3, param4, param5)

# Good  
very_long_function_name_with_many_parameters(
  param1,
  param2, 
  param3,
  param4,
  param5
)
```

#### TODO Comments
```elixir
# Error: Credo.Check.Design.TagTODO
# Fix: Remove TODO comments or create GitHub issues

# Bad
# TODO: Fix this later

# Good (if needed)
# GitHub Issue #123: Implement caching strategy
```

### 2. Common Sobelow Issues

#### XSS.Raw Warnings
```elixir
# Warning: XSS.Raw in raw_t function
# This is intentionally excluded in .sobelow-conf
# Ensure proper documentation and usage warnings
```

#### DOS.BinToAtom Warnings
```elixir
# Warning: String.to_atom usage
# Fix: Use String.to_existing_atom/1 instead

# Bad
String.to_atom(user_input)

# Good
String.to_existing_atom(user_input)
```

### 3. Common Dialyzer Issues

#### Undefined Functions
```bash
# Error: Function module.function/1 undefined
# Fix: Ensure all called functions exist and are exported

# Check if function exists
iex> :module.module_info(:exports)
```

#### Type Mismatches
```elixir
# Error: Type mismatch
# Fix: Add proper type specifications

@spec translate_field(map(), atom(), atom()) :: binary() | nil
def translate_field(resource, field, locale)
```

### 4. Test Coverage Issues

#### Low Coverage Warning
```bash
# Coverage below 90%
# Fix: Add tests for uncovered lines

# Generate detailed coverage report
mix coveralls.html
open cover/excoveralls.html
```

#### Missing Test Cases
```elixir
# Add tests for all code paths
describe "error handling" do
  test "handles invalid input gracefully" do
    assert {:error, :invalid_input} = function_under_test("invalid")
  end
end
```

## Performance Guidelines

### 1. Translation Caching

```elixir
# Use built-in caching for frequently accessed translations
translations do
  cache_ttl 3600  # 1 hour cache
end

# Warm cache for critical translations
AshPhoenixTranslations.Cache.warm(Product, [:name, :description], [:en, :es])
```

### 2. Batch Operations

```elixir
# ✅ Good: Batch translation loading
products = Product.list!()
translated = AshPhoenixTranslations.translate_all(products, :es)

# ❌ Bad: Individual translation calls
products = Product.list!()
translated = Enum.map(products, &AshPhoenixTranslations.translate(&1, :es))
```

### 3. Database Optimization

```elixir
# Use efficient JSONB operations for PostgreSQL backend
# Index JSONB columns for better query performance
create index("products", ["(name_translations->>'en')"]) 
create index("products", ["(name_translations ? 'es')"]) # Key existence
```

## Best Practices

### 1. Documentation

```elixir
# Complete module documentation
@moduledoc """
Handles translation operations for Ash resources.

This module provides functions for translating resources based on locale,
with support for fallback strategies and caching.

## Usage

    iex> translate(product, :es)
    %Product{name: "Producto"}

## Security

All functions in this module properly sanitize input and escape output.
"""

# Function documentation with examples
@doc """
Translates a resource to the specified locale.

Returns a translated copy of the resource with calculated fields.

## Examples

    iex> product = %Product{name_translations: %{es: "Producto"}}
    iex> translate(product, :es)
    %Product{name: "Producto"}

## Security

Input locale is validated using String.to_existing_atom/1 to prevent
atom exhaustion attacks.
"""
```

### 2. Error Handling

```elixir
# Proper error handling with informative messages
def translate_field(resource, field, locale) do
  case validate_inputs(resource, field, locale) do
    {:ok, {resource, field, locale}} ->
      perform_translation(resource, field, locale)
    
    {:error, :invalid_resource} ->
      {:error, "Resource must implement AshPhoenixTranslations extension"}
    
    {:error, :invalid_field} ->
      {:error, "Field #{field} is not translatable"}
    
    {:error, :invalid_locale} ->
      {:error, "Locale #{locale} is not supported"}
  end
end
```

### 3. Testing Strategies

```elixir
# Comprehensive test coverage
describe "translate/2" do
  test "translates resource to specified locale" do
    # Happy path test
  end
  
  test "falls back to default locale when translation missing" do
    # Fallback behavior test
  end
  
  test "handles invalid locale gracefully" do
    # Error handling test
  end
  
  test "prevents XSS in translated content" do
    # Security test
  end
  
  property "handles any valid locale input" do
    # Property-based test for robustness
  end
end
```

### 4. Security Mindset

```elixir
# Always consider security implications
# - Validate all inputs
# - Sanitize all outputs
# - Use safe atom conversion
# - Document security considerations
# - Test with malicious inputs

def secure_function(user_input) do
  with {:ok, validated} <- validate_input(user_input),
       {:ok, sanitized} <- sanitize_input(validated),
       {:ok, result} <- process_input(sanitized) do
    {:ok, escape_output(result)}
  end
end
```

---

## Getting Help

- **GitHub Issues**: Technical problems and bug reports
- **GitHub Discussions**: Architecture and design questions  
- **Security Issues**: security@yourproject.com (private)
- **Ash Discord**: #extensions channel for Ash-specific questions

## Development Resources

- [Ash Framework Documentation](https://ash-hq.org/)
- [Phoenix Framework Guides](https://hexdocs.pm/phoenix/)
- [Elixir Security Guidelines](https://github.com/elixir-lang/elixir/blob/main/SECURITY.md)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

**Happy Development!** 🚀

Remember: Security and quality are not optional - they're integral to everything we build.