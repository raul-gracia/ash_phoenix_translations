# AshPhoenixTranslations v1.0.0 Security Assessment

**Assessment Date**: 2025-10-17
**Assessor**: Security Engineering Team
**Assessment Type**: Pre-Release Security Audit
**Scope**: OWASP Top 10, Elixir/Phoenix vulnerabilities, production readiness

---

## Executive Summary

This security assessment identified **1 CRITICAL vulnerability** that MUST be fixed before v1.0.0 release, **3 IMPORTANT security gaps** that should be addressed, and several recommendations for future enhancements. The library demonstrates strong security fundamentals with comprehensive input validation, but has critical flaws in Mix task atom handling that could enable DoS attacks.

### Risk Summary
- **CRITICAL (P0)**: 1 finding - Atom exhaustion vulnerability in Mix export task
- **HIGH (P1)**: 0 findings
- **MEDIUM (P2)**: 3 findings - Missing security controls
- **LOW (P3)**: 5 findings - Defense-in-depth improvements

---

## 🔴 CRITICAL ISSUES (Must Fix for v1.0.0)

### VULN-NEW-001: Atom Exhaustion in Mix Export Task
**Severity**: CRITICAL
**CWE**: CWE-400 (Uncontrolled Resource Consumption)
**OWASP**: A05:2021 – Security Misconfiguration

**Location**: `/lib/mix/tasks/ash_phoenix_translations.export.ex`

**Vulnerable Code**:
```elixir
# Lines 110-112
locales = opts[:locale]
  |> String.split(",")
  |> Enum.map(&String.to_atom/1)  # ❌ UNSAFE

# Lines 121-123
fields = opts[:field]
  |> String.split(",")
  |> Enum.map(&String.to_atom/1)  # ❌ UNSAFE
```

**Impact**:
- Attacker can exhaust BEAM atom table (1M limit) causing VM crash
- Affects all Mix tasks accepting comma-separated locale/field lists
- No authentication required (Mix tasks run with developer privileges)
- Complete denial of service for entire application

**Attack Vector**:
```bash
# Create malicious CSV with 1 million unique locales
mix ash_phoenix_translations.export output.csv \
  --resource Product \
  --locale "$(python -c 'print(",".join([f"loc{i}" for i in range(1000000)]))')"
```

**Proof of Concept**:
```bash
# Generate atom exhaustion attack
for i in {1..1000000}; do
  echo "locale_$RANDOM" >> locales.txt
done

# This will crash the VM
mix ash_phoenix_translations.export test.csv \
  --resource Product \
  --locale "$(cat locales.txt | tr '\n' ',')"
```

**Affected Files**:
1. `/lib/mix/tasks/ash_phoenix_translations.export.ex` (lines 110-112, 121-123)
2. `/lib/mix/tasks/ash_phoenix_translations.validate.ex` (lines 58-60, 67-69)
3. `/lib/mix/tasks/ash_phoenix_translations.extract.ex` (line 34)

**Root Cause**: Direct use of `String.to_atom/1` with user-controlled input bypasses validation layer.

**Fix Required**:
```elixir
# Replace in all affected Mix tasks:
locales = opts[:locale]
  |> String.split(",")
  |> Enum.map(fn locale_str ->
    case AshPhoenixTranslations.LocaleValidator.validate_locale(locale_str) do
      {:ok, locale_atom} -> locale_atom
      {:error, _} ->
        Mix.shell().error("Invalid locale: #{locale_str}")
        nil
    end
  end)
  |> Enum.reject(&is_nil/1)

# Same pattern for fields:
fields = opts[:field]
  |> String.split(",")
  |> Enum.map(fn field_str ->
    try do
      String.to_existing_atom(field_str)
    rescue
      ArgumentError ->
        Mix.shell().error("Invalid field: #{field_str}")
        nil
    end
  end)
  |> Enum.reject(&is_nil/1)
```

**Testing**:
```elixir
# Add test case to security suite
test "export task rejects invalid locales preventing atom exhaustion" do
  # Attempt to create atoms from invalid locales
  invalid_locales = for i <- 1..1000, do: "invalid_#{i}"

  opts = [
    locale: Enum.join(invalid_locales, ","),
    resource: "TestProduct"
  ]

  # Should reject without creating atoms
  assert_raise Mix.Error, fn ->
    Mix.Tasks.AshPhoenixTranslations.Export.run([
      "test.csv",
      "--locale", opts[:locale],
      "--resource", "TestProduct"
    ])
  end

  # Verify no new atoms created
  atom_count_before = :erlang.system_info(:atom_count)
  # Run should fail early without atom creation
  atom_count_after = :erlang.system_info(:atom_count)
  assert atom_count_after - atom_count_before < 10
end
```

