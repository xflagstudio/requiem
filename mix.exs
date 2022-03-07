defmodule Requiem.MixProject do
  use Mix.Project

  def project do
    [
      app: :requiem,
      version: "0.3.10",
      elixir: "~> 1.11",
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :eex, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.23", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:toml, "~> 0.5"},
      {:fastglobal, "~> 1.0"},
      {:rustler, "~> 0.22"}
    ]
  end

  defp package() do
    [
      description: "A QuicTransport server framework.",
      files: ["lib", "mix.exs", "README*", "LICENSE*", "native", "test"],
      licenses: ["MIT"],
      links: %{
        "Github" => "https://github.com/xflagstudio/requiem",
        "Docs" => "https://hexdocs.pm/requiem/Requiem.html"
      },
      maintainers: ["Lyo Kato", "Hidetaka Kojo"]
    ]
  end
end
