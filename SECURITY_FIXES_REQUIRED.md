# Security Fixes Required for v1.0.0 Release

**Status**: 🔴 **BLOCKER** - Critical vulnerability found
**Action Required**: Fix VULN-NEW-001 before release

---

## 🔴 BLOCKER: Critical Atom Exhaustion Vulnerability

### Issue
Mix tasks use unsafe `String.to_atom/1` with user input, allowing attackers to exhaust the BEAM atom table and crash the application.

### Affected Files
1. `lib/mix/tasks/ash_phoenix_translations.export.ex` (lines 110-112, 121-123)
2. `lib/mix/tasks/ash_phoenix_translations.validate.ex` (lines 58-60, 67-69)
3. `lib/mix/tasks/ash_phoenix_translations.extract.ex` (line 34)

### Attack Example
```bash
# This will crash your VM
mix ash_phoenix_translations.export out.csv \
  --resource Product \
  --locale "$(for i in {1..100000}; do echo -n "loc$i,"; done)"
```

### Fix Implementation

Replace ALL instances of this pattern:

**BEFORE (Unsafe)**:
```elixir
locales = opts[:locale]
  |> String.split(",")
  |> Enum.map(&String.to_atom/1)  # ❌ UNSAFE
```

**AFTER (Safe)**:
```elixir
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

if Enum.empty?(locales) do
  Mix.raise("No valid locales provided")
end
```

### Files to Modify

#### 1. `lib/mix/tasks/ash_phoenix_translations.export.ex`

**Location 1** (lines 108-116):
```elixir
filters =
  if opts[:locale] do
    locales =
      opts[:locale]
      |> String.split(",")
      |> Enum.map(fn locale_str ->
        case AshPhoenixTranslations.LocaleValidator.validate_locale(String.trim(locale_str)) do
          {:ok, locale_atom} -> locale_atom
          {:error, _} ->
            Mix.shell().error("Skipping invalid locale: #{locale_str}")
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(locales) do
      Mix.shell().error("No valid locales found")
      filters
    else
      Map.put(filters, :locales, locales)
    end
  else
    filters
  end
```

**Location 2** (lines 119-129):
```elixir
filters =
  if opts[:field] do
    fields =
      opts[:field]
      |> String.split(",")
      |> Enum.map(fn field_str ->
        trimmed = String.trim(field_str)
        try do
          String.to_existing_atom(trimmed)
        rescue
          ArgumentError ->
            Mix.shell().error("Skipping invalid field: #{field_str}")
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(fields) do
      Mix.shell().error("No valid fields found")
      filters
    else
      Map.put(filters, :fields, fields)
    end
  else
    filters
  end
```

#### 2. `lib/mix/tasks/ash_phoenix_translations.validate.ex`

Apply same pattern to:
- Lines 58-60 (locale parsing)
- Lines 67-69 (field parsing)

#### 3. `lib/mix/tasks/ash_phoenix_translations.extract.ex`

**Line 34**:
```elixir
# BEFORE
format: String.to_atom(opts[:format] || "pot")

# AFTER
format: case opts[:format] || "pot" do
  format when format in ["pot", "po", "json"] ->
    String.to_existing_atom(format)
  invalid ->
    Mix.raise("Invalid format: #{invalid}. Allowed: pot, po, json")
end
```

### Testing

Add this test to verify the fix:

```elixir
# test/security/atom_exhaustion_mix_test.exs
defmodule AshPhoenixTranslations.AtomExhaustionMixTest do
  use ExUnit.Case

  describe "Mix task atom exhaustion prevention" do
    test "export task rejects invalid locales" do
      # Create 1000 invalid locale strings
      invalid_locales = for i <- 1..1000, do: "malicious_locale_#{i}"
      locale_string = Enum.join(invalid_locales, ",")

      # Capture output
      ExUnit.CaptureIO.capture_io(fn ->
        assert_raise Mix.Error, fn ->
          Mix.Tasks.AshPhoenixTranslations.Export.run([
            "test.csv",
            "--resource", "TestProduct",
            "--locale", locale_string
          ])
        end
      end)

      # Verify no atoms were created (allow small margin for legitimate atoms)
      atom_count = :erlang.system_info(:atom_count)
      # Should not have created 1000 new atoms
      assert atom_count < 500_000  # Well below 1M limit
    end

    test "validate task rejects invalid fields" do
      invalid_fields = for i <- 1..1000, do: "field_#{:rand.uniform(1_000_000)}"
      field_string = Enum.join(invalid_fields, ",")

      atom_count_before = :erlang.system_info(:atom_count)

      ExUnit.CaptureIO.capture_io(fn ->
        assert_raise Mix.Error, fn ->
          Mix.Tasks.AshPhoenixTranslations.Validate.run([
            "--resource", "TestProduct",
            "--field", field_string
          ])
        end
      end)

      atom_count_after = :erlang.system_info(:atom_count)

      # Should not have created significant atoms
      assert (atom_count_after - atom_count_before) < 10
    end

    test "extract task validates format parameter" do
      assert_raise Mix.Error, ~r/Invalid format/, fn ->
        Mix.Tasks.AshPhoenixTranslations.Extract.run([
          "--format", "malicious_format_#{:rand.uniform(1_000_000)}"
        ])
      end
    end
  end
end
```