---

## 🟡 IMPORTANT SECURITY GAPS (Should Fix for v1.0.0)

### GAP-001: Missing Rate Limiting Implementation
**Severity**: MEDIUM
**CWE**: CWE-770 (Allocation of Resources Without Limits or Throttling)
**OWASP**: A04:2021 – Insecure Design

**Issue**: While `RateLimiter` module exists with comprehensive interface, it's not integrated into critical operations.

**Location**: `/lib/ash_phoenix_translations/rate_limiter.ex` (exists but unused)

**Missing Integration Points**:
1. Translation update actions - no rate limiting on `update_translation`
2. Bulk import operations - no throttling on `import_translations`
3. Cache operations - unlimited cache writes per client
4. API endpoints - JSON API/GraphQL mutations unprotected

**Impact**:
- Attackers can flood translation updates causing database exhaustion
- Bulk import abuse can trigger storage/memory DoS
- Cache pollution attacks without limits
- API abuse enabling resource exhaustion

**Recommended Fix**:
```elixir
# In update_translation change:
defmodule AshPhoenixTranslations.Changes.UpdateTranslation do
  def change(changeset, opts, context) do
    # Add rate limiting
    actor = context[:actor]
    rate_key = "translation_update:#{actor.id}"

    case AshPhoenixTranslations.RateLimiter.check_rate(rate_key, 100, 60) do
      {:ok, _count} ->
        # Proceed with update
        update_database_translation(changeset, attribute, locale, value)

      {:error, :rate_limit_exceeded} ->
        Ash.Changeset.add_error(changeset,
          field: :base,
          message: "Rate limit exceeded. Please try again later."
        )
    end
  end
end
```

**Configuration Needed**:
```elixir
# config/runtime.exs
config :ash_phoenix_translations,
  rate_limits: [
    translation_update: {100, :per_minute},
    translation_import: {10, :per_minute},
    cache_write: {1000, :per_minute},
    api_mutation: {50, :per_minute}
  ]
```

---

### GAP-002: No SQL Injection Protection for JSONB Queries
**Severity**: MEDIUM
**CWE**: CWE-89 (SQL Injection)
**OWASP**: A03:2021 – Injection

**Issue**: Database backend uses JSONB storage but lacks explicit SQL injection protection for dynamic queries.

**Location**: Database backend JSONB operations (implicit in Ash queries)

**Risk Assessment**:
- **Current State**: Ash Framework provides parameterized queries by default
- **Risk**: Custom query construction in future updates could introduce SQL injection
- **Mitigation Status**: Partially protected by framework, needs explicit validation

**Concern Areas**:
1. Translation key construction: `"#{field}_translations"` (safe - atom interpolation)
2. Locale parameter in JSONB queries: `translations->>'locale'` (needs validation)
3. Dynamic field references in queries (if added in future)

**Current Protection**:
```elixir
# Ash automatically parameterizes queries:
Ash.Query.filter(resource, ^ref(field) == ^value)
# Generates safe SQL: SELECT * FROM table WHERE field = $1
```

**Recommended Enhancement**:
```elixir
# Add explicit query validation for JSONB operations
defmodule AshPhoenixTranslations.QueryValidator do
  @doc """
  Validates JSONB query parameters to prevent injection.
  """
  def validate_jsonb_path(field, locale) do
    with {:ok, field_atom} <- validate_field(field),
         {:ok, locale_atom} <- LocaleValidator.validate_locale(locale) do
      # Safe to use in JSONB query
      {:ok, field_atom, locale_atom}
    else
      error -> error
    end
  end

  defp validate_field(field) when is_atom(field), do: {:ok, field}
  defp validate_field(field) when is_binary(field) do
    if Regex.match?(~r/^[a-z][a-z0-9_]*$/, field) do
      try do
        {:ok, String.to_existing_atom(field)}
      rescue
        ArgumentError -> {:error, :invalid_field}
      end
    else
      {:error, :invalid_field_format}
    end
  end
end
```

---

### GAP-003: Incomplete Authorization Bypass Prevention
**Severity**: MEDIUM
**CWE**: CWE-863 (Incorrect Authorization)
**OWASP**: A01:2021 – Broken Access Control

**Issue**: Policy checks exist but lack defense-in-depth for certain edge cases.

