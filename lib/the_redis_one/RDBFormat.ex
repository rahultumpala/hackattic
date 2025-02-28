defmodule TheRedisOne.RDBFormat do
  defmacro int32, do: quote(do: integer - signed)
  defmacro int16, do: quote(do: integer - signed)

  def parse(<<bits::binary>>) do
    {fmt, bits} = magic({%{}, bits})

    IO.inspect(fmt)
  end

  defp magic({fmt, bits}) do
    <<key::bitstring-size(40), rest::bitstring>> = bits

    case key do
      <<"mysql">> -> {Map.put(fmt, "magic", "mysql"), rest}
      <<"MySQL">> -> {Map.put(fmt, "magic", "MySQL"), rest}
      <<"MYSQL">> -> {Map.put(fmt, "magic", "MYSQL"), rest}
      <<"mySQL">> -> {Map.put(fmt, "magic", "mySQL"), rest}
    end
  end
end
