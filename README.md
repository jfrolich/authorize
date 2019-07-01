![authorize-logo](https://user-images.githubusercontent.com/579279/39227502-8e7fbf56-488b-11e8-9711-5973fe1ba3aa.png)
# Authorize

Authorize is a rule based authorization module for your elixir app.

Authorize walks through rules in your resource to determine if it grants authorization, or not. These rules are easily created using a DSL.

Any rule can return three states:

- `:ok`: grand access (return `:ok`)
- `:next`: got to next rule
- `:error`: return `{:error, description}` 

How this translates to code is as follows:

```elixir
defmodule Item do
  use Authorize

  defstruct user_id: nil, private?: false, invisible?: false

  authorize do
    # signature of rule:
    # rule(
    #  actions: one or a list of actions [optional], if not included this rule
    #           applies to all actions
    #  description: a description of the the rule, this will be returned as the
    #               'reason'.
    #  struct_or_changeset: the struct or changeset that you wish to apply the
    #                       rule to.
    #  actor: a data structure that describes the actor of the action. This will
    #         be the user in most cases.
    # )

    rule "authorize super admins for everything", _, actor do
      if actor.super_admin?, do: :ok, else: :next
    end

    # An :error response will stop the chain, as will an :ok response.
    # When returning :next it will evaluate the next rule.
    rule [:read], "only admins can read invisible items", struct_or_changeset, actor do
      item = get_struct(struct_or_changeset)
      cond do
        item.invisible? and actor.admin? -> :ok
        item.invisible? -> :error
        :else -> :next
      end
    end

    # Action can be a list of actions, a single action such as ':read',
    # or be completely omitted (equivalent to :all)
    rule :read, "actors can read their own private items", struct_or_changeset, actor do
      item = get_struct(struct_or_changeset)
      if item.private? and item.user_id == actor.id do
        :ok
      else
        :next
      end
    end

    rule [:read], "admins can read private items", struct_or_changeset, actor do
      if actor.admin? and get_struct(struct_or_changeset).private?, do: :ok, else: :next
    end

    rule [:read], "all actors can read public items", struct_or_changeset, actor do
      if get_struct(struct_or_changeset).public?, do: :ok
    end
  end
end

defmodule User do
  defstruct id: nil, name: nil, admin?: false, super_admin?: false
end
```

We can now use this authorization module in the following way, with ordered rules (executed from top to bottom):
```elixir
iex> normal_user = %User{id: 1, name: "Ed", admin?: false}
...> admin = %User{id: 2, name: "Admin", admin?: true}
...> invisible_item = %Item{private?: true, invisible?: true, user_id: 2}
...> private_item = %Item{private?: true, user_id: 2}

iex> Item.authorize(invisible_item, normal_user, :read)
{:error, "only admins can read invisible items"}

iex> Item.authorize(invisible_item, admin, :read)
:ok

iex> Item.authorize(private_item, normal_user, :read)
{:error, "no authorization rule found"}

iex> Item.authorize(private_item, admin, :read, include_reason: true)
{:ok, "members can read their own private items"}
```

You can define a rule with `rule [action], description, struct_or_changeset, actor`

With `rule` you are defining a rule.

The first argument is the action this rule applies to. I would recommend to use the well known CRUD (`create`, `read`, `update`, and `delete`) actions, but you can also use something else (Authorize does not care). If you leave the first argument out and start with the description, the rule will apply to all actions.

The second argument is a description, when this rule returns :error this will be passed as the reason.

`struct_or_changeset` and `actor` are the variables that you can use in the rule's body. The `struct_or_changeset` is the resource, and `actor` is the actor that tries to perform the action. This can be anything you like. To make it work well with ecto we provide two helper methods `is_changeset?/1` and `get_struct/1`. `is_changeset/1` will return true if `struct_or_changeset` is a changeset. `get_struct/1` returns the struct. If the item is a changeset, it will return `changeset.data`.

If there is no rule found that returns `:error` or `:ok`, the `authorize/3` function will return `{:error, "no authorization rule found"}`

More examples in `test/authorize_test`.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `authorize` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:authorize, "~> 1.0.0"}]
end
```

  2. Ensure `authorize` is started before your application:

```elixir
def application do
  [applications: [:authorize]]
end
```

