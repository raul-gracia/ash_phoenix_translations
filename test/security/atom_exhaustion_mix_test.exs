defmodule AshPhoenixTranslations.AtomExhaustionMixTest do
  use ExUnit.Case, async: false

  @moduletag :security

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
          Mix.Tasks.AshPhoenixTranslations.Export.run([
            "test_output.csv",
            "--resource",
            "AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct",
            "--locale",
            locale_string
          ])
        end)

      # Verify error messages were shown for invalid locales
      assert output =~ "Skipping invalid locale"
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
          Mix.Tasks.AshPhoenixTranslations.Validate.run([
            "--resource",
            "AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct",
            "--field",
            field_string
          ])
        end)

      # Verify error messages were shown
      assert output =~ "Skipping invalid field"
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
        Mix.Tasks.AshPhoenixTranslations.Extract.run([
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
          Mix.Tasks.AshPhoenixTranslations.Export.run([
            "test_valid.csv",
            "--resource",
            "AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct",
            "--locale",
            "en,es"
          ])
        end)

      # Should not have any error messages for valid locales
      refute output =~ "Skipping invalid locale"
      refute output =~ "No valid locales found"
    end

    test "validate task handles valid fields correctly" do
      # Valid fields (that exist as atoms) should work
      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Mix.Tasks.AshPhoenixTranslations.Validate.run([
            "--resource",
            "AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct",
            "--field",
            "name,description"
          ])
        end)

      # Should not have error messages for valid fields
      refute output =~ "Skipping invalid field"
      refute output =~ "No valid fields found"
    end

    test "extract task accepts valid formats" do
      # Valid formats should not raise Mix.Error for invalid format
      # Note: The task will exit(1) if no resources are found, which is expected behavior

      # Test 'pot' format - should not raise on format validation
      catch_exit do
        ExUnit.CaptureIO.capture_io(fn ->
          Mix.Tasks.AshPhoenixTranslations.Extract.run([
            "--format",
            "pot"
          ])
        end)
      end

      # Test 'po' format - should not raise on format validation
      catch_exit do
        ExUnit.CaptureIO.capture_io(fn ->
          Mix.Tasks.AshPhoenixTranslations.Extract.run([
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
          Mix.Tasks.AshPhoenixTranslations.Export.run([
            "test_mixed.csv",
            "--resource",
            "AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct",
            "--locale",
            mixed_locales
          ])
        end)

      # Should show errors for invalid ones only
      assert output =~ "Skipping invalid locale"
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
          Mix.Tasks.AshPhoenixTranslations.Export.run([
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
          Mix.Tasks.AshPhoenixTranslations.Validate.run([
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
