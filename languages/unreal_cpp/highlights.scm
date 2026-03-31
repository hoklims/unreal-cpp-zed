; ═══════════════════════════════════════════════════════════════════════
; Unreal C++ — Tree-sitter Syntax Highlighting for Zed
; Grammar: tree-sitter-cpp (inherits tree-sitter-c node types)
;
; Pattern priority in Zed: LATER patterns override EARLIER patterns
; when they capture the same node. Structure:
;   1. C base patterns           (lowest priority)
;   2. C++ additions
;   3. Unreal Engine patterns    (highest priority)
; ═══════════════════════════════════════════════════════════════════════


; ─── C BASE PATTERNS ──────────────────────────────────────────────────
; From tree-sitter-c/queries/highlights.scm

; --- Baseline: all identifiers as variables (lowest priority) ---
(identifier) @variable

; --- C Keywords ---
[
  "break"
  "case"
  "const"
  "continue"
  "default"
  "do"
  "else"
  "enum"
  "extern"
  "for"
  "goto"
  "if"
  "inline"
  "register"
  "restrict"
  "return"
  "sizeof"
  "static"
  "struct"
  "switch"
  "typedef"
  "union"
  "volatile"
  "while"
  "_Atomic"
  "_Generic"
  "_Noreturn"
  "_Static_assert"
  "_Thread_local"
] @keyword

; --- Preprocessor ---
[
  "#define"
  "#elif"
  "#else"
  "#endif"
  "#if"
  "#ifdef"
  "#ifndef"
  "#include"
  "#pragma"
  "#undef"
] @keyword

(preproc_directive) @keyword

; --- Operators ---
[
  "--"
  "-"
  "-="
  "->"
  "="
  "!="
  "!"
  "*"
  "&"
  "&&"
  "+"
  "++"
  "+="
  "<"
  "<="
  "<<"
  "<<="
  "=="
  ">"
  ">="
  ">>"
  ">>="
  "||"
  "|"
  "|="
  "^"
  "^="
  "~"
  "*="
  "/="
  "%"
  "%="
  "/"
  "?"
  ":"
] @operator

; --- Punctuation ---
"." @punctuation.delimiter
";" @punctuation.delimiter
"," @punctuation.delimiter

"(" @punctuation.bracket
")" @punctuation.bracket
"[" @punctuation.bracket
"]" @punctuation.bracket
"{" @punctuation.bracket
"}" @punctuation.bracket

; --- Literals ---
[
  (string_literal)
  (system_lib_string)
] @string

(escape_sequence) @string.escape
(true) @boolean
(false) @boolean
(nullptr) @constant

[
  (number_literal)
  (char_literal)
] @number

; --- Types & Identifiers ---
(field_identifier) @property
(statement_identifier) @label

[
  (type_identifier)
  (primitive_type)
  (sized_type_specifier)
] @type

; --- Functions ---
(call_expression
  function: (identifier) @function)

(call_expression
  function: (field_expression
    field: (field_identifier) @function))

(function_declarator
  declarator: (identifier) @function)

(preproc_function_def
  name: (identifier) @function.special)

