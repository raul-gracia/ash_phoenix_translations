What is an Ash Extensions?
Extensions in Ash are modules capable of changing the structure and functionality of a resource or domain programmatically or if you like during runtime or compilation time. They are portable, reusable and can be extracted into a package.
An extension extends a resource to add business rules by adding attributes, actions, aggregates, calculations, changes, preparations, relationships and more to the resource programmatically. Extensions allow you to write features once and share it in multiple resources, domains and in different separated applications. They make your feature repeatable and portable across different Ash framework applications. You write a feature once and deploy it to multiple applications. If you have been using Ash you might have come across packages such as ash_authentication, ash_paper_trail, ash_archival. These packages add extensions to your Ash resources, so you have already used an ash extension.
Ash extensions makes it possible to extract sharable business rules into a package and reuse them in other ash framework applications without repeating your codes. They allows you to extend functionalities of your resource and domain.
Ash resources are maps of data structs that can be extended by adding more data. That’s what Ash extensions do. Extensions are modules that can tap into the resource data structure and modify them to add attributes, actions, relationships and even more to the resource domain specific languages(DSLs) blocks. Extensions can be installed as hex packages or as a group of module to add to your domain and resource.
To understand what Ash extension is, let’s buld one.
We’ll start with the basic extension in part 1 then in in part-3 we’ll end up having an extension published on hex.pm that can be installed by other developers in the Ash community.
Building Your First Extension — AshParental
We want to build an extension that adds STI(Single Table Interface) capability to a resource. It will modify the resource it is applied to, to add parent-child behaviour.
To achieve the parent-child behaviour, this extensions will:
Add a parent_id attribute to the resource
Add a belongs_to parent relationship to the resource
Add a has_many children relationship to the resource
Add a count_of_children aggregates to the resource
It transforms a basic resource like Comment into a parent-child like resource that has comments and comments reply.
Here is an illustration of before and after the extension has been applied.

We now understand what we want to do, let’s start building our extension.
Basic Composition of Ash Extension
Extensions implement of Spark DSL behavious(interface or contract in other languages). They transform Ash resources and domains to add new capabilities.
The basic components of extensions are:
Extension Entry module: A module that adds 1 or more transformers to an extension.
Transformer: A module that implements transform/1 to make changes to resources or a domain.
When an extension is loaded, Ash framework looks for its entry point module, then loads all the transformers listed in the entry module and apply one by one to the resource in the specified order to extend the resource functionalities, apply changes or perform other related business rules.
The journey start with the entry module of the extension, next, it applies each defined transformer to extend a resource with business rules in predefined order until the last transformer is defined and continues to building the resource.
Press enter or click to view image in full size

To build the AshParental extension, we need at least 2 modules.
The entry module AshParental and AddParentIdField transformer to add parent_id attribute to the resource.
Create lib/helpcenter/extensions/ash_parental/ash_parental.ex and add below content.

# lib/helpcenter/extensions/ash_parental/ash_parental.ex

defmodule Helpcenter.Extensions.AshParental do

# The list of transformers to be applied when this extension is used.

@transformers [
Helpcenter.Extensions.AshParental.Transformers.AddParentIdAttribute
]

use Spark.Dsl.Extension, transformers: @transformers
end
In the above code, we are telling the Ash that when the AshParental extension is loaded, it should locate the AddParentIdAttribute transformer and apply it to the resource.
Let’s define this transformer.

# lib/helpcenter/extensions/ash_parental/transformers/add_parent_id_attribute.ex

defmodule Helpcenter.Extensions.AshParental.Transformers.AddParentIdAttribute do
use Spark.Dsl.Transformer

def transform(dsl_state) do
Ash.Resource.Builder.add_new_attribute(dsl_state, :parent_id, :uuid, allow_nil?: true)
end
end
The dsl_state is the map containing the structure of the current resource this transformer is applied to. Transformers must define transform/1 callback. Ash calls transform/1 to apply a transformer. This is a must be defined function.
We used Ash.Resource.Builder.add_new_attribute/4 to add a new attribute called :parent_id of type :uuid that is nullable.
The Ash.Resource.Build contains functions to transform resources by adding attributes, actions, relationships and more. I encourage you to read it and see what’s possible when it comes to resource transformation.
The above code is equivalent to manually adding the parent_id attribute to a resource like below:

# lib/helpcenter/knowledge_base/comment.ex

defmodule Helpcenter.KnowledgeBase.Comment do
use Ash.Resource

# ...

attributes do

