; Classes
(class_specifier
  name: (type_identifier) @name) @item

; Structs
(struct_specifier
  name: (type_identifier) @name) @item

; Enums
(enum_specifier
  name: (type_identifier) @name) @item

; Free functions
(function_definition
  declarator: (function_declarator
    declarator: (identifier) @name)) @item

; Qualified member functions (Class::Method)
(function_definition
  declarator: (function_declarator
    declarator: (qualified_identifier
      name: (identifier) @name)
    ) @context) @item

; Namespaces
(namespace_definition
  name: (identifier) @name) @item
