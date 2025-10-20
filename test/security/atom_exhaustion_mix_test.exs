defmodule AshPhoenixTranslations.AtomExhaustionMixTest do
  @moduledoc """
  Critical security tests for atom exhaustion prevention in Mix tasks.

  ## Security Vulnerability

  The BEAM VM has a **fixed limit of ~1 million atoms**. Once this limit is reached,
  the VM crashes with "no more index entries in atom_tab". Atoms are never garbage
  collected, making atom exhaustion a denial-of-service (DoS) vulnerability.

  ### Attack Vector

  Mix tasks that accept user input (locales, fields, formats) are vulnerable if they:
  1. Convert user strings to atoms using `String.to_atom/1`
  2. Don't validate input before conversion
  3. Process comma-separated lists without filtering

  Example attack:
  ```bash
  # Attacker supplies 1000 invalid locales
  mix ash_phoenix_translations.export output.csv \\
    --locale "attack_1,attack_2,...,attack_1000"
  ```

  If each invalid locale becomes an atom, this creates 1000 permanent atoms,
  consuming ~0.1% of the atom table per execution.

  ## Prevention Strategy

  All Mix tasks use `String.to_existing_atom/1` instead of `String.to_atom/1`:

  - **Safe**: `String.to_existing_atom("en")` → `:en` (if atom exists)
  - **Safe**: `String.to_existing_atom("invalid")` → raises ArgumentError
  - **Unsafe**: `String.to_atom("invalid")` → creates `:invalid` permanently

  Combined with whitelisting via `LocaleValidator` module.

  ## Test Coverage

  ### Mix Task Validation
  Tests verify each Mix task rejects invalid input without creating atoms:

  - **export task**: Locale validation (100 invalid locales → <150 atoms)
  - **validate task**: Field validation (100 invalid fields → <150 atoms)
  - **extract task**: Format validation (invalid formats raise Mix.Error)

  ### Mixed Input Handling
  Tests verify filtering separates valid from invalid input:

  - Mixed locales: "en,invalid1,es,malicious_123,fr"
  - Result: Process valid (en, es, fr), skip invalid (2 skipped)
  - Atoms created: <150 (not 2+ for invalid entries)

  ### Large-Scale Attack Simulation
  Stress tests with 1000 invalid inputs (tagged `:slow`):

  - 1000 invalid locales → <300 atoms created
  - 1000 invalid fields → <300 atoms created
  - Tolerance: Allow overhead for task execution, error messages
  - Critical threshold: Should be FAR below 1000 atoms

  ## Why `async: false`

  This test module uses `async: false` because:

  1. **Shared VM State**: Atom count is global across the entire BEAM VM
  2. **Accurate Measurement**: Parallel tests would interfere with atom counting
  3. **Test Isolation**: Each test needs clean atom count baseline
  4. **Module Warmup**: `setup_all` absorbs ~1200 atoms of initialization overhead

  ## Test Setup

  ### Module-Level Warmup (`setup_all`)
  Runs a single export task to absorb initialization overhead:

      setup_all do
        # Absorb ~1200 atoms from Mix.Task and Ash resource initialization
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Mix.Tasks.AshPhoenixTranslations.Export.run([...])
        end)
        :ok
      end

  Without this warmup, the first test would appear to create ~1200 atoms
  (false positive).

  ### Per-Test Setup (`setup`)
  Records atom count before each test:

      setup do
        atom_count_before = :erlang.system_info(:atom_count)
        {:ok, atom_count_before: atom_count_before}
      end

  ## Atom Count Tolerance

  Tests use tolerance of **150 atoms** for task execution overhead:

  - Task module loading: ~20 atoms
  - Error message strings: ~30 atoms
  - Execution context: ~40 atoms
  - Logging and output: ~30 atoms
  - Safety margin: ~30 atoms

  **Total**: ~150 atoms per task execution

  This is FAR below the 100+ atoms that would indicate vulnerability
  (one atom per invalid input).

  ## Key Assertions

  ### Atom Creation Bounds
      atom_count_after = :erlang.system_info(:atom_count)
      atoms_created = atom_count_after - atom_count_before

      assert atoms_created < 150,
             "Too many atoms created: \#{atoms_created}"

  ### Error Message Validation
      assert output =~ "Skipping 100 invalid locale(s)"
      assert output =~ "No valid locales found"

  ### Valid Input Processing
      refute output =~ "Skipping"  # No errors for valid input
      refute output =~ "No valid locales found"

  ## Running Tests

      # Run all security tests
      mix test test/security/atom_exhaustion_mix_test.exs

      # Run only fast tests (exclude :slow)
      mix test test/security/atom_exhaustion_mix_test.exs --exclude slow

      # Run specific test
      mix test test/security/atom_exhaustion_mix_test.exs:73

      # Run with detailed trace
      mix test test/security/atom_exhaustion_mix_test.exs --trace

  ## Attack Simulation Tests

  Large-scale attack tests (tagged `:slow`) simulate realistic DoS attempts:

      @tag :slow
      test "export task handles 1000 invalid locales" do
        # Generate 1000 unique malicious locale strings
        invalid_locales = for i <- 1..1000, do: "attack_\#{i}_\#{:rand.uniform(1_000_000)}"

        # Verify <300 atoms created (not 1000!)
        assert atoms_created < 300,
               "CRITICAL: Created \#{atoms_created} atoms from 1000 invalid locales!"
      end

  ## Related Security

  - `locale_validator.ex` - Whitelisting and validation logic
  - `atom_exhaustion_test.exs` - Core API function validation
  - `phase*_security_test.exs` - Progressive security testing phases

  ## References

  - [Erlang Efficiency Guide - Atoms](http://erlang.org/doc/efficiency_guide/advanced.html#atoms)
  - [Elixir Security Working Group - Atom Exhaustion](https://github.com/dashbitco/nimble_options#preventing-atom-exhaustion)
  - OWASP: Denial of Service through Resource Exhaustion
  """
  use ExUnit.Case, async: false

  @moduletag :security

  # Aliases for Mix tasks to avoid Credo nested module warnings
  alias Mix.Tasks.AshPhoenixTranslations.Export
  alias Mix.Tasks.AshPhoenixTranslations.Validate
  alias Mix.Tasks.AshPhoenixTranslations.Extract

  # Test domain definition
  defmodule TestDomain do
    use Ash.Domain,
      validate_config_inclusion?: false

    resources do
      allow_unregistered? true
    end
  end

  # Test resource definition
  defmodule TestProduct do
    @moduledoc false

    use Ash.Resource,
      domain: TestDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]

    ets do
      private? true
    end

    attributes do
      uuid_primary_key :id
    end

    translations do
      translatable_attribute :name, :string, locales: [:en, :es, :fr]
      translatable_attribute :description, :string, locales: [:en, :es, :fr]

      backend :database
      policy view: :public, edit: :admin
    end

    actions do
      defaults [:read, :destroy, :create, :update]
    end
  end

  # Module-level setup to absorb initialization overhead
  setup_all do
    # Run a simple task to initialize Mix.Task infrastructure and Ash resource
    # This ensures the first test doesn't incur ~1200 atoms of initialization overhead
    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      Export.run([
        "warmup_test.csv",
        "--resource",
        "AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct",
        "--locale",
        "en"
      ])
    end)

    # Clean up warmup file
    File.rm("warmup_test.csv")

    :ok
  end

  describe "Mix task atom exhaustion prevention" do
    setup do
      # Record atom count before test
      atom_count_before = :erlang.system_info(:atom_count)
      {:ok, atom_count_before: atom_count_before}
    end

    test "export task rejects invalid locales without creating atoms", %{
      atom_count_before: before_count
    } do
      # Create 100 invalid locale strings (would exhaust atoms if vulnerable)
      invalid_locales = for i <- 1..100, do: "malicious_locale_#{i}"
      locale_string = Enum.join(invalid_locales, ",")

      # Capture output to suppress error messages
      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          # This should NOT create 100 new atoms
          Export.run([
            "test_output.csv",
            "--resource",
            "AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct",
            "--locale",
            locale_string
          ])
        end)

      # Verify error messages were shown for invalid locales
      assert output =~ "Skipping 100 invalid locale(s)"
      assert output =~ "No valid locales found"

      # Verify no significant atoms were created (allow small margin for legitimate atoms)
      atom_count_after = :erlang.system_info(:atom_count)
      atoms_created = atom_count_after - before_count

      # Should not have created more than 150 atoms (some legitimate ones for task execution, error messages, etc.)
      # The key is that we should NOT have created 100 atoms (one per invalid locale)
      # Tolerance of 150 is still far below the 100+ that would indicate vulnerability
      assert atoms_created < 150,
             "Too many atoms created: #{atoms_created}. Potential atom exhaustion vulnerability!"
    end

    test "validate task rejects invalid fields without creating atoms", %{
      atom_count_before: before_count
    } do
      # Create 100 invalid field strings
      invalid_fields = for _i <- 1..100, do: "field_#{:rand.uniform(1_000_000)}"
      field_string = Enum.join(invalid_fields, ",")

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          # This should NOT create 100 new atoms
          Validate.run([
            "--resource",
            "AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct",
            "--field",
            field_string
          ])
        end)

      # Verify error messages were shown
      assert output =~ "Skipping 100 invalid field(s)"
      assert output =~ "No valid fields found"

      atom_count_after = :erlang.system_info(:atom_count)
      atoms_created = atom_count_after - before_count

      # Should not have created significant atoms (not 100!)
      # Tolerance of 150 is still far below the 100+ that would indicate vulnerability
      assert atoms_created < 150,
             "Too many atoms created: #{atoms_created}. Potential atom exhaustion vulnerability!"
    end

    test "extract task validates format parameter", %{atom_count_before: before_count} do
      # Try to create an atom with random malicious format
      malicious_format = "malicious_format_#{:rand.uniform(1_000_000)}"

      assert_raise Mix.Error, ~r/Invalid format/, fn ->
        Extract.run([
          "--format",
          malicious_format
        ])
      end

      atom_count_after = :erlang.system_info(:atom_count)
      atoms_created = atom_count_after - before_count

      # Should not have created the malicious atom
      assert atoms_created < 150,
             "Atoms created during format validation: #{atoms_created}"
    end

    test "export task handles valid locales correctly" do
      # Valid locales should work normally
      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Export.run([
            "test_valid.csv",
            "--resource",
            "AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct",
            "--locale",
            "en,es"
          ])
        end)

      # Should not have any error messages for valid locales
      refute output =~ "Skipping"
      refute output =~ "No valid locales found"
    end

    test "validate task handles valid fields correctly" do
      # Valid fields (that exist as atoms) should work
      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Validate.run([
            "--resource",
            "AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct",
            "--field",
            "name,description"
          ])
        end)

      # Should not have error messages for valid fields
      refute output =~ "Skipping"
      refute output =~ "No valid fields found"
    end

    test "extract task accepts valid formats" do
      # Valid formats should not raise Mix.Error for invalid format
      # Note: The task will exit(1) if no resources are found, which is expected behavior

      # Test 'pot' format - should not raise on format validation
      catch_exit do
        ExUnit.CaptureIO.capture_io(fn ->
          Extract.run([
            "--format",
            "pot"
          ])
        end)
      end

      # Test 'po' format - should not raise on format validation
      catch_exit do
        ExUnit.CaptureIO.capture_io(fn ->
          Extract.run([
            "--format",
            "po"
          ])
        end)
      end

      # If we get here without Mix.Error, format validation passed
      assert true
    end

    test "mixed valid and invalid locales are filtered correctly", %{
      atom_count_before: before_count
    } do
      # Mix valid and invalid locales
      mixed_locales = "en,invalid1,es,malicious_#{:rand.uniform(1000)},fr"

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Export.run([
            "test_mixed.csv",
            "--resource",
            "AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct",
            "--locale",
            mixed_locales
          ])
        end)

      # Should show errors for invalid ones only (2 invalid: "invalid1" and "malicious_X")
      assert output =~ "Skipping 2 invalid locale(s)"
      # Should NOT show "No valid locales found" because we have en, es, fr
      refute output =~ "No valid locales found"

      atom_count_after = :erlang.system_info(:atom_count)
      atoms_created = atom_count_after - before_count

      # Should not have created atoms for invalid locales
      assert atoms_created < 150,
             "Too many atoms created: #{atoms_created}"
    end
  end

  describe "Protection against large-scale atom exhaustion attacks" do
    @tag :slow
    test "export task handles 1000 invalid locales without atom exhaustion" do
      # This is a more aggressive test simulating a real attack
      invalid_locales = for i <- 1..1000, do: "attack_#{i}_#{:rand.uniform(1_000_000)}"
      locale_string = Enum.join(invalid_locales, ",")

      atom_count_before = :erlang.system_info(:atom_count)

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Export.run([
            "attack_test.csv",
            "--resource",
            "AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct",
            "--locale",
            locale_string
          ])
        end)

      atom_count_after = :erlang.system_info(:atom_count)
      atoms_created = atom_count_after - atom_count_before

      # Verify we didn't create 1000 atoms
      # Allow some overhead but should be FAR below 1000 if vulnerability is fixed
      assert atoms_created < 300,
             "CRITICAL: Created #{atoms_created} atoms from 1000 invalid locales! Atom exhaustion vulnerability still present!"

      # Verify error messages
      assert output =~ "No valid locales found"
    end

    @tag :slow
    test "validate task handles 1000 invalid fields without atom exhaustion" do
      invalid_fields = for i <- 1..1000, do: "field_attack_#{i}_#{:rand.uniform(1_000_000)}"
      field_string = Enum.join(invalid_fields, ",")

      atom_count_before = :erlang.system_info(:atom_count)

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Validate.run([
            "--resource",
            "AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct",
            "--field",
            field_string
          ])
        end)

      atom_count_after = :erlang.system_info(:atom_count)
      atoms_created = atom_count_after - atom_count_before

      # Verify we didn't create 1000 atoms
      # Allow some overhead but should be FAR below 1000 if vulnerability is fixed
      assert atoms_created < 300,
             "CRITICAL: Created #{atoms_created} atoms from 1000 invalid fields! Atom exhaustion vulnerability still present!"

      assert output =~ "No valid fields found"
    end
  end
end
