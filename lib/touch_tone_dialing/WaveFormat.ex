defmodule WaveFormat do
  defmacro int32LE, do: quote(do: integer - signed - 32 - little)
  defmacro int16LE, do: quote(do: integer - signed - 16 - little)
  import ExFft

  def parse(bytes) do
    # WAVE HEADER
    {fmt, bytes} =
      read_riff_chunk({%{}, bytes})
      |> read_fmt_subChunk
      |> read_data_subChunk

    IO.inspect(fmt)

    {amplitude, length} = Map.get(fmt, "SubChunk2Size") |> decode_amplitude(bytes)

    # IO.inspect([fmt, amplitude, length])
    ExFft.fft(amplitude, :ortho)
    |> Enum.with_index()
    |> IO.inspect()

    # |> Enum.each(fn {x, idx} -> (idx * 4000 / 16384) |> IO.inspect() end)
  end

  defp read_riff_chunk({fmt, bytes}) do
    <<"RIFF", chunkSize::int32LE, "WAVE", rest::binary>> = bytes

    fmt =
      Map.put(fmt, "ChunkID", "RIFF")
      |> Map.put("ChunkSize", chunkSize)
      |> Map.put("Format", "WAVE")

    {fmt, rest}
  end

  defp read_fmt_subChunk({fmt, bytes}) do
    <<"fmt ", subChunk1Size::int32LE, audioFormat::int16LE, numChannels::int16LE,
      sampleRate::int32LE, byteRate::int32LE, blockAlign::int16LE, bitsPerSample::int16LE,
      rest::binary>> = bytes

    fmt =
      Map.put(fmt, "SubChunk1ID", "fmt ")
      |> Map.put("SubChunk1Size", subChunk1Size)
      |> Map.put("AudioFormat", extract_audio_fmt(audioFormat))
      |> Map.put("NumChannels", numChannels)
      |> Map.put("SampleRate", sampleRate)
      |> Map.put("ByteRate", byteRate)
      |> Map.put("BlockAlign", blockAlign)
      |> Map.put("BitsPerSample", bitsPerSample)

    {fmt, rest}
  end

  defp read_data_subChunk({fmt, bytes}) do
    <<"data", subChunk2Size::int32LE, data::binary>> = bytes

    fmt =
      Map.put(fmt, "SubChunk2ID", "data")
      |> Map.put("SubChunk2Size", subChunk2Size)

    {fmt, data}
  end

  defp extract_audio_fmt(bytes) do
    format = bytes

    if format == 1, do: "PCM", else: "OTHER"
  end

  defp decode_amplitude(size, point, points \\ [])

  defp decode_amplitude(_, "", points) do
    Enum.reduce(points, {[], 0}, fn point, {rev, len} -> {[point | rev], len + 1} end)
  end

  defp decode_amplitude(size, <<point::int32LE, rest::binary>>, points) do
    decode_amplitude(size - 1, rest, [point | points])
  end
end
