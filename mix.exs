defmodule Gatekeeper.Mixfile do
  use Mix.Project

  def project do
    [
      app: :gatekeeper,
      description: "Rule based authorization for Elixir",
      version: "0.1.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      package: package(),
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
      {:ecto, "~> 2.0"},
    ]
  end

  defp package do
    [
      contributors: ["Jaap Frölich"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/jfrolich/gatekeeper"},
      files: ~w(lib mix.exs README.md),
    ]
  end
end
