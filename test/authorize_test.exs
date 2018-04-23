defmodule SubItem do
  use Authorize

  defstruct title: "subitem", item: nil

  # if the actor is able to update the parent item, they are able to create /
  # update / delete a subitem
  authorize do
    rule [:create, :update, :delete], "delegate to item", struct_or_changeset, actor do
      Item.authorize(get_struct(struct_or_changeset).item, actor, :update)
    end

    # if the actor is able to read the parent item, it can also read the subitem
    rule [:read], "deletegate to item", struct_or_changeset, actor do
      Item.authorize(get_struct(struct_or_changeset).item, actor, :read)
    end
  end
end

defmodule Item do
  use Authorize

  defstruct title: "an item", readonly?: false, invisible?: false, secret_field: "secret"

  authorize do
    rule :read, "only admins can read invisible items", struct_or_changeset, actor do
      if !actor.admin? and get_struct(struct_or_changeset).invisible?,
        do: :error,
        else: :next
    end

    rule :read, "only admins can read secret_field", _struct_or_changeset, fields, actor do
      if Enum.member?(fields, :secret_field) && !actor.admin?, do: :error, else: :ok
    end

    rule [:create, :update],
         "users with name john cannot create or update items",
         _struct_or_changeset,
         actor do
      if actor.name == "John", do: :error, else: :next
    end

    rule [:create], "admins can create items", _struct_or_changeset, actor do
      if actor.admin?, do: :ok, else: :next
    end

    rule [:update], "normal users can update non read-only items", struct_or_changeset, _actor do
      if !get_struct(struct_or_changeset).readonly?, do: :ok, else: :next
    end

    rule [:update, :delete],
         "admins can update and delete any item",
         _struct_or_changeset,
         actor do
      if actor.admin?, do: :ok, else: :next
    end
  end
end

defmodule User do
  defstruct admin?: false, name: "John"
end

defmodule AuthorizeTest do
  use ExUnit.Case
  doctest Authorize

  @normal_user %User{name: "Ed", admin?: false}
  @john %User{name: "John", admin?: true}
  @admin %User{name: "Admin", admin?: true}

  @normal_item %Item{readonly?: false, invisible?: false}
  @readonly_item %Item{readonly?: true, invisible?: false}
  @invisible_item %Item{readonly?: false, invisible?: true}

  test "authorization as seperate module api surface" do
    assert :ok = Item.authorize(@normal_item, @normal_user, :update)

    assert {:error, "users with name john cannot create or update items"} =
             Item.authorize(@normal_item, @john, :update)

    assert :ok = Item.authorize(@readonly_item, @admin, :update)

    assert {:error, _} = Item.authorize(@readonly_item, @normal_user, :update)

    assert :ok = Item.authorize(@normal_item, @admin, :read)
    assert :ok = Item.authorize(@normal_item, @normal_user, :read)
    assert :ok = Item.authorize(@normal_item, @john, :read)

    assert {:error, _} = Item.authorize(@invisible_item, @normal_user, :read)

    assert :ok = Item.authorize(@invisible_item, @admin, :read)
  end

  test "secret field" do
    assert {:ok, "only admins can read secret_field"} =
             Item.authorize_fields(
               @normal_item,
               @admin,
               :read,
               :secret_field,
               include_reason: true
             )

    assert {:error, "only admins can read secret_field"} =
             Item.authorize_fields(@normal_item, @normal_user, :read, :secret_field)
  end
end
