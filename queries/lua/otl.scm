(((comment) @c (#lua-match? @c "^--%[%[[^\n]+%]%]$")) (#join! "head"  "" "[-] " @c))

((function_declaration (identifier) @a (parameters) @b (#join! "head" "" "[f] " @a @b)))

((function_declaration (dot_index_expression) @a (parameters) @b (#join! "head" "" "[.] " @a @b)))

((function_declaration (method_index_expression) @a (parameters) @b (#join! "head" "" "[m] " @a @b)))

; Tables - TODO: this works in Inspect, but not here?? Shows up as [v] ??
((variable_declaration
  (assignment_statement
    (variable_list (identifier) @a)
    (expression_list (table_constructor)))))(#join! "head" "" "[t] " "={}" @a)

; variables
(((variable_declaration) @head) (#join! "head" "" "[v] " @head))

; assignment statements
((assignment_statement
  ((variable_list) @a) (("=") @b)
  (expression_list (function_definition (("function") @c) ((parameters)@d))))
  (#join! "head" "" "[f] " @a " " @b " " @c @d))

(((assignment_statement) @head) (#join! "head" "" "[s] " @head))

