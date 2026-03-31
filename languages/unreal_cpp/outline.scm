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

; Namespaces
(namespace_definition
  name: (namespace_identifier) @name) @item
