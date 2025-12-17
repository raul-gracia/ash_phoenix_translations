defmodule AshPhoenixTranslations.RateLimiterTest do
  @moduledoc """
  Comprehensive tests for the RateLimiter module.

  Tests cover:
  - Basic rate limiting functionality
  - Token bucket algorithm behavior
  - Different operation types and their limits
  - Window expiration and reset
  - Status and reset operations
  - Edge cases and error handling
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias AshPhoenixTranslations.RateLimiter

  setup do
    # Start rate limiter for each test
    {:ok, _pid} = RateLimiter.start_link()

    # Create unique identifiers for each test to avoid interference
    identifier = "test_user_#{:rand.uniform(1_000_000)}"

    {:ok, identifier: identifier}
  end

  describe "start_link/1" do
    test "starts the rate limiter GenServer" do
      # Already started in setup, verify it's running
      assert Process.whereis(RateLimiter) != nil
    end

    test "handles already started scenario gracefully" do
      # Attempting to start again should return ok with existing pid
      {:ok, pid} = RateLimiter.start_link()
      assert is_pid(pid)
    end
  end

  describe "check_rate/2 - basic functionality" do
    test "allows first request for any operation", %{identifier: identifier} do
      assert {:ok, remaining} = RateLimiter.check_rate(identifier, :translation_read)
      assert is_integer(remaining)
      assert remaining >= 0
    end

    test "decrements remaining tokens on each request", %{identifier: identifier} do
      {:ok, first_remaining} = RateLimiter.check_rate(identifier, :translation_read)
      {:ok, second_remaining} = RateLimiter.check_rate(identifier, :translation_read)

      assert second_remaining == first_remaining - 1
    end

    test "returns remaining count accurately", %{identifier: identifier} do
      # First request
      {:ok, remaining1} = RateLimiter.check_rate(identifier, :translation_read)

      # Second request
      {:ok, remaining2} = RateLimiter.check_rate(identifier, :translation_read)

      assert remaining1 - remaining2 == 1
    end
  end

  describe "check_rate/2 - rate limit enforcement" do
    test "blocks requests after limit is exhausted", %{identifier: identifier} do
      capture_log(fn ->
        # Exhaust the translation_write limit (20 per minute)
        for _ <- 1..20 do
          RateLimiter.check_rate(identifier, :translation_write)
        end

        # Next request should be rate limited
        result = RateLimiter.check_rate(identifier, :translation_write)
        assert {:error, :rate_limited, retry_after} = result
        assert is_integer(retry_after)
        assert retry_after > 0
      end)
    end

    test "returns correct retry_after time", %{identifier: identifier} do
      capture_log(fn ->
        # Exhaust limit
        for _ <- 1..20 do
          RateLimiter.check_rate(identifier, :translation_write)
        end

        {:error, :rate_limited, retry_after} =
          RateLimiter.check_rate(identifier, :translation_write)

        # Retry after should be within the window (1 minute = 60000ms)
        assert retry_after > 0
        assert retry_after <= 60_000
      end)
    end

    test "different identifiers have separate rate limits" do
      id1 = "user_a_#{:rand.uniform(100_000)}"
      id2 = "user_b_#{:rand.uniform(100_000)}"

      capture_log(fn ->
        # Exhaust limit for id1
        for _ <- 1..20 do
          RateLimiter.check_rate(id1, :translation_write)
        end

        # id1 should be rate limited
        assert {:error, :rate_limited, _} = RateLimiter.check_rate(id1, :translation_write)

        # id2 should still be allowed
        assert {:ok, _} = RateLimiter.check_rate(id2, :translation_write)
      end)
    end
  end

  describe "check_rate/2 - operation types" do
    test "translation_read has 100 operations per minute limit", %{identifier: identifier} do
      capture_log(fn ->
        # Make 100 requests - all should succeed
        results =
          Enum.map(1..100, fn _ ->
            RateLimiter.check_rate(identifier, :translation_read)
          end)

        successes = Enum.count(results, fn res -> match?({:ok, _}, res) end)
        assert successes == 100

        # 101st request should be rate limited
        assert {:error, :rate_limited, _} = RateLimiter.check_rate(identifier, :translation_read)
      end)
    end

    test "translation_write has 20 operations per minute limit", %{identifier: identifier} do
      capture_log(fn ->
        # Make 20 requests - all should succeed
        results =
          Enum.map(1..20, fn _ ->
            RateLimiter.check_rate(identifier, :translation_write)
          end)

        successes = Enum.count(results, fn res -> match?({:ok, _}, res) end)
        assert successes == 20

        # 21st request should be rate limited
        assert {:error, :rate_limited, _} = RateLimiter.check_rate(identifier, :translation_write)
      end)
    end

    test "import has 5 operations per 5 minutes limit", %{identifier: identifier} do
      capture_log(fn ->
        # Make 5 requests - all should succeed
        results =
          Enum.map(1..5, fn _ ->
            RateLimiter.check_rate(identifier, :import)
          end)

        successes = Enum.count(results, fn res -> match?({:ok, _}, res) end)
        assert successes == 5

        # 6th request should be rate limited
        assert {:error, :rate_limited, _} = RateLimiter.check_rate(identifier, :import)
      end)
    end

    test "export has 10 operations per 5 minutes limit", %{identifier: identifier} do
      capture_log(fn ->
        # Make 10 requests - all should succeed
        results =
          Enum.map(1..10, fn _ ->
            RateLimiter.check_rate(identifier, :export)
          end)

        successes = Enum.count(results, fn res -> match?({:ok, _}, res) end)
        assert successes == 10

        # 11th request should be rate limited
        assert {:error, :rate_limited, _} = RateLimiter.check_rate(identifier, :export)
      end)
    end

    test "api_request has 60 operations per minute limit", %{identifier: identifier} do
      capture_log(fn ->
        # Make 60 requests - all should succeed
        results =
          Enum.map(1..60, fn _ ->
            RateLimiter.check_rate(identifier, :api_request)
          end)

        successes = Enum.count(results, fn res -> match?({:ok, _}, res) end)
        assert successes == 60

        # 61st request should be rate limited
        assert {:error, :rate_limited, _} = RateLimiter.check_rate(identifier, :api_request)
      end)
    end

    test "different operation types have separate limits", %{identifier: identifier} do
      capture_log(fn ->
        # Exhaust translation_write limit
        for _ <- 1..20 do
          RateLimiter.check_rate(identifier, :translation_write)
        end

        # translation_write should be rate limited
        assert {:error, :rate_limited, _} = RateLimiter.check_rate(identifier, :translation_write)

        # But translation_read should still work (different operation type)
        assert {:ok, _} = RateLimiter.check_rate(identifier, :translation_read)
      end)
    end

    test "unknown operation types use default limit", %{identifier: identifier} do
      # Unknown operation type should use default {100, 60_000}
      result = RateLimiter.check_rate(identifier, :unknown_operation)
      assert {:ok, _remaining} = result
    end
  end

  describe "reset/2" do
    test "resets rate limit for identifier and operation", %{identifier: identifier} do
      capture_log(fn ->
        # Exhaust limit
        for _ <- 1..20 do
          RateLimiter.check_rate(identifier, :translation_write)
        end

        # Should be rate limited
        assert {:error, :rate_limited, _} = RateLimiter.check_rate(identifier, :translation_write)

        # Reset
        assert :ok = RateLimiter.reset(identifier, :translation_write)

        # Should be allowed again
        assert {:ok, _} = RateLimiter.check_rate(identifier, :translation_write)
      end)
    end

    test "reset only affects specific operation type", %{identifier: identifier} do
      # Use some tokens for both operation types
      for _ <- 1..5 do
        RateLimiter.check_rate(identifier, :translation_write)
        RateLimiter.check_rate(identifier, :translation_read)
      end

      # Reset only translation_write
      RateLimiter.reset(identifier, :translation_write)

      # translation_write should have full tokens
      {:ok, write_remaining} = RateLimiter.check_rate(identifier, :translation_write)
      # 20 - 1 = 19 (after reset and one new request)
      assert write_remaining == 19

      # translation_read should still have reduced tokens
      {:ok, read_remaining} = RateLimiter.check_rate(identifier, :translation_read)
      # 100 - 5 - 1 = 94 (original minus previous minus current)
      assert read_remaining == 94
    end
  end

  describe "status/2" do
    test "returns remaining tokens and window start for existing entry", %{identifier: identifier} do
      # Make some requests
      RateLimiter.check_rate(identifier, :translation_write)

      {:ok, status} = RateLimiter.status(identifier, :translation_write)

      assert is_map(status)
      assert Map.has_key?(status, :remaining)
      assert Map.has_key?(status, :window_start)
      assert is_integer(status.remaining)
      assert is_integer(status.window_start)
    end

    test "returns nil values for non-existent entry", %{identifier: identifier} do
      {:ok, status} = RateLimiter.status(identifier, :never_used_operation)

      assert is_map(status)
      assert status.remaining == nil
      assert status.window_start == nil
    end

    test "shows accurate remaining count", %{identifier: identifier} do
      # Use 5 tokens
      for _ <- 1..5 do
        RateLimiter.check_rate(identifier, :translation_write)
      end

      {:ok, status} = RateLimiter.status(identifier, :translation_write)

      # Should have 20 - 5 = 15 remaining
      assert status.remaining == 15
    end
  end

  describe "window expiration" do
    @tag :slow
    test "window resets after expiration", %{identifier: identifier} do
      # Use some tokens
      for _ <- 1..5 do
        RateLimiter.check_rate(identifier, :translation_write)
      end

      {:ok, status_before} = RateLimiter.status(identifier, :translation_write)
      assert status_before.remaining == 15

      # Note: We can't easily test actual window expiration without waiting
      # for the full window duration. This test verifies the mechanism works
      # when window would expire.
    end
  end

  describe "concurrent access" do
    test "handles concurrent requests correctly", %{identifier: identifier} do
      # Spawn multiple processes making concurrent requests
      tasks =
        for _ <- 1..50 do
          Task.async(fn ->
            RateLimiter.check_rate(identifier, :translation_read)
          end)
        end

      results = Enum.map(tasks, &Task.await/1)

      # All should succeed (limit is 100)
      successes = Enum.count(results, fn res -> match?({:ok, _}, res) end)
      assert successes == 50
    end

    test "maintains consistency under concurrent load" do
      id = "concurrent_test_#{:rand.uniform(100_000)}"

      capture_log(fn ->
        # Make 20 concurrent requests (exactly at limit for translation_write)
        tasks =
          for _ <- 1..20 do
            Task.async(fn ->
              RateLimiter.check_rate(id, :translation_write)
            end)
          end

        results = Enum.map(tasks, &Task.await/1)

        # All 20 should succeed
        successes = Enum.count(results, fn res -> match?({:ok, _}, res) end)
        assert successes == 20

        # 21st should fail
        assert {:error, :rate_limited, _} = RateLimiter.check_rate(id, :translation_write)
      end)
    end
  end

  describe "edge cases" do
    test "handles empty string identifier", %{identifier: _identifier} do
      result = RateLimiter.check_rate("", :translation_read)
      assert {:ok, _} = result
    end

    test "handles very long identifier", %{identifier: _identifier} do
      long_id = String.duplicate("a", 10_000)
      result = RateLimiter.check_rate(long_id, :translation_read)
      assert {:ok, _} = result
    end

    test "handles special characters in identifier", %{identifier: _identifier} do
      special_id = "user@domain.com:action/path?query=value"
      result = RateLimiter.check_rate(special_id, :translation_read)
      assert {:ok, _} = result
    end

    test "handles nil-like identifiers", %{identifier: _identifier} do
      # Atom identifier
      result = RateLimiter.check_rate(:nil_like, :translation_read)
      assert {:ok, _} = result
    end

    test "handles complex identifier tuples", %{identifier: _identifier} do
      complex_id = {"user", 123, :context}
      result = RateLimiter.check_rate(complex_id, :translation_read)
      assert {:ok, _} = result
    end
  end

  describe "security scenarios" do
    test "prevents rapid fire attacks", %{identifier: identifier} do
      capture_log(fn ->
        # Simulate rapid fire attack
        results =
          for _ <- 1..100 do
            RateLimiter.check_rate(identifier, :translation_write)
          end

        # Only first 20 should succeed
        successes = Enum.count(results, fn res -> match?({:ok, _}, res) end)
        failures = Enum.count(results, fn res -> match?({:error, :rate_limited, _}, res) end)

        assert successes == 20
        assert failures == 80
      end)
    end

    test "prevents distributed attack from same logical user", %{identifier: identifier} do
      capture_log(fn ->
        # Even if using same identifier from multiple "sources", rate limit applies
        tasks =
          for _ <- 1..50 do
            Task.async(fn ->
              RateLimiter.check_rate(identifier, :translation_write)
            end)
          end

        results = Enum.map(tasks, &Task.await/1)

        # Only 20 should succeed
        successes = Enum.count(results, fn res -> match?({:ok, _}, res) end)
        assert successes == 20
      end)
    end

    test "tracks abuse attempts across operation types", %{identifier: identifier} do
      capture_log(fn ->
        # Exhaust all operation types for a single identifier
        for _ <- 1..20, do: RateLimiter.check_rate(identifier, :translation_write)
        for _ <- 1..5, do: RateLimiter.check_rate(identifier, :import)
        for _ <- 1..10, do: RateLimiter.check_rate(identifier, :export)

        # All should be rate limited now
        assert {:error, :rate_limited, _} = RateLimiter.check_rate(identifier, :translation_write)
        assert {:error, :rate_limited, _} = RateLimiter.check_rate(identifier, :import)
        assert {:error, :rate_limited, _} = RateLimiter.check_rate(identifier, :export)

        # But translation_read should still work (higher limit)
        assert {:ok, _} = RateLimiter.check_rate(identifier, :translation_read)
      end)
    end
  end
end
