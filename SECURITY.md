# Security Policy

## Table of Contents

1. [Security Overview](#security-overview)
2. [Reporting Vulnerabilities](#reporting-vulnerabilities)
3. [Security Measures](#security-measures)
4. [Secure Usage Guidelines](#secure-usage-guidelines)
5. [XSS Prevention](#xss-prevention)
6. [Input Validation](#input-validation)
7. [Security Tools](#security-tools)
8. [Atom Creation Safety](#atom-creation-safety)
9. [Threat Model](#threat-model)

## Security Overview

AshPhoenixTranslations takes security seriously as a library handling user content and translations. This document outlines our security practices, measures implemented, and guidelines for secure usage.

### Security Principles

- **Defense in Depth**: Multiple layers of security validation and sanitization
- **Secure by Default**: Safe defaults that prevent common security issues
- **Principle of Least Privilege**: Minimal permissions for translation access
- **Input Validation**: Comprehensive validation of all user inputs
- **Automated Security Testing**: Continuous security scanning in CI/CD

## Reporting Vulnerabilities

### Reporting Process

If you discover a security vulnerability in AshPhoenixTranslations, please report it responsibly:

1. **DO NOT** open a public issue on GitHub
2. **DO** send an email to: [security@yourproject.com]
3. Include detailed information about the vulnerability
4. Provide steps to reproduce the issue
5. Include the affected version(s)

### Response Timeline

- **24 hours**: Initial acknowledgment of your report
- **72 hours**: Preliminary assessment and severity classification
- **7 days**: Detailed analysis and fix development (for high/critical issues)
- **14 days**: Security patch release and public disclosure

### Security Hall of Fame

We maintain a security hall of fame to recognize responsible security researchers who help improve our security.

## Security Measures

### 1. Automated Security Scanning

We use multiple automated tools to continuously scan for vulnerabilities:

#### Sobelow Security Analysis
- **Tool**: Sobelow - Security-focused static analysis for Phoenix applications
- **Configuration**: `.sobelow-conf`
- **Scope**: Library-specific security rules with appropriate exclusions
- **Frequency**: Every commit and PR via GitHub Actions

**Key Sobelow Checks:**
- XSS vulnerability detection
- SQL injection prevention
- Unsafe atom creation
- Directory traversal prevention
- Configuration security validation

**Intentional Exclusions:**
- `Config.CSP`, `Config.HTTPS`, `Config.Session`, `Config.CSRF`, `Config.Headers`: Host application responsibility
- `XSS.Raw`: Documented unsafe function (`raw_t/3`) for trusted content
- `DOS.BinToAtom`: Acceptable for compile-time field names in DSL contexts

#### Dependency Vulnerability Scanning
- **Tools**: `mix hex.audit` and `mix deps.audit`
- **Frequency**: Weekly scheduled scans + every PR
- **Scope**: All production and development dependencies

#### License Compliance
- **Tool**: Licensir
- **Purpose**: Ensure all dependencies use compatible licenses
- **Frequency**: Weekly scans

### 2. Code Quality and Security Standards

#### Credo Configuration
- **Mode**: Strict mode for library development
- **Rules**: Enhanced security-focused rule set
- **Exclusions**: Carefully documented with security justifications

**Security-Relevant Credo Checks:**
- `Warning.UnsafeToAtom`: Disabled with documented justification for DSL parsing
- `Warning.LeakyEnvironment`: Monitored for configuration leaks
- `Design.TagTODO`: Exit status 2 to prevent incomplete security implementations

### 3. Input Validation and Sanitization

#### Translation Content Validation
```elixir
# All translation inputs are validated for:
# - Maximum length limits (prevent DoS)
# - Character encoding validation (prevent injection)
# - HTML/script tag detection (prevent XSS)
# - Null byte prevention (prevent path traversal)
```

#### Locale Parameter Validation
- Locale strings converted to atoms using `String.to_existing_atom/1`
- Prevents atom exhaustion attacks
- Fallback to default locale for invalid inputs

### 4. Atom Creation Safety

**Critical Security Fix Implemented:**

The library uses secure atom conversion practices to prevent atom exhaustion attacks:

```elixir
# SAFE: Uses existing atoms only
String.to_existing_atom(locale_string)

# UNSAFE: Would create unlimited atoms (NOT USED)
String.to_atom(user_input)
```

**Implementation Details:**
- All user-provided locale strings use `String.to_existing_atom/1`
- Compile-time known field names use safe conversion
- Exception handling with fallback to default locale
- Documentation warnings in security-sensitive functions

### 5. Phoenix Integration Security

#### XSS Prevention
- Default HTML escaping for all translation output
- Explicit `raw_t/3` function for trusted content with security warnings
- Input sanitization for translation data

#### CSRF Protection
- Translation update actions require CSRF tokens
- LiveView integration includes CSRF protection
- Form helpers generate secure form tokens

## Secure Usage Guidelines

### 1. Translation Content Handling

#### DO ✅
```elixir
# Use safe HTML-escaped translation
<%= t(@product, :name) %>

# Use raw_t only for trusted content you control
<%= raw_t(@trusted_content, :description) %>

# Validate translation content before storage
translations = %{en: sanitize_html(user_input)}
```

#### DON'T ❌
```elixir
# Never use raw_t with user-generated content
<%= raw_t(@user_comment, :content) %>  # XSS vulnerability!

# Never bypass locale validation
locale = String.to_atom(user_input)  # Atom exhaustion attack!

# Never trust translation content without validation
translations = %{en: params[:unsafe_content]}  # Potential XSS!
```

### 2. Policy Configuration

#### Secure Policy Examples
```elixir
policies do
  # Secure: Explicit authorization
  policy action(:update_translations) do
    authorize_if actor_attribute_equals(:role, :translator)
    authorize_if actor_attribute_equals(:role, :admin)
  end
  
  # Secure: Locale-specific access
  policy action(:update_translation) do
    authorize_if expr(
      ^actor(:role) == :translator and 
      ^context(:locale) in ^actor(:assigned_locales)
    )
  end
end
```

#### Insecure Patterns to Avoid
```elixir
policies do
  # INSECURE: Too permissive
  policy action(:update_translations) do
    authorize_if always()  # Anyone can edit!
  end
  
  # INSECURE: Missing locale validation
  policy action(:update_translation) do
    authorize_if actor_attribute_equals(:role, :user)  # Can edit any locale!
  end
end
```

### 3. Backend Configuration Security

#### Database Backend Security
- Use parameterized queries (handled by Ecto)
- Enable row-level security in PostgreSQL
- Regular security updates for database drivers

#### Gettext Backend Security
- Validate POT/PO file content during import
- Restrict file system access to translation directories
- Use secure file upload handling for translation files

## XSS Prevention

### 1. HTML Escaping

**Default Behavior**: All translation content is HTML-escaped by default through the `t/3` helper function.

```elixir
# This is automatically escaped
<%= t(@product, :name) %>  # Safe even if name contains <script>
```

### 2. Raw HTML Function

**Security Warning**: The `raw_t/3` function bypasses HTML escaping and should only be used with trusted content.

```elixir
def raw_t(resource, field, opts \\ []) do
  # ⚠️  SECURITY WARNING: This function bypasses HTML escaping!
  # - Only use with trusted translation content that you control
  # - Never use with user-generated content
  # - Potential XSS vulnerability if misused
  # - Consider using `t/3` for safe HTML-escaped output instead
  
  content = t(resource, field, opts)
  Phoenix.HTML.raw(content)
end
```

### 3. Content Security Policy

Implement Content Security Policy headers in your Phoenix application:

```elixir
# In your router or controller
plug :put_secure_browser_headers, %{
  "content-security-policy" => "default-src 'self'; script-src 'self' 'unsafe-inline'"
}
```

## Input Validation

### 1. Translation Content Validation

```elixir
# Example validation in your resource
validations do
  validate present([:name_translations])
  validate translation_content_safe(:name_translations)
  validate translation_length(:description_translations, max: 10_000)
end
```

### 2. Locale Validation

```elixir
# Secure locale validation
defp validate_locale(locale) when is_binary(locale) do
  case String.to_existing_atom(locale) do
    valid_locale -> {:ok, valid_locale}
  rescue
    ArgumentError -> {:error, :invalid_locale}
  end
end
```

### 3. File Upload Security

When implementing translation import/export:

```elixir
# Validate file types
allowed_types = ~w(.csv .json .po .pot)
if Path.extname(filename) not in allowed_types do
  {:error, :invalid_file_type}
end

# Validate file size (prevent DoS)
max_size = 10 * 1024 * 1024  # 10MB
if File.stat!(path).size > max_size do
  {:error, :file_too_large}
end
```

## Security Tools

### 1. Sobelow Configuration

Our Sobelow configuration (`.sobelow-conf`) includes:

```elixir
[
  verbose: true,
  exit: "low",  # Exit with error on any vulnerability
  threshold: "low",  # Catch all potential issues
  ignore: [
    # Host application responsibilities
    "Config.CSP", "Config.HTTPS", "Config.Session", 
    "Config.CSRF", "Config.Headers",
    
    # Documented intentional patterns
    "XSS.Raw",      # raw_t function with security warnings
    "DOS.BinToAtom" # Compile-time field names only
  ]
]
```

### 2. CI/CD Security Pipeline

Our GitHub Actions security workflow includes:

1. **Dependency Scanning**: Check for known vulnerabilities
2. **Static Analysis**: Sobelow security analysis
3. **License Compliance**: Verify dependency licenses
4. **Code Quality**: Credo analysis with security rules

### 3. Local Security Testing

Run security checks locally:

```bash
# Full security scan
mix quality

# Individual security checks
mix deps.audit          # Check dependencies
mix sobelow --config    # Security analysis
mix hex.audit          # Check for retired packages
```

## Atom Creation Safety

### Background

Elixir atoms are not garbage collected and can cause memory exhaustion if created dynamically from user input.

### Our Approach

**Secure Pattern**: Use `String.to_existing_atom/1`
```elixir
# Safe: Only converts to existing atoms
defp normalize_locale(locale) when is_binary(locale) do
  try do
    String.to_existing_atom(locale)
  rescue
    ArgumentError -> @default_locale  # Safe fallback
  end
end
```

**Insecure Pattern**: Never use `String.to_atom/1` with user input
```elixir
# NEVER DO THIS - Atom exhaustion attack vector
def bad_locale_conversion(user_input) do
  String.to_atom(user_input)  # Can exhaust atom table!
end
```

### DSL Context Exception

In DSL contexts with compile-time known field names, atom creation is acceptable:

```elixir
# Safe: Field names are compile-time constants
storage_field = :"#{field_name}_translations"  # field_name is known at compile time
```

## Threat Model

### 1. Identified Threats

| Threat | Impact | Mitigation | Status |
|--------|--------|------------|--------|
| XSS via translations | High | HTML escaping, CSP | ✅ Mitigated |
| Atom exhaustion | High | `String.to_existing_atom/1` | ✅ Mitigated |
| SQL injection | Medium | Parameterized queries | ✅ Mitigated |
| DoS via large content | Medium | Input validation, size limits | ✅ Mitigated |
| Unauthorized translation access | Medium | Policy-based authorization | ✅ Mitigated |
| Malicious file upload | Low | File type/size validation | ✅ Mitigated |

### 2. Risk Assessment Matrix

- **Critical**: Memory exhaustion, privilege escalation
- **High**: XSS, data corruption, unauthorized access
- **Medium**: DoS, information disclosure
- **Low**: Configuration issues, logging concerns

### 3. Security Boundaries

- **Trust Boundary**: Host Phoenix application
- **Attack Surface**: Translation content, locale parameters, file uploads
- **Protection Mechanisms**: Input validation, output encoding, access control

## Compliance and Standards

### 1. Security Standards
- OWASP Top 10 Web Application Security Risks
- CWE (Common Weakness Enumeration) categories
- Secure coding practices for Elixir/Phoenix

### 2. Privacy Considerations
- Translation content may contain personally identifiable information
- Implement data retention policies for translation history
- Consider GDPR compliance for user-generated translations

### 3. Audit Requirements
- Security audit logs for translation modifications
- Access control audit trail
- Regular security assessment schedule

---

## Contact Information

- **Security Team**: [security@yourproject.com]
- **General Issues**: [GitHub Issues](https://github.com/raul-gracia/ash_phoenix_translations/issues)
- **Documentation**: [HexDocs](https://hexdocs.pm/ash_phoenix_translations)

Last Updated: 2024-01-01
Version: 1.0.0