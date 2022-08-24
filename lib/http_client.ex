defmodule HttpClient do
  @callback get(String.t()) :: binary()
end

defmodule FinchHttpClient do
  @behaviour HttpClient

  @impl true
  def get(url) do
    {:ok, response} = Finch.build(:get, url) |> Finch.request(FinchClient)
    response.body
  end
end
