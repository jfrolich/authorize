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

      def authorize(struct_or_changeset, actor, context) do
        @rules
        |> Enum.reverse
        |> Enum.filter(fn
          {ctx, _, _} when is_atom(ctx) -> ctx == :global || ctx == context
          {ctx, _, _} -> ctx == :global || Enum.member?(ctx, context)
        end)
        |> Enum.reduce(:undecided, fn
          ({_context, description, rule_func}, :undecided) ->
            apply(__MODULE__, rule_func, [struct_or_changeset, actor])
          (_fun, other) -> other
        end)
        |> case do
          :undecided ->
            {:unauthorized, struct_or_changeset, "no authorization rule found"}
          other ->
            other
        end
      end
      def authorize(struct_or_changeset, actor), do: authorize(struct_or_changeset, actor, :global)
    end
  end

  defmacro __before_compile__(_env) do
    create_authorize
  end

  def apply_rule(description, struct_or_changeset, actor) do
    apply(__MODULE__, String.to_atom(description), [struct_or_changeset, actor])
  end

  def create_rule(context, description, struct_or_changeset, actor, do: rule_block) do
    rule_func = String.to_atom(description)
    quote do
      @rules {unquote(context), unquote(description), unquote(rule_func)}
      def unquote(rule_func)(unquote(struct_or_changeset), unquote(actor)) do
        case unquote(rule_block) do
          :undecided -> :undecided
          :ok -> {:ok, unquote(struct_or_changeset)}
          :unauthorized -> {:unauthorized, unquote(struct_or_changeset), unquote(description)}

          # make composition of authorization functions possible
          {:ok, _struct_or_changeset} -> {:ok, unquote(struct_or_changeset)}
          {:unauthorized, _struct_or_changeset, "no authorization rule found"} -> :undecided
          {:unauthorized, _struct_or_changeset, description} -> {:unauthorized, unquote(struct_or_changeset), description}
        end
      end
    end
  end

  defmacro rule(description, changeset, actor, do: rule_block), do:
    create_rule(:global, description, changeset, actor, do: rule_block)


  defmacro rule(context, description, changeset, actor, do: rule_block), do:
    create_rule(context, description, changeset, actor, do: rule_block)
end
