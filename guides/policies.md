# Translation Policies Guide

This guide covers how to configure policy-based access control for translations using Ash's built-in authorization system.

## Overview

AshPhoenixTranslations integrates seamlessly with Ash's policy system to provide fine-grained control over who can view, edit, and manage translations. This enables you to implement complex translation workflows with role-based access control.

## ⚠️ Important: How the Policy System Works

**The translation policy configuration is metadata-only.** The `policy` option in the `translations` block stores policy metadata but **does not automatically generate Ash Policy rules**. You must implement the actual Ash policies yourself using the standard `policies` block.

### What the Transformer Does

```elixir
translations do
  translatable_attribute :name, locales: [:en, :es, :fr]

  # This STORES METADATA but does NOT create actual policies
  policy view: :public, edit: :translator
end
```

The transformer:
1. ✅ Enables `Ash.Policy.Authorizer` extension
2. ✅ Stores policy configuration as metadata (accessible via `AshPhoenixTranslations.Info`)
3. ❌ **Does NOT generate policy rules automatically**

### What You Must Implement

You must add the actual policy rules in the `policies` block:

```elixir
policies do
  # YOU must implement these based on the metadata configuration
  policy action_type(:read) do
    authorize_if always()  # Because view: :public
  end

  policy action_type([:create, :update]) do
    authorize_if actor_attribute_equals(:role, :translator)  # Because edit: :translator
  end
end
```

### Why This Design?

Ash policies are extremely flexible and context-dependent. Rather than generating limited, opinionated policies automatically, AshPhoenixTranslations provides:

1. **Policy metadata** - Stores your intended policy configuration
2. **PolicyCheck module** - Provides helper functions for common authorization patterns
3. **Complete flexibility** - You write policies that match your exact requirements

### Using the PolicyCheck Module

AshPhoenixTranslations provides `AshPhoenixTranslations.PolicyCheck` with helper functions:

```elixir
alias AshPhoenixTranslations.PolicyCheck

policies do
  policy action_type(:read) do
    # Use the helper to check if actor can view translations
    authorize_if PolicyCheck.can_view_translations()
  end

  policy action_type([:create, :update]) do
    # Use the helper to check if actor can edit translations
    authorize_if PolicyCheck.can_edit_translations()
  end
end
```

The `PolicyCheck` module reads the metadata you configured and implements common authorization patterns. See the examples below for detailed usage.

## Basic Policy Configuration

**Note**: All examples below show both the metadata configuration (`policy` in `translations do`) and the actual policy implementation (`policies do`). Remember: the metadata stores your intent, but you must write the policy rules yourself.

### Simple Role-Based Access

```elixir
defmodule MyApp.Catalog.Product do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]
  
  translations do
    translatable_attribute :name, 
      locales: [:en, :es, :fr, :de],
      required: [:en]
    
    translatable_attribute :description,
      locales: [:en, :es, :fr, :de]
    
    # Translation-specific policies
    policy view: :public,     # Anyone can view translations  
           edit: :translator  # Only translators can edit
  end
  
  # Standard Ash policies
  policies do
    # Allow anyone to read products
    policy action_type(:read) do
      authorize_if always()
    end
    
    # Only admins and translators can modify translations
    policy action_type([:create, :update]) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :translator)
    end
  end
  
  attributes do
    uuid_primary_key :id
    attribute :sku, :string
    attribute :price, :decimal
    timestamps()
  end
  
  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

### Advanced Locale-Based Policies

```elixir
defmodule MyApp.Catalog.Product do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]
  
  translations do
    translatable_attribute :name, locales: [:en, :es, :fr, :de]
    translatable_attribute :description, locales: [:en, :es, :fr, :de]
    
    # Complex policy configuration
    policy view: :authenticated,  # Must be logged in to view
           edit: {:translator_for_locales, [:assigned_locales]},  # Can only edit assigned locales
           approval: [
             approvers: [:admin, :translation_manager],
             required_for: [:production]
           ]
  end
  
  policies do
    # View policies - anyone authenticated can read
    policy action_type(:read) do
      authorize_if actor_present()
    end
    
    # Translation edit policies - complex locale-based authorization
    policy action_type([:create, :update]) do
      # Admins can edit everything
      authorize_if actor_attribute_equals(:role, :admin)
      
      # Translation managers can edit everything
      authorize_if actor_attribute_equals(:role, :translation_manager)
      
      # Translators can only edit their assigned locales
      authorize_if expr(^actor(:role) == :translator and 
                       locale in ^actor(:assigned_locales))
    end
    
    # Special approval workflow for production environment
    policy changing_attributes([:name_translations, :description_translations]) do
      authorize_if not expr(^context(:environment) == :production)
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :translation_manager)
    end
  end
