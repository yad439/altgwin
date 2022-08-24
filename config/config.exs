import Config
config :altgwin, :http_client, if(Mix.env() == :test, do: MockHttpClient, else: FinchHttpClient)
