; comment

(((comment) @c (#lua-match? @c "^[%s#]+%[%[[^\n]+%]%]")) (#join! "head" "" "[c] " @c))
((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "def")) (#join! "head" "" "[f] " @a))
((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "defp")) (#join! "head" "" "[p] " @a))
((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "test")) (#join! "head" "" "[t] " @a))
((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "describe")) (#join! "head" "" "[d] " @a))
((call target: (((identifier) ((arguments) @a)) @x)(#any-of? @x "defguard" "defguardp")) (#join! "head" "" "[g] " @a))
((call target: (((identifier) ((arguments) @a)) @x)(#any-of? @x "defmodule" "alias")) (#join! "head" "" "[M] " @x " " @a))
((((unary_operator (call (((identifier) @i)(#not-any-of? @i "doc" "spec" "typedoc" "moduledoc")))) @m))(#join! "head" "" "[@] " @m))
((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "defimpl")) (#join! "head" "" "[I] " @a))
((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "defmacro")) (#join! "head" "" "[m] " @a))
((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "defstruct")) (#join! "head" "" "[S] " @a))
((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "use")) (#join! "head" "" "[U] " @a))
