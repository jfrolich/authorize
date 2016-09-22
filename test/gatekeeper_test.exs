defmodule AuthorizeTest do
  use ExUnit.Case
  doctest Authorize


  defmodule Item do
    defstruct title: "an item", readonly?: false, invisible?: false
  end

  defmodule SubItem do
    defstruct title: "subitem", item: nil
  end

  defmodule User do
    defstruct admin?: false, name: "John"
  end

  defmodule SubItem.Authorization do
    use Authorize

    # if the actor is able to update the parent item, they are able to create /
    # update / delete a subitem
    rule [:create, :update, :delete], "delegate to item", struct_or_changeset, actor do
      Item.Authorization.authorize(get_struct(struct_or_changeset).item, actor, :update)
    end

    # if the actor is able to read the parent item, it can also read the subitem
    rule [:read], "deletegate to item", struct_or_changeset, actor do
      Item.Authorization.authorize(get_struct(struct_or_changeset).item, actor, :read)
    end
  end

  defmodule Item.Authorization do
    use Authorize

    rule [:read], "only admins can read invisible items", struct_or_changeset, actor do
      if !actor.admin? and get_struct(struct_or_changeset).invisible?, do: :unauthorized, else: :ok
    end

    rule [:create, :update], "users with name john cannot create or update items", struct_or_changeset, actor do
      if actor.name == "John", do: :unauthorized, else: :undecided
    end

    rule [:create], "admins can create items", struct_or_changeset, actor do
      if actor.admin?, do: :ok, else: :undecided
    end

    rule [:update], "normal users can update non read-only items", struct_or_changeset, actor do
      if !get_struct(struct_or_changeset).readonly?, do: :ok, else: :undecided
    end

    rule [:update, :delete], "admins can update and delete any item", struct_or_changeset, actor do
      if actor.admin?, do: :ok, else: :undecided
    end
  end

  test "verify authorization module" do
    normal_user = %User{name: "Ed", admin?: false}
    john = %User{name: "John", admin?: true}
    admin = %User{name: "Admin", admin?: true}

    normal_item = %Item{readonly?: false, invisible?: false}
    readonly_item = %Item{readonly?: true, invisible?: false}
    invisible_item = %Item{readonly?: false, invisible?: true}

    assert {:ok, _} = Item.Authorization.authorize(normal_item, normal_user, :update)
    assert {:unauthorized, _, "users with name john cannot create or update items"} = Item.Authorization.authorize(normal_item, john, :update)

    assert {:ok, _} = Item.Authorization.authorize(readonly_item, admin, :update)
    assert {:unauthorized, _, _} = Item.Authorization.authorize(readonly_item, normal_user, :update)

    assert {:ok, _} = Item.Authorization.authorize(normal_item, admin, :read)
    assert {:ok, _} = Item.Authorization.authorize(normal_item, normal_user, :read)
    assert {:ok, _} = Item.Authorization.authorize(normal_item, john, :read)

    assert {:unauthorized, _, _} = Item.Authorization.authorize(invisible_item, normal_user, :read)
    assert {:ok, _} = Item.Authorization.authorize(invisible_item, admin, :read)
  end
end
