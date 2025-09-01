defmodule AshPhoenixTranslations do
  @moduledoc """
  AshPhoenixTranslations - A powerful Ash Framework extension for handling translations
  in Phoenix applications with policy-aware, multi-backend support.

  ## Installation

  Add to your mix.exs:

      {:ash_phoenix_translations, "~> 1.0"}

  ## Usage

  Add to your resource:

      defmodule MyApp.Product do
        use Ash.Resource,
          extensions: [AshPhoenixTranslations]

        translations do
          translatable_attribute :name, :string do
            locales [:en, :es, :fr]
            required [:en]
          end

          translatable_attribute :description, :text do
            locales [:en, :es, :fr]
            markdown true
          end

          backend :database
          cache_ttl 3600
        end
      end

  ## Examples

      iex> # Assuming you have a product with translations
      iex> product = %{
      ...>   __struct__: MyApp.Product,
      ...>   id: "123",
      ...>   name_translations: %{en: "Product", es: "Producto"},
      ...>   description_translations: %{en: "Description", es: "Descripción"}
      ...> }
      iex> 
      iex> # Translate to Spanish
      iex> spanish_product = AshPhoenixTranslations.translate(product, :es)
      iex> spanish_product.name
      "Producto"
      
      iex> # Translate multiple resources  
      iex> products = [product, product]
      iex> spanish_products = AshPhoenixTranslations.translate_all(products, :es)
      iex> length(spanish_products)
      2

  """

  @transformers [
    AshPhoenixTranslations.Transformers.AddTranslationStorage,
    AshPhoenixTranslations.Transformers.AddTranslationRelationships,
    AshPhoenixTranslations.Transformers.AddTranslationActions,
    AshPhoenixTranslations.Transformers.AddTranslationCalculations,
    AshPhoenixTranslations.Transformers.AddTranslationChanges,
    AshPhoenixTranslations.Transformers.SetupTranslationPolicies
  ]

  use Spark.Dsl.Extension,
    transformers: @transformers,
    sections: [
      %Spark.Dsl.Section{
        name: :translations,
        describe: "Configure translation behavior for the resource",
        schema: [
          backend: [
            type: {:in, [:database, :gettext]},
            default: :database,
            doc: "The backend to use for storing translations"
          ],
          gettext_module: [
            type: :atom,
            doc: "The Gettext module to use (e.g., MyAppWeb.Gettext). Required when backend is :gettext"
          ],
          cache_ttl: [
            type: :pos_integer,
            default: 3600,
            doc: "Cache TTL in seconds"
          ],
          audit_changes: [
            type: :boolean,
            default: false,
            doc: "Whether to audit translation changes"
          ],
          auto_validate: [
            type: :boolean,
            default: true,
            doc: "Whether to automatically validate required translations"
          ],
          policy: [
            type: :keyword_list,
            doc: "Policy configuration for translation access control",
            keys: [
              view: [
                type: {:or, [
                  {:in, [:public, :authenticated, :admin, :translator]},
                  {:tuple, [:atom, :keyword_list]},
                  :atom
                ]},
                doc: "Policy for viewing translations"
              ],
              edit: [
                type: {:or, [
                  {:in, [:admin, :translator]},
                  {:tuple, [:atom, {:list, :atom}]},
                  :atom
                ]},
                doc: "Policy for editing translations"
              ],
              approval: [
                type: :keyword_list,
                doc: "Approval workflow configuration",
                keys: [
                  approvers: [
                    type: {:list, :atom},
                    doc: "List of roles that can approve translations"
                  ],
                  required_for: [
                    type: {:list, :atom},
                    doc: "Environments where approval is required"
                  ]
                ]
              ]
            ]
          ]
        ],
        entities: [
          %Spark.Dsl.Entity{
            name: :translatable_attribute,
            describe: "Define a translatable attribute",
            args: [:name, :type],
            target: AshPhoenixTranslations.TranslatableAttribute,
            schema: AshPhoenixTranslations.TranslatableAttribute.schema(),
            transform: {AshPhoenixTranslations.TranslatableAttribute, :transform, []}
          }
        ]
      }
    ]

  @doc """
  Translate a single resource based on the connection's locale.
  
  This function loads calculated translation fields based on the current locale
  and returns a copy of the resource with the translated values.
  
  ## Examples
  
      # Translate based on conn locale
      product = MyApp.Product |> MyApp.Product.get!(id)
      translated = AshPhoenixTranslations.translate(product, conn)
      translated.name  # Returns the name in the current locale
      
      # Translate to specific locale
      spanish_product = AshPhoenixTranslations.translate(product, :es)
      spanish_product.name  # Returns Spanish translation
      
      # Translate from LiveView socket
      translated = AshPhoenixTranslations.translate(product, socket)
  """
  def translate(resource, conn_or_socket_or_locale)

  def translate(resource, %Plug.Conn{} = conn) do
    locale = get_locale(conn)
    do_translate(resource, locale)
  end

  def translate(resource, %Phoenix.LiveView.Socket{} = socket) do
    locale = get_locale(socket)
    do_translate(resource, locale)
  end

  def translate(resource, locale) when is_atom(locale) do
    do_translate(resource, locale)
  end

  @doc """
  Translate multiple resources based on the connection's locale.
  
  ## Examples
  
      products = MyApp.Product.list!()
      translated_products = AshPhoenixTranslations.translate_all(products, conn)
      
      # All products now have calculated translation fields
      Enum.each(translated_products, fn product ->
        IO.inspect(product.name)  # Shows name in current locale
      end)
  """
  def translate_all(resources, conn_or_socket_or_locale) when is_list(resources) do
    locale =
      case conn_or_socket_or_locale do
        %Plug.Conn{} = conn -> get_locale(conn)
        %Phoenix.LiveView.Socket{} = socket -> get_locale(socket)
        locale when is_atom(locale) -> locale
      end

    Enum.map(resources, &do_translate(&1, locale))
  end

  @doc """
  Live translate a resource for LiveView with reactive updates.
  
  This function translates a resource and stores it in socket assigns
  for reactive LiveView updates when the locale changes.
  
  ## Examples
  
      def mount(_params, _session, socket) do
        product = MyApp.Product.get!(id)
        {translated_product, socket} = AshPhoenixTranslations.live_translate(product, socket)
        
        socket = assign(socket, product: translated_product)
        {:ok, socket}
      end
  """
  def live_translate(resource, %Phoenix.LiveView.Socket{} = socket) do
    locale = get_locale(socket)
    translated = do_translate(resource, locale)

    # Store in socket assigns for reactive updates
    socket =
      socket
      |> Phoenix.Component.assign(:__translated_resource__, translated)
      |> Phoenix.Component.assign(:__translation_locale__, locale)

    {translated, socket}
  end

  @doc """
  Update the locale for a LiveView socket and retranslate resources.
  
  ## Examples
  
      def handle_event("change_locale", %{"locale" => locale}, socket) do
        socket = AshPhoenixTranslations.update_locale(socket, String.to_atom(locale))
        {:noreply, socket}
      end
  """
  def update_locale(%Phoenix.LiveView.Socket{} = socket, locale) when is_atom(locale) do
    socket
    |> Phoenix.Component.assign(:__translation_locale__, locale)
    |> maybe_retranslate_resources()
  end

  defp do_translate(resource, locale) do
    # Get the calculation names directly from the resource
    calculations = 
      resource.__struct__
      |> Ash.Resource.Info.calculations()
      |> Enum.filter(fn calc ->
        # Only load translation-related calculations
        String.contains?(to_string(calc.name), ["name", "description", "features"]) &&
        !String.contains?(to_string(calc.name), "_all_translations")
      end)
      |> Enum.map(& &1.name)
    
    # Load the calculations with locale context
    resource
    |> Ash.load!(calculations, authorize?: false, context: %{locale: locale})
  end


  defp get_locale(%Plug.Conn{} = conn) do
    Plug.Conn.get_session(conn, :locale) ||
      conn.assigns[:locale] ||
      Application.get_env(:ash_phoenix_translations, :default_locale, :en)
  end

  defp get_locale(%Phoenix.LiveView.Socket{} = socket) do
    socket.assigns[:__translation_locale__] ||
      Phoenix.Component.get_connect_params(socket)["locale"] ||
      Application.get_env(:ash_phoenix_translations, :default_locale, :en)
  end

  defp maybe_retranslate_resources(%Phoenix.LiveView.Socket{} = socket) do
    case socket.assigns[:__translated_resource__] do
      nil ->
        socket

      resource ->
        locale = socket.assigns[:__translation_locale__]
        retranslated = do_translate(resource, locale)
        Phoenix.Component.assign(socket, :__translated_resource__, retranslated)
    end
  end
end