# Manually define parent_id which the extension will do automatically for us.

attribute :parent_id, :uuid, allow_nil?: true
end

# Other resource definitions....

end
Congratulations! You have built your first Ash extension!
We’ll test it on the Helpcenter.KnowledgeBase.Comment resource to confirm that it adds the parent_id attribute. We’ll first confirm that the parent_id attribute does not exist on the Comment resource, then we’ll add the extension and check if the attribute has been added.
From your CLI run iex -S mix in the root folder of your project
➜ iex -S mix
Erlang/OTP 27 [erts-15.0.1] [source] [64-bit] [smp:12:12] [ds:12:12:10] [async-threads:1] [jit:ns]
Compiling 8 files (.ex)
Generated helpcenter app
Interactive Elixir (1.17.2) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)>
Then run Ash.Resource.Info.attribute_names(Helpcenter.KnowledgeBase.Comment) to list attribute names on the resource.
iex(4)> Ash.Resource.Info.attribute_names(Helpcenter.KnowledgeBase.Comment)
MapSet.new([:id, :content, :article_id, :inserted_at, :updated_at])
We can confirm that there’s no parent_id attribute on the Comment resource.
Let’s apply the extensions and see if it will add the parent_id attribute.
Add the AshParental extension to the Comment resource like below:

# lib/helpcenter/knowledge_base/comment.ex

defmodule Helpcenter.KnowledgeBase.Comment do
use Ash.Resource,
domain: Helpcenter.KnowledgeBase,
data_layer: AshPostgres.DataLayer,

# Add the AshParental extension to this resource

extensions: [Helpcenter.Extensions.AshParental]

# The rest of the resource definitions...

end
Go back to iex, run recompile, then run Ash.Resource.Info.attribute_names(Helpcenter.KnowledgeBase.Comment), you will realise that we now have the parent_id attribute added to the resource.
Press enter or click to view image in full size

We need to automate tests so that in the future, we are able to confidently modify codes without the fear of breaking working codes.
Let’s add unit tests for our extensions.
Unit Testing Extension
Since this extension is applied to a resource, we need a domain and a resource to test it. We don’t need postgresSQL. We’ll use Erlang Term Storage(ETS) as data layer to test it.
Create ash_parent_test.exs next to the entry module and add below codes:

# lib/helpcenter/extensions/ash_parental/ash_parental_test.exs

defmodule Helpcenter.Extensions.AshParentalTest do
use ExUnit.Case

# Define a simple Ash resource for testing purposes

defmodule Comment do
use Ash.Resource,
domain: Helpcenter.Extensions.AshParentalTest.Domain,
data_layer: Ash.DataLayer.Ets, # Add the AshParental extension to test
extensions: [Helpcenter.Extensions.AshParental]

ets do
table :comments
end

actions do
defaults [:create, :read, :update, :destroy]
end

attributes do
uuid_primary_key :id
attribute :content, :string, allow_nil?: false
timestamps()
end
end

# Define a domain to hold the resource for testing

defmodule Domain do
use Ash.Domain

resources do
resource Helpcenter.Extensions.AshParentalTest.Comment
end
end

describe "AshParental" do
test "AshParental adds parent_id to the resource" do # Confirm that the parent_id attribute has been added # to the reource's attributes after applying the extension
assert :parent_id in Ash.Resource.Info.attribute_names(Comment)
end
end
end
Next run:
mix test lib/helpcenter/extensions/ash_parental/ash_parental_test.exs to confirm that all is working as expected.
Since our tests are passing, we can start to add more features to our extension.
Dynamically Detect Primary Key Type
Not all primary keys will have UUID data type, so it is prudent to match primary key data type with the parent_id data type.
Modify add_parent_id_attribute.ex to add the get_primary_key_type/1 private function.

# lib/helpcenter/extensions/ash_parental/transformers/add_parent_id_attribute.ex

defmodule Helpcenter.Extensions.AshParental.Transformers.AddParentIdAttribute do
use Spark.Dsl.Transformer

def transform(dsl_state) do

# Detect the primary key type to use as parent key type

primary_key_type = get_primary_key_type(dsl_state)

Ash.Resource.Builder.add_new_attribute(
dsl_state,
:parent_id,
primary_key_type,
allow_nil?: false
)
End

# Helper function to get the current resource primary key type

