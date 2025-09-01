# Contributing to AshPhoenixTranslations

Welcome to AshPhoenixTranslations! We're excited to have you contribute to this project. This guide will help you understand our development workflow, code quality standards, and contribution requirements.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Development Setup](#development-setup)
3. [Code Quality Standards](#code-quality-standards)
4. [Contribution Workflow](#contribution-workflow)
5. [Testing Guidelines](#testing-guidelines)
6. [Documentation Standards](#documentation-standards)
7. [Security Guidelines](#security-guidelines)
8. [CI/CD Pipeline](#cicd-pipeline)
9. [Release Process](#release-process)

## Getting Started

### Prerequisites

- Elixir 1.14+ and OTP 25+
- PostgreSQL 13+ (for database backend testing)
- Git for version control

### Quick Setup

```bash
# Clone the repository
git clone https://github.com/raul-gracia/ash_phoenix_translations.git
cd ash_phoenix_translations

# Install dependencies
mix deps.get
mix deps.compile

# Run tests to ensure everything works
mix test

# Run quality checks
mix quality
```

## Development Setup

### Environment Setup

1. **Install Elixir and Erlang**:
   ```bash
   # Using asdf (recommended)
   asdf plugin add elixir
   asdf plugin add erlang
   asdf install  # Installs versions from .tool-versions
   ```

2. **PostgreSQL Setup** (for testing database backend):
   ```bash
   # macOS with Homebrew
   brew install postgresql
   brew services start postgresql
   
   # Create test database
   createdb ash_phoenix_translations_test
   ```

3. **Editor Configuration**:
   - Use ElixirLS for VSCode/NeoVim
   - Configure automatic formatting on save
   - Enable Credo linting integration

### Project Structure

```
lib/
├── ash_phoenix_translations.ex              # Main extension module
├── ash_phoenix_translations/
│   ├── transformers/                        # DSL transformers
│   ├── calculations/                        # Translation calculations
│   ├── changes/                             # Translation changes
│   ├── plugs/                              # Phoenix plugs
│   ├── helpers.ex                          # View helpers
│   ├── cache.ex                            # Caching layer
│   └── ...
├── mix/
│   └── tasks/                              # Mix tasks
test/
├── support/                                # Test utilities
├── transformers/                           # Transformer tests
└── ...
```

## Code Quality Standards

We maintain high code quality standards to ensure the library is reliable, maintainable, and secure.

### 1. Credo Configuration

Our Credo configuration enforces strict code quality standards:

#### Key Quality Checks

**Consistency Checks** (Critical):
- Exception naming consistency
- Parameter pattern matching consistency  
- Space and indentation consistency
- Tabs vs spaces consistency

**Design Checks** (Important):
- Alias usage patterns (nested depth < 2)
- TODO comments (exit status 2 - must be resolved)

**Readability Checks** (Critical for public library):
- Module documentation required (priority: high)
- Function and variable naming conventions
- Maximum line length: 120 characters
- Proper alias ordering

**Refactoring Checks** (Maintainability):
- ABC complexity max: 50
- Module dependencies max: 10  
- Nesting depth max: 3

#### Running Credo

```bash
# Standard check
mix credo

# Strict mode (required for CI)
mix credo --strict

# Check specific files
mix credo lib/ash_phoenix_translations/helpers.ex
```

### 2. Code Formatting

We use Elixir's built-in formatter with these standards:

```elixir
# .formatter.exs
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 120,
  locals_without_parens: [
    # Ash DSL
    translatable_attribute: 2,
    translatable_attribute: 3,
    # Testing
    describe: 2,
    test: 2
  ]
]
```

**Format Commands**:
```bash
# Format all files
mix format

# Check formatting (CI requirement)
mix format --check-formatted

# Format specific files
mix format lib/ash_phoenix_translations/helpers.ex
```

### 3. Documentation Standards

#### Module Documentation
All public modules must include:

```elixir
defmodule AshPhoenixTranslations.YourModule do
  @moduledoc """
  Brief description of module purpose.

  Longer description explaining the module's role in the system,
  key concepts, and usage patterns.

  ## Examples

      iex> YourModule.function(arg)
      expected_result

  ## Security Considerations

  Document any security-sensitive functionality.
  """
```

#### Function Documentation
All public functions must include:

```elixir
@doc """
Brief description of what the function does.

Detailed explanation including edge cases and important behavior.

## Parameters

  * `resource` - The Ash resource to translate
  * `locale` - Target locale (atom or string)
  * `opts` - Options keyword list

## Options

  * `:fallback` - Fallback value if translation missing
  * `:default` - Default locale to use

## Examples

    iex> translate(resource, :es)
    %Resource{name: "Producto"}

## Security Notes

Document any security implications or requirements.
"""
def translate(resource, locale, opts \\ [])
```

### 4. Security Code Standards

#### Safe Atom Conversion
```elixir
# ✅ CORRECT: Use String.to_existing_atom/1
defp safe_locale_conversion(locale_string) do
  try do
    String.to_existing_atom(locale_string)
  rescue
    ArgumentError -> :en  # Safe fallback
  end
end

# ❌ INCORRECT: Never use String.to_atom/1 with user input
defp unsafe_conversion(user_input) do
  String.to_atom(user_input)  # Atom exhaustion vulnerability!
end
```

#### XSS Prevention
```elixir
# ✅ CORRECT: Default HTML escaping
def safe_translation(resource, field) do
  content = get_translation(resource, field)
  Phoenix.HTML.html_escape(content)
end

# ⚠️  CAUTION: Document when bypassing escaping
def raw_translation(resource, field) do
  # SECURITY WARNING: This bypasses HTML escaping!
  # Only use with trusted content that you control
  content = get_translation(resource, field)
  Phoenix.HTML.raw(content)
end
```

## Contribution Workflow

### 1. Fork and Branch Strategy

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/YOUR-USERNAME/ash_phoenix_translations.git
cd ash_phoenix_translations

# Add upstream remote
git remote add upstream https://github.com/raul-gracia/ash_phoenix_translations.git

# Create feature branch
git checkout -b feature/your-feature-name

# Keep your fork updated
git fetch upstream
git checkout main
git merge upstream/main
```

### 2. Development Process

1. **Make Changes**:
   ```bash
   # Make your changes
   # Write/update tests
   # Update documentation
   ```

2. **Run Quality Checks**:
   ```bash
   # Run full quality suite
   mix quality
   
   # Individual checks
   mix test                    # Tests
   mix format --check-formatted # Formatting
   mix credo --strict          # Code quality
   mix sobelow --config        # Security
   mix dialyzer                # Type analysis
   ```

3. **Commit Changes**:
   ```bash
   # Stage changes
   git add .
   
   # Commit with descriptive message
   git commit -m "Add feature: translation completeness validation
   
   - Add translation_completeness/2 helper function
   - Include percentage calculation for locale coverage
   - Add comprehensive test coverage
   - Update documentation with examples"
   ```

### 3. Pull Request Process

1. **Push to Your Fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create Pull Request**:
   - Use the GitHub web interface
   - Fill out the PR template completely
   - Include detailed description of changes
   - Reference any related issues

3. **PR Requirements**:
   - [ ] All CI checks pass
   - [ ] Code coverage maintained (>90%)
   - [ ] Documentation updated
   - [ ] Security review completed (if applicable)
   - [ ] Breaking changes documented

### 4. Code Review Process

**Review Checklist**:
- Code quality and style compliance
- Test coverage and quality
- Documentation completeness
- Security implications
- API consistency
- Performance considerations

**Addressing Review Comments**:
```bash
# Make requested changes
# Commit changes
git add .
git commit -m "Address PR review: improve error handling"

# Push updates
git push origin feature/your-feature-name
```

## Testing Guidelines

### 1. Test Structure

```elixir
defmodule AshPhoenixTranslations.YourModuleTest do
  use ExUnit.Case, async: true
  
  import AshPhoenixTranslations.Factory
  
  describe "function_name/2" do
    test "handles valid input correctly" do
      # Test happy path
    end
    
    test "handles edge cases gracefully" do
      # Test boundary conditions
    end
    
    test "returns appropriate errors for invalid input" do
      # Test error cases
    end
  end
end
```

### 2. Testing Requirements

**Coverage Requirements**:
- Minimum 90% line coverage
- 100% coverage for security-sensitive functions
- All public API functions tested

**Test Types**:
- Unit tests for individual functions
- Integration tests for transformer chains  
- Property-based tests for complex logic
- Security tests for input validation

### 3. Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/ash_phoenix_translations_test.exs

# Run specific test
mix test test/ash_phoenix_translations_test.exs:42

# Run tests in watch mode (development)
mix test.watch
```

### 4. Test Utilities

Use the provided test factories and helpers:

```elixir
# Create test resources with translations
product = build(:product_with_translations, %{
  name_translations: %{en: "Product", es: "Producto"}
})

# Test transformer behavior  
resource = build_resource_with_translations([:name, :description])
transformed = apply_transformers(resource)
```

## Security Guidelines

### 1. Security Review Requirements

All contributions must pass security review:

- **Input validation** for all user-facing functions
- **Output sanitization** for web-rendered content  
- **Access control** for administrative functions
- **Error handling** that doesn't leak sensitive information

### 2. Security Testing

```bash
# Run security analysis
mix sobelow --config

# Check dependencies for vulnerabilities
mix deps.audit
mix hex.audit

# Run with security focus
MIX_ENV=test mix test --only security
```

### 3. Secure Coding Practices

**Input Validation**:
```elixir
def secure_function(input) when is_binary(input) and byte_size(input) < 1000 do
  # Validate input constraints
  with {:ok, sanitized} <- sanitize_input(input),
       {:ok, validated} <- validate_format(sanitized) do
    process_input(validated)
  end
end
```

**Error Handling**:
```elixir
def safe_operation(params) do
  case dangerous_operation(params) do
    {:ok, result} -> {:ok, result}
    {:error, _internal_details} -> 
      Logger.warn("Operation failed", params: sanitize_for_logging(params))
      {:error, :operation_failed}  # Don't leak internal details
  end
end
```

## CI/CD Pipeline

Our GitHub Actions pipeline ensures code quality and security:

### 1. Test Matrix

Tests run on multiple Elixir/OTP combinations:
- Minimum supported: Elixir 1.14.5 / OTP 25.0
- Current stable: Elixir 1.17.3 / OTP 27.0  
- Upcoming: Elixir 1.18.0 / OTP 27.1 (experimental)

### 2. Quality Checks

```yaml
# Quality pipeline includes:
- Format checking: mix format --check-formatted
- Code quality: mix credo --strict  
- Security analysis: mix sobelow --config
- Dependency audit: mix deps.audit
- Type analysis: mix dialyzer
- Documentation: mix docs
```

### 3. Security Scanning

```yaml
# Security pipeline includes:
- Retired dependency check: mix hex.audit
- Vulnerability scanning: mix sobelow  
- Dependency audit: mix deps.audit
- License compliance: mix licensir
```

### 4. Release Preparation

```yaml
# Release pipeline includes:
- Package building: mix hex.build
- Dry-run publish: mix hex.publish --dry-run
- Documentation generation: mix docs
```

## Release Process

### 1. Version Management

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking API changes
- **MINOR**: New features, backwards compatible  
- **PATCH**: Bug fixes, backwards compatible

### 2. Release Checklist

**Pre-Release**:
- [ ] Update CHANGELOG.md
- [ ] Update version in mix.exs
- [ ] Update documentation
- [ ] Run full test suite
- [ ] Security review completed
- [ ] Performance regression testing

**Release**:
- [ ] Create release branch
- [ ] Tag release version
- [ ] Publish to Hex.pm
- [ ] Update documentation site
- [ ] Announce release

### 3. Changelog Standards

```markdown
## [1.1.0] - 2024-01-15

### Added
- New translation completeness validation
- Support for custom fallback strategies
- Performance improvements for large datasets

### Changed  
- Improved error messages for translation failures
- Updated default cache TTL from 1800 to 3600 seconds

### Fixed
- Fixed atom exhaustion vulnerability in locale parsing
- Resolved race condition in cache invalidation

### Security
- Enhanced input validation for translation content
- Added XSS protection for raw translation output

### Deprecated
- `old_function/2` will be removed in v2.0.0

### Removed
- Support for Elixir < 1.14

### Breaking Changes
- Changed default backend from `:gettext` to `:database`
- Renamed `translate_unsafe/2` to `raw_translate/2`
```

## Getting Help

### 1. Communication Channels

- **GitHub Issues**: Bug reports, feature requests
- **GitHub Discussions**: General questions, design discussions
- **Security Issues**: security@yourproject.com (private)

### 2. Development Support  

- **Ash Discord**: Join #extensions channel for Ash-specific questions
- **Elixir Forum**: General Elixir/Phoenix development help
- **Documentation**: https://hexdocs.pm/ash_phoenix_translations

### 3. Contribution Recognition

We recognize contributors in:
- CHANGELOG.md for each release
- README.md contributors section
- GitHub contributor statistics
- Annual contributor appreciation posts

## Code of Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/) code of conduct. By participating, you agree to uphold this code.

### Our Pledge

We pledge to make participation in our project a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, education, socio-economic status, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Enforcement

Instances of unacceptable behavior may be reported to the project maintainers. All complaints will be reviewed and investigated fairly and confidentially.

---

Thank you for contributing to AshPhoenixTranslations! Your efforts help make translation management better for the entire Elixir/Phoenix community.

For questions about this guide, please open a GitHub Discussion or contact the maintainers directly.

**Happy coding!** 🎉