defmodule DTMF do
  @target_freqs [697, 770, 852, 941, 1209, 1336, 1477]

  defp generate_samples(points, threshold) do
    {samples, sample, zeros} =
      Enum.reduce(points, {[], [], 0}, fn point, {samples, sample, zeros} ->
        zeros = if point == 0, do: zeros + 1, else: 0

        cond do
          zeros <= threshold ->
            {samples, [point | sample], zeros}

          zeros > threshold ->
            case length(sample) do
              0 -> {samples, [], zeros}
              _ -> {[sample | samples], [], zeros}
            end
        end
      end)

    samples =
      cond do
        length(sample) > 0 -> [sample | samples]
        true -> samples
      end

    Enum.map(samples, fn sample -> Enum.reverse(sample) end) |> Enum.reverse()
  end

  def decode(fmt, length, amplitude) do
    IO.inspect({fmt, length, amplitude})
    samples = generate_samples(amplitude, 10)
    IO.inspect({"TOTAL DIGIT SAMPLES SIZE : ", length(samples)})

    chars =
      Enum.map(samples, fn sample ->
        Map.get(fmt, "SampleRate")
        |> goertzel(sample)
      end)

    seq = Enum.reduce(chars, "", fn char, str -> str <> char end)

    seq
  end

  def goertzel(sampleRate, sample) do
    freqs =
      Enum.map(@target_freqs, fn target_freq ->
        # IO.inspect({"CURRENT TARGET FREQ", target_freq})
        w = 2 * Math.pi() * target_freq / sampleRate
        coeff = 2 * Math.cos(w)

        {q1, q2} =
          Enum.reduce(sample, {0, 0}, fn point, {q1, q2} ->
            q0 = coeff * q1 - q2 + point
            {q0, q1}
          end)

        magnitude_sqr = q1 * q1 + q2 * q2 - q1 * q2 * coeff

        {target_freq, magnitude_sqr}
      end)

    {high_freqs, low_freqs} =
      Enum.reduce(freqs, {[], []}, fn {freq, magnitude}, {high, low} ->
        cond do
          freq > 1000 -> {[{freq, magnitude} | high], low}
          freq < 1000 -> {high, [{freq, magnitude} | low]}
        end
      end)

    high_freqs = Enum.sort_by(high_freqs, &Kernel.elem(&1, 1), :desc)
    low_freqs = Enum.sort_by(low_freqs, &Kernel.elem(&1, 1), :desc)

    [{high, _} | _] = high_freqs
    [{low, _} | _] = low_freqs

    IO.inspect({high, low})

    get_dtmf_char({high, low})
  end

  defp get_dtmf_char({high_freq, low_freq}) do
    case {high_freq, low_freq} do
      {1209, 697} -> "1"
      {1336, 697} -> "2"
      {1477, 697} -> "3"
      {1209, 770} -> "4"
      {1336, 770} -> "5"
      {1477, 770} -> "6"
      {1209, 852} -> "7"
      {1336, 852} -> "8"
      {1477, 852} -> "9"
      {1336, 941} -> "0"
      {1209, 941} -> "*"
      {1477, 941} -> "#"
      _ -> "."
    end
  end
end
