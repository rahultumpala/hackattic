defmodule Hackattic.MixProject do
  use Mix.Project

  def project do
    [
      app: :hackattic,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets, :ssl],
      mod: {Hackattic, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:math, "~> 0.3.0"},
      {:websockex, "~> 0.4.3"},
      {:bandit, "~> 0.7.7"},
      {:plug, "~> 1.14"}
    ]
  end
end
