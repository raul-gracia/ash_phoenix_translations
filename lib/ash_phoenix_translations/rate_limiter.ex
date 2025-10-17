defmodule AshPhoenixTranslations.RateLimiter do
  @moduledoc """
  Rate limiting for translation operations to prevent abuse.

  SECURITY: VULN-008 - Insufficient rate limiting

  Implements token bucket algorithm with configurable limits per operation type.
  """

  use GenServer
  require Logger

  @table_name :ash_translations_rate_limiter
  @cleanup_interval :timer.minutes(5)

  # Rate limit configurations (operations per window)
  @default_limits %{
    # 100 reads per minute
    translation_read: {100, :timer.minutes(1)},
    # 20 writes per minute
    translation_write: {20, :timer.minutes(1)},
    # 5 imports per 5 minutes
    import: {5, :timer.minutes(5)},
    # 10 exports per 5 minutes
    export: {10, :timer.minutes(5)},
    # 60 API requests per minute
    api_request: {60, :timer.minutes(1)}
  }

  # Client API

  @doc """
  Starts the rate limiter GenServer.
  """
  def start_link(opts \\ []) do
    case GenServer.start_link(__MODULE__, opts, name: __MODULE__) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  @doc """
  Checks if an operation is allowed for a given identifier.

  Returns `{:ok, remaining}` if allowed, `{:error, :rate_limited, retry_after}` if denied.

  ## Examples

      case RateLimiter.check_rate("user:123", :translation_write) do
        {:ok, remaining} ->
          perform_operation()
        {:error, :rate_limited, retry_ms} ->
          {:error, "Rate limit exceeded, retry after \#{retry_ms}ms"}
      end
  """
  def check_rate(identifier, operation_type) do
    {limit, window} = get_limit(operation_type)
    key = {identifier, operation_type}
    now = System.monotonic_time(:millisecond)

    GenServer.call(__MODULE__, {:check_rate, key, limit, window, now})
  end

  @doc """
  Resets rate limit for an identifier and operation type.

  Useful for testing or administrative actions.
  """
  def reset(identifier, operation_type) do
    key = {identifier, operation_type}
    GenServer.call(__MODULE__, {:reset, key})
  end

  @doc """
  Gets current rate limit status for an identifier.
  """
  def status(identifier, operation_type) do
    key = {identifier, operation_type}
    GenServer.call(__MODULE__, {:status, key})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:check_rate, key, limit, window, now}, _from, state) do
    result = check_rate_impl(key, limit, window, now)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:reset, key}, _from, state) do
    :ets.delete(@table_name, key)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:status, key}, _from, state) do
    status = get_status_impl(key)
    {:reply, status, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp check_rate_impl(key, limit, window, now) do
    case :ets.lookup(@table_name, key) do
      [{^key, tokens, window_start}] ->
        elapsed = now - window_start

        if elapsed >= window do
          # Window expired, reset
          :ets.insert(@table_name, {key, limit - 1, now})
          {:ok, limit - 1}
        else
          if tokens > 0 do
            # Token available
            :ets.update_counter(@table_name, key, {2, -1})
            {:ok, tokens - 1}
          else
            # Rate limited
            retry_after = window - elapsed
            Logger.warning("Rate limit exceeded", key: inspect(key), retry_after: retry_after)
            {:error, :rate_limited, retry_after}
          end
        end

      [] ->
        # First request in window
        :ets.insert(@table_name, {key, limit - 1, now})
        {:ok, limit - 1}
    end
  rescue
    ArgumentError ->
      # Table doesn't exist
      {:error, :unavailable}
  end

  defp get_status_impl(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, tokens, window_start}] ->
        {:ok, %{remaining: tokens, window_start: window_start}}

      [] ->
        {:ok, %{remaining: nil, window_start: nil}}
    end
  rescue
    ArgumentError ->
      {:error, :unavailable}
  end

  defp get_limit(operation_type) do
    custom_limits = Application.get_env(:ash_phoenix_translations, :rate_limits, %{})
    Map.get(custom_limits, operation_type, @default_limits[operation_type] || {100, 60_000})
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_expired do
    now = System.monotonic_time(:millisecond)

    # Remove entries older than 1 hour
    max_age = :timer.hours(1)

    expired =
      :ets.select(@table_name, [
        {
          {:"$1", :"$2", :"$3"},
          [{:<, {:-, now, :"$3"}, max_age}],
          [:"$1"]
        }
      ])

    Enum.each(expired, &:ets.delete(@table_name, &1))
    Logger.debug("Cleaned up #{length(expired)} expired rate limit entries")
  rescue
    ArgumentError ->
      # Table doesn't exist
      :ok
  end
end