end
```

## User and Role System

### User Resource with Translation Roles

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    domain: MyApp.Accounts
  
  attributes do
    uuid_primary_key :id
    
    attribute :email, :string do
      allow_nil? false
    end
    
    attribute :name, :string
    
    # Role-based access control
    attribute :role, :atom do
      constraints one_of: [:user, :translator, :translation_manager, :admin]
      default :user
    end
    
    # Locale assignment for translators
    attribute :assigned_locales, {:array, :atom} do
      default []
    end
    
    # Translation-specific permissions
    attribute :translation_permissions, :map do
      default %{}
    end
    
    timestamps()
  end
  
  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :create_translator do
      accept [:email, :name, :assigned_locales]
      change set_attribute(:role, :translator)
    end
    
    update :assign_locales do
      accept [:assigned_locales]
      require_atomic? false
    end
  end
  
  code_interface do
    define :create_translator
    define :assign_locales
  end
end
```

### Role Management Functions

```elixir
defmodule MyApp.Accounts do
  @moduledoc "User and role management"
  
  def create_translator(email, name, locales) do
    MyApp.Accounts.User.create_translator(%{
      email: email,
      name: name,
      assigned_locales: locales
    })
  end
  
  def assign_translation_locales(user, locales) do
    MyApp.Accounts.User.assign_locales(user, %{assigned_locales: locales})
  end
  
  def can_edit_locale?(user, locale) do
    case user.role do
      :admin -> true
      :translation_manager -> true
      :translator -> locale in user.assigned_locales
      _ -> false
    end
  end
  
  def can_approve_translations?(user) do
    user.role in [:admin, :translation_manager]
  end
  
  def translation_dashboard_access?(user) do
    user.role in [:admin, :translation_manager, :translator]
  end
end
```

## Context-Based Authorization

### Environment-Aware Policies

```elixir
defmodule MyApp.Catalog.Product do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]
  
  translations do
    translatable_attribute :name, locales: [:en, :es, :fr, :de]
    
    # Environment-specific policies
    policy view: :public,
           edit: :translator,
           approval: [
             approvers: [:admin],
             required_for: [:staging, :production]
           ]
  end
  
  policies do
    # Development environment - relaxed rules
    policy expr(^context(:environment) == :development) do
      authorize_if always()
    end
    
    # Staging environment - require approval
    policy expr(^context(:environment) == :staging) do
      policy action_type([:create, :update]) do
        authorize_if actor_attribute_equals(:role, :admin)
        authorize_if expr(
          ^actor(:role) == :translator and 
          approved_by in [:admin, :translation_manager]
        )
      end
    end
    
    # Production environment - strict controls
    policy expr(^context(:environment) == :production) do
      policy action_type([:create, :update]) do
        # Only approved translations can be updated
        authorize_if actor_attribute_equals(:role, :admin)
        authorize_if expr(
          ^actor(:role) == :translation_manager and
          translation_approved? == true
        )
      end
    end
  end
end
```

### Locale-Specific Authorization

```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]
  
  translations do
    translatable_attribute :title, locales: [:en, :es, :fr, :de, :ja, :zh]
    translatable_attribute :content, locales: [:en, :es, :fr, :de, :ja, :zh]
  end
  
  policies do
    # Base read access
    policy action_type(:read) do
      authorize_if always()
    end
    
    # Locale-specific edit policies
    policy action_type([:create, :update]) do
      # Admins can edit all locales
      authorize_if actor_attribute_equals(:role, :admin)
      
      # European language translators
      authorize_if expr(
        ^actor(:role) == :translator and
        ^actor(:specialization) == :european and
        locale in [:en, :es, :fr, :de]
      )
      
      # Asian language translators  
      authorize_if expr(
        ^actor(:role) == :translator and
        ^actor(:specialization) == :asian and
        locale in [:ja, :zh]
      )
      
      # Native speakers can edit their language
      authorize_if expr(
        ^actor(:role) == :native_speaker and
        locale == ^actor(:native_locale)
      )
    end
  end
end
```

## Approval Workflows

### Translation Approval System

