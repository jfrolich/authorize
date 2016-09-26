# Authorize

Authorize is a rule based authorization module for your elixir app.

Authorize walks through rules your resource to determine if it grands authorization, or not. These rules are easily created using a DSL.

Any rule can return three states:

- `:ok`: means that this rule grands authorization
- `:undecided`: it will continue with the following rules to see if it will grand authorization
- `:unauthorized`: it will not grand authorization and will not look at the following rules

How this translate to code is as follows:

```elixir
defmodule Item do
  defstruct user_id: nil, private?: false, invisible?: false
end

defmodule User do
  defstruct id: nil, name: nil, admin?: false
end

defmodule Item.Authorization do
  use Authorize

  rule [:read], "only admins can read invisible items", struct_or_changeset, actor do
    if !actor.admin? and get_struct(struct_or_changeset).invisible?, do: :unauthorized, else: :ok
  end

  rule [:read], "members can only read their own private items", struct_or_changeset, actor do
    item = get_struct(struct_or_changeset)
    if !item.public? and item.user_id == actor.id do
      :ok
    else
      :undecided
    end
  end

  rule [:read], "all members can read public items", struct_or_changeset, actor do
    if get_struct(struct_or_changeset).public?, do: :ok
  end
end
```

We can now use this authorization module in the following way, with ordered rules (executed from top to bottom):
```elixir
iex> normal_user = %User{id: 1, name: "Ed", admin?: false}
...> admin = %User{id: 2, name: "Admin", admin?: true}
...> invisible_item = %Item{private?: true, invisible?: true, user_id: 2}

iex> Item.Authorization.authorize(normal_user, invisible_item, :read)
{:unauthorized, %Item{...}, "only admins can read invisible items"}

iex> Item.Authorization.authorize(admin, invisible_item, :read)
{:ok, %Item{...}}

iex> private_item = %{invisible_item | invisible?: false}
...> Item.Authorization.authorize(normal_user, private_item, :read)
{:unauthorized, %Item{...}, "members can only read their own private items"}

iex> Item.Authorization.authorize(admin, private_item, :read)
{:ok, %Item{...}}
```

You can define a rule with `rule [action], description, struct_or_changeset, actor`

With `rule` you are defining a rule.

The first argument is the action this rule applies to. I would recommend to use the well known CRUD (`create`, `read`, `update`, and `delete`) actions, but you can also use something else (Authorize does not care). If you leave the first argument out and start with the description, the rule will apply to all actions.

The second argument is a description, when this rule returns :unauthorized this will be passed as the reason.

`struct_or_changeset` and `actor` are the variables that you can use in the rule's body. The `struct_or_changeset` is the resource, and `actor` is the actor that tries to perform the action. This can be anything you like. To make it work well with ecto we provide two helper methods `is_changeset?/1` and `get_struct/1`. `is_changeset/1` will return true if `struct_or_changeset` is a changeset. `get_struct/1` returns the struct. If the item is a changeset, it will return `changeset.data`.

If there is no rule found that returns `:unauthorized` or `:ok`, the `authorize/3` function will return `{:unauthorized, _, "no authorization rule found"}`

More examples in `test/authorize_test`.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `authorize` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:authorize, "~> 0.1.0"}]
    end
    ```

  2. Ensure `authorize` is started before your application:

    ```elixir
    def application do
      [applications: [:authorize]]
    end
    ```