**Location**: `/lib/ash_phoenix_translations/policy_check.ex`

**Identified Gaps**:

1. **Missing Locale-Level Authorization Check**:
```elixir
# Current: Translator can edit ANY locale they're assigned
# Problem: No verification that locale in request matches assigned locales
defp check_edit_policy(actor, action, :translator) do
  actor[:role] == :translator
  # ❌ Missing: Verify action.arguments[:locale] in actor[:assigned_locales]
end
```

2. **No Resource-Level Ownership Validation**:
```elixir
# Missing check: Does actor have permission for THIS specific resource instance?
# Current policy only checks role, not resource ownership
```

3. **Custom Policy Module Whitelist Not Enforced by Default**:
```elixir
# Lines 174-176
defp get_allowed_policy_modules do
  Application.get_env(:ash_phoenix_translations, :allowed_policy_modules, [])
  # ❌ Default empty list means NO custom policies allowed
  # But code allows custom policies if whitelisting not configured
end
```

**Recommended Fixes**:

**Fix 1: Locale Authorization Check**:
```elixir
defp check_edit_policy(actor, action, :translator) do
  with true <- is_map(actor),
       :translator <- actor[:role],
       locale when not is_nil(locale) <- action.arguments[:locale],
       assigned when is_list(assigned) <- actor[:assigned_locales],
       true <- locale in assigned,
       # NEW: Verify locale is actually supported
       true <- locale in get_supported_locales(action.resource) do
    true
  else
    _ -> false
  end
end
```

**Fix 2: Resource Ownership Check**:
```elixir
defp check_edit_policy(actor, action, :owner) do
  # Verify actor owns the resource being modified
  record = action.data

  cond do
    is_nil(record) -> false
    record.owner_id != actor[:id] -> false
    true -> true
  end
end
```

**Fix 3: Enforce Custom Policy Whitelist**:
```elixir
defp valid_policy_module?(module) do
  allowed = get_allowed_policy_modules()

  # ENFORCE whitelist - no custom policies if not configured
  if Enum.empty?(allowed) do
    Logger.warning("Custom policy attempted but whitelist empty", module: module)
    false
  else
    module in allowed && Code.ensure_loaded?(module) &&
      function_exported?(module, :authorized?, 3)
  end
end
```

---

## 🟢 SECURITY ENHANCEMENTS (Nice-to-Have)

### ENH-001: Content Security Policy (CSP) Helpers
**Severity**: LOW
**CWE**: CWE-693 (Protection Mechanism Failure)

**Recommendation**: Add CSP helper for HTML translations

```elixir
defmodule AshPhoenixTranslations.CSP do
  @doc """
  Generates CSP nonce for safe inline content.
  """
  def generate_nonce do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end

  def safe_render(content, conn) do
    nonce = generate_nonce()
    conn = put_resp_header(conn, "content-security-policy",
      "script-src 'nonce-#{nonce}' 'strict-dynamic'")

    {:safe, ["<div data-nonce='", nonce, "'>", content, "</div>"]}
  end
end
```

---

### ENH-002: Input Sanitization for Translation Content
**Severity**: LOW
**CWE**: CWE-20 (Improper Input Validation)

**Current**: Translations validated for length and encoding
**Enhancement**: Add content-type specific validation

```elixir
defmodule AshPhoenixTranslations.ContentValidator do
  @doc """
  Validates translation content based on type.
  """
  def validate_content(value, :html) do
    # Stricter validation for HTML content
    with {:ok, _} <- validate_html_structure(value),
         {:ok, _} <- check_dangerous_tags(value),
         {:ok, sanitized} <- HtmlSanitizeEx.basic_html(value) do
      {:ok, sanitized}
    end
  end

  def validate_content(value, :text) do
    # Standard validation for plain text
    InputValidator.validate_translation(value)
  end

  defp check_dangerous_tags(html) do
    dangerous = ~w(script iframe object embed)

    if Enum.any?(dangerous, &String.contains?(html, "<#{&1}")) do
      {:error, :dangerous_tags_detected}
    else
      {:ok, html}
    end
  end
end
```

---

### ENH-003: Audit Log Encryption for Sensitive Data
**Severity**: LOW
**CWE**: CWE-311 (Missing Encryption of Sensitive Data)

**Current**: Audit logs stored in plain text
**Enhancement**: Encrypt sensitive audit log fields

