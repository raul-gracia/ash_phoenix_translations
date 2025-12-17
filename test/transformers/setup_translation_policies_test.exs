defmodule AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  describe "Public View Policy" do
    defmodule PublicViewProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_public_view_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es]
        end

        backend :database
        policy view: :public
      end

      actions do
        create :create
        read :read
        update :update
        destroy :destroy
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "sets public view policy" do
      # Check that view policy is set to public
      assert AshPhoenixTranslations.Info.view_policy(PublicViewProduct) == :public
    end
  end

  describe "Authenticated View Policy" do
    defmodule AuthenticatedViewProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_authenticated_view_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es]
        end

        backend :database
        policy view: :authenticated
      end

      actions do
        create :create
        read :read
        update :update
        destroy :destroy
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "sets authenticated view policy" do
      assert AshPhoenixTranslations.Info.view_policy(AuthenticatedViewProduct) == :authenticated
    end
  end

  describe "Admin Edit Policy" do
    defmodule AdminEditProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_admin_edit_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es]
        end

        backend :database
        policy edit: :admin
      end

      actions do
        create :create
        read :read
        update :update
        destroy :destroy
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "sets admin edit policy" do
      assert AshPhoenixTranslations.Info.edit_policy(AdminEditProduct) == :admin
    end
  end

  describe "Translator Edit Policy" do
    defmodule TranslatorEditProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_translator_edit_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
        end

        backend :database
        policy edit: :translator
      end

      actions do
        create :create
        read :read
        update :update
        destroy :destroy
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "sets translator edit policy" do
      assert AshPhoenixTranslations.Info.edit_policy(TranslatorEditProduct) == :translator
    end
  end

  describe "Role-based Policies" do
    defmodule RoleBasedProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_role_based_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es]
        end

        backend :database

        policy view: {:locale, [en: [:viewer, :editor], es: [:spanish_viewer]]},
               edit: {:role, [:editor, :admin]}
      end

      actions do
        create :create
        read :read
        update :update
        destroy :destroy
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "sets role-based policies" do
      assert AshPhoenixTranslations.Info.view_policy(RoleBasedProduct) ==
               {:locale, [en: [:viewer, :editor], es: [:spanish_viewer]]}

      assert AshPhoenixTranslations.Info.edit_policy(RoleBasedProduct) ==
               {:role, [:editor, :admin]}
    end
  end

  describe "Approval Workflow Policy" do
    defmodule ApprovalWorkflowProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_approval_workflow_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es]
        end

        backend :database

        policy edit: :translator,
               approval: [
                 approvers: [:admin, :senior_translator],
                 required_for: [:production]
               ]
      end

      actions do
        create :create
        read :read
        update :update
        destroy :destroy
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "sets approval workflow policy" do
      assert AshPhoenixTranslations.Info.approval_policy(ApprovalWorkflowProduct) == [
               approvers: [:admin, :senior_translator],
               required_for: [:production]
             ]
    end
  end

  describe "No Policy Configuration" do
    defmodule NoPolicyProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_no_policy_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es]
        end

        backend :database
        # No policy configuration
      end

      actions do
        create :create
        read :read
        update :update
        destroy :destroy
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "does not set policies when not configured" do
      # Default view is public, edit is admin when not configured
      assert AshPhoenixTranslations.Info.view_policy(NoPolicyProduct) == :public
      assert AshPhoenixTranslations.Info.edit_policy(NoPolicyProduct) == :admin
      assert AshPhoenixTranslations.Info.approval_policy(NoPolicyProduct) == nil
    end
  end

  describe "Policy Check Module" do
    test "authenticated check works correctly" do
      capture_log(fn ->
        # Test with nil actor
        refute AshPhoenixTranslations.PolicyCheck.match?(
                 nil,
                 %{
                   action: %{
                     name: :read,
                     resource:
                       AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.AuthenticatedViewProduct
                   }
                 },
                 []
               )

        # Test with authenticated actor
        assert AshPhoenixTranslations.PolicyCheck.match?(
                 %{id: "user-123"},
                 %{
                   action: %{
                     name: :read,
                     resource:
                       AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.AuthenticatedViewProduct
                   }
                 },
                 []
               )
      end)
    end

    test "admin edit check works correctly" do
      capture_log(fn ->
        # Test with non-admin actor
        refute AshPhoenixTranslations.PolicyCheck.match?(
                 %{role: :translator},
                 %{
                   action: %{
                     name: :update_translation,
                     resource:
                       AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.AdminEditProduct
                   }
                 },
                 []
               )

        # Test with admin actor
        assert AshPhoenixTranslations.PolicyCheck.match?(
                 %{role: :admin},
                 %{
                   action: %{
                     name: :update_translation,
                     resource:
                       AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.AdminEditProduct
                   }
                 },
                 []
               )
      end)
    end

    test "translator edit check works correctly" do
      capture_log(fn ->
        # Test translator with assigned locale
        assert AshPhoenixTranslations.PolicyCheck.match?(
                 %{role: :translator, assigned_locales: [:en, :es]},
                 %{
                   action: %{
                     name: :update_translation,
                     arguments: %{locale: :en},
                     resource:
                       AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.TranslatorEditProduct
                   }
                 },
                 []
               )

        # Test translator without assigned locale
        refute AshPhoenixTranslations.PolicyCheck.match?(
                 %{role: :translator, assigned_locales: [:es]},
                 %{
                   action: %{
                     name: :update_translation,
                     arguments: %{locale: :en},
                     resource:
                       AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.TranslatorEditProduct
                   }
                 },
                 []
               )
      end)
    end

    test "role-based check works correctly" do
      capture_log(fn ->
        # Test with allowed role
        assert AshPhoenixTranslations.PolicyCheck.match?(
                 %{role: :editor},
                 %{
                   action: %{
                     name: :update_translation,
                     resource:
                       AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.RoleBasedProduct
                   }
                 },
                 []
               )

        # Test with disallowed role
        refute AshPhoenixTranslations.PolicyCheck.match?(
                 %{role: :viewer},
                 %{
                   action: %{
                     name: :update_translation,
                     resource:
                       AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.RoleBasedProduct
                   }
                 },
                 []
               )
      end)
    end
  end

  # Test domain
  defmodule Domain do
    use Ash.Domain,
      validate_config_inclusion?: false

    resources do
      resource AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.PublicViewProduct

      resource AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.AuthenticatedViewProduct

      resource AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.AdminEditProduct

      resource AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.TranslatorEditProduct

      resource AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.RoleBasedProduct

      resource AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.ApprovalWorkflowProduct

      resource AshPhoenixTranslations.Transformers.SetupTranslationPoliciesTest.NoPolicyProduct
    end
  end
end
