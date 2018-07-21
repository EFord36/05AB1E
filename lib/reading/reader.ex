defmodule Reading.Reader do
    
    defp regexify(list) do
        "(" <> Enum.join(Enum.map(list, fn x -> Regex.escape(x) end), "|") <> ")"
    end
    
    def nullary_ops, do: regexify ["∞", "т", "₁", "₂", "₃", "₄", "A", "®", "N", "y", "w", "¶", "õ"]

    def unary_ops, do: regexify ["γ", "η", "θ", "н", "Θ", "Ω", "≠", "∊", "∞", "!", "(", ",", ";", "<", ">", 
                                 "?", "@", "C", "D", "H", "J", "L", "R", "S", "U", "V", "_", "`", "a", "b", 
                                 "d", "f", "g", "h", "j", "l", "n", "o", "p", "t", "u", "x", "z", "{", "ˆ", 
                                 "Œ", "Ć", "ƶ", "Ā", "–", "—", "˜", "™", "š", "œ", "ć", "¥", "¦", "§", "¨", 
                                 "ª", "°", "±", "·", "¸", "À", "Á", "Â", "Ä", "Æ", "Ç", "È", "É", "Ë", "Ì", 
                                 "Í", "Ñ", "Ò", "Ó", "Ô", "Õ", "Ø", "Ù", "Ú", "Ý", "Þ", "á", "æ", "ç", "é", 
                                 "ê", "í", "î", "ï", "ò", "ó", "û", "þ", ".€", ".ä", ".A", ".b", ".B", ".c", 
                                 ".C", ".e", ".E", ".j", ".J", ".l", ".M", ".m", ".N", ".p", ".R", ".r", ".s", 
                                 ".u", ".V", ".w", ".W", ".²", ".ï", ".ˆ", ".^", ".¼", ".½", ".¾", ".∞", ".¥", 
                                 ".ǝ", ".∊", ".Ø", "\\", "ā", "¤", "¥", "¬", "O", "P"]

    def binary_ops, do: regexify ["α", "β", "ζ", "в", "и", "м", "∍", "%", "&", "*", "+", "-", "/", "B", "K",
                                  "Q", "^", "c", "e", "k", "m", "s", "~", "‚", "†", "‰", "‹", "›", "¡", "¢",
                                  "£", "«", "¿", "Ã", "Ê", "Ï", "Ö", "×", "Û", "Ü", "Ý", "â", "ã", "ä", "å", "è",
                                  "ì", "ô", "ö", "÷", "ø", "ù", "ú", "ý", ".å", ".D", ".h", ".H"]
    
    def ternary_ops, do: regexify ["ǝ", "Š"]

    def special_ops, do: regexify [")", "r", "©", "¹", "²", "³", "I", "$", "Î", "#", "Ÿ"]
    
    def subprogram_ops, do: regexify ["ʒ", "ε", "Δ", "Σ", "F", "G", "v", "ƒ", "µ"]
    
    def subcommand_ops, do: regexify ["δ", "€", "ü", ".«", ".»"]
    
    def closing_brackets, do: regexify ["}", "]"]
    
    def string_delimiters, do: regexify ["\"", "•", "‘", "’", "“", "”"]
    
    def compressed_chars, do: regexify ["€", "‚", "ƒ", "„", "…", "†", "‡", "ˆ", "‰", "Š", "‹", "Œ", "Ž", "í", "î", "•", "–", "—", 
                                        "ï", "™", "š", "›", "œ", "ž", "Ÿ", "¡", "¢", "£", "¤", "¥", "¦", "§", "¨", "©", "ª", "«", 
                                        "¬", "®", "¯", "°", "±", "²", "³", "´", "µ", "¶", "·", "¸", "¹", "º", "»", "¼", "½", "¾", 
                                        "¿", "À", "Á", "Â", "Ã", "Ä", "Å", "Æ", "Ç", "È", "É", "Ê", "Ë", "Ì", "Í", "Î", "Ï", "Ð", 
                                        "Ñ", "Ò", "Ó", "Ô", "Õ", "Ö", "×", "Ø", "Ù", "Ú", "Û", "Ü", "Ý", "Þ", "ß", "à", "á", "â", 
                                        "ã", "ä", "å", "æ", "ç", "è", "é", "ê", "ë", "ì"]
                        

    alias Reading.CodePage
    alias Reading.Dictionary
    alias Commands.IntCommands
    
    def read_file(file_path, encoding) do

        case encoding do
            :utf_8 -> 
                String.codepoints(File.read!(file_path))
            :osabie -> 
                {_, file} = :file.open(file_path, [:read, :binary])
                Stream.map(IO.binread(file, :all), fn x -> CodePage.osabie_to_utf8(x) end)
        end
    end

    def read_step(raw_code) do

        cond do
            # Numbers
            Regex.match?(~r/^(\d*\.\d+|\d+)(.*)/, raw_code) ->
                matches = Regex.named_captures(~r/^(?<number>(\d*\.\d+|\d+))(?<remaining>.*)/, raw_code)
                {:number, matches["number"], matches["remaining"]}

            # Strings and equivalent values
            Regex.match?(~r/^#{string_delimiters()}(.*?)(\1|$)/, raw_code) ->
                matches = Regex.named_captures(~r/^(?<delimiter>#{string_delimiters()})(?<string>.*?)(\1|$)(?<remaining>.*)/, raw_code)
                case matches["delimiter"] do
                    # Compressed numbers
                    "•" -> {:number, IntCommands.string_from_base(matches["string"], 255), matches["remaining"]}

                    # Strings
                    "\"" -> {:string, matches["string"], matches["remaining"]}

                    # Compressed strings
                    "‘" -> {:string, Dictionary.uncompress(matches["string"], :upper), matches["remaining"]}
                    "’" -> {:string, Dictionary.uncompress(matches["string"], :no_space), matches["remaining"]}
                    "“" -> {:string, Dictionary.uncompress(matches["string"], :normal), matches["remaining"]}
                    "”" -> {:string, Dictionary.uncompress(matches["string"], :title), matches["remaining"]}
                end

            # Nullary functions
            Regex.match?(~r/^#{nullary_ops()}/, raw_code) ->
                matches = Regex.named_captures(~r/^(?<nullary_op>#{nullary_ops()})(?<remaining>.*)/, raw_code)
                {:nullary_op, matches["nullary_op"], matches["remaining"]}

            # Constants as nullary functions
            Regex.match?(~r/^ž./, raw_code) ->
                matches = Regex.named_captures(~r/^(?<nullary_op>ž.)(?<remaining>.*)/, raw_code)
                {:nullary_op, matches["nullary_op"], matches["remaining"]}
        
            # Unary functions
            Regex.match?(~r/^#{unary_ops()}/, raw_code) ->
                matches = Regex.named_captures(~r/^(?<unary_op>#{unary_ops()})(?<remaining>.*)/, raw_code)
                {:unary_op, matches["unary_op"], matches["remaining"]}
            
            # Binary functions
            Regex.match?(~r/^#{binary_ops()}/, raw_code) ->
                matches = Regex.named_captures(~r/^(?<binary_op>#{binary_ops()})(?<remaining>.*)/, raw_code)
                {:binary_op, matches["binary_op"], matches["remaining"]}
            
            # Ternary functions
            Regex.match?(~r/^#{ternary_ops()}/, raw_code) ->
                matches = Regex.named_captures(~r/^(?<ternary_op>#{ternary_ops()})(?<remaining>.*)/, raw_code)
                {:ternary_op, matches["ternary_op"], matches["remaining"]}
            
            # Special functions
            Regex.match?(~r/^#{special_ops()}/, raw_code) ->
                matches = Regex.named_captures(~r/^(?<special_op>#{special_ops()})(?<remaining>.*)/, raw_code)
                {:special_op, matches["special_op"], matches["remaining"]}
            
            # Subprograms
            Regex.match?(~r/^#{subprogram_ops()}/, raw_code) ->
                matches = Regex.named_captures(~r/^(?<subprogram>#{subprogram_ops()})(?<remaining>.*)/, raw_code)
                {:subprogram, matches["subprogram"], matches["remaining"]}
            
            # Subcommands
            Regex.match?(~r/^#{subcommand_ops()}/, raw_code) ->
                matches = Regex.named_captures(~r/^(?<subcommand>#{subcommand_ops()})(?<remaining>.*)/, raw_code)
                {:subcommand, matches["subcommand"], matches["remaining"]}
            
            # Closing brackets
            Regex.match?(~r/^#{closing_brackets()}/, raw_code) ->
                matches = Regex.named_captures(~r/^(?<bracket>#{closing_brackets()})(?<remaining>.*)/, raw_code)
                case matches["bracket"] do
                    "}" -> {:end, "}", matches["remaining"]}
                    "]" -> {:end_all, "]", matches["remaining"]}
                end
            
            # No-ops
            Regex.match?(~r/^(.).*/, raw_code) ->
                matches = Regex.named_captures(~r/^(?<no_op>.)(?<remaining>.*)/, raw_code)
                {:no_op, matches["no_op"], matches["remaining"]}
            
            # EOF
            true ->
                {:eof, nil, nil}
        end
    end

    def read(raw_code) do
        case read_step(raw_code) do
            {:eof, val, _} -> [[:eof, val]]
            {type, val, remaining} -> [[type, val]] ++ read(remaining)
        end
    end
end