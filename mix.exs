defmodule Requiem.MixProject do
  use Mix.Project

  def project do
    [
      app: :requiem,
      version: "0.3.4-rc.0",
      elixir: "~> 1.11",
      package: package(),
      compilers: [:rustler] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      rustler_crates: rustler_crates(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :eex, :crypto]
    ]
  end

  defp rustler_crates do
    [
      requiem_nif: [
        path: "native/requiem_nif",
        mode: rustc_mode(Mix.env())
      ]
    ]
  end

  defp rustc_mode(_), do: :release
  # defp rustc_mode(:prod), do: :release
  # defp rustc_mode(_), do: :debug

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.23", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:toml, "~> 0.5"},
      {:fastglobal, "~> 1.0"},
      {:rustler, "~> 0.22.0-rc.0"},
    ]
  end

  defp package() do
    [
      description: "A QuicTransport server framework.",
      licenses: ["MIT"],
      links: %{
        "Github" => "https://github.com/xflagstudio/requiem",
        "Docs" => "https://hexdocs.pm/requiem/Requiem.html"
      },
      maintainers: ["Lyo Kato", "Hidetaka Kojo"]
    ]
  end
end