```elixir
defmodule AshPhoenixTranslations.AuditEncryption do
  @secret Application.compile_env(:ash_phoenix_translations, :audit_secret)

  def encrypt_audit_data(data) do
    :crypto.crypto_one_time(
      :aes_256_gcm,
      @secret,
      generate_iv(),
      Jason.encode!(data),
      true
    )
  end
end
```

---

### ENH-004: JSONB Column Encryption at Rest
**Severity**: LOW
**CWE**: CWE-311 (Missing Encryption of Sensitive Data)

**Recommendation**: Add optional encryption for sensitive translations

```elixir
# In resource definition:
translations do
  translatable_attribute :ssn, :string,
    locales: [:en],
    encrypted: true  # Enable field-level encryption
end
```

---

### ENH-005: Security Headers for API Responses
**Severity**: LOW
**CWE**: CWE-693 (Protection Mechanism Failure)

**Recommendation**: Add security headers plug for API endpoints

```elixir
defmodule AshPhoenixTranslations.SecurityHeaders do
  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("strict-transport-security",
         "max-age=31536000; includeSubDomains")
  end
end
```

---

## Security Test Coverage Analysis

### ✅ Well-Tested Areas
1. **Atom Exhaustion Prevention**: 100 malicious locale inputs tested
2. **Input Validation**: Comprehensive tests for LocaleValidator and InputValidator
3. **XSS Protection**: HtmlSanitizeEx integration tested
4. **Path Traversal**: PathValidator prevents directory traversal
5. **Policy Authorization**: Audit logging for all policy decisions

### ⚠️ Areas Needing More Tests
1. **Race Conditions**: No tests for concurrent translation updates
2. **Cache Tampering**: Limited tests for cache signature verification
3. **API Injection**: No tests for GraphQL/JSON API injection attempts
4. **CSV Injection**: Formula injection prevention needs integration tests

### Recommended Test Additions

```elixir
defmodule AshPhoenixTranslations.SecurityIntegrationTest do
  test "prevents race condition in concurrent translation updates" do
    # Spawn multiple processes updating same translation
    tasks = for i <- 1..100 do
      Task.async(fn ->
        update_translation(product, :name, :en, "Value #{i}")
      end)
    end

    results = Task.await_many(tasks)

    # Verify data integrity - no lost updates
    assert length(Enum.uniq(results)) == 1
  end

  test "detects and rejects CSV formula injection" do
    malicious_csv = """
    resource_id,field,locale,value
    123,name,en,"=1+1"
    124,name,en,"+cmd|'/c calc'"
    125,name,en,"-2+3"
    126,name,en,"@SUM(A1:A10)"
    """

    # Import should sanitize formulas
    result = import_csv(malicious_csv)

    assert result.imported == 4

    # Verify formulas are escaped
    for product <- loaded_products do
      assert String.starts_with?(product.name, "'")
    end
  end
end
```

---

## OWASP Top 10 Compliance

### A01:2021 – Broken Access Control ✅
- **Status**: GOOD with improvements needed
- **Implementation**: Policy-based authorization with audit logging
- **Gap**: Missing resource-level ownership checks (GAP-003)

### A02:2021 – Cryptographic Failures ⚠️
- **Status**: ACCEPTABLE for v1.0.0
- **Implementation**: Cache value signing, HTTPS for production
- **Gap**: No encryption at rest for sensitive translations (ENH-004)

### A03:2021 – Injection ✅
- **Status**: GOOD
- **Implementation**: Parameterized queries, input validation, XSS protection
- **Gap**: Missing explicit JSONB query validation (GAP-002)

### A04:2021 – Insecure Design ⚠️
- **Status**: NEEDS IMPROVEMENT
- **Implementation**: Security-first architecture with validators
- **Gap**: Missing rate limiting integration (GAP-001)

### A05:2021 – Security Misconfiguration 🔴
- **Status**: CRITICAL ISSUE
- **Implementation**: Secure defaults, fail-closed policies
- **Gap**: Atom exhaustion in Mix tasks (VULN-NEW-001)

### A06:2021 – Vulnerable and Outdated Components ✅
- **Status**: GOOD
- **Implementation**: Modern dependencies, Ash Framework 3.5+
- **Recommendation**: Regular dependency audits with `mix audit`

### A07:2021 – Identification and Authentication Failures ✅
- **Status**: GOOD
- **Implementation**: Delegates to parent application, CSRF protection
- **Note**: Authentication is application responsibility

### A08:2021 – Software and Data Integrity Failures ✅
- **Status**: GOOD
- **Implementation**: Cache signature verification, audit logging
- **Enhancement**: Add code signing for releases (ENH-003)

