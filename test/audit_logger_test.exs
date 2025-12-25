defmodule AshPhoenixTranslations.AuditLoggerTest do
  @moduledoc """
  Comprehensive tests for the security audit logging functionality.

  This test module verifies the audit logging system that tracks security-relevant
  events throughout the translation system.

  ## Test Coverage

  ### Policy Decision Logging
  - Successful policy evaluations (allowed)
  - Failed policy evaluations (denied)
  - Policy decisions with reasons
  - Actor identification (map-based, keyword list, nil)
  - Actor role extraction

  ### Validation Logging
  - Locale validation (success and failure)
  - Field validation (success and failure)
  - Path validation (success and failure)
  - Cache key validation (success and failure)
  - Input validation failures

  ### Rate Limiting
  - Rate limit checks (allowed and denied)
  - Identifier sanitization
  - Long identifier hashing

  ### Authentication Events
  - Authentication successes
  - Authentication failures
  - Actor tracking

  ### CSRF Protection
  - CSRF token validation success
  - CSRF token validation failure

  ### Suspicious Activity
  - Security event detection
  - Severity levels (debug, info, warning, error)
  - Event details logging

  ### Data Sanitization
  - Path sanitization (security-sensitive)
  - Identifier sanitization (prevent log flooding)
  - Value truncation (prevent log flooding)

  ## Why `async: true`

  This test module uses `async: true` because:
  1. **No shared state**: Tests only verify logging behavior
  2. **No ETS tables**: No shared data structures
  3. **Logger isolation**: Logger calls don't interfere between tests
  4. **Independence**: Each test is completely independent

  ## Running Tests

      # Run all audit logger tests
      mix test test/audit_logger_test.exs

      # Run specific test group
      mix test test/audit_logger_test.exs --only describe:"policy decision logging"

      # Run with detailed trace
      mix test test/audit_logger_test.exs --trace

  ## Test Patterns

  ### Capture Log Output
  Tests use ExUnit's capture_log to verify logging behavior:

      import ExUnit.CaptureLog

      log = capture_log(fn ->
        AuditLogger.log_policy_decision(:allowed, actor, action, resource)
      end)

      assert log =~ "result: allowed"
      assert log =~ "actor_id:"

  ### Mock Data Structures
  Tests create minimal mock structures:

      actor = %{id: 123, role: :admin}
      action = %{name: :update}
      resource = MyApp.Product

  ## Security Considerations

  The audit logger implements several security best practices:

  1. **Path Sanitization**: Prevents leaking absolute system paths
  2. **Identifier Hashing**: Prevents log flooding with long identifiers
  3. **Value Truncation**: Prevents log flooding with large values
  4. **Severity Levels**: Appropriate log levels for different events

  ## Related Tests

  - `security/policy_check_test.exs` - Policy enforcement integration
  - `security/rate_limiter_test.exs` - Rate limiting integration
  - `security/csrf_protection_test.exs` - CSRF protection integration
  """

  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias AshPhoenixTranslations.AuditLogger

  # Mock modules for testing
  defmodule MockAction do
    defstruct [:name]
  end

  defmodule MockResource do
  end

  describe "log_policy_decision/5" do
    test "logs allowed policy decision" do
      actor = %{id: 123, role: :admin}
      action = %MockAction{name: :update}
      resource = MockResource

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:allowed, actor, action, resource)
        end)

      assert log =~ "Translation policy decision"
      assert log =~ "result: allowed"
      assert log =~ "actor_id: 123"
      assert log =~ "actor_role: :admin"
      assert log =~ "action: :update"
      assert log =~ "resource: AshPhoenixTranslations.AuditLoggerTest.MockResource"
    end

    test "logs denied policy decision" do
      actor = %{id: 456, role: :user}
      action = %MockAction{name: :delete}
      resource = MockResource

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:denied, actor, action, resource)
        end)

      assert log =~ "Translation policy decision"
      assert log =~ "result: denied"
      assert log =~ "actor_id: 456"
      assert log =~ "actor_role: :user"
      assert log =~ "action: :delete"
    end

    test "logs policy decision with reason" do
      actor = %{id: 789, role: :user}
      action = %MockAction{name: :update}
      resource = MockResource
      reason = "insufficient permissions"

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:denied, actor, action, resource, reason)
        end)

      assert log =~ "Translation policy decision"
      assert log =~ "result: denied"
      assert log =~ "reason: insufficient permissions"
    end

    test "handles nil actor" do
      action = %MockAction{name: :read}
      resource = MockResource

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:allowed, nil, action, resource)
        end)

      assert log =~ "Translation policy decision"
      assert log =~ "actor_id:"
      assert log =~ "actor_role:"
    end

    test "handles keyword list actor" do
      actor = [id: 999, role: :moderator]
      action = %MockAction{name: :create}
      resource = MockResource

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:allowed, actor, action, resource)
        end)

      assert log =~ "Translation policy decision"
      assert log =~ "actor_id: 999"
      assert log =~ "actor_role: :moderator"
    end

    test "handles actor without id or role" do
      actor = %{name: "John"}
      action = %MockAction{name: :read}
      resource = MockResource

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:allowed, actor, action, resource)
        end)

      assert log =~ "Translation policy decision"
      assert log =~ "actor_id: nil"
      assert log =~ "actor_role: nil"
    end

    test "handles boolean result values" do
      actor = %{id: 1, role: :admin}
      action = %MockAction{name: :update}
      resource = MockResource

      log_true =
        capture_log(fn ->
          AuditLogger.log_policy_decision(true, actor, action, resource)
        end)

      log_false =
        capture_log(fn ->
          AuditLogger.log_policy_decision(false, actor, action, resource)
        end)

      assert log_true =~ "result: allowed"
      assert log_false =~ "result: denied"
    end
  end

  describe "log_locale_validation/3" do
    test "logs successful locale validation at debug level" do
      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_locale_validation({:ok, :en}, :en)
        end)

      assert log =~ "Locale validation"
      assert log =~ "result: success"
      assert log =~ "locale: :en"
    end

    test "logs failed locale validation at warning level" do
      log =
        capture_log(fn ->
          AuditLogger.log_locale_validation({:error, :invalid}, :xyz)
        end)

      assert log =~ "Locale validation"
      assert log =~ "result: failure"
      assert log =~ "locale: :xyz"
    end

    test "includes context when provided" do
      context = %{source: :user_input}

      log =
        capture_log(fn ->
          AuditLogger.log_locale_validation({:error, :invalid}, :bad, context)
        end)

      assert log =~ "Locale validation"
      assert log =~ "context: %{source: :user_input}"
    end

    test "handles empty context" do
      log =
        capture_log(fn ->
          AuditLogger.log_locale_validation({:error, :invalid}, :xyz, %{})
        end)

      assert log =~ "Locale validation"
      assert log =~ "context: %{}"
    end
  end

  describe "log_field_validation/4" do
    test "logs successful field validation at debug level" do
      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_field_validation({:ok, :name}, :name, MockResource)
        end)

      assert log =~ "Field validation"
      assert log =~ "result: success"
      assert log =~ "field: :name"
      assert log =~ "resource: AshPhoenixTranslations.AuditLoggerTest.MockResource"
    end

    test "logs failed field validation at warning level" do
      log =
        capture_log(fn ->
          AuditLogger.log_field_validation({:error, :not_found}, :invalid_field, MockResource)
        end)

      assert log =~ "Field validation"
      assert log =~ "result: failure"
      assert log =~ "field: :invalid_field"
    end

    test "includes context when provided" do
      context = %{operation: :import}

      log =
        capture_log(fn ->
          AuditLogger.log_field_validation({:error, :invalid}, :field, MockResource, context)
        end)

      assert log =~ "Field validation"
      assert log =~ "context: %{operation: :import}"
    end
  end

  describe "log_path_validation/4" do
    test "logs successful path validation at info level" do
      log =
        capture_log(fn ->
          AuditLogger.log_path_validation({:ok, "safe/path"}, "safe/path", :read)
        end)

      assert log =~ "Path validation"
      assert log =~ "result: success"
      assert log =~ "path:"
      assert log =~ "operation: read"
    end

    test "logs failed path validation at warning level" do
      log =
        capture_log(fn ->
          AuditLogger.log_path_validation({:error, :traversal}, "../etc/passwd", :read)
        end)

      assert log =~ "Path validation"
      assert log =~ "result: failure"
      assert log =~ "operation: read"
    end

    test "sanitizes long paths" do
      long_path = "/very/long/path/to/some/file/that/should/be/truncated/file.csv"

      log =
        capture_log(fn ->
          AuditLogger.log_path_validation({:ok, long_path}, long_path, :write)
        end)

      assert log =~ "Path validation"
      assert log =~ ".../"
      refute log =~ "/very/long/path/to/some/file"
    end

    test "handles short paths without sanitization" do
      short_path = "data/file.csv"

      log =
        capture_log(fn ->
          AuditLogger.log_path_validation({:ok, short_path}, short_path, :read)
        end)

      assert log =~ "Path validation"
      assert log =~ "data/file.csv"
    end

    test "includes context when provided" do
      context = %{user_id: 123}

      log =
        capture_log(fn ->
          AuditLogger.log_path_validation({:error, :invalid}, "/bad/path", :write, context)
        end)

      assert log =~ "Path validation"
      assert log =~ "context: %{user_id: 123}"
    end

    test "handles non-binary path" do
      log =
        capture_log(fn ->
          AuditLogger.log_path_validation({:error, :invalid}, nil, :read)
        end)

      assert log =~ "Path validation"
      assert log =~ "path: nil"
    end
  end

  describe "log_cache_validation/3" do
    test "logs successful cache validation at debug level" do
      key = {:translation, MockResource, 123, :name, :en}

      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_cache_validation({:ok, key}, key, :get)
        end)

      assert log =~ "Cache key validation"
      assert log =~ "result: success"
      assert log =~ "key_type: translation"
      assert log =~ "operation: get"
    end

    test "logs failed cache validation at warning level" do
      key = "invalid_key"

      log =
        capture_log(fn ->
          AuditLogger.log_cache_validation({:error, :invalid}, key, :put)
        end)

      assert log =~ "Cache key validation"
      assert log =~ "result: failure"
      assert log =~ "key_type: other"
      assert log =~ "operation: put"
    end

    test "identifies tuple key types" do
      tuple_key = {:some, :tuple, :key}

      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_cache_validation({:ok, tuple_key}, tuple_key, :delete)
        end)

      assert log =~ "Cache key validation"
      assert log =~ "key_type: tuple"
    end

    test "identifies translation key types" do
      translation_key = {:translation, MockResource, 456, :description, :es}

      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_cache_validation({:ok, translation_key}, translation_key, :get)
        end)

      assert log =~ "Cache key validation"
      assert log =~ "key_type: translation"
    end
  end

  describe "log_rate_limit/3" do
    test "logs allowed rate limit check at debug level" do
      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_rate_limit({:ok, :allowed}, "user_123", :translation_update)
        end)

      assert log =~ "Rate limit check"
      assert log =~ "result: success"
      assert log =~ "identifier: user_123"
      assert log =~ "operation_type: translation_update"
    end

    test "logs denied rate limit check at warning level" do
      log =
        capture_log(fn ->
          AuditLogger.log_rate_limit({:error, :rate_limited}, "user_456", :import)
        end)

      assert log =~ "Rate limit check"
      assert log =~ "result: failure"
      assert log =~ "identifier: user_456"
      assert log =~ "operation_type: import"
    end

    test "sanitizes long identifiers" do
      long_id = String.duplicate("a", 60)

      log =
        capture_log(fn ->
          AuditLogger.log_rate_limit({:error, :rate_limited}, long_id, :test)
        end)

      assert log =~ "Rate limit check"
      assert log =~ "..."
      assert log =~ "#"
      refute String.contains?(log, long_id)
    end

    test "does not sanitize short identifiers" do
      short_id = "user_123"

      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_rate_limit({:ok, :allowed}, short_id, :test)
        end)

      assert log =~ "Rate limit check"
      assert log =~ "identifier: user_123"
    end

    test "handles non-binary identifier" do
      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_rate_limit({:ok, :allowed}, 12_345, :test)
        end)

      assert log =~ "Rate limit check"
      # Integer is logged without underscore formatting
      assert log =~ "identifier: 12345"
    end
  end

  describe "log_input_validation/4" do
    test "logs input validation failure at warning level" do
      log =
        capture_log(fn ->
          AuditLogger.log_input_validation({:error, :invalid}, :locale, "xyz")
        end)

      assert log =~ "Input validation failed"
      assert log =~ "result: failure"
      assert log =~ "input_type: locale"
      assert log =~ "value: xyz"
    end

    test "truncates long values" do
      long_value = String.duplicate("x", 150)

      log =
        capture_log(fn ->
          AuditLogger.log_input_validation({:error, :too_long}, :text, long_value)
        end)

      assert log =~ "Input validation failed"
      assert log =~ "[truncated]"
      refute String.contains?(log, long_value)
    end

    test "does not truncate short values" do
      short_value = "valid_input"

      log =
        capture_log(fn ->
          AuditLogger.log_input_validation({:error, :invalid}, :field, short_value)
        end)

      assert log =~ "Input validation failed"
      assert log =~ "value: valid_input"
      refute log =~ "[truncated]"
    end

    test "includes context when provided" do
      context = %{field: :name, resource: MockResource}

      log =
        capture_log(fn ->
          AuditLogger.log_input_validation({:error, :invalid}, :translation, "bad", context)
        end)

      assert log =~ "Input validation failed"
      assert log =~ "context:"
      assert log =~ "field: :name"
    end

    test "handles empty context" do
      log =
        capture_log(fn ->
          AuditLogger.log_input_validation({:error, :invalid}, :locale, "xyz", %{})
        end)

      assert log =~ "Input validation failed"
      assert log =~ "context: %{}"
    end

    test "handles non-binary value" do
      log =
        capture_log(fn ->
          AuditLogger.log_input_validation({:error, :invalid}, :number, 12_345)
        end)

      assert log =~ "Input validation failed"
      # Integer is logged without underscore formatting
      assert log =~ "value: 12345"
    end
  end

  describe "log_suspicious_activity/3" do
    test "logs suspicious activity at warning level by default" do
      details = %{ip: "1.2.3.4", attempts: 5}

      log =
        capture_log(fn ->
          AuditLogger.log_suspicious_activity(:brute_force_attempt, details)
        end)

      assert log =~ "Suspicious activity detected"
      assert log =~ "event_type: brute_force_attempt"
      assert log =~ "details:"
      assert log =~ "attempts: 5"
      assert log =~ "ip: \"1.2.3.4\""
      assert log =~ "severity: warning"
    end

    test "logs suspicious activity at error level when specified" do
      details = %{attack_type: :sql_injection}

      log =
        capture_log(fn ->
          AuditLogger.log_suspicious_activity(:attack_detected, details, :error)
        end)

      assert log =~ "Suspicious activity detected"
      assert log =~ "event_type: attack_detected"
      assert log =~ "severity: error"
    end

    test "logs suspicious activity at info level when specified" do
      details = %{user: "anonymous"}

      log =
        capture_log(fn ->
          AuditLogger.log_suspicious_activity(:unusual_pattern, details, :info)
        end)

      assert log =~ "Suspicious activity detected"
      assert log =~ "event_type: unusual_pattern"
      assert log =~ "severity: info"
    end

    test "handles empty details map" do
      log =
        capture_log(fn ->
          AuditLogger.log_suspicious_activity(:unknown_event, %{})
        end)

      assert log =~ "Suspicious activity detected"
      assert log =~ "details: %{}"
    end

    test "handles complex details map" do
      details = %{
        user_id: 123,
        path: "/admin",
        method: "POST",
        payload: %{sensitive: "data"}
      }

      log =
        capture_log(fn ->
          AuditLogger.log_suspicious_activity(:unauthorized_access, details)
        end)

      assert log =~ "Suspicious activity detected"
      assert log =~ "user_id: 123"
      assert log =~ "path: \"/admin\""
    end
  end

  describe "log_auth_event/4" do
    test "logs successful authentication at info level" do
      actor = %{id: 123, role: :user}

      log =
        capture_log(fn ->
          AuditLogger.log_auth_event(:login, actor, MockResource, {:ok, :authenticated})
        end)

      assert log =~ "Authentication event"
      assert log =~ "event_type: login"
      assert log =~ "actor_id: 123"
      assert log =~ "actor_role: user"
      assert log =~ "result: success"
    end

    test "logs failed authentication at warning level" do
      actor = %{id: 456, role: :user}

      log =
        capture_log(fn ->
          AuditLogger.log_auth_event(:login, actor, MockResource, {:error, :invalid_credentials})
        end)

      assert log =~ "Authentication event"
      assert log =~ "event_type: login"
      assert log =~ "actor_id: 456"
      assert log =~ "result: failure"
    end

    test "handles nil actor" do
      log =
        capture_log(fn ->
          AuditLogger.log_auth_event(:anonymous_access, nil, MockResource, {:ok, :allowed})
        end)

      assert log =~ "Authentication event"
      assert log =~ "actor_id:"
      assert log =~ "actor_role:"
    end

    test "handles different event types" do
      actor = %{id: 789, role: :admin}

      logout_log =
        capture_log(fn ->
          AuditLogger.log_auth_event(:logout, actor, MockResource, {:ok, :logged_out})
        end)

      assert logout_log =~ "event_type: logout"

      refresh_log =
        capture_log(fn ->
          AuditLogger.log_auth_event(:token_refresh, actor, MockResource, {:ok, :refreshed})
        end)

      assert refresh_log =~ "event_type: token_refresh"
    end

    test "includes resource information" do
      actor = %{id: 123, role: :user}

      log =
        capture_log(fn ->
          AuditLogger.log_auth_event(:access, actor, MockResource, {:ok, :granted})
        end)

      assert log =~ "Authentication event"
      assert log =~ "resource: AshPhoenixTranslations.AuditLoggerTest.MockResource"
    end
  end

  describe "log_csrf_validation/2" do
    test "logs successful CSRF validation at debug level" do
      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_csrf_validation(:ok)
        end)

      assert log =~ "CSRF token validation"
      assert log =~ "result: success"
    end

    test "logs failed CSRF validation at warning level" do
      log =
        capture_log(fn ->
          AuditLogger.log_csrf_validation(:error)
        end)

      assert log =~ "CSRF token validation"
      assert log =~ "result: failure"
    end

    test "includes context when provided" do
      context = %{action: :update, ip: "1.2.3.4"}

      log =
        capture_log(fn ->
          AuditLogger.log_csrf_validation(:error, context)
        end)

      assert log =~ "CSRF token validation"
      assert log =~ "context:"
      assert log =~ "action: :update"
      assert log =~ "ip: \"1.2.3.4\""
    end

    test "handles empty context" do
      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_csrf_validation(:ok, %{})
        end)

      assert log =~ "CSRF token validation"
      assert log =~ "context: %{}"
    end
  end

  describe "result status conversion" do
    test "converts {:ok, _} tuples to success" do
      log =
        capture_log(fn ->
          AuditLogger.log_locale_validation({:ok, :en}, :en)
        end)

      assert log =~ "result: success"
    end

    test "converts {:error, _} tuples to failure" do
      log =
        capture_log(fn ->
          AuditLogger.log_locale_validation({:error, :invalid}, :xyz)
        end)

      assert log =~ "result: failure"
    end

    test "converts :ok atom to success" do
      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_csrf_validation(:ok)
        end)

      assert log =~ "result: success"
    end

    test "converts :error atom to failure" do
      log =
        capture_log(fn ->
          AuditLogger.log_csrf_validation(:error)
        end)

      assert log =~ "result: failure"
    end

    test "converts true to allowed" do
      actor = %{id: 1, role: :admin}
      action = %MockAction{name: :read}

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(true, actor, action, MockResource)
        end)

      assert log =~ "result: allowed"
    end

    test "converts false to denied" do
      actor = %{id: 1, role: :user}
      action = %MockAction{name: :delete}

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(false, actor, action, MockResource)
        end)

      assert log =~ "result: denied"
    end

    test "converts atom to string" do
      actor = %{id: 1, role: :admin}
      action = %MockAction{name: :read}

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:custom_result, actor, action, MockResource)
        end)

      assert log =~ "result: custom_result"
    end

    test "inspects other values" do
      actor = %{id: 1, role: :admin}
      action = %MockAction{name: :read}

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision({:custom, :tuple}, actor, action, MockResource)
        end)

      assert log =~ "result:"
    end
  end

  describe "data sanitization" do
    test "sanitizes long paths to prevent info leakage" do
      long_path = "/usr/local/very/long/path/to/some/directory/file.csv"

      log =
        capture_log(fn ->
          AuditLogger.log_path_validation({:ok, long_path}, long_path, :read)
        end)

      assert log =~ ".../"
      refute log =~ "/usr/local"
    end

    test "does not sanitize short paths" do
      short_path = "data/file.csv"

      log =
        capture_log(fn ->
          AuditLogger.log_path_validation({:ok, short_path}, short_path, :read)
        end)

      assert log =~ "data/file.csv"
      refute log =~ ".../"
    end

    test "hashes long identifiers to prevent log flooding" do
      long_identifier = String.duplicate("x", 60)

      log =
        capture_log(fn ->
          AuditLogger.log_rate_limit({:error, :limited}, long_identifier, :test)
        end)

      assert log =~ "..."
      assert log =~ "#"
      # Should contain first 20 chars and hash
      assert log =~ String.slice(long_identifier, 0..20)
    end

    test "does not hash short identifiers" do
      short_identifier = "user_123"

      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_rate_limit({:ok, :allowed}, short_identifier, :test)
        end)

      assert log =~ "identifier: user_123"
      refute log =~ "..."
      refute log =~ "#"
    end

    test "truncates long values to prevent log flooding" do
      long_value = String.duplicate("x", 150)

      log =
        capture_log(fn ->
          AuditLogger.log_input_validation({:error, :invalid}, :text, long_value)
        end)

      assert log =~ "[truncated]"
      assert log =~ String.slice(long_value, 0..100)
      refute String.contains?(log, long_value)
    end

    test "does not truncate short values" do
      short_value = "normal value"

      log =
        capture_log(fn ->
          AuditLogger.log_input_validation({:error, :invalid}, :field, short_value)
        end)

      assert log =~ "value: normal value"
      refute log =~ "[truncated]"
    end
  end

  describe "actor extraction" do
    test "extracts id and role from map actor" do
      actor = %{id: 123, role: :admin, name: "John"}
      action = %MockAction{name: :read}

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:allowed, actor, action, MockResource)
        end)

      assert log =~ "actor_id: 123"
      assert log =~ "actor_role: :admin"
    end

    test "extracts id and role from keyword list actor" do
      actor = [id: 456, role: :user, email: "user@example.com"]
      action = %MockAction{name: :update}

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:allowed, actor, action, MockResource)
        end)

      assert log =~ "actor_id: 456"
      assert log =~ "actor_role: :user"
    end

    test "handles actor with missing id" do
      actor = %{role: :guest}
      action = %MockAction{name: :read}

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:allowed, actor, action, MockResource)
        end)

      assert log =~ "actor_id: nil"
      assert log =~ "actor_role: :guest"
    end

    test "handles actor with missing role" do
      actor = %{id: 789}
      action = %MockAction{name: :read}

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:allowed, actor, action, MockResource)
        end)

      assert log =~ "actor_id: 789"
      assert log =~ "actor_role: nil"
    end

    test "handles nil actor" do
      action = %MockAction{name: :read}

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:allowed, nil, action, MockResource)
        end)

      assert log =~ "actor_id:"
      assert log =~ "actor_role:"
    end

    test "handles non-map non-list actor" do
      action = %MockAction{name: :read}

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:allowed, "invalid_actor", action, MockResource)
        end)

      assert log =~ "actor_id: nil"
      assert log =~ "actor_role: nil"
    end
  end

  describe "integration scenarios" do
    test "logs complete policy decision flow" do
      actor = %{id: 100, role: :admin}
      action = %MockAction{name: :update_translation}
      resource = MockResource

      log =
        capture_log(fn ->
          # Simulate policy check
          AuditLogger.log_policy_decision(:allowed, actor, action, resource)

          # Simulate field validation
          AuditLogger.log_field_validation({:ok, :name}, :name, resource)

          # Simulate locale validation
          AuditLogger.log_locale_validation({:ok, :en}, :en)

          # Simulate rate limit check
          AuditLogger.log_rate_limit({:ok, :allowed}, "user_100", :translation_update)
        end)

      assert log =~ "Translation policy decision"
      assert log =~ "Field validation"
      assert log =~ "Locale validation"
      assert log =~ "Rate limit check"
    end

    test "logs security incident flow" do
      actor = %{id: 999, role: :user}
      action = %MockAction{name: :delete_all}

      log =
        capture_log(fn ->
          # Suspicious activity detected
          AuditLogger.log_suspicious_activity(
            :unauthorized_bulk_delete,
            %{user_id: 999, action: :delete_all},
            :error
          )

          # Policy denies access
          AuditLogger.log_policy_decision(
            :denied,
            actor,
            action,
            MockResource,
            "insufficient permissions"
          )

          # Rate limiter triggers
          AuditLogger.log_rate_limit({:error, :rate_limited}, "user_999", :bulk_delete)
        end)

      assert log =~ "Suspicious activity detected"
      assert log =~ "Translation policy decision"
      assert log =~ "result: denied"
      assert log =~ "Rate limit check"
      assert log =~ "result: failure"
    end

    test "logs validation failure cascade" do
      log =
        capture_log(fn ->
          # Invalid locale
          AuditLogger.log_locale_validation({:error, :invalid}, :xyz)

          # Invalid field
          AuditLogger.log_field_validation({:error, :not_found}, :bad_field, MockResource)

          # Input validation failure
          AuditLogger.log_input_validation({:error, :invalid_format}, :translation, "invalid<>")

          # Path traversal attempt
          AuditLogger.log_path_validation({:error, :traversal}, "../../etc/passwd", :read)
        end)

      assert log =~ "Locale validation"
      assert log =~ "Field validation"
      assert log =~ "Input validation failed"
      assert log =~ "Path validation"
    end
  end
end
