defmodule Example.Blog do
  @moduledoc """
  Example blog application demonstrating AshPhoenixTranslations usage.
  
  This module shows how to use translations in a real-world scenario
  with blog posts and categories.
  """
  
  defmodule Domain do
    use Ash.Domain
    
    resources do
      resource Example.Blog.Post
      resource Example.Blog.Category
      resource Example.Blog.Author
    end
  end
  
  defmodule Post do
    use Ash.Resource,
      domain: Example.Blog.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]
    
    translations do
      translatable_attribute :title, :string,
        locales: [:en, :es, :fr, :de, :ja],
        required: [:en],
        max_length: 200
      
      translatable_attribute :content, :text,
        locales: [:en, :es, :fr, :de, :ja],
        required: [:en]
      
      translatable_attribute :excerpt, :text,
        locales: [:en, :es, :fr, :de, :ja],
        max_length: 500
      
      backend :database
      cache_ttl 7200  # 2 hours
      audit_changes true
    end
    
    attributes do
      uuid_primary_key :id
      
      attribute :slug, :string do
        allow_nil? false
      end
      
      attribute :published_at, :datetime
      attribute :views, :integer, default: 0
      attribute :featured, :boolean, default: false
      
      timestamps()
    end
    
    relationships do
      belongs_to :author, Example.Blog.Author
      belongs_to :category, Example.Blog.Category
    end
    
    actions do
      defaults [:read, :destroy]
      
      create :create do
        accept [:slug, :published_at, :featured, :author_id, :category_id]
        # Translation fields are automatically accepted
      end
      
      update :update do
        accept [:slug, :published_at, :featured, :views]
        # Translation fields are automatically accepted
      end
      
      read :published do
        filter expr(not is_nil(published_at) and published_at <= now())
      end
      
      read :featured do
        filter expr(featured == true)
      end
      
      update :increment_views do
        change increment(:views)
      end
    end
    
    calculations do
      calculate :published?, :boolean do
        calculation fn record, _ ->
          record.published_at && DateTime.compare(record.published_at, DateTime.utc_now()) == :lt
        end
      end
      
      calculate :word_count, :integer do
        calculation fn record, _ ->
          content = record.content_translations[Ash.context().locale] || record.content_translations[:en]
          if content, do: length(String.split(content)), else: 0
        end
      end
    end
    
    code_interface do
      define :create
      define :get_by_id, args: [:id], action: :read
      define :get_by_slug, args: [:slug], action: :read, get?: true
      define :list_published, action: :published
      define :list_featured, action: :featured
      define :update
      define :increment_views
    end
  end
  
  defmodule Category do
    use Ash.Resource,
      domain: Example.Blog.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]
    
    translations do
      translatable_attribute :name, :string,
        locales: [:en, :es, :fr, :de, :ja],
        required: [:en]
      
      translatable_attribute :description, :text,
        locales: [:en, :es, :fr, :de, :ja]
      
      backend :database
      cache_ttl 86400  # 24 hours - categories change rarely
    end
    
    attributes do
      uuid_primary_key :id
      
      attribute :slug, :string do
        allow_nil? false
      end
      
      attribute :color, :string, default: "#3B82F6"
      attribute :icon, :string
      
      timestamps()
    end
    
    relationships do
      has_many :posts, Example.Blog.Post
    end
    
    actions do
      defaults [:create, :read, :update, :destroy]
    end
    
    calculations do
      calculate :post_count, :integer do
        calculation fn _record, _ ->
          # In real app, this would count related posts
          0
        end
      end
    end
    
    code_interface do
      define :create
      define :get_by_id, args: [:id], action: :read
      define :get_by_slug, args: [:slug], action: :read, get?: true
      define :list
      define :update
    end
  end
  
  defmodule Author do
    use Ash.Resource,
      domain: Example.Blog.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]
    
    translations do
      translatable_attribute :bio, :text,
        locales: [:en, :es, :fr, :de, :ja],
        max_length: 1000
      
      backend :database
      cache_ttl 86400  # 24 hours
    end
    
    attributes do
      uuid_primary_key :id
      
      attribute :name, :string do
        allow_nil? false
      end
      
      attribute :email, :string do
        allow_nil? false
      end
      
      attribute :avatar_url, :string
      attribute :website, :string
      attribute :twitter, :string
      
      timestamps()
    end
    
    relationships do
      has_many :posts, Example.Blog.Post
    end
    
    actions do
      defaults [:create, :read, :update, :destroy]
    end
    
    code_interface do
      define :create
      define :get_by_id, args: [:id], action: :read
      define :get_by_email, args: [:email], action: :read, get?: true
      define :list
      define :update
    end
  end
  
  @doc """
  Seeds example data for testing and demonstration.
  """
  def seed_data do
    # Create authors
    {:ok, author1} = Author.create(%{
      name: "Jane Doe",
      email: "jane@example.com",
      bio_translations: %{
        en: "Tech writer and software engineer with 10+ years of experience.",
        es: "Escritora técnica e ingeniera de software con más de 10 años de experiencia.",
        fr: "Rédactrice technique et ingénieure logiciel avec plus de 10 ans d'expérience.",
        de: "Technische Autorin und Software-Ingenieurin mit über 10 Jahren Erfahrung.",
        ja: "10年以上の経験を持つテクニカルライターおよびソフトウェアエンジニア。"
      },
      website: "https://janedoe.com",
      twitter: "@janedoe"
    })
    
    {:ok, author2} = Author.create(%{
      name: "John Smith",
      email: "john@example.com",
      bio_translations: %{
        en: "Full-stack developer passionate about Elixir and functional programming.",
        es: "Desarrollador full-stack apasionado por Elixir y la programación funcional.",
        fr: "Développeur full-stack passionné par Elixir et la programmation fonctionnelle."
      }
    })
    
    # Create categories
    {:ok, tech_category} = Category.create(%{
      slug: "technology",
      name_translations: %{
        en: "Technology",
        es: "Tecnología",
        fr: "Technologie",
        de: "Technologie",
        ja: "テクノロジー"
      },
      description_translations: %{
        en: "Articles about software development, programming, and tech trends.",
        es: "Artículos sobre desarrollo de software, programación y tendencias tecnológicas.",
        fr: "Articles sur le développement logiciel, la programmation et les tendances technologiques."
      },
      color: "#10B981",
      icon: "💻"
    })
    
    {:ok, elixir_category} = Category.create(%{
      slug: "elixir",
      name_translations: %{
        en: "Elixir",
        es: "Elixir",
        fr: "Elixir",
        de: "Elixir",
        ja: "Elixir"
      },
      description_translations: %{
        en: "Everything about Elixir, Phoenix, and the BEAM ecosystem.",
        es: "Todo sobre Elixir, Phoenix y el ecosistema BEAM.",
        fr: "Tout sur Elixir, Phoenix et l'écosystème BEAM."
      },
      color: "#8B5CF6",
      icon: "⚗️"
    })
    
    # Create posts
    {:ok, post1} = Post.create(%{
      slug: "getting-started-with-ash",
      author_id: author1.id,
      category_id: elixir_category.id,
      published_at: DateTime.utc_now() |> DateTime.add(-7, :day),
      featured: true,
      title_translations: %{
        en: "Getting Started with Ash Framework",
        es: "Comenzando con Ash Framework",
        fr: "Débuter avec Ash Framework",
        de: "Erste Schritte mit Ash Framework",
        ja: "Ash Frameworkを始める"
      },
      excerpt_translations: %{
        en: "Learn how to build powerful applications with Ash Framework, the declarative resource framework for Elixir.",
        es: "Aprende a construir aplicaciones poderosas con Ash Framework, el framework de recursos declarativo para Elixir.",
        fr: "Apprenez à créer des applications puissantes avec Ash Framework, le framework de ressources déclaratif pour Elixir."
      },
      content_translations: %{
        en: """
        # Getting Started with Ash Framework
        
        Ash Framework is a declarative, resource-oriented framework for building Elixir applications.
        It provides a powerful DSL for defining your domain model, business logic, and authorization rules.
        
        ## Why Ash?
        
        - **Declarative**: Define what your application does, not how
        - **Extensible**: Add custom functionality through extensions
        - **Powerful**: Built-in support for authorization, filtering, sorting, and more
        
        ## Installation
        
        Add Ash to your dependencies:
        
        ```elixir
        def deps do
          [{:ash, "~> 3.0"}]
        end
        ```
        
        ## Your First Resource
        
        Let's create a simple blog post resource...
        """,
        es: """
        # Comenzando con Ash Framework
        
        Ash Framework es un framework declarativo y orientado a recursos para construir aplicaciones Elixir.
        Proporciona un DSL poderoso para definir tu modelo de dominio, lógica de negocio y reglas de autorización.
        
        ## ¿Por qué Ash?
        
        - **Declarativo**: Define qué hace tu aplicación, no cómo
        - **Extensible**: Añade funcionalidad personalizada a través de extensiones
        - **Poderoso**: Soporte integrado para autorización, filtrado, ordenación y más
        
        ## Instalación
        
        Añade Ash a tus dependencias:
        
        ```elixir
        def deps do
          [{:ash, "~> 3.0"}]
        end
        ```
        
        ## Tu Primer Recurso
        
        Vamos a crear un recurso simple de publicación de blog...
        """,
        fr: """
        # Débuter avec Ash Framework
        
        Ash Framework est un framework déclaratif orienté ressources pour créer des applications Elixir.
        Il fournit un DSL puissant pour définir votre modèle de domaine, votre logique métier et vos règles d'autorisation.
        
        ## Pourquoi Ash?
        
        - **Déclaratif**: Définissez ce que fait votre application, pas comment
        - **Extensible**: Ajoutez des fonctionnalités personnalisées via des extensions
        - **Puissant**: Support intégré pour l'autorisation, le filtrage, le tri et plus
        
        ## Installation
        
        Ajoutez Ash à vos dépendances:
        
        ```elixir
        def deps do
          [{:ash, "~> 3.0"}]
        end
        ```
        
        ## Votre Première Ressource
        
        Créons une ressource simple d'article de blog...
        """
      },
      views: 342
    })
    
    {:ok, post2} = Post.create(%{
      slug: "phoenix-liveview-tips",
      author_id: author2.id,
      category_id: tech_category.id,
      published_at: DateTime.utc_now() |> DateTime.add(-3, :day),
      featured: false,
      title_translations: %{
        en: "10 Phoenix LiveView Tips You Should Know",
        es: "10 Consejos de Phoenix LiveView que Deberías Conocer",
        fr: "10 Astuces Phoenix LiveView à Connaître"
      },
      excerpt_translations: %{
        en: "Improve your Phoenix LiveView applications with these essential tips and best practices.",
        es: "Mejora tus aplicaciones Phoenix LiveView con estos consejos esenciales y mejores prácticas.",
        fr: "Améliorez vos applications Phoenix LiveView avec ces conseils essentiels et bonnes pratiques."
      },
      content_translations: %{
        en: """
        Phoenix LiveView has revolutionized how we build interactive web applications...
        
        ## Tip 1: Use Streams for Large Lists
        
        When dealing with large lists, streams are your best friend...
        """,
        es: """
        Phoenix LiveView ha revolucionado cómo construimos aplicaciones web interactivas...
        
        ## Consejo 1: Usa Streams para Listas Grandes
        
        Cuando trabajas con listas grandes, los streams son tu mejor amigo...
        """,
        fr: """
        Phoenix LiveView a révolutionné la façon dont nous construisons des applications web interactives...
        
        ## Astuce 1: Utilisez les Streams pour les Grandes Listes
        
        Lorsque vous travaillez avec de grandes listes, les streams sont votre meilleur ami...
        """
      },
      views: 567
    })
    
    {:ok, post3} = Post.create(%{
      slug: "elixir-pattern-matching",
      author_id: author1.id,
      category_id: elixir_category.id,
      published_at: DateTime.utc_now() |> DateTime.add(-1, :day),
      featured: true,
      title_translations: %{
        en: "Mastering Pattern Matching in Elixir",
        es: "Dominando el Pattern Matching en Elixir",
        fr: "Maîtriser le Pattern Matching en Elixir",
        de: "Pattern Matching in Elixir meistern",
        ja: "Elixirのパターンマッチングをマスターする"
      },
      excerpt_translations: %{
        en: "Deep dive into one of Elixir's most powerful features: pattern matching.",
        es: "Inmersión profunda en una de las características más poderosas de Elixir: pattern matching.",
        fr: "Plongée en profondeur dans l'une des fonctionnalités les plus puissantes d'Elixir: le pattern matching.",
        de: "Tiefer Einblick in eines der mächtigsten Features von Elixir: Pattern Matching.",
        ja: "Elixirの最も強力な機能の1つであるパターンマッチングの詳細。"
      },
      content_translations: %{
        en: "Pattern matching is at the heart of Elixir programming...",
        es: "El pattern matching está en el corazón de la programación en Elixir...",
        fr: "Le pattern matching est au cœur de la programmation Elixir...",
        de: "Pattern Matching ist das Herzstück der Elixir-Programmierung...",
        ja: "パターンマッチングはElixirプログラミングの中心です..."
      },
      views: 892
    })
    
    # Create draft post (unpublished)
    {:ok, draft_post} = Post.create(%{
      slug: "upcoming-features",
      author_id: author2.id,
      category_id: tech_category.id,
      published_at: nil,  # Not published yet
      featured: false,
      title_translations: %{
        en: "Upcoming Features in Elixir 2.0",
        es: "Próximas Características en Elixir 2.0"
      },
      excerpt_translations: %{
        en: "A sneak peek at what's coming in the next major release.",
        es: "Un vistazo a lo que viene en la próxima versión mayor."
      },
      content_translations: %{
        en: "This is still a work in progress...",
        es: "Esto todavía es un trabajo en progreso..."
      }
    })
    
    IO.puts("✅ Seeded example blog data successfully!")
    IO.puts("   - #{2} authors created")
    IO.puts("   - #{2} categories created")
    IO.puts("   - #{3} published posts created")
    IO.puts("   - #{1} draft post created")
    
    {:ok, %{
      authors: [author1, author2],
      categories: [tech_category, elixir_category],
      posts: [post1, post2, post3, draft_post]
    }}
  end
  
  @doc """
  Example queries demonstrating translation features.
  """
  def example_queries do
    IO.puts("\n📚 Example Queries:\n")
    
    # List all published posts
    posts = Post.list_published!()
    IO.puts("Published posts: #{length(posts)}")
    
    # Get posts translated to Spanish
    spanish_posts = Enum.map(posts, &AshPhoenixTranslations.translate(&1, :es))
    
    IO.puts("\nSpanish translations:")
    Enum.each(spanish_posts, fn post ->
      IO.puts("  - #{post.title}: #{post.excerpt}")
    end)
    
    # Get featured posts
    featured = Post.list_featured!()
    IO.puts("\nFeatured posts: #{length(featured)}")
    
    # Check translation completeness
    Enum.each(posts, fn post ->
      completeness = AshPhoenixTranslations.translation_completeness(post)
      IO.puts("#{post.slug}: #{completeness}% complete")
    end)
    
    # Get available locales for a post
    post = List.first(posts)
    if post do
      locales = AshPhoenixTranslations.available_locales(post, :title)
      IO.puts("\nAvailable locales for '#{post.slug}': #{inspect(locales)}")
    end
  end
end

# Example usage:
# Example.Blog.seed_data()
# Example.Blog.example_queries()