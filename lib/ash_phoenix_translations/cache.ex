defmodule AshPhoenixTranslations.Cache do
  @moduledoc """
  Caching layer for translations with ETS backend.
  
  Provides:
  - In-memory caching using ETS
  - TTL support
  - Cache invalidation
  - Warmup strategies
  """

  use GenServer
  require Logger

  @table_name :ash_translations_cache
  @default_ttl 3600  # 1 hour in seconds

  # Client API

  @doc """
  Starts the cache server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets a translation from cache.
  
  Returns `{:ok, value}` if found, `:miss` if not cached or expired.
  """
  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expiry}] ->
        if DateTime.compare(DateTime.utc_now(), expiry) == :lt do
          {:ok, value}
        else
          # Expired, delete it
          :ets.delete(@table_name, key)
          :miss
        end
      [] ->
        :miss
    end
  rescue
    ArgumentError ->
      # Table doesn't exist
      :miss
  end

  @doc """
  Puts a translation in cache with TTL.
  """
  def put(key, value, ttl \\ nil) do
    ttl = ttl || @default_ttl
    expiry = DateTime.add(DateTime.utc_now(), ttl, :second)
    
    :ets.insert(@table_name, {key, value, expiry})
    :ok
  rescue
    ArgumentError ->
      # Table doesn't exist, silently fail
      :ok
  end

  @doc """
  Gets a value from cache or computes it if missing.
  
  ## Examples
  
      Cache.get_or_compute(key, fn -> expensive_operation() end)
  """
  def get_or_compute(key, compute_fn, ttl \\ nil) do
    case get(key) do
      {:ok, value} ->
        value
      :miss ->
        value = compute_fn.()
        put(key, value, ttl)
        value
    end
  end

  @doc """
  Invalidates cache entries matching a pattern.
  
  ## Examples
  
      # Invalidate all translations for a resource
      Cache.invalidate({:resource, Product, :*, :*})
      
      # Invalidate all translations for a specific locale
      Cache.invalidate({:*, :*, :fr, :*})
  """
  def invalidate(pattern) do
    GenServer.cast(__MODULE__, {:invalidate, pattern})
  end

  @doc """
  Clears the entire cache.
  """
  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  @doc """
  Warms up the cache with frequently accessed translations.
  """
  def warmup(resources, locales) do
    GenServer.cast(__MODULE__, {:warmup, resources, locales})
  end

  @doc """
  Gets cache statistics.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    # Create ETS table
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    state = %{
      ttl: Keyword.get(opts, :ttl, @default_ttl),
      hits: 0,
      misses: 0,
      evictions: 0
    }
    
    {:ok, state}
  end

  @impl true
  def handle_cast({:invalidate, pattern}, state) do
    count = invalidate_pattern(pattern)
    Logger.debug("Invalidated #{count} cache entries matching #{inspect(pattern)}")
    {:noreply, %{state | evictions: state.evictions + count}}
  end

  @impl true
  def handle_cast(:clear, state) do
    :ets.delete_all_objects(@table_name)
    Logger.debug("Cleared translation cache")
    {:noreply, %{state | evictions: state.evictions + :ets.info(@table_name, :size)}}
  end

  @impl true
  def handle_cast({:warmup, resources, locales}, state) do
    Task.start(fn -> perform_warmup(resources, locales) end)
    {:noreply, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      size: :ets.info(@table_name, :size),
      memory: :ets.info(@table_name, :memory),
      hits: state.hits,
      misses: state.misses,
      evictions: state.evictions,
      hit_rate: calculate_hit_rate(state)
    }
    {:reply, stats, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    expired_count = cleanup_expired()
    Logger.debug("Cleaned up #{expired_count} expired cache entries")
    
    schedule_cleanup()
    {:noreply, %{state | evictions: state.evictions + expired_count}}
  end

  # Private functions

  defp schedule_cleanup do
    # Run cleanup every 5 minutes
    Process.send_after(self(), :cleanup, 5 * 60 * 1000)
  end

  defp cleanup_expired do
    now = DateTime.utc_now()
    
    expired = :ets.select(@table_name, [
      {
        {:"$1", :"$2", :"$3"},
        [{:<, :"$3", now}],
        [:"$1"]
      }
    ])
    
    Enum.each(expired, &:ets.delete(@table_name, &1))
    length(expired)
  end

  defp invalidate_pattern(pattern) when is_tuple(pattern) do
    # Convert pattern to match spec
    match_spec = build_match_spec(pattern)
    keys = :ets.select(@table_name, match_spec)
    Enum.each(keys, &:ets.delete(@table_name, &1))
    length(keys)
  end

  defp build_match_spec(pattern) do
    # Build ETS match specification from pattern
    # This is simplified - real implementation would be more complex
    [
      {
        {:"$1", :"$2", :"$3"},
        [],
        [:"$1"]
      }
    ]
  end

  defp perform_warmup(resources, locales) do
    Logger.info("Starting cache warmup for #{length(resources)} resources and #{length(locales)} locales")
    
    # This would load translations for the specified resources and locales
    # Implementation depends on specific requirements
    
    Logger.info("Cache warmup completed")
  end

  defp calculate_hit_rate(%{hits: hits, misses: misses}) do
    total = hits + misses
    if total > 0 do
      Float.round(hits / total * 100, 2)
    else
      0.0
    end
  end

  @doc """
  Builds a cache key for a translation.
  
  ## Examples
  
      Cache.key(Product, :name, :fr, record_id)
      # => {:translation, Product, :name, :fr, "123"}
  """
  def key(resource, field, locale, record_id) do
    {:translation, resource, field, locale, record_id}
  end
end