```elixir
defmodule MyApp.Catalog.Product do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]
  
  translations do
    translatable_attribute :name, locales: [:en, :es, :fr, :de]
    translatable_attribute :description, locales: [:en, :es, :fr, :de]
    
    # Approval workflow configuration
    policy edit: :translator,
           approval: [
             approvers: [:admin, :translation_manager],
             required_for: [:production],
             auto_approve_for: [:admin]
           ]
    
    audit_changes true  # Required for approval workflows
  end
  
  attributes do
    # Approval tracking fields (added by transformers)
    attribute :translation_status, :atom do
      constraints one_of: [:draft, :pending_approval, :approved, :rejected]
      default :draft
    end
    
    attribute :approved_by, :uuid
    attribute :approved_at, :datetime
    attribute :rejection_reason, :text
  end
  
  actions do
    defaults [:create, :read, :update, :destroy]
    
    # Translation-specific actions
    create :create_translation do
      accept [:sku, :price, :name_translations, :description_translations]
      change set_attribute(:translation_status, :draft)
    end
    
    update :submit_for_approval do
      require_atomic? false
      change set_attribute(:translation_status, :pending_approval)
      
      validate present([:name_translations, :description_translations])
    end
    
    update :approve_translation do
      require_atomic? false
      accept [:approved_by]
      change set_attribute(:translation_status, :approved)
      change set_attribute(:approved_at, &DateTime.utc_now/0)
    end
    
    update :reject_translation do
      require_atomic? false
      accept [:rejection_reason]
      change set_attribute(:translation_status, :rejected)
    end
  end
  
  policies do
    # Anyone can read approved translations
    policy action([:read]) do
      authorize_if expr(translation_status in [:approved, :draft])
    end
    
    # Translators can create and edit drafts
    policy action([:create_translation, :submit_for_approval]) do
      authorize_if actor_attribute_equals(:role, :translator)
    end
    
    # Only translation managers and admins can approve/reject
    policy action([:approve_translation, :reject_translation]) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :translation_manager)
    end
    
    # Prevent editing approved translations
    policy action(:update) do
      forbid_if expr(translation_status == :approved)
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end
end
```

### Approval Workflow Implementation

```elixir
defmodule MyApp.TranslationWorkflow do
  @moduledoc "Translation approval workflow implementation"
  
  alias MyApp.Accounts.User
  alias MyApp.Catalog.Product
  
  def submit_for_approval(product, translator) do
    with :ok <- validate_translation_completeness(product),
         {:ok, updated} <- Product.submit_for_approval(product),
         :ok <- notify_approvers(updated, translator) do
      {:ok, updated}
    end
  end
  
  def approve_translation(product, approver) do
    with {:ok, updated} <- Product.approve_translation(product, %{approved_by: approver.id}),
         :ok <- notify_translator(updated, approver, :approved) do
      {:ok, updated}
    end
  end
  
  def reject_translation(product, approver, reason) do
    with {:ok, updated} <- Product.reject_translation(product, %{rejection_reason: reason}),
         :ok <- notify_translator(updated, approver, :rejected) do
      {:ok, updated}
    end
  end
  
  defp validate_translation_completeness(product) do
    case AshPhoenixTranslations.translation_completeness(product) do
      completeness when completeness >= 80.0 -> :ok
      _ -> {:error, "Translation must be at least 80% complete"}
    end
  end
  
  defp notify_approvers(product, translator) do
    approvers = User |> Ash.Query.filter(role: [:admin, :translation_manager]) |> Ash.read!()
    
    Enum.each(approvers, fn approver ->
      MyApp.Notifications.send_approval_request(approver, product, translator)
    end)
    
    :ok
  end
  
  defp notify_translator(product, approver, status) do
    # Implementation depends on your notification system
    :ok
  end
end
```

## Advanced Policy Examples

### Time-Based Policies

```elixir
defmodule MyApp.Campaign.Promotion do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]
  
  translations do
    translatable_attribute :title, locales: [:en, :es, :fr]
    translatable_attribute :description, locales: [:en, :es, :fr]
  end
  
  attributes do
    uuid_primary_key :id
    attribute :start_date, :date
    attribute :end_date, :date
    attribute :is_active, :boolean, default: false
  end
  
  policies do
    # Can only edit translations before campaign starts
    policy action_type([:create, :update]) do
      authorize_if expr(is_nil(start_date) or start_date > ^Date.utc_today())
      authorize_if actor_attribute_equals(:role, :admin)  # Admins can always edit
    end
    
    # Different rules for active campaigns
    policy expr(is_active == true) do
      forbid_unless actor_attribute_equals(:role, :admin)
    end
  end
end
```

### Regional Policies

```elixir
defmodule MyApp.Store.Product do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]
  
  translations do
    translatable_attribute :name, locales: [:en, :es, :fr, :de, :pt, :it]
    translatable_attribute :description, locales: [:en, :es, :fr, :de, :pt, :it]
  end
  
  attributes do
    uuid_primary_key :id
    attribute :available_regions, {:array, :atom}, default: [:global]
  end
  
  policies do
    # Regional translation editors
    policy action_type([:create, :update]) do
      # North American locales
      authorize_if expr(
        ^actor(:role) == :regional_translator and
        ^actor(:region) == :north_america and
        locale in [:en, :es]
      )
      
      # European locales
      authorize_if expr(
        ^actor(:role) == :regional_translator and
        ^actor(:region) == :europe and
        locale in [:en, :es, :fr, :de, :pt, :it]
      )
      
      # Global admins can edit all locales
      authorize_if actor_attribute_equals(:role, :global_admin)
    end
  end
end
```

