# Guidelines : Creer une extension de langage Zed

Guide de reference complet pour developper une extension de langage dans Zed Editor.
Toutes les informations ci-dessous ont ete verifiees contre la documentation officielle Zed,
le code source de Zed (extensions GLSL, HTML, WGSL...), et le fonctionnement reel de Tree-sitter.

> **Derniere verification** : Mars 2026 — Zed schema_version 1

---

## Table des matieres

1. [Architecture d'une extension Zed](#1-architecture-dune-extension-zed)
2. [extension.toml — Le manifeste](#2-extensiontoml--le-manifeste)
3. [Grammaires Tree-sitter](#3-grammaires-tree-sitter)
4. [Configuration du langage (config.toml)](#4-configuration-du-langage-configtoml)
5. [Tree-sitter queries (.scm)](#5-tree-sitter-queries-scm)
6. [Systeme de priorite des captures](#6-systeme-de-priorite-des-captures)
7. [Reutiliser une grammaire existante](#7-reutiliser-une-grammaire-existante)
8. [Detection des fichiers et conflits](#8-detection-des-fichiers-et-conflits)
9. [Snippets](#9-snippets)
10. [Integration LSP](#10-integration-lsp)
11. [Workflow de dev et debug](#11-workflow-de-dev-et-debug)
12. [Publication sur le marketplace](#12-publication-sur-le-marketplace)
13. [Pieges courants](#13-pieges-courants)
14. [References](#14-references)

---

## 1. Architecture d'une extension Zed

### Structure minimale (langage uniquement, pas de LSP)

```
my-extension/
├── extension.toml                  # OBLIGATOIRE — manifeste
├── LICENSE                         # OBLIGATOIRE pour publication
└── languages/
    └── my_language/                # un sous-dossier par langage
        ├── config.toml             # OBLIGATOIRE — declaration du langage
        ├── highlights.scm          # coloration syntaxique
        ├── brackets.scm            # paires de brackets
        ├── outline.scm             # symboles pour navigation
        └── indents.scm             # regles d'indentation
```

### Structure complete (avec LSP)

```
my-extension/
├── extension.toml
├── Cargo.toml                      # necessaire si code Rust (LSP adapter)
├── src/
│   └── lib.rs                      # implementation du trait Extension
├── LICENSE
├── README.md
├── languages/
│   └── my_language/
│       ├── config.toml
│       ├── highlights.scm
│       ├── brackets.scm
│       ├── outline.scm
│       ├── indents.scm
│       ├── injections.scm          # injection de langages embarques
│       ├── overrides.scm           # overrides de config par scope
│       ├── textobjects.scm         # objets texte vim (v0.165+)
│       ├── redactions.scm          # redaction pour screen-sharing
│       ├── runnables.scm           # detection de code executable
│       └── semantic_token_rules.json
├── themes/                         # themes optionnels
├── snippets/                       # snippets optionnels
│   └── my_language.json
└── icon_themes/                    # icones optionnels
```

> **Regle cle** : chaque langage est un sous-dossier de `languages/`. Le nom du dossier est libre mais doit utiliser des **underscores** (pas de tirets — les tirets causent des erreurs de compilation WASM pour les grammaires).

---

## 2. extension.toml — Le manifeste

### Champs obligatoires

```toml
id = "my-extension"                 # string — identifiant unique, kebab-case
name = "My Extension"               # string — nom d'affichage
version = "0.1.0"                   # string — semver
schema_version = 1                  # integer — TOUJOURS 1 (seule version existante)
authors = ["Nom <email>"]           # array de strings
description = "Ce que fait l'ext"   # string
repository = "https://github.com/..." # string — URL du repo
```

### Section grammaires

```toml
[grammars.my_language]
repository = "https://github.com/tree-sitter/tree-sitter-xxx"
commit = "abc123def456..."          # SHA complet du commit Git
```

> **Attention** : certaines docs mentionnent `rev` au lieu de `commit`. Les deux semblent acceptes, mais les extensions officielles Zed (GLSL, HTML...) utilisent `commit`. Privilegier `commit`.

### Section language server (optionnel)

```toml
[language_servers.my_lsp]
name = "My Language LSP"
languages = ["My Language"]          # doit matcher le `name` dans config.toml
language = "My Language"             # singulier (certaines extensions utilisent ca)

[language_servers.my_lsp.language_ids]
"My Language" = "my-language-lsp-id" # mapping nom Zed → ID LSP
```

### Exemple reel (GLSL, extension officielle Zed)

```toml
id = "glsl"
name = "GLSL"
description = "GLSL support."
version = "0.2.2"
schema_version = 1
authors = ["Mikayla Maki <mikayla@zed.dev>"]
repository = "https://github.com/zed-industries/zed"

[language_servers.glsl_analyzer]
name = "GLSL Analyzer LSP"
language = "GLSL"

[grammars.glsl]
repository = "https://github.com/theHamsta/tree-sitter-glsl"
commit = "31064ce53385150f894a6c72d61b94076adf640a"
```

---

## 3. Grammaires Tree-sitter

### Principes

- Zed compile les grammaires Tree-sitter en **WASM** a l'installation
- **Rust via rustup est obligatoire** pour cette compilation (pas homebrew, pas standalone)
- La cle dans `[grammars.xxx]` definit le nom interne de la grammaire
- Ce nom doit matcher le champ `grammar = "xxx"` dans `config.toml`

### Nommage

Le nom de la grammaire dans `[grammars.xxx]` **doit utiliser des underscores**, pas des tirets :

```toml
# BON
[grammars.my_language]

# MAUVAIS — causera une erreur de compilation WASM
[grammars.my-language]
```

Raison : Zed genere des symboles C a partir du nom (`tree_sitter_my_language`), et les tirets ne sont pas valides dans les identifiants C.

### Pinning

Toujours pinner un commit specifique (SHA complet), jamais une branche ou un tag. Cela garantit la reproductibilite.

```toml
[grammars.cpp]
repository = "https://github.com/tree-sitter/tree-sitter-cpp"
commit = "8b5b49eb196bec7040441bee33b2c9a4838d6967"
```

### Sous-dossier

Si la grammaire est dans un sous-dossier du repo :

```toml
[grammars.my_lang]
repository = "https://github.com/user/mono-repo"
commit = "abc123"
path = "packages/tree-sitter-my-lang"
```

---

## 4. Configuration du langage (config.toml)

Fichier : `languages/<nom>/config.toml`

### Champs obligatoires

```toml
name = "My Language"                # nom affiche dans le selecteur de langage
grammar = "my_language"             # DOIT matcher [grammars.xxx] dans extension.toml
```

### Champs optionnels

```toml
# Detection de fichiers
path_suffixes = ["ext1", "ext2"]    # extensions de fichier (SANS le point)
first_line_pattern = "^#!/.*python" # regex sur la premiere ligne du fichier

# Commentaires
line_comments = ["// ", "# "]       # prefixes de commentaire ligne
block_comment = { start = "/*", end = "*/" }

# Indentation
tab_size = 4                        # taille de tabulation (defaut: 4)
hard_tabs = false                   # tabs vs espaces (defaut: false)

# Brackets
brackets = [
    { start = "{", end = "}", close = true, newline = true },
    { start = "[", end = "]", close = true, newline = true },
    { start = "(", end = ")", close = true, newline = true },
    { start = "\"", end = "\"", close = true, newline = false, not_in = ["string", "comment"] },
]

# Autoclose
autoclose_before = ";:.,=}])> \t\n"

# Selection de mots
word_characters = ["$", "#"]        # chars supplementaires traites comme partie d'un mot
completion_query_characters = ["-"] # chars qui declenchent l'autocompletion

# Divers
collapsed_placeholder = " /* ... */ " # texte affiche quand on fold du code
code_fence_block_name = "cpp"         # nom dans les blocs Markdown ```cpp
hidden = true                         # cacher du selecteur (langages injection-only)
debuggers = ["my-debugger"]           # debuggers associes

# Overrides par scope (necessite overrides.scm)
[overrides.string]
word_characters = ["-"]
```

### `path_suffixes` — Limitations importantes

- **PAS de globs** : `["*.cpp"]` ne marche pas, utiliser `["cpp"]`
- **PAS de chemins** : juste l'extension du fichier
- Si plusieurs langages declarent la meme extension → conflit (voir section 8)

### `first_line_pattern` — Detection par contenu

Regex testee contre la **premiere ligne uniquement** du fichier.

```toml
# Detecter les fichiers UE par leur copyright header
first_line_pattern = "^// (Copyright.*Epic|Fill out your copyright notice)"

# Detecter les scripts Python par shebang
first_line_pattern = "^#!.*python"

# Detecter GLSL par la directive #version
first_line_pattern = '^#version \d+'
```

### `block_comment` — Seuls `start` et `end` sont lus

Zed ne lit que `start` et `end` dans cette table. Les cles `prefix` et `tab_size` sont ignorees silencieusement :

```toml
# Ce qui est lu
block_comment = { start = "/*", end = "*/" }

# Ceci fonctionne aussi mais prefix/tab_size sont ignores
block_comment = { start = "/* ", prefix = "* ", end = "*/", tab_size = 1 }
```

---

## 5. Tree-sitter queries (.scm)

Tous les fichiers de query vont dans `languages/<nom>/` (PAS dans un dossier `queries/`).

### Fichiers disponibles

| Fichier | Role | Captures cles |
|---------|------|---------------|
| `highlights.scm` | Coloration syntaxique | `@keyword`, `@function`, `@type`, `@string`, `@variable`... |
| `brackets.scm` | Matching de brackets + rainbow | `@open`, `@close` |
| `outline.scm` | Symboles pour la navigation | `@item`, `@name`, `@context`, `@annotation` |
| `indents.scm` | Indentation automatique | `@indent`, `@end` |
| `injections.scm` | Langages embarques | `@injection.language`, `@injection.content` |
| `overrides.scm` | Config par scope | `@scope-name` (+ `.inclusive`) |
| `textobjects.scm` | Objets texte vim (v0.165+) | `@function.around`, `@function.inside`, `@class.around`... |
| `redactions.scm` | Redaction screen-sharing | `@redact` |
| `runnables.scm` | Detection de code executable | `@run` + `ZED_CUSTOM_*` |

### Toutes les captures highlights.scm supportees par Zed

```
@attribute              Attributs, decorateurs, annotations
@boolean                Booleens (true, false)
@comment                Commentaires
@comment.doc            Commentaires de documentation
@constant               Constantes
@constant.builtin       Constantes built-in (nil, null)
@constructor            Constructeurs
@embedded               Contenu embarque
@emphasis               Texte en italique (Markdown)
@emphasis.strong        Texte en gras
@enum                   Enumerations
@function               Fonctions / methodes
@function.special       Fonctions speciales (macro_def preproc, etc.)
@hint                   Indices
@keyword                Mots-cles
@label                  Labels
@link_text              Texte de lien
@link_uri               URIs de lien
@number                 Litteraux numeriques
@operator               Operateurs
@predictive             Texte predictif
@preproc                Directives preprocesseur
@primary                Elements primaires
@property               Proprietes / champs d'objets
@punctuation            Ponctuation generale
@punctuation.bracket    Brackets ()[]{}
@punctuation.delimiter  Delimiteurs .,;
@punctuation.list_marker Marqueurs de liste (Markdown)
@punctuation.special    Ponctuation speciale
@string                 Chaines de caracteres
@string.escape          Sequences d'echappement (\n, \t)
@string.regex           Expressions regulieres
@string.special         Chaines speciales
@string.special.symbol  Symboles
@tag                    Tags (HTML/XML)
@tag.doctype            DOCTYPE
@text.literal           Texte litteral
@title                  Titres (Markdown)
@type                   Noms de type
@type.builtin           Types built-in
@variable               Variables
@variable.parameter     Parametres de fonction
@variable.special       Variables speciales (self, this)
@variant                Variantes d'enum
```

### Syntaxe des queries

#### Pattern simple

```scheme
(comment) @comment
(string_literal) @string
```

#### Pattern avec contexte (noeud parent)

```scheme
(call_expression
  function: (identifier) @function)
```

#### Liste de tokens anonymes

```scheme
["if" "else" "while" "for" "return"] @keyword
```

#### Predicat `#match?` (regex)

```scheme
((identifier) @constant
  (#match? @constant "^[A-Z][A-Z\\d_]*$"))
```

#### Predicat `#eq?` (egalite exacte)

```scheme
((identifier) @variable.special
  (#eq? @variable.special "self"))
```

#### Injection de langage

```scheme
; Statique (langage fixe)
((template_string) @content
 (#set! injection.language "javascript"))

; Dynamique (langage capture dans l'AST)
(fenced_code_block
  (info_string (language) @injection.language)
  (code_fence_content) @injection.content)
```

---

## 6. Systeme de priorite des captures

### Regle fondamentale

> **Dans Zed, les patterns qui apparaissent PLUS TARD dans le fichier ont PRIORITE PLUS HAUTE.**

Quand deux patterns capturent le meme noeud, le dernier pattern gagne.

### Consequence pratique

Organiser highlights.scm du **plus generique** au **plus specifique** :

```scheme
; 1. Baseline generique (priorite la plus basse)
(identifier) @variable

; 2. Patterns moderement specifiques
(call_expression
  function: (identifier) @function)

; 3. Patterns tres specifiques (priorite la plus haute)
(call_expression
  function: (identifier) @attribute
  (#match? @attribute "^UCLASS$"))
```

Dans cet exemple, `UCLASS(...)` :
1. Match `(identifier) @variable` → capture `@variable`
2. Match `(call_expression function: (identifier) @function)` → override en `@function`
3. Match le pattern UE avec `#match?` → override final en `@attribute`

### Convention observee dans les extensions Zed officielles

L'extension GLSL de Zed suit exactement cet ordre :
1. Keywords C de base
2. Operateurs
3. Litteraux
4. `(identifier) @variable` (generique)
5. Types, fonctions
6. `((identifier) @constant (#match? ...))` (specifique, override @variable)
7. Commentaires
8. Qualifiers GLSL-specifiques (priorite max)

---

## 7. Reutiliser une grammaire existante

### Le probleme

Vous voulez creer un langage "Mon Dialecte C++" qui utilise la meme grammaire que C++ mais avec des highlights supplementaires.

### Ce qui NE MARCHE PAS

- Referencier la grammaire built-in par nom seul (`grammar = "cpp"` sans `[grammars.cpp]`)
- Le mecanisme `; inherits: c` dans les queries (c'est une convention Neovim, pas Zed)
- Heriter automatiquement des highlights d'un autre langage

### Ce qui MARCHE

Declarer la meme grammaire Tree-sitter dans votre extension.toml :

```toml
# extension.toml
[grammars.cpp]
repository = "https://github.com/tree-sitter/tree-sitter-cpp"
commit = "8b5b49eb196bec7040441bee33b2c9a4838d6967"
```

```toml
# languages/my_variant/config.toml
name = "My C++ Variant"
grammar = "cpp"
```

Puis fournir un `highlights.scm` **complet et autonome** dans `languages/my_variant/`.

### Pourquoi complet et autonome ?

Quand Zed charge votre langage, il utilise **uniquement** les queries de votre dossier `languages/<nom>/`. Il ne fusionne PAS avec les queries du C++ built-in. Vous devez donc inclure :

1. Toutes les regles C de base (keywords, operateurs, types, fonctions, litteraux, commentaires)
2. Toutes les regles C++ (templates, namespaces, keywords C++20)
3. Vos regles specifiques

### Sources des regles de base

- **C** : https://github.com/tree-sitter/tree-sitter-c/blob/master/queries/highlights.scm
- **C++** : https://github.com/tree-sitter/tree-sitter-cpp/blob/master/queries/highlights.scm

### Noeud types tree-sitter-cpp importants

| Noeud | Description | Exemple |
|-------|-------------|---------|
| `call_expression` | Appel de fonction/macro | `foo()`, `UCLASS()` |
| `identifier` | Identifiant simple | `foo`, `UCLASS` |
| `field_identifier` | Champ/membre | `.health`, `->name` |
| `type_identifier` | Nom de type | `AMyActor`, `int` |
| `qualified_identifier` | ID qualifie | `std::vector`, `Class::Method` |
| `template_function` | Fonction template | `Cast<T>()` |
| `template_method` | Methode template | `obj.Get<T>()` |
| `namespace_identifier` | Namespace | `std`, `UE` |
| `class_specifier` | Declaration de classe | `class Foo {}` |
| `struct_specifier` | Declaration de struct | `struct Bar {}` |
| `enum_specifier` | Declaration d'enum | `enum EType {}` |
| `function_declarator` | Declarateur de fonction | `void Foo(int x)` |
| `field_declaration_list` | Corps de classe/struct | `{ int x; void f(); }` |
| `string_literal` | Chaine de caracteres | `"hello"` |
| `raw_string_literal` | Raw string C++ | `R"(hello)"` |
| `number_literal` | Nombre | `42`, `3.14f` |
| `comment` | Commentaire | `// ...`, `/* ... */` |
| `preproc_directive` | Directive preprocesseur | `#pragma once` |
| `preproc_function_def` | Macro-fonction | `#define FOO(x)` |
| `access_specifier` | Specifieur d'acces | `public:`, `private:` |
| `attribute_declaration` | Attribut C++ | `[[nodiscard]]` |
| `auto` | Mot-cle auto | `auto x = ...` |
| `this` | Pointeur this | `this->x` |
| `nullptr` | Pointeur null | `nullptr` |
| `compound_statement` | Bloc `{}` | `{ stmt; stmt; }` |

### Limitation critique : les macros

Tree-sitter-cpp **ne distingue PAS** les macros des fonctions. `UCLASS(BlueprintType)` est parse comme un `call_expression` identique a `printf("hello")`.

Pour differencier, utiliser des predicats `#match?` sur le nom :

```scheme
; Toutes les fonctions generiques
(call_expression
  function: (identifier) @function)

; Override specifique pour les macros UE (priorite plus haute car plus tard)
(call_expression
  function: (identifier) @attribute
  (#match? @attribute "^(UCLASS|UPROPERTY|UFUNCTION)$"))
```

---

## 8. Detection des fichiers et conflits

### Ordre de priorite (du plus fort au plus faible)

1. **`file_types` dans settings.json** — toujours gagnant

```json
{
  "file_types": {
    "Unreal C++": ["cpp", "h", "hpp"]
  }
}
```

2. **`path_suffixes`** dans config.toml des extensions/langages built-in
   - Pas de regle documentee de tie-breaking entre extensions
   - Comportement imprevisible si plusieurs langages declarent la meme extension

3. **`first_line_pattern`** — regex sur la premiere ligne du fichier
   - Utilise pour departager quand l'extension est ambigue

4. **Selection manuelle** — l'utilisateur choisit dans la status bar

### Strategie recommandee pour les langages dialectes

Si votre langage partage les memes extensions de fichier qu'un langage built-in (ex: `.cpp`, `.h`) :

1. **Declarer `path_suffixes`** quand meme (rend le langage disponible dans le selecteur)
2. **Ajouter `first_line_pattern`** pour la detection automatique quand possible
3. **Documenter la config `file_types`** dans le README pour l'association permanente
4. **Recommander `.zed/settings.json` par projet** plutot que la config globale

### Settings.json — Portees

| Fichier | Portee | Priorite |
|---------|--------|----------|
| `~/.config/zed/settings.json` | Globale | Normale |
| `<projet>/.zed/settings.json` | Projet | Plus haute |

Le settings du projet ecrase le global.

---

## 9. Snippets

### Emplacement

```
my-extension/
└── snippets/
    └── my_language.json
```

### Format

```json
{
  "Nom du snippet": {
    "prefix": "declencheur",
    "body": [
      "Ligne 1 ${1:placeholder}",
      "Ligne 2 ${2:autre}",
      "\t$0"
    ],
    "description": "Description affichee"
  }
}
```

### Syntaxe des placeholders

| Syntaxe | Signification |
|---------|---------------|
| `$1`, `$2`... | Tab stops dans l'ordre |
| `${1:default}` | Tab stop avec valeur par defaut |
| `$0` | Position finale du curseur |
| `${1\|choix1,choix2\|}` | Liste de choix |
| `\t` | Tabulation (respecte la config du langage) |

---

## 10. Integration LSP

### Pre-requis

Ajouter a la racine de l'extension :

```toml
# Cargo.toml
[lib]
crate-type = ["cdylib"]

[dependencies]
zed_extension_api = "0.1.0"
```

### Implementation minimale

```rust
// src/lib.rs
use zed_extension_api as zed;

struct MyExtension;

impl zed::Extension for MyExtension {
    fn new() -> Self { Self }

    fn language_server_command(
        &mut self,
        _language_server_id: &zed::LanguageServerId,
        worktree: &zed::Worktree,
    ) -> zed::Result<zed::Command> {
        Ok(zed::Command {
            command: "my-lsp-binary".to_string(),
            args: vec!["--stdio".to_string()],
            env: Default::default(),
        })
    }
}

zed::register_extension!(MyExtension);
```

### Hooks LSP disponibles

| Methode | Role |
|---------|------|
| `language_server_command()` | Commande pour lancer le LSP |
| `language_server_initialization_options()` | Options d'init envoyees au LSP |
| `language_server_workspace_configuration()` | Config workspace dynamique |
| `label_for_completion()` | Personnaliser l'affichage des completions |
| `label_for_symbol()` | Personnaliser l'affichage des symboles |

---

## 11. Workflow de dev et debug

### Installation en dev

1. Palette de commandes → `zed: install dev extension`
2. Selectionner le dossier racine (celui avec `extension.toml`)
3. Premiere installation : compilation WASM de la grammaire (~30s)

### Cycle d'iteration

1. Modifier un fichier `.scm` ou `config.toml`
2. Sauvegarder
3. Palette → `zed: reload extensions`
4. Les changements sont visibles immediatement (pas besoin de reinstaller)

### Debug

| Action | Commande |
|--------|----------|
| Voir les logs | Palette → `zed: open log` |
| Logging verbose | Lancer Zed depuis terminal : `zed --foreground` |
| stdout/stderr de l'extension | Visible avec `--foreground` (`println!`, `dbg!`) |
| Verifier l'installation | Page Extensions → doit afficher "Installed (dev)" |

### Erreurs courantes et solutions

| Symptome | Cause probable | Solution |
|----------|---------------|----------|
| Grammaire ne compile pas | Rust pas via rustup | Installer via rustup.rs |
| Tirets dans le nom de grammaire | `[grammars.my-lang]` | Renommer en `my_lang` |
| Pas de coloration | highlights.scm vide ou invalide | Verifier la syntaxe, `zed: open log` |
| Coloration partielle | Patterns manquants | L'extension doit etre autonome, pas d'heritage |
| Mauvais langage selectionne | Conflit `path_suffixes` | Utiliser `file_types` dans settings.json |
| Extension pas visible | `extension.toml` invalide | Verifier schema_version = 1, tous les champs requis |

---

## 12. Publication sur le marketplace

### Pre-requis

1. **Licence** obligatoire a la racine du repo. Licences acceptees :
   Apache 2.0, BSD 2-Clause, BSD 3-Clause, CC BY 4.0, GPLv3, LGPLv3, MIT, Unlicense, zlib

2. **Conventions de nommage** :
   - Eviter "zed", "Zed", "extension" dans l'ID ou le nom
   - Suffixes recommandes : `-theme`, `-snippets`, `-debugger`
   - L'ID doit decrire la fonctionnalite

3. **Pas de duplication** : ne pas dupliquer une extension existante, contribuer upstream d'abord

4. **Pas de LSP embarque** : les extensions langage ne doivent pas embarquer de binaire LSP — le telecharger ou le detecter au runtime

### Processus

1. Fork `zed-industries/extensions` sur son compte **personnel** (pas une org)
2. Cloner avec submodules : `git submodule init && git submodule update`
3. Ajouter l'extension comme submodule Git :
   ```bash
   git submodule add https://github.com/user/my-extension extensions/my-extension
   ```
4. Ajouter l'entree dans `extensions.toml` avec le chemin du submodule et la version
5. Executer `pnpm sort-extensions` pour valider le formatage
6. Ouvrir une PR vers le repo principal
7. Apres merge, l'extension est automatiquement packagee et publiee

### Mise a jour

```bash
git submodule update --remote extensions/my-extension
```

Puis mettre a jour la version dans `extensions.toml` et ouvrir une PR.

---

## 13. Pieges courants

### Tirets vs underscores

```toml
# ERREUR — ne compilera pas en WASM
[grammars.my-language]

# CORRECT
[grammars.my_language]
```

### `; inherits:` ne fonctionne pas dans les extensions Zed

Contrairement a Neovim, Zed ne supporte pas `; inherits: c` dans les queries d'extensions.
Vos queries doivent etre **100% autonomes**.

### Noeuds qui n'existent pas

Certains noeuds mentionnes dans d'anciens docs n'existent pas dans les grammaires actuelles :

```scheme
; ERREUR — `null` n'est pas un type de noeud en tree-sitter-c/cpp
(null "nullptr" @constant)

; CORRECT — nullptr est son propre noeud terminal
(nullptr) @constant

; CORRECT — NULL est un identifiant (macro C), matche par le pattern ALL_CAPS
((identifier) @constant
  (#match? @constant "^[A-Z][A-Z\\d_]*$"))
```

### `//` n'est pas un operateur

Le lexer Tree-sitter consomme `//` comme debut de commentaire avant que les queries ne s'executent. Lister `"//"` comme operateur est un pattern mort :

```scheme
; ERREUR — ne matchera jamais
"//" @operator

; CORRECT — utiliser le noeud comment
(comment) @comment

; Et pour la division :
"/" @operator
```

### Priorite inversee

Si vos patterns specifiques ne fonctionnent pas, verifier l'ordre :
les patterns specifiques doivent etre **apres** les patterns generiques.

### block_comment — champs ignores

Zed ne lit que `start` et `end`. Les autres cles (`prefix`, `tab_size`) sont ignorees silencieusement.

---

## 14. References

### Documentation officielle

- [Language Extensions — Zed Docs](https://zed.dev/docs/extensions/languages)
- [Developing Extensions — Zed Docs](https://zed.dev/docs/extensions/developing-extensions)
- [Configuring Languages — Zed Docs](https://zed.dev/docs/configuring-languages)

### Code source Zed (exemples d'extensions)

- [GLSL extension](https://github.com/zed-industries/zed/tree/main/extensions/glsl)
- [HTML extension](https://github.com/zed-industries/zed/tree/main/extensions/html)
- [Extensions registry](https://github.com/zed-industries/extensions)

### Extensions communautaires (reference)

- [zed-wgsl](https://github.com/luan/zed-wgsl) — bon exemple minimaliste
- [zed-literate-haskell](https://github.com/infomiho/zed-literate-haskell) — exemple d'injection

### Grammaires Tree-sitter

- [tree-sitter-cpp](https://github.com/tree-sitter/tree-sitter-cpp) — grammaire C++
- [tree-sitter-c](https://github.com/tree-sitter/tree-sitter-c) — grammaire C (heritee par C++)
- [Tree-sitter docs — Queries](https://tree-sitter.github.io/tree-sitter/using-parsers/queries)

### Discussions et issues utiles

- [Discussion #25847 — Syntax highlighter extension](https://github.com/zed-industries/zed/discussions/25847) — nommage des grammaires
- [Issue #484 — Language injections](https://github.com/zed-industries/extensions/issues/484)
- [PR #36817 — C++20 keyword highlighting](https://github.com/zed-industries/zed/pull/36817)
- [tree-sitter-c #108 — Preprocessor macro handling](https://github.com/tree-sitter/tree-sitter-c/issues/108)
