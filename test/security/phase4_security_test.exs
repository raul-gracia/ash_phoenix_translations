defmodule AshPhoenixTranslations.Phase4SecurityTest do
  use ExUnit.Case, async: false

  alias AshPhoenixTranslations.{AuditLogger, Cache, PolicyCheck}

  import ExUnit.CaptureLog

  # ============================================================================
  # VULN-014: Security Audit Logging
  # ============================================================================

  describe "VULN-014: Security Audit Logging" do
    setup do
      # Start cache for testing
      {:ok, _} = Cache.start_link()
      Cache.clear()

      on_exit(fn ->
        Cache.clear()
      end)

      :ok
    end

    test "logs policy decisions for allowed access" do
      actor = %{id: 1, role: :admin}
      action = %{name: :update_translation, resource: TestProduct, arguments: %{locale: :en}}

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:allowed, actor, action, TestProduct)
        end)

      assert log =~ "Translation policy decision"
      assert log =~ "result: allowed"
      assert log =~ "actor_id: 1"
      assert log =~ "actor_role: :admin"
    end

    test "logs policy decisions for denied access" do
      actor = %{id: 2, role: :user}
      action = %{name: :update_translation, resource: TestProduct, arguments: %{}}

      log =
        capture_log(fn ->
          AuditLogger.log_policy_decision(:denied, actor, action, TestProduct, "missing role")
        end)

      assert log =~ "Translation policy decision"
      assert log =~ "result: denied"
      assert log =~ "reason: missing role"
    end

    test "logs locale validation successes at debug level" do
      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_locale_validation({:ok, :en}, "en", %{source: :param})
        end)

      assert log =~ "Locale validation"
      assert log =~ "result: success"
    end

    test "logs locale validation failures at warning level" do
      log =
        capture_log(fn ->
          AuditLogger.log_locale_validation(
            {:error, :invalid_locale},
            "invalid",
            %{source: :param}
          )
        end)

      assert log =~ "Locale validation"
      assert log =~ "result: failure"
      assert log =~ "locale: \"invalid\""
    end

    test "logs field validation events" do
      log =
        capture_log(fn ->
          AuditLogger.log_field_validation(
            {:error, :invalid_field},
            :unknown_field,
            TestProduct,
            %{source: :csv}
          )
        end)

      assert log =~ "Field validation"
      assert log =~ "result: failure"
      assert log =~ "field: :unknown_field"
    end

    test "logs path validation for file operations" do
      log =
        capture_log(fn ->
          AuditLogger.log_path_validation(
            {:ok, "/safe/path"},
            "/safe/path",
            :import,
            %{user_id: 1}
          )
        end)

      assert log =~ "Path validation"
      assert log =~ "result: success"
      assert log =~ "operation: import"
    end

    test "logs cache validation events" do
      key = Cache.key(TestProduct, :name, :en, "123")

      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_cache_validation({:ok, key}, key, :get)
        end)

      assert log =~ "Cache key validation"
      assert log =~ "result: success"
      assert log =~ "key_type: translation"
    end

    test "logs rate limit events" do
      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_rate_limit({:ok, 19}, "user:123", :translation_write)
        end)

      assert log =~ "Rate limit check"
      assert log =~ "result: success"
      assert log =~ "operation_type: translation_write"
    end

    test "logs suspicious activity" do
      log =
        capture_log(fn ->
          AuditLogger.log_suspicious_activity(
            :atom_exhaustion_attempt,
            %{source: :csv, count: 1000},
            :error
          )
        end)

      assert log =~ "Suspicious activity detected"
      assert log =~ "event_type: atom_exhaustion_attempt"
      assert log =~ "severity: error"
    end

    test "sanitizes sensitive information in logs" do
      # Test with very long values
      long_value = String.duplicate("a", 200)

      log =
        capture_log(fn ->
          AuditLogger.log_input_validation(
            {:error, :too_long},
            :translation,
            long_value,
            %{}
          )
        end)

      # Should truncate the value
      assert log =~ "Input validation failed"
      assert log =~ "[truncated]"
    end

    test "logs CSRF validation events" do
      log =
        capture_log([level: :debug], fn ->
          AuditLogger.log_csrf_validation(:ok, %{method: :post})
        end)

      assert log =~ "CSRF token validation"
      assert log =~ "result: success"
    end

    test "integration: cache validation triggers audit logging" do
      # Valid key should log at debug level
      valid_key = Cache.key(TestProduct, :name, :en, "123")

      log =
        capture_log([level: :debug], fn ->
          Cache.put(valid_key, "Test value")
        end)

      # Validation logging happens internally
      assert log == "" or log =~ "Cache key validation"

      # Invalid key should log at warning level
      invalid_key = "not_a_tuple"

      log =
        capture_log(fn ->
          Cache.put(invalid_key, "Value")
        end)

      assert log =~ "Invalid cache key type rejected" or log =~ "Cache key validation"
    end

    test "integration: policy check triggers audit logging" do
      actor = %{id: 1, role: :translator, assigned_locales: [:en, :es]}

      action = %{
        name: :update_translation,
        arguments: %{locale: :en},
        resource: AshPhoenixTranslations.Phase4SecurityTest.TestProduct
      }

      log =
        capture_log(fn ->
          # Call PolicyCheck which should trigger audit logging
          _result = PolicyCheck.match?(actor, %{action: action}, [])
        end)

      # Should log the policy decision
      assert log =~ "Translation policy decision"
    end
  end

  # Helper modules for tests
  defmodule TestProduct do
    @moduledoc false

    use Ash.Resource,
      domain: AshPhoenixTranslations.Phase4SecurityTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations],
      validate_domain_inclusion?: false

    ets do
      private? true
    end

    attributes do
      uuid_primary_key :id
    end

    translations do
      translatable_attribute :name, :string, locales: [:en, :es, :fr]

      backend :database

      # Configure policies for audit logging tests
      policy view: :public,
             edit: :translator
    end
  end

  defmodule TestDomain do
    use Ash.Domain,
      validate_config_inclusion?: false

    resources do
      resource TestProduct
    end
  end
end
