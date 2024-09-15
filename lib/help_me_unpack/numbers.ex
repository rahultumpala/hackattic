defmodule HelpMeUnpack.Numbers do
  defp invert([]), do: ""

  defp invert([bit | rest]) do
    case bit do
      "1" -> "0" <> invert(rest)
      "0" -> "1" <> invert(rest)
    end
  end

  defp invert_and_parse(string) do
    String.graphemes(string)
    |> invert()
    |> Integer.parse(2)
    |> Kernel.elem(0)
    |> Kernel.+(1)
  end

  def parse_integer(string) do
    IO.inspect(string, label: :integer)
    {sign, bits} = slice(string, 1)
    {num, ""} = Integer.parse(bits, 2)

    case sign do
      "1" -> -1 * invert_and_parse(bits)
      "0" -> num
    end
  end

  def parse_unsigned_int(string) do
    IO.inspect(string, label: :unsigned_integer)
    Integer.parse(string, 2) |> Kernel.elem(0)
  end

  def parse_short(string) do
    IO.inspect(string, label: :short)
    {sign, bits} = slice(string, 1)
    {num, ""} = Integer.parse(bits, 2)

    case sign do
      "1" -> -1 * invert_and_parse(bits)
      "0" -> num
    end
  end

  def parse_float(string) do
    IO.inspect(string, label: :float)
    {sign, bits} = slice(string, 1)
    {exponent, bits} = slice(bits, 8)
    {mantissa, ""} = slice(bits, 23)
    {exponent, ""} = Integer.parse(exponent, 2)
    {mantissa, ""} = Integer.parse(mantissa, 2)

    # IO.puts(sign)
    # IO.puts(exponent)
    # IO.puts(mantissa)

    offset = 1.0 + mantissa / Float.pow(2.0, 23)
    float = Float.pow(2.0, exponent - 127) * offset

    case sign do
      "0" -> float
      "1" -> -1.0 * float
    end
  end

  def parse_double(string, label) do
    IO.inspect(string, label: label)
    {sign, bits} = slice(string, 1)
    {exponent, bits} = slice(bits, 11)
    {mantissa, ""} = slice(bits, 52)
    {exponent, ""} = Integer.parse(exponent, 2)
    {mantissa, ""} = Integer.parse(mantissa, 2)

    # IO.puts(sign)
    # IO.puts(exponent)
    # IO.puts(mantissa)

    offset = 1.0 + mantissa / Float.pow(2.0, 52)
    double = Float.pow(2.0, exponent - 1023) * offset

    case sign do
      "0" -> double
      "1" -> -1.0 * double
    end
  end

  def convert_big_endian(string) do
    chunk8(string, [])
    |> Enum.reduce("", fn el, acc -> acc <> el end)
  end

  def chunk8("", chunks) do
    chunks
  end

  def chunk8(string, chunks) do
    {chunk, rest} = slice(string, 8)
    chunk8(rest, [chunk | chunks])
  end

  def slice(string, size) do
    len = String.length(string)
    {String.slice(string, 0, size), String.slice(string, size, len)}
  end
end
