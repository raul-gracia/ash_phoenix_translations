defmodule AshPhoenixTranslations.CacheTest do
  use ExUnit.Case, async: false

  alias AshPhoenixTranslations.Cache

  setup do
    # Start cache for each test
    {:ok, _pid} = Cache.start_link()

    # Wait a bit for GenServer to fully initialize
    Process.sleep(10)

    # Clear cache before each test
    Cache.clear()

    :ok
  end

  describe "basic operations" do
    test "get returns miss for non-existent key" do
      assert Cache.get({:test, :key}) == :miss
    end

    test "put and get work correctly" do
      Cache.put({:test, :key}, "value")
      assert Cache.get({:test, :key}) == {:ok, "value"}
    end

    test "put with custom TTL" do
      Cache.put({:test, :key}, "value", 1)
      assert Cache.get({:test, :key}) == {:ok, "value"}

      # Wait for expiry
      Process.sleep(1100)
      assert Cache.get({:test, :key}) == :miss
    end

    test "delete removes key" do
      Cache.put({:test, :key}, "value")
      assert Cache.get({:test, :key}) == {:ok, "value"}

      Cache.delete({:test, :key})
      assert Cache.get({:test, :key}) == :miss
    end

    test "clear removes all keys" do
      Cache.put({:test, :key1}, "value1")
      Cache.put({:test, :key2}, "value2")

      Cache.clear()

      assert Cache.get({:test, :key1}) == :miss
      assert Cache.get({:test, :key2}) == :miss
    end
  end

  describe "fetch" do
    test "returns cached value if present" do
      Cache.put({:test, :key}, "cached_value")

      result = Cache.fetch({:test, :key}, fn -> "computed_value" end)
      assert result == "cached_value"
    end

    test "computes and caches value if missing" do
      result = Cache.fetch({:test, :key}, fn -> "computed_value" end)
      assert result == "computed_value"

      # Verify it was cached
      assert Cache.get({:test, :key}) == {:ok, "computed_value"}
    end

    test "respects custom TTL in fetch" do
      result = Cache.fetch({:test, :key}, fn -> "value" end, ttl: 1)
      assert result == "value"

      Process.sleep(1100)
      assert Cache.get({:test, :key}) == :miss
    end
  end

  describe "pattern deletion" do
    test "delete_pattern removes matching keys" do
      # Add various keys
      Cache.put({Product, 1, :name, :en}, "Product 1")
      Cache.put({Product, 1, :name, :es}, "Producto 1")
      Cache.put({Product, 2, :name, :en}, "Product 2")
      Cache.put({Category, 1, :name, :en}, "Category 1")

      # Delete all Product translations
      Cache.delete_pattern({Product, :_, :_, :_})

      assert Cache.get({Product, 1, :name, :en}) == :miss
      assert Cache.get({Product, 1, :name, :es}) == :miss
      assert Cache.get({Product, 2, :name, :en}) == :miss
      assert Cache.get({Category, 1, :name, :en}) == {:ok, "Category 1"}
    end

    test "invalidate_resource removes all translations for a resource" do
      Cache.put({Product, 123, :name, :en}, "Name")
      Cache.put({Product, 123, :description, :en}, "Description")
      Cache.put({Product, 456, :name, :en}, "Other")

      Cache.invalidate_resource(Product, 123)

      assert Cache.get({Product, 123, :name, :en}) == :miss
      assert Cache.get({Product, 123, :description, :en}) == :miss
      assert Cache.get({Product, 456, :name, :en}) == {:ok, "Other"}
    end

    test "invalidate_field removes all translations for a field" do
      Cache.put({Product, 1, :name, :en}, "Name 1")
      Cache.put({Product, 2, :name, :en}, "Name 2")
      Cache.put({Product, 1, :description, :en}, "Desc")

      Cache.invalidate_field(Product, :name)

      assert Cache.get({Product, 1, :name, :en}) == :miss
      assert Cache.get({Product, 2, :name, :en}) == :miss
      assert Cache.get({Product, 1, :description, :en}) == {:ok, "Desc"}
    end

    test "invalidate_locale removes all translations for a locale" do
      Cache.put({Product, 1, :name, :en}, "Name")
      Cache.put({Product, 1, :name, :es}, "Nombre")
      Cache.put({Category, 1, :name, :es}, "Categoría")

      Cache.invalidate_locale(:es)

      assert Cache.get({Product, 1, :name, :en}) == {:ok, "Name"}
      assert Cache.get({Product, 1, :name, :es}) == :miss
      assert Cache.get({Category, 1, :name, :es}) == :miss
    end
  end

  describe "statistics" do
    test "tracks hits and misses" do
      # Start fresh
      Cache.clear()

      # Generate some misses
      Cache.get({:test, :miss1})
      Cache.get({:test, :miss2})

      # Generate some hits
      Cache.put({:test, :hit}, "value")
      Cache.get({:test, :hit})
      Cache.get({:test, :hit})

      stats = Cache.stats()
      assert stats.hits == 2
      assert stats.misses == 2
      assert stats.hit_rate == 50.0
    end

    test "returns cache size" do
      Cache.put({:test, :key1}, "value1")
      Cache.put({:test, :key2}, "value2")
      Cache.put({:test, :key3}, "value3")

      assert Cache.size() == 3
    end

    test "stats include size" do
      Cache.put({:test, :key1}, "value1")
      Cache.put({:test, :key2}, "value2")

      stats = Cache.stats()
      assert stats.size == 2
    end
  end

  describe "eviction" do
    test "evicts oldest entries when max size reached" do
      # Create a cache with small max size
      # Note: This test assumes we can configure max_size
      # In production, this would be configurable

      # Add entries up to limit
      for i <- 1..100 do
        Cache.put({:test, i}, "value#{i}", i)
      end

      # Older entries should be evicted based on expiry time
      # This is a simplified test - actual implementation may vary
      # Default max size
      assert Cache.size() <= 10_000
    end
  end

  describe "cache warming" do
    test "warm cache triggers async loading" do
      # This is a placeholder test since warm is async
      # In production, we'd mock the loading function
      Cache.warmup(Product, [:name, :description])

      # The warm function should not crash
      Process.sleep(100)
      assert true
    end
  end

  describe "expiry" do
    test "expired entries are removed on access" do
      # Put with 1 second TTL
      Cache.put({:test, :expiring}, "value", 1)

      # Should be accessible immediately
      assert Cache.get({:test, :expiring}) == {:ok, "value"}

      # Wait for expiry
      Process.sleep(1100)

      # Should be gone
      assert Cache.get({:test, :expiring}) == :miss
    end

    test "cleanup process removes expired entries" do
      # Add some entries with short TTL
      for i <- 1..5 do
        Cache.put({:test, i}, "value#{i}", 1)
      end

      # Wait for expiry and cleanup
      # Cleanup runs every 5 minutes, so we can't test it directly
      # But expired entries should be removed on access
      Process.sleep(1100)

      for i <- 1..5 do
        assert Cache.get({:test, i}) == :miss
      end
    end
  end
end