## Testing Policies

### Policy Testing Setup

```elixir
defmodule MyApp.TranslationPoliciesTest do
  use MyApp.DataCase
  
  alias MyApp.Accounts.User
  alias MyApp.Catalog.Product
  
  describe "translation view policies" do
    test "public can view translations" do
      product = insert(:product_with_translations)
      
      assert {:ok, _} = Product.get!(product.id, authorize?: true, actor: nil)
    end
    
    test "authenticated users can view all translations" do
      user = insert(:user)
      product = insert(:product_with_translations)
      
      assert {:ok, _} = Product.get!(product.id, authorize?: true, actor: user)
    end
  end
  
  describe "translation edit policies" do
    test "admin can edit all translations" do
      admin = insert(:user, role: :admin)
      product = insert(:product)
      
      params = %{
        name_translations: %{en: "New Name", es: "Nuevo Nombre"}
      }
      
      assert {:ok, updated} = Product.update!(product, params, authorize?: true, actor: admin)
      assert updated.name_translations.en == "New Name"
    end
    
    test "translator can only edit assigned locales" do
      translator = insert(:user, role: :translator, assigned_locales: [:en, :es])
      product = insert(:product)
      
      # Should succeed for assigned locales
      params = %{name_translations: %{en: "New Name", es: "Nuevo Nombre"}}
      assert {:ok, _} = Product.update!(product, params, authorize?: true, actor: translator)
      
      # Should fail for unassigned locales
      params = %{name_translations: %{fr: "Nouveau Nom"}}
      assert_raise Ash.Error.Forbidden, fn ->
        Product.update!(product, params, authorize?: true, actor: translator)
      end
    end
    
    test "regular user cannot edit translations" do
      user = insert(:user, role: :user)
      product = insert(:product)
      
      params = %{name_translations: %{en: "New Name"}}
      
      assert_raise Ash.Error.Forbidden, fn ->
        Product.update!(product, params, authorize?: true, actor: user)
      end
    end
  end
  
  describe "approval workflow policies" do
    test "translator can submit for approval" do
      translator = insert(:user, role: :translator, assigned_locales: [:en, :es])
      product = insert(:product, translation_status: :draft)
      
      assert {:ok, updated} = Product.submit_for_approval!(product, authorize?: true, actor: translator)
      assert updated.translation_status == :pending_approval
    end
    
    test "translation manager can approve translations" do
      manager = insert(:user, role: :translation_manager)
      product = insert(:product, translation_status: :pending_approval)
      
      params = %{approved_by: manager.id}
      assert {:ok, updated} = Product.approve_translation!(product, params, authorize?: true, actor: manager)
      assert updated.translation_status == :approved
      assert updated.approved_by == manager.id
    end
    
    test "translator cannot approve their own translations" do
      translator = insert(:user, role: :translator)
      product = insert(:product, translation_status: :pending_approval)
      
      params = %{approved_by: translator.id}
      assert_raise Ash.Error.Forbidden, fn ->
        Product.approve_translation!(product, params, authorize?: true, actor: translator)
      end
    end
  end
end
```

### Factory Setup for Testing

```elixir
defmodule MyApp.Factory do
  use ExMachina.Ecto, repo: MyApp.Repo
  
  def user_factory do
    %MyApp.Accounts.User{
      email: sequence(:email, &"user#{&1}@example.com"),
      name: "Test User",
      role: :user,
      assigned_locales: []
    }
  end
  
  def translator_factory do
    struct!(
      user_factory(),
      %{
        role: :translator,
        assigned_locales: [:en, :es]
      }
    )
  end
  
  def admin_factory do
    struct!(
      user_factory(),
      %{
        role: :admin,
        assigned_locales: [:en, :es, :fr, :de]
      }
    )
  end
  
  def product_factory do
    %MyApp.Catalog.Product{
      sku: sequence(:sku, &"PROD-#{&1}"),
      price: Decimal.new("99.99"),
      translation_status: :draft
    }
  end
  
  def product_with_translations_factory do
    struct!(
      product_factory(),
      %{
        name_translations: %{
          en: "Test Product",
          es: "Producto de Prueba"
        },
        description_translations: %{
          en: "A great test product",
          es: "Un gran producto de prueba"
        }
      }
    )
  end
end
```

This comprehensive policies guide covers all aspects of configuring and implementing authorization for translations in AshPhoenixTranslations, from basic role-based access to complex approval workflows.