---

## 🟡 Important Security Improvements (Strongly Recommended)

### 1. Integrate Rate Limiting

**Why**: Prevent abuse of translation operations and bulk imports.

**Files to Modify**:
- `lib/ash_phoenix_translations/changes/update_translation.ex`
- `lib/ash_phoenix_translations/changes/import_translations.ex`

**Implementation**:
```elixir
# In UpdateTranslation.change/3
def change(changeset, opts, context) do
  actor = context[:actor]

  # Add rate limiting
  if actor do
    rate_key = "translation_update:#{actor.id}"

    case AshPhoenixTranslations.RateLimiter.check_rate(rate_key, 100, 60) do
      {:ok, _count} ->
        # Proceed with update
        perform_update(changeset, opts, context)

      {:error, :rate_limit_exceeded} ->
        Ash.Changeset.add_error(changeset,
          field: :base,
          message: "Rate limit exceeded. Maximum 100 updates per minute."
        )
    end
  else
    perform_update(changeset, opts, context)
  end
end

defp perform_update(changeset, opts, _context) do
  # Existing update logic
end
```

### 2. Fix Translator Authorization Check

**Why**: Ensure translators can only edit locales they're assigned to.

**File**: `lib/ash_phoenix_translations/policy_check.ex`

**Change** (lines 97-115):
```elixir
defp check_edit_policy(actor, action, :translator) do
  # SECURITY: Strict validation for translator role
  with true <- is_map(actor),
       :translator <- actor[:role],
       locale when not is_nil(locale) <- action.arguments[:locale],
       assigned when is_list(assigned) <- actor[:assigned_locales],
       true <- locale in assigned,
       # NEW: Verify locale is supported by resource
       resource_locales <- get_resource_locales(action.resource),
       true <- locale in resource_locales do
    true
  else
    error ->
      Logger.warning("Translator edit authorization failed",
        actor_role: actor[:role],
        requested_locale: action.arguments[:locale],
        assigned_locales: actor[:assigned_locales],
        reason: inspect(error)
      )

      false
  end
end

# Add helper function
defp get_resource_locales(resource) do
  resource
  |> AshPhoenixTranslations.Info.supported_locales()
  |> List.wrap()
end
```

### 3. Add SQL Injection Prevention Documentation

**Why**: Ensure developers understand JSONB query safety.

**File**: Create `guides/security.md`

**Content**:
````markdown
# Security Best Practices

## SQL Injection Prevention

### Database Backend Safety

The database backend uses JSONB columns to store translations. While Ash Framework provides automatic query parameterization, follow these guidelines:

#### Safe Query Patterns

```elixir
# ✅ SAFE: Using Ash query builders
Ash.Query.filter(Product, name == ^user_input)

# ✅ SAFE: Validated locale atoms
locale = validate_locale!(user_locale)
Ash.Query.filter(Product, fragment("? ->> ? IS NOT NULL",
  name_translations, ^Atom.to_string(locale)))
```

#### Unsafe Patterns to Avoid

```elixir
# ❌ UNSAFE: String interpolation in queries
Ash.Query.filter(Product, fragment("name_translations ->> '#{locale}'"))

# ❌ UNSAFE: Unvalidated field names
field = String.to_atom(user_input)  # Atom exhaustion!
```

#### Validation Requirements

Always validate before JSONB operations:

```elixir
defmodule MyApp.TranslationQuery do
  def get_translation(resource_id, field, locale) do
    # 1. Validate field exists
    with {:ok, field_atom} <- validate_field(field),
         # 2. Validate locale is supported
         {:ok, locale_atom} <- validate_locale(locale),
         # 3. Build safe query
         {:ok, record} <- Ash.get(Product, resource_id) do

      storage_field = :"#{field_atom}_translations"
      Map.get(record, storage_field, %{})
      |> Map.get(locale_atom)
    end
  end

  defp validate_field(field) do
    # Only allow existing atoms
    try do
      atom = String.to_existing_atom(field)
      {:ok, atom}
    rescue
      ArgumentError -> {:error, :invalid_field}
    end
  end

  defp validate_locale(locale) do
    AshPhoenixTranslations.LocaleValidator.validate_locale(locale)
  end
end
```
````

---

## Verification Steps

After implementing fixes:

### 1. Manual Testing
```bash
# Test 1: Verify invalid locales are rejected
mix ash_phoenix_translations.export test.csv \
  --resource Product \
  --locale "invalid1,invalid2,en,invalid3"
# Should show errors but not crash

# Test 2: Verify large input is handled
mix ash_phoenix_translations.export test.csv \
  --resource Product \
  --locale "$(for i in {1..10000}; do echo -n "loc$i,"; done)"
# Should reject without creating atoms

# Test 3: Verify format validation
mix ash_phoenix_translations.extract --format "malicious_format"
# Should show clear error message
```

### 2. Automated Testing
```bash
# Run security test suite
mix test test/security/

# Run atom exhaustion tests specifically
mix test test/security/atom_exhaustion_mix_test.exs

# Verify test coverage
mix test --cover
```

### 3. Integration Testing
```bash
# Start application
iex -S mix

# Check atom count before
iex> before = :erlang.system_info(:atom_count)

# Attempt malicious operation
iex> Mix.Tasks.AshPhoenixTranslations.Export.run([
  "test.csv",
  "--resource", "Product",
  "--locale", Enum.join((1..1000 |> Enum.map(&"loc#{&1}")), ",")
])

# Check atom count after
iex> after = :erlang.system_info(:atom_count)
iex> after - before < 10  # Should be true
```

---

## Pre-Release Checklist

- [ ] Fix all atom exhaustion vulnerabilities (VULN-NEW-001)
- [ ] Add security tests for Mix tasks
- [ ] Implement rate limiting for translation operations
- [ ] Fix translator locale authorization check
- [ ] Add SQL injection prevention documentation
- [ ] Update CHANGELOG.md with security fixes
- [ ] Update documentation with security best practices
- [ ] Run full security test suite
- [ ] Verify no regression in functionality
- [ ] Generate new cache_secret for production
- [ ] Configure allowed_policy_modules whitelist

---

## Post-Fix Validation

After implementing fixes, verify:

```elixir
# test/post_fix_validation_test.exs
defmodule PostFixValidationTest do
  use ExUnit.Case

  test "all Mix tasks use safe atom conversion" do
    mix_task_files = Path.wildcard("lib/mix/tasks/*.ex")

    for file <- mix_task_files do
      content = File.read!(file)

      # Should NOT contain unsafe String.to_atom/1 calls
      refute content =~ ~r/String\.to_atom\(/,
        "Found unsafe String.to_atom in #{file}"

      # Should use LocaleValidator or String.to_existing_atom
      if content =~ ~r/locale/ do
        assert content =~ ~r/LocaleValidator\.validate_locale/ or
               content =~ ~r/String\.to_existing_atom/,
          "#{file} handles locales but doesn't use safe validation"
      end
    end
  end

  test "rate limiter is integrated in critical operations" do
    update_change = File.read!("lib/ash_phoenix_translations/changes/update_translation.ex")

    assert update_change =~ ~r/RateLimiter/,
      "UpdateTranslation change should use RateLimiter"
  end

  test "policy check validates translator locales" do
    policy_check = File.read!("lib/ash_phoenix_translations/policy_check.ex")

    assert policy_check =~ ~r/locale in assigned/,
      "PolicyCheck should verify locale assignment"
  end
end
```

---

## Release Notes Template

```markdown
## v1.0.0 - Security Release

### 🔒 Security Fixes

**CRITICAL**: Fixed atom exhaustion vulnerability in Mix tasks (VULN-NEW-001)
- Mix tasks now use `LocaleValidator.validate_locale/1` instead of `String.to_atom/1`
- Prevents attackers from exhausting atom table and crashing application
- Affects: `export`, `validate`, and `extract` Mix tasks
- **Action Required**: If you use these Mix tasks in production scripts, verify they still work with your locale lists

### ✨ Security Enhancements

- Added rate limiting integration for translation operations
- Enhanced translator authorization to verify locale assignment
- Added SQL injection prevention documentation
- Comprehensive security test suite

### 📚 Documentation

- New security best practices guide
- Added SECURITY_ASSESSMENT_v1.0.0.md with full audit results
- Updated configuration examples with security recommendations

### ⚠️ Breaking Changes

None - all changes are backward compatible.

### 🎯 Upgrade Instructions

1. Update dependency: `{:ash_phoenix_translations, "~> 1.0.0"}`
2. Configure rate limiting (optional but recommended):
   ```elixir
   config :ash_phoenix_translations,
     rate_limits: [
       translation_update: {100, :per_minute},
       translation_import: {10, :per_minute}
     ]
   ```
3. Configure custom policy whitelist if using custom policies:
   ```elixir
   config :ash_phoenix_translations,
     allowed_policy_modules: [
       MyApp.Policies.TranslationPolicy
     ]
   ```
```

---

**Priority**: 🔴 **P0 - CRITICAL**
**Timeline**: Fix before any v1.0.0 release
**Estimated Effort**: 2-4 hours for fixes + 2 hours for testing
