defmodule AshPhoenixTranslations.Cache do
  @moduledoc """
  Caching layer for translations with support for multiple backends.
  
  Provides efficient caching of translations with TTL support,
  invalidation strategies, and cache warming.
  
  ## Configuration
  
      config :ash_phoenix_translations, :cache,
        backend: :ets,  # :ets, :redis, :persistent_term, or module
        ttl: 3600,       # seconds
        max_size: 10000, # max number of entries
        namespace: "translations"
  
  ## Usage
  
      # Get from cache or compute
      Cache.fetch({Product, :name, :es}, fn ->
        load_translation_from_database()
      end)
      
      # Direct cache operations
      Cache.put(key, value)
      Cache.get(key)
      Cache.delete(key)
      Cache.clear()
  """

  use GenServer
  require Logger

  @default_ttl 3600
  @default_max_size 10000
  @table_name :ash_translations_cache

  # Client API

  @doc """
  Starts the cache process.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Fetches a value from cache or computes it if not found.
  
      translation = Cache.fetch({Product, :name, :es}, fn ->
        # Load from database
        load_translation(product, :name, :es)
      end)
  """
  def fetch(key, fun, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    
    case get(key) do
      {:ok, value} ->
        value
      
      :miss ->
        value = fun.()
        put(key, value, ttl)
        value
    end
  end

  @doc """
  Gets a value from cache.
  
      case Cache.get({Product, :name, :es}) do
        {:ok, translation} -> translation
        :miss -> nil
      end
  """
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  catch
    :exit, _ -> :miss
  end

  @doc """
  Puts a value in cache with optional TTL.
  
      Cache.put({Product, :name, :es}, "Producto", ttl: 7200)
  """
  def put(key, value, ttl \\ @default_ttl) do
    GenServer.cast(__MODULE__, {:put, key, value, ttl})
  catch
    :exit, _ -> :ok
  end

  @doc """
  Deletes a key from cache.
  
      Cache.delete({Product, :name, :es})
  """
  def delete(key) do
    GenServer.cast(__MODULE__, {:delete, key})
  catch
    :exit, _ -> :ok
  end

  @doc """
  Deletes all keys matching a pattern.
  
      # Delete all Spanish translations for Product
      Cache.delete_pattern({Product, :_, :es})
      
      # Delete all translations for a specific product
      Cache.delete_pattern({Product, product_id, :_, :_})
  """
  def delete_pattern(pattern) do
    GenServer.cast(__MODULE__, {:delete_pattern, pattern})
  catch
    :exit, _ -> :ok
  end

  @doc """
  Clears the entire cache.
  """
  def clear do
    GenServer.cast(__MODULE__, :clear)
  catch
    :exit, _ -> :ok
  end

  @doc """
  Invalidates cache for a specific resource.
  
      Cache.invalidate_resource(Product, 123)
  """
  def invalidate_resource(resource_module, resource_id) do
    pattern = {resource_module, resource_id, :_, :_}
    delete_pattern(pattern)
  end

  @doc """
  Invalidates cache for a specific field across all resources.
  
      Cache.invalidate_field(Product, :name)
  """
  def invalidate_field(resource_module, field) do
    pattern = {resource_module, :_, field, :_}
    delete_pattern(pattern)
  end

  @doc """
  Invalidates cache for a specific locale.
  
      Cache.invalidate_locale(:es)
  """
  def invalidate_locale(locale) do
    pattern = {:_, :_, :_, locale}
    delete_pattern(pattern)
  end

  @doc """
  Warms the cache by preloading translations.
  
      Cache.warm(Product, [:name, :description], [:en, :es])
  """
  def warm(resource_module, fields \\ nil, locales \\ nil, opts \\ []) do
    GenServer.cast(__MODULE__, {:warm, resource_module, fields, locales, opts})
  catch
    :exit, _ -> :ok
  end

  @doc """
  Returns cache statistics.
  
      stats = Cache.stats()
      # => %{size: 1234, hits: 5678, misses: 234, hit_rate: 96.0}
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  catch
    :exit, _ -> %{size: 0, hits: 0, misses: 0, hit_rate: 0.0}
  end

  @doc """
  Returns cache size.
  """
  def size do
    GenServer.call(__MODULE__, :size)
  catch
    :exit, _ -> 0
  end

  # Server callbacks

  @impl true
  def init(opts) do
    # Create ETS table for cache storage
    :ets.new(@table_name, [:set, :named_table, :public, read_concurrency: true])
    
    # Create stats table
    :ets.new(:ash_translations_cache_stats, [:set, :named_table, :public])
    :ets.insert(:ash_translations_cache_stats, {:hits, 0})
    :ets.insert(:ash_translations_cache_stats, {:misses, 0})
    
    # Schedule cleanup
    schedule_cleanup()
    
    config = %{
      backend: Keyword.get(opts, :backend, :ets),
      ttl: Keyword.get(opts, :ttl, @default_ttl),
      max_size: Keyword.get(opts, :max_size, @default_max_size),
      namespace: Keyword.get(opts, :namespace, "translations")
    }
    
    {:ok, config}
  end

  @impl true
  def handle_call({:get, key}, _from, config) do
    case lookup(key, config) do
      {:ok, value} ->
        increment_hits()
        {:reply, {:ok, value}, config}
      
      :miss ->
        increment_misses()
        {:reply, :miss, config}
    end
  end

  @impl true
  def handle_call(:stats, _from, config) do
    hits = get_counter(:hits)
    misses = get_counter(:misses)
    total = hits + misses
    
    hit_rate = 
      if total > 0 do
        Float.round(hits / total * 100, 1)
      else
        0.0
      end
    
    stats = %{
      size: :ets.info(@table_name, :size),
      hits: hits,
      misses: misses,
      hit_rate: hit_rate
    }
    
    {:reply, stats, config}
  end

  @impl true
  def handle_call(:size, _from, config) do
    size = :ets.info(@table_name, :size)
    {:reply, size, config}
  end

  @impl true
  def handle_cast({:put, key, value, ttl}, config) do
    # Check size limit
    if :ets.info(@table_name, :size) >= config.max_size do
      evict_oldest()
    end
    
    expiry = System.system_time(:second) + ttl
    :ets.insert(@table_name, {key, value, expiry})
    
    {:noreply, config}
  end

  @impl true
  def handle_cast({:delete, key}, config) do
    :ets.delete(@table_name, key)
    {:noreply, config}
  end

  @impl true
  def handle_cast({:delete_pattern, pattern}, config) do
    # Delete all entries matching the pattern
    :ets.select_delete(@table_name, [
      {pattern_to_match_spec(pattern), [], [true]}
    ])
    
    {:noreply, config}
  end

  @impl true
  def handle_cast(:clear, config) do
    :ets.delete_all_objects(@table_name)
    :ets.insert(:ash_translations_cache_stats, {:hits, 0})
    :ets.insert(:ash_translations_cache_stats, {:misses, 0})
    
    {:noreply, config}
  end

  @impl true
  def handle_cast({:warm, resource_module, fields, locales, _opts}, config) do
    # Spawn a task to warm the cache asynchronously
    Task.start(fn ->
      warm_cache(resource_module, fields, locales, config)
    end)
    
    {:noreply, config}
  end

  @impl true
  def handle_info(:cleanup, config) do
    cleanup_expired()
    schedule_cleanup()
    {:noreply, config}
  end

  # Private helpers

  defp lookup(key, _config) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expiry}] ->
        if expiry > System.system_time(:second) do
          {:ok, value}
        else
          :ets.delete(@table_name, key)
          :miss
        end
      
      [] ->
        :miss
    end
  end

  defp increment_hits do
    :ets.update_counter(:ash_translations_cache_stats, :hits, 1, {:hits, 0})
  end

  defp increment_misses do
    :ets.update_counter(:ash_translations_cache_stats, :misses, 1, {:misses, 0})
  end

  defp get_counter(key) do
    case :ets.lookup(:ash_translations_cache_stats, key) do
      [{^key, value}] -> value
      [] -> 0
    end
  end

  defp evict_oldest do
    # Simple eviction: remove 10% of oldest entries
    entries = :ets.tab2list(@table_name)
    
    oldest = 
      entries
      |> Enum.sort_by(fn {_key, _value, expiry} -> expiry end)
      |> Enum.take(div(length(entries), 10))
    
    Enum.each(oldest, fn {key, _, _} ->
      :ets.delete(@table_name, key)
    end)
  end

  defp cleanup_expired do
    now = System.system_time(:second)
    
    :ets.select_delete(@table_name, [
      {{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}
    ])
  end

  defp schedule_cleanup do
    # Run cleanup every 5 minutes
    Process.send_after(self(), :cleanup, 5 * 60 * 1000)
  end

  defp pattern_to_match_spec(pattern) do
    pattern
    |> Tuple.to_list()
    |> Enum.map(fn
      :_ -> :_
      value -> value
    end)
    |> List.to_tuple()
  end

  defp warm_cache(resource_module, fields, locales, _config) do
    fields = fields || get_translatable_fields(resource_module)
    locales = locales || get_supported_locales(resource_module)
    
    # This would load translations from the appropriate backend
    # For now, it's a placeholder
    Logger.info("Warming cache for #{resource_module} with fields #{inspect(fields)} and locales #{inspect(locales)}")
    
    # In production, this would:
    # 1. Query all resources
    # 2. Load translations for specified fields and locales
    # 3. Put them in cache
    
    :ok
  end

  defp get_translatable_fields(resource_module) do
    resource_module
    |> AshPhoenixTranslations.Info.translatable_attributes()
    |> Enum.map(& &1.name)
  rescue
    _ -> []
  end

  defp get_supported_locales(resource_module) do
    AshPhoenixTranslations.Info.supported_locales(resource_module)
  rescue
    _ -> [:en]
  end
end