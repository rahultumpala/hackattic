defmodule WebSocketClient do
  use WebSockex

  def start_link(url, state) do
    {:ok, time} = DateTime.now("Etc/UTC")
    WebSockex.start_link(url, __MODULE__, state)
  end

  def handle_connect(_conn, state) do
    {:ok, time} = DateTime.now("Etc/UTC")
    IO.inspect({"Time when connection established: ", time})
    {:ok, [time | state]}
  end

  def handle_frame({type, msg}, [prev_time, parent_pid]) do
    IO.puts("Received Message - Type: #{inspect(type)} -- Message: #{inspect(msg)}")

    cond do
      msg == "good!" ->
        {:ok, [prev_time, parent_pid]}

      msg == "ping!" ->
        {:ok, time} = DateTime.now("Etc/UTC")

        diff = DateTime.diff(time, prev_time, :millisecond)
        IO.inspect({"Actual DIFF: ", diff})

        diff = detect_interval(diff)

        IO.inspect({"Sending time as ", diff})
        {:reply, {:text, Integer.to_string(diff)}, [time, parent_pid]}

      String.starts_with?(msg, "congratulations!") ->
        secret = fetch_secret(msg)
        IO.inspect({"The secret is ", secret})
        {:reply, :submitted} = GenServer.call(parent_pid, {:submit, secret})
        {:ok, [prev_time, parent_pid]}

      true ->
        {:ok, [prev_time, parent_pid]}
    end
  end

  # added 50ms to account for transit
  defp detect_interval(diff) do
    cond do
      diff < 1450 -> 700
      diff < 1950 -> 1500
      diff < 2450 -> 2000
      diff < 2950 -> 2500
      diff >= 2950 -> 3000
    end
  end

  defp fetch_secret(text) do
    IO.puts("Fetching secret from the message")

    {:match, [secret]} =
      :re.run(text, "congratulations! the solution to this challenge is \"(.*)\"", [
        {:capture, [1], :list}
      ])

    List.to_string(secret)
  end
end
