defmodule TouchToneDialing.TouchToneTask do
  defp download_problem(access_token) do
    url =
      ~s"https://hackattic.com/challenges/touch_tone_dialing/problem?access_token=" <>
        access_token

    {:ok, response} = :httpc.request(url)
    {{_, 200, _}, _, body} = response

    {:ok, path} =
      case Jason.decode(body) do
        {:ok, json} ->
          Map.get(json, "wav_url")
          |> download_wav()
      end

    path
  end

  defp submit_response(access_token, solution) do
    headers = []
    content_type = ~c"application/json"
    {:ok, req_body} = Jason.encode(solution)

    url =
      ~s"https://hackattic.com/challenges/touch_tone_dialing/solve?access_token=" <> access_token

    {:ok, {{_, 200, _}, _, body}} =
      :httpc.request(:post, {url, headers, content_type, req_body}, [], [])

    IO.inspect(body)
  end

  def run(access_token) do
    path =
      File.cwd!()
      |> Path.join("/lib/touch_tone_dialing/wav")
      |> Path.join("audio.wav")
      |> String.to_charlist()

    path = download_problem(access_token)

    {:ok, bytes} = File.read(path)

    File.stat(path) |> IO.inspect()
    fmt = WaveFormat.parse(bytes)

    # FORMAT
  end

  defp download_wav(url) do
    path_to_file =
      File.cwd!()
      |> Path.join("/lib/touch_tone_dialing/wav")

    File.mkdir(path_to_file)

    path_to_file =
      path_to_file
      |> Path.join("audio.wav")
      |> String.to_charlist()

    {:ok, :saved_to_file} = :httpc.request(:get, {url, []}, [], stream: path_to_file)

    {:ok, path_to_file}
  end
end
