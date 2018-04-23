defmodule Authorize do
  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :rules, accumulate: true)
      @before_compile unquote(__MODULE__)
    end
  end

  def authorize(do: block) do
    block
  end

  def create_authorize() do
    quote do
      def is_changeset?(%{__struct__: :"Elixir.Ecto.Changeset"}), do: true
      def is_changeset?(_), do: false

      def get_struct(%{__struct__: :"Elixir.Ecto.Changeset"} = changeset), do: changeset.data
      def get_struct(struct), do: struct

      def authorize_fields(struct_or_changeset, actor, actions, field, options \\ [])

      def authorize_fields(struct_or_changeset, actor, actions, field, options)
          when is_atom(field) do
        authorize(struct_or_changeset, actor, actions, Keyword.put(options, :fields, [field]))
      end

      def authorize_fields(struct_or_changeset, actor, actions, fields, options) do
        authorize(struct_or_changeset, actor, actions, Keyword.put(options, :fields, fields))
      end

      def authorize(struct_or_changeset, actor, action, options \\ []) do
        @rules
        |> Enum.reverse()
        # filter based on actions
        |> Enum.filter(fn
          {acts, _, _} when is_atom(acts) -> acts == :all || acts == action
          {acts, _, _} -> Enum.member?(acts, :all) || Enum.member?(acts, action)
        end)
        |> Enum.reduce(:next, fn
          {_actions, description, rule_func}, :next ->
            apply(__MODULE__, rule_func, [
              struct_or_changeset,
              Keyword.get(options, :fields, []),
              actor
            ])

          _fun, other ->
            other
        end)
        |> case do
          :next ->
            {:error, "no authorization rule found"}

          :ok ->
            :ok

          {:ok, reason} ->
            if Keyword.get(options, :include_reason, false) do
              {:ok, reason}
            else
              :ok
            end

          {:error, reason} ->
            {:error, reason}

          other ->
            other
        end
      end

      def authorize(struct_or_changeset, actor), do: authorize(struct_or_changeset, actor, :all)
    end
  end

  defmacro __before_compile__(_env) do
    create_authorize()
  end

  def create_rule(actions, description, struct_or_changeset, fields, actor, do: rule_block) do
    rule_func = String.to_atom(description)

    quote do
      @rules {unquote(actions), unquote(description), unquote(rule_func)}
      def unquote(rule_func)(unquote(struct_or_changeset), unquote(fields), unquote(actor)) do
        case unquote(rule_block) do
          :next ->
            :next

          :ok ->
            {:ok, unquote(description)}

          :error ->
            {:error, unquote(description)}

          # make composition of authorization functions possible
          {:ok, description} ->
            {:ok, description}

          {:error, "no authorization rule found"} ->
            :next

          {:error, description} ->
            {:error, description}
        end
      end
    end
  end

  defmacro rule(description, struct_or_changeset, actor, do: rule_block)
           when is_binary(description) do
    create_rule(:all, description, struct_or_changeset, quote(do: field), actor, do: rule_block)
  end

  defmacro rule(description, changeset, fields, actor, do: rule_block)
           when is_binary(description) do
    create_rule(:all, description, changeset, fields, actor, do: rule_block)
  end

  defmacro rule(actions, description, struct_or_changeset, actor, do: rule_block)
           when is_binary(description) do
    create_rule(
      actions,
      description,
      struct_or_changeset,
      quote(do: field),
      actor,
      do: rule_block
    )
  end

  defmacro rule(actions, description, struct_or_changeset, fields, actor, do: rule_block)
           when is_binary(description) do
    create_rule(actions, description, struct_or_changeset, fields, actor, do: rule_block)
  end
end