### A09:2021 – Security Logging and Monitoring Failures ✅
- **Status**: EXCELLENT
- **Implementation**: Comprehensive audit logging via AuditLogger
- **Strength**: All security events logged with sanitization

### A10:2021 – Server-Side Request Forgery (SSRF) ✅
- **Status**: NOT APPLICABLE
- **Reason**: No external HTTP requests in library functionality

---

## Elixir/Phoenix Specific Vulnerabilities

### Atom Exhaustion Protection ⚠️
- **Status**: CRITICAL issue in Mix tasks (VULN-NEW-001)
- **Good**: Web layer uses String.to_existing_atom/1 consistently
- **Bad**: Mix tasks use String.to_atom/1 without validation

### ETS Table Security ✅
- **Status**: GOOD
- **Implementation**: Public tables with read concurrency, validated keys
- **Protection**: Cache key validation prevents poisoning

### Process Dictionary Misuse ✅
- **Status**: NOT APPLICABLE
- **Reason**: No process dictionary usage in library

### Erlang Binary Injection ✅
- **Status**: GOOD
- **Implementation**: Binary operations use safe Elixir functions
- **Protection**: :erlang.binary_to_term/2 uses [:safe] flag

---

## Production Deployment Checklist

### Required for v1.0.0 Launch
- [ ] **CRITICAL**: Fix atom exhaustion in Mix tasks (VULN-NEW-001)
- [ ] Configure rate limiting for translation operations (GAP-001)
- [ ] Add explicit SQL injection prevention docs (GAP-002)
- [ ] Enhance authorization checks for translators (GAP-003)
- [ ] Set up security monitoring and alerting
- [ ] Configure `allowed_policy_modules` whitelist
- [ ] Generate cache_secret from secure random source
- [ ] Enable HTTPS-only in production (use HSTS)
- [ ] Set up log aggregation for audit logs

### Configuration Template
```elixir
# config/runtime.exs
config :ash_phoenix_translations,
  # SECURITY: Generate with: :crypto.strong_rand_bytes(32) |> Base.encode64()
  cache_secret: System.fetch_env!("TRANSLATION_CACHE_SECRET"),

  # SECURITY: Whitelist only trusted policy modules
  allowed_policy_modules: [
    MyApp.Policies.TranslationPolicy,
    MyApp.Policies.AdminPolicy
  ],

  # SECURITY: Rate limiting configuration
  rate_limits: [
    translation_update: {100, :per_minute},
    translation_import: {10, :per_minute},
    api_mutation: {50, :per_minute}
  ],

  # SECURITY: Audit log retention
  audit_retention_days: 90,

  # SECURITY: File operation limits
  max_file_size: 10_000_000,  # 10MB
  import_directory: "/var/app/imports",

  # SECURITY: Supported locales (prevents atom exhaustion)
  supported_locales: [:en, :es, :fr, :de, :it, :pt, :ja, :zh, :ko, :ar, :ru]
```

---

## Responsible Disclosure

If you discover a security vulnerability in this library:

1. **DO NOT** create a public GitHub issue
2. Email security contact: [security@yourcompany.com]
3. Include:
   - Vulnerability description
   - Steps to reproduce
   - Impact assessment
   - Suggested fix (if any)
4. Expect response within 48 hours
5. Allow 90 days for patch before public disclosure

---

## Conclusion

AshPhoenixTranslations demonstrates strong security fundamentals with comprehensive input validation and authorization controls. However, the **CRITICAL atom exhaustion vulnerability in Mix tasks MUST be fixed before v1.0.0 release**.

### Release Recommendation

**DO NOT RELEASE v1.0.0** until VULN-NEW-001 is fixed. After fixing:

1. Fix VULN-NEW-001 (atom exhaustion in Mix tasks) - **MANDATORY**
2. Implement rate limiting (GAP-001) - **STRONGLY RECOMMENDED**
3. Add explicit SQL injection docs (GAP-002) - **RECOMMENDED**
4. Enhance authorization checks (GAP-003) - **RECOMMENDED**
5. Add security test coverage - **RECOMMENDED**

### Post-Release Monitoring

Monitor for:
- Unusual atom table growth (`erlang:system_info(:atom_count)`)
- Authorization bypass attempts in audit logs
- Rate limit violations
- Cache signature verification failures
- Path traversal attempts

---

**Assessment Completed**: 2025-10-17
**Next Review**: After VULN-NEW-001 fix + before v1.0.0 release
**Classification**: SECURITY-SENSITIVE / CONFIDENTIAL