defp get_primary_key_type(dsl_state) do
dsl_state
|> Ash.Resource.Info.primary_key()
|> Enum.map(&Ash.Resource.Info.attribute(dsl_state, &1))
|> List.first()
|> Map.get(:type)
end
end
The get_primary_key_type/1 function takes the dsl state and extracts the primary key, then gets primary key attribute information and finally extracts the data type of the primary key and returns it.
Run the tests to confirm that all is well.
At this point nothing much has changed, but now, we have a dynamic data type for the parent_id attribute. If the primary key data type is integer, the parent_id will also be integer. If it is UUID, the parent id will also be UUID.
Next, we’ll add relationship and aggregate to the extension.
Add Relationships and Aggregate
At this point, we want to add parent and children relationships, and count_of_children aggregate.
We need a transformer to add a belongs_to parent relationship. You will realise that this transformer has the same structure as the AddParentIdAttribute transformer.
They both use Spark.Dsl.Transformer and implement the transform/1 callback function. We used add_new_relationship function from on Ash.Resource.Builder to add a belongs to parent relationship.
You will also notice that I have added after?/1 callback function to define the order of which this transformer will be applied in. This transformer will be applied only after the AddParentIdAttribute has been applied.
Create the AddBelongsToParentRelationships transformer like below.

# lib/helpcenter/extensions/ash_parental/transformers/add_belongs_to_parent_relationship.ex

defmodule Helpcenter.Extensions.AshParental.Transformers.AddBelongsToParentRelationship do
use Spark.Dsl.Transformer

@doc """
Ensure that this transformer runs after the AddParentIdAttribute transformer.
This transformer will be applied after the parent*id attribute transformer.
"""
def after?(Helpcenter.Extensions.AshParental.Transformers.AddParentIdAttribute), do: true
def after?(*), do: false

def transform(dsl_state) do
Ash.Resource.Builder.add_new_relationship(
dsl_state,
:belongs_to,
:parent,
get_current_resource_name(dsl_state),
source_attribute: :parent_id,
destination_attribute: get_primary_key_name(dsl_state)
)
end

# Get the current resource name

defp get_current_resource_name(dsl_state) do
Spark.Dsl.Transformer.get_persisted(dsl_state, :module)
end

# Get the current primary key name

defp get_primary_key_name(dsl_state) do
dsl_state
|> Ash.Resource.Info.primary_key()
|> Enum.map(&Ash.Resource.Info.attribute(dsl_state, &1))
|> List.first()
|> Map.get(:name)
end
end
The above is equivalent to adding relationship manually to a resource like below:
belongs_to :parent, Helpcenter.KnowledgeBase.Comment do
source_attribute :parent_id
destination_attribute :id
end
Next, let’s add a has_many chidlren relationship.
It is the same as the previous relationship except that this relationship is of the type has_may.

# lib/helpcenter/extensions/ash_parental/transformers/add_has_many_children_relationship.ex

defmodule Helpcenter.Extensions.AshParental.Transformers.AddHasManyChildrenRelationship do
use Spark.Dsl.Transformer

def after?(Helpcenter.Extensions.AshParental.Transformers.AddParentIdAttribute), do: true
def after?(\_), do: false

def transform(dsl_state) do
Ash.Resource.Builder.add_new_relationship(
dsl_state,
:has_many,
:children,
get_current_resource_name(dsl_state),
source_attribute: get_primary_key_name(dsl_state),
destination_attribute: :parent_id
)
end

defp get_current_resource_name(dsl_state) do
Spark.Dsl.Transformer.get_persisted(dsl_state, :module)
end

defp get_primary_key_name(dsl_state) do
dsl_state
|> Ash.Resource.Info.primary_key()
|> Enum.map(&Ash.Resource.Info.attribute(dsl_state, &1))
|> List.first()
|> Map.get(:name)
end
end
Finally, let’s add the count_of_children aggregate to count children of a parent.

# lib/helpcenter/extensions/ash_parental/transformers/add_children_count_aggregate.ex

defmodule Helpcenter.Extensions.AshParental.Transformers.AddChildrenCountAggregate do
use Spark.Dsl.Transformer

def after?(Helpcenter.Extensions.AshParental.Transformers.AddHasManyChildrenRelationship) do
true
end

def after?(\_), do: false

def transform(dsl_state) do
Ash.Resource.Builder.add_new_aggregate(
dsl_state,
:count_of_children,
:count,
[:children]
)
end
end
The new transformers are not yet applied to the resource because we haven’t added them to the AshParental module(entry module).
Open it and modify it to add new transformers

# lib/helpcenter/extensions/ash_parental/ash_parental.ex

