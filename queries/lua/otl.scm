(((comment) @c (#lua-match? @c "^--%[%[[^\n]+%]%]$")) (#join! "head"  "" "[-] " @c))

((function_declaration (identifier) @a (parameters) @b (#join! "head" "" "[f] " @a @b)))

((function_declaration (dot_index_expression) @a (parameters) @b (#join! "head" "" "[f] " @a @b)))

((assignment_statement
  ((variable_list) @a) (("=") @b)
  (expression_list (function_definition (("function") @c) ((parameters)@d))))
  (#join! "head" "" "[f] " @a " " @b " " @c @d))

(((assignment_statement) @head) (#join! "head" "" "[S] " @head))

(((variable_declaration) @head) (#join! "head" "" "[v] " @head))
