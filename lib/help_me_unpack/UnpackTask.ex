defmodule HelpMeUnpack.UnpackTask do
  alias HelpMeUnpack.Base64
  alias HelpMeUnpack.Numbers

  def run(access_token) do
    url =
      ~s"https://hackattic.com/challenges/help_me_unpack/problem?access_token=" <> access_token

    {:ok, response} = :httpc.request(url)
    {{_, 200, _}, _, body} = response

    solution =
      case Jason.decode(body) do
        {:ok, json} -> Map.get(json, "bytes") |> handle_bytes()
      end

    headers = []
    content_type = ~c"application/json"
    {:ok, req_body} = Jason.encode(solution)

    url = ~s"https://hackattic.com/challenges/help_me_unpack/solve?access_token=" <> access_token

    {:ok, {{_, 200, _}, _, body}} =
      :httpc.request(:post, {url, headers, content_type, req_body}, [], [])

    IO.inspect(body)
  end

  defp handle_bytes(bytes_str) do
    {binary_str, _length} =
      String.codepoints(bytes_str)
      |> decode("")

    :logger.info(
      "The following bytes are in big-endian order & have to be reversed before parsing."
    )

    binary_str
    |> Numbers.chunk8([])
    |> Enum.reverse()
    |> IO.inspect(width: 50)

    integer =
      String.slice(binary_str, 0, 32)
      |> Numbers.convert_big_endian()
      |> Numbers.parse_integer()

    unsigned_int =
      String.slice(binary_str, 32, 32)
      |> Numbers.convert_big_endian()
      |> Numbers.parse_unsigned_int()

    short =
      String.slice(binary_str, 64, 16)
      |> Numbers.convert_big_endian()
      |> Numbers.parse_short()

    float =
      String.slice(binary_str, 96, 32)
      |> Numbers.convert_big_endian()
      |> Numbers.parse_float()

    double =
      String.slice(binary_str, 128, 64)
      |> Numbers.convert_big_endian()
      |> Numbers.parse_double(:lil_end_double)

    big_end_double =
      String.slice(binary_str, 192, 64)
      |> Numbers.parse_double(:big_end_double)

    %{
      int: integer,
      uint: unsigned_int,
      short: short,
      float: float,
      double: double,
      big_endian_double: big_end_double
    }
    |> IO.inspect()
  end

  defp decode([char | tail], state) do
    if char == "=" do
      state = String.slice(state, 0, String.length(state) - 2)
      decode(tail, state)
    else
      binary_str = Base64.decode_char(char)
      decode(tail, state <> binary_str)
    end
  end

  defp decode([], state) do
    {state, String.length(state)}
  end
end