defmodule Helpcenter.Extensions.AshParental do
@moduledoc """
An Ash extension that adds parental relationships to a resource.
When added to a resource, it will automatically add: - A `parent_id` attribute (of the same type as the resource's primary key) - A `belongs_to :parent` relationship to the same resource - A `has_many :children` relationship to the same resource - A `count_of_children` aggregate to count the number of children
"""

@transformers [
Helpcenter.Extensions.AshParental.Transformers.AddParentIdAttribute,
Helpcenter.Extensions.AshParental.Transformers.AddChildrenCountAggregate,
Helpcenter.Extensions.AshParental.Transformers.AddBelongsToParentRelationship,
Helpcenter.Extensions.AshParental.Transformers.AddHasManyChildrenRelationship
]

use Spark.Dsl.Extension, transformers: @transformers
end
Go to iex and run recompile then manually test if the new relationships are added by running below codes.
Helpcenter.KnowledgeBase.Comment
|> Ash.Resource.Info.relationships()
|> Enum.map(& &1.name)

# Should return

# [:article, :parent, :children]

Confirm that the count_of_children aggreate has been added.
Helpcenter.KnowledgeBase.Comment
|> Ash.Resource.Info.aggregates()
|> Enum.map(& &1.name)

# Should return

# [:count_of_children]

At last let’s add comprehensive tests to confirm that all works as expected

# lib/helpcenter/extensions/ash_parental/ash_parental_test.exs

defmodule Helpcenter.Extensions.AshParentalTest do
use ExUnit.Case

# Define a simple Ash resource for testing purposes

defmodule Comment do
use Ash.Resource,
domain: Helpcenter.Extensions.AshParentalTest.Domain,
data_layer: Ash.DataLayer.Ets, # Add the AshParental extension to test
extensions: [Helpcenter.Extensions.AshParental]

ets do
table :comments
end

actions do
defaults [:create, :read, :update, :destroy]
end

attributes do
uuid_primary_key :id
attribute :content, :string, allow_nil?: false
timestamps()
end
end

# Define a domain to hold the resource for testing

defmodule Domain do
use Ash.Domain

resources do
resource Helpcenter.Extensions.AshParentalTest.Comment
end
end

defp relationships(resource) do
Ash.Resource.Info.relationships(resource)
|> Enum.map(& &1.name)
end

alias Helpcenter.Extensions.AshParentalTest.Comment

describe "AshParental" do
test "Adds parent_id to the resource" do # Confirm that the parent_id attribute has been added # to the reource's attributes after applying the extension
assert :parent_id in Ash.Resource.Info.attribute_names(Comment)
end

test "Adds a belongs_to relationship to the resource" do
assert :parent in relationships(Comment)
end

test "Adds a children relationships" do
assert :children in relationships(Comment)
end

test "Adds children count aggregate" do
%{name: aggregate_name, kind: kind} =
Ash.Resource.Info.aggregates(Comment)
|> List.first()

     assert :count_of_children == aggregate_name
     assert :count == kind

end

test "Parents - Child and versa relationships records" do
parent = Ash.Seed.seed!(Comment, %{content: "parent"})
child_1 = Ash.Seed.seed!(Comment, %{content: "child 1", parent_id: parent.id})
child_2 = Ash.Seed.seed!(Comment, %{content: "child 2", parent_id: parent.id})

     parent_record = Ash.get!(Comment, parent.id, load: [:children, :count_of_children])


     assert 2 == parent_record.count_of_children
     assert Enum.count(parent_record.children) == parent_record.count_of_children


     child_1_record = Ash.get!(Comment, child_1.id, load: [:parent])


     assert child_1_record.parent_id == parent.id

end
end
end
And run mix test lib/helpcenter/extensions/ash_parental/ash_parental_test.exs
All your tests should be passing now.

Now you can reuse this extension on any Ash resource and it will add parent-child behavious to it.
For example you can add this behaviour to the Category resource like below:

# lib/helpcenter/knowledge_base/category.ex

defmodule Helpcenter.KnowledgeBase.Category do
use Ash.Resource,
domain: Helpcenter.KnowledgeBase,
data_layer: AshPostgres.DataLayer,

# Add the AshParental extension to this resource

extensions: [Helpcenter.Extensions.AshParental]

# The rest of the resource definitions...

end
In summary we’ve covered:
What Ash extensions are
How Ash extensions works
We built AshParent extension that adds parent-child behaviour
How to test Ash Extensions.
In the next article we’ll cover how to make your resource configurable, then we’ll turn it into an installable package other people can install from hex.pm.