; --- ALL_CAPS identifiers as constants ---
((identifier) @constant
  (#match? @constant "^[A-Z][A-Z\\d_]*$"))

; --- Comments ---
(comment) @comment


; ─── C++ ADDITIONS ────────────────────────────────────────────────────
; From tree-sitter-cpp/queries/highlights.scm

; --- C++ Functions ---
(call_expression
  function: (qualified_identifier
    name: (identifier) @function))

(template_function
  name: (identifier) @function)

(template_method
  name: (field_identifier) @function)

(function_declarator
  declarator: (qualified_identifier
    name: (identifier) @function))

(function_declarator
  declarator: (field_identifier) @function)

; --- C++ Types ---
((namespace_identifier) @type
  (#match? @type "^[A-Z]"))

(auto) @type

; --- C++ Built-in values ---
(this) @variable.special

; --- C++ Module names ---
(module_name
  (identifier) @label)

; --- C++ Keywords ---
[
  "catch"
  "class"
  "co_await"
  "co_return"
  "co_yield"
  "constexpr"
  "constinit"
  "consteval"
  "decltype"
  "delete"
  "explicit"
  "final"
  "friend"
  "mutable"
  "namespace"
  "noexcept"
  "new"
  "operator"
  "override"
  "private"
  "protected"
  "public"
  "static_assert"
  "static_cast"
  "dynamic_cast"
  "reinterpret_cast"
  "const_cast"
  "template"
  "throw"
  "try"
  "typename"
  "typeid"
  "using"
  "concept"
  "requires"
  "virtual"
  "import"
  "export"
  "module"
] @keyword

; --- C++ Strings ---
(raw_string_literal) @string

; --- C++ Access specifiers highlighting ---
(access_specifier) @keyword

; --- C++ Attributes [[...]] ---
(attribute_declaration) @attribute


; ═══════════════════════════════════════════════════════════════════════
; UNREAL ENGINE — Reflection & Macro System
; Placed LAST = HIGHEST PRIORITY (overrides generic patterns above)
; ═══════════════════════════════════════════════════════════════════════

; ─── UE Reflection Macros (class/struct/enum/interface declarations) ──
; Matches: UCLASS(...), USTRUCT(...), UENUM(...), UINTERFACE(...)
;
; Example:
;   UCLASS(BlueprintType, Blueprintable)    ← "UCLASS" → @attribute
;   class MYGAME_API AMyActor : public AActor { ... };

(call_expression
  function: (identifier) @attribute
  (#match? @attribute "^(UCLASS|USTRUCT|UENUM|UINTERFACE)$"))

; ─── UE Property/Function Specifier Macros ────────────────────────────
; Matches: UPROPERTY(...), UFUNCTION(...), UDELEGATE(...), UMETA(...)
;
; Example:
;   UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Stats")
;   float Health = 100.f;                   ← "UPROPERTY" → @attribute
;
;   UFUNCTION(BlueprintCallable, Category = "Combat")
;   void TakeDamage(float Amount);          ← "UFUNCTION" → @attribute

(call_expression
  function: (identifier) @attribute
  (#match? @attribute "^(UPROPERTY|UFUNCTION|UDELEGATE|UMETA)$"))

; ─── UE Generated Body Macros ─────────────────────────────────────────
; Matches: GENERATED_BODY(), GENERATED_UCLASS_BODY(), etc.
;
; Example:
;   class AMyActor : public AActor
;   {
;       GENERATED_BODY()                    ← @attribute

(call_expression
  function: (identifier) @attribute
  (#match? @attribute "^GENERATED_(BODY|UCLASS_BODY|USTRUCT_BODY|UINTERFACE_BODY)$"))

; ─── UE Delegate Declaration Macros ───────────────────────────────────
; Matches all DECLARE_*DELEGATE* variants:
;   DECLARE_DELEGATE(FMyDelegate)
;   DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(...)
;   DECLARE_EVENT(...)

(call_expression
  function: (identifier) @attribute
  (#match? @attribute "^DECLARE_(DYNAMIC_)?(MULTICAST_)?(DELEGATE|EVENT)"))

; ─── UE Logging Macros ────────────────────────────────────────────────
; Matches: UE_LOG, UE_LOGFMT, UE_CLOG
;
; Example:
;   UE_LOG(LogTemp, Warning, TEXT("Health: %f"), Health);

(call_expression
  function: (identifier) @function
  (#match? @function "^UE_(LOG|LOGFMT|CLOG)$"))

; ─── UE Assertion Macros ──────────────────────────────────────────────
; Matches: check, checkf, ensure, ensureAlways, verify, etc.
;
; Example:
;   check(MyPointer != nullptr);
;   ensureMsgf(Health > 0, TEXT("Health should be positive"));

(call_expression
  function: (identifier) @function
  (#match? @function "^(check|checkf|checkSlow|checkfSlow|checkNoEntry|checkNoReentry|checkNoRecursion|ensure|ensureAlways|ensureMsgf|verify|verifyf)$"))

; ─── UE API Export Macros ─────────────────────────────────────────────
; Matches: MYGAME_API, MYPROJECT_API, ENGINE_API, CORE_API, etc.
; Pattern: ALL_CAPS ending with _API
;
; Example:
;   class MYGAME_API AMyActor : public AActor

((identifier) @attribute
  (#match? @attribute "^[A-Z][A-Z_]*_API$"))

; ─── UE TEXT Macro ────────────────────────────────────────────────────
; Matches: TEXT("...")
;
; Example:
;   FString Name = TEXT("Hello");

(call_expression
  function: (identifier) @function.special
  (#match? @function.special "^TEXT$"))

; ─── UE Common Specifier Flags ────────────────────────────────────────
; These appear as identifier arguments inside UPROPERTY/UFUNCTION calls.
; Highlighted as constants since they are predefined named values.
;
; Example:
;   UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Stats")
;             ^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^^^  ^^^^^^^^
;             all three → @constant

((identifier) @constant
  (#match? @constant "^(EditAnywhere|EditDefaultsOnly|EditInstanceOnly|VisibleAnywhere|VisibleDefaultsOnly|VisibleInstanceOnly|BlueprintReadWrite|BlueprintReadOnly|BlueprintCallable|BlueprintImplementableEvent|BlueprintNativeEvent|BlueprintPure|BlueprintType|Blueprintable|NotBlueprintable|BlueprintAssignable|BlueprintAuthorityOnly|BlueprintGetter|BlueprintSetter|Category|DisplayName|Transient|DuplicateTransient|NonTransactional|Config|GlobalConfig|Replicated|ReplicatedUsing|NotReplicated|Instanced|SimpleDisplay|AdvancedDisplay|SaveGame|NoClear|Interp|Export|EditFixedSize|AllowPrivateAccess|ExposeOnSpawn|Abstract|MinimalAPI|Within|Exec|Server|Client|NetMulticast|Reliable|Unreliable|WithValidation|SealedEvent|CustomThunk|ServiceRequest|ServiceResponse|meta)$"))

; ─── UE Miscellaneous Macros ──────────────────────────────────────────
; Common UE macros used as standalone identifiers (not call expressions)
;
; IMPLEMENT_PRIMARY_GAME_MODULE, DEFINE_LOG_CATEGORY, etc.

((identifier) @attribute
  (#match? @attribute "^(IMPLEMENT_PRIMARY_GAME_MODULE|IMPLEMENT_MODULE|IMPLEMENT_GAME_MODULE|DEFINE_LOG_CATEGORY|DEFINE_LOG_CATEGORY_STATIC|DECLARE_LOG_CATEGORY_EXTERN)$"))

; ─── UE Cast Macros ───────────────────────────────────────────────────
; Matches: Cast<T>(...), CastChecked<T>(...)
; These parse as template_function calls

(call_expression
  function: (template_function
    name: (identifier) @function
    (#match? @function "^(Cast|CastChecked|ExactCast)$")))
