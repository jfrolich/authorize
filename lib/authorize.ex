defmodule Authorize.Inline do
  defmacro __using__(_options) do
    quote do
      use Authorize
      import unquote(__MODULE__)

    end
  end
  defmacro authorize(do: block) do
    quote do
      unquote(block)
    end
  end
end

defmodule Authorize do
  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :rules, accumulate: true)
      @before_compile unquote(__MODULE__)
    end
  end

  def create_authorize() do
    quote do
      def is_changeset?(%{__struct__: :"Elixir.Ecto.Changeset"}), do: true
      def is_changeset?(_), do: false

      def get_struct(%{__struct__: :"Elixir.Ecto.Changeset"} = changeset), do: changeset.data
      def get_struct(struct), do: struct

      def authorize(struct_or_changeset, actor, actions, options \\ [include_reason: false]) do
        @rules
        |> Enum.reverse
        |> Enum.filter(fn
          {acts, _, _} when is_atom(acts) -> acts == :all || acts == actions
          {acts, _, _} -> acts == :all || Enum.member?(acts, actions)
        end)
        |> Enum.reduce(:undecided, fn
          ({_actions, description, rule_func}, :undecided) ->
            apply(__MODULE__, rule_func, [struct_or_changeset, actor])
          (_fun, other) -> other
        end)
        |> case do
          :undecided ->
            {:unauthorized, struct_or_changeset, "no authorization rule found"}
          {:ok, struct_or_changeset, reason} ->
            if Keyword.get(options, :include_reason) do
              {:ok, struct_or_changeset, reason}
            else
              {:ok, struct_or_changeset}
            end
          other -> other
        end
      end
      def authorize(struct_or_changeset, actor), do: authorize(struct_or_changeset, actor, :all)
    end
  end

  defmacro __before_compile__(_env) do
    create_authorize
  end

  def apply_rule(description, struct_or_changeset, actor) do
    apply(__MODULE__, String.to_atom(description), [struct_or_changeset, actor])
  end

  def create_rule(actions, description, struct_or_changeset, actor, do: rule_block) do
    rule_func = String.to_atom(description)
    quote do
      @rules {unquote(actions), unquote(description), unquote(rule_func)}
      def unquote(rule_func)(unquote(struct_or_changeset), unquote(actor)) do
        case unquote(rule_block) do
          :undecided -> :undecided
          :ok -> {:ok, unquote(struct_or_changeset), unquote(description)}
          :unauthorized -> {:unauthorized, unquote(struct_or_changeset), unquote(description)}

          # make composition of authorization functions possible
          {:ok, _struct_or_changeset} -> {:ok, unquote(struct_or_changeset)}
          {:ok, _struct_or_changeset, description} -> {:ok, unquote(struct_or_changeset), description}
          {:unauthorized, _struct_or_changeset, "no authorization rule found"} -> :undecided
          {:unauthorized, _struct_or_changeset, description} -> {:unauthorized, unquote(struct_or_changeset), description}
        end
      end
    end
  end

  defmacro rule(description, changeset, actor, do: rule_block), do:
    create_rule(:all, description, changeset, actor, do: rule_block)


  defmacro rule(actions, description, changeset, actor, do: rule_block), do:
    create_rule(actions, description, changeset, actor, do: rule_block)
end
