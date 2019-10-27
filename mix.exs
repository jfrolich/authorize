defmodule Authorize.Mixfile do
  use Mix.Project

  def project do
    [
      app: :authorize,
      description: "Rule based authorization for Elixir",
      version: "1.0.0",
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.21.2", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: :authorize,
      maintainers: ["Jaap Frölich"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/jfrolich/authorize"},
      files: ~w(lib mix.exs README.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md"
      ],
      source_url: "https://github.com/jfrolich/authorize",
      groups_for_functions: [
        Rules: & &1[:group] == :rules
      ]
    ]
  end
end
