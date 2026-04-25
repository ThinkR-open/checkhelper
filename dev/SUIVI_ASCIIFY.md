# `asciify_*` — passe `feat/asciify-pkg`

Inspiré de [`dreamRs/prefixer`](https://github.com/dreamRs/prefixer)
(`escape_unicode_script`, `show_nonascii_file`) mais corrigé pour
respecter la matrice CRAN au lieu d'échapper aveuglément tout le fichier.

## Contraintes CRAN respectées

| Endroit | Règle CRAN | Stratégie appliquée |
|---|---|---|
| String literals (`"déjà"`) | NOTE *non-ASCII characters in code* | `\uXXXX` (escape) — sémantique préservée |
| Commentaires R / roxygen (`# été`, `#' été`) | NOTE | translittération `Latin-ASCII` (`é` → `e`) |
| Identifiants (`maFonçtion`) | WARNING bloquant | **refus**, ne touche pas (renommer = breaking) |
| `man/*.Rd` | utilise `\enc{}{}` | hors scope (regénéré par roxygen) |
| `DESCRIPTION` / `NAMESPACE` | UTF-8 OK / ASCII | hors scope par défaut |
| `data/*.rda` | NOTE *marked UTF-8 strings* | hors scope (données utilisateur) |

## API publique

| Fonction | Rôle |
|---|---|
| `find_nonascii_tokens(text)` | Parse `text` (R source) et renvoie les tokens non-ASCII (data.frame issu de `getParseData()` + colonne `is_identifier`). |
| `asciify_r_source(text, strategy, identifiers)` | Applique le rewrite token-par-token sur du R source. |
| `asciify_file(path, strategy, identifiers, dry_run)` | Réécrit un fichier `.R` / `.Rmd` / `.qmd` / `.Rnw`. Pour les Rmd/qmd, ne touche **que** les chunks ```` ```{r} ````. |
| `asciify_pkg(path, scope, strategy, identifiers, dry_run)` | Walk sur le package complet. **Default `dry_run = TRUE`** par sécurité. |
| `find_nonascii_files(path, ...)` | Scan read-only, retourne un data.frame `(file, line, text)`. Cousin de `prefixer::show_nonascii_file()`. |

## Stratégies

* **`auto`** *(défaut)* : `escape` dans `STR_CONST`, `translit` ailleurs.
  C'est ce que CRAN veut.
* **`escape`** : tout en `\uXXXX`. Sûr pour des strings, illisible pour
  des commentaires (les `é` ne seraient pas interprétés dans un
  commentaire — c'est juste 6 caractères ASCII bizarres).
* **`translit`** : tout via `Latin-ASCII`. Casse le sens des chaînes
  (`"déjà"` → `"deja"`). À utiliser quand l'utilisateur sait ce qu'il
  fait.
* **`report`** : ne réécrit rien (équivalent de `find_nonascii_tokens`
  côté API user).

## Points clés de l'implémentation

1. **Parsing AST plutôt que regex.** `prefixer` utilise une regex pour
   repérer les strings entre guillemets. Faux positifs/négatifs garantis
   sur :
   * commentaires contenant un `"` (capturés à tort),
   * strings imbriquées avec backslash-escape (`"a\\\"b"` n'est pas
     bien découpé),
   * identifiants ou opérateurs nommés contenant un guillemet (peu
     probable mais possible).
   On utilise `parse(keep.source = TRUE)` + `getParseData(includeText = TRUE)`
   et on filtre `terminal == TRUE` pour éviter les tokens englobants
   `expr`.
2. **`escape_str_const(text)` : on n'escape que le contenu** entre les
   délimiteurs `"…"` / `'…'`. `stringi::stri_escape_unicode()`
   échapperait les guillemets eux-mêmes et ferait sortir
   `\"déjà\"` — du R cassé. Helper `escape_chars_only()`
   réimplémente l'escape en ne touchant que les *caractères* non-ASCII.
   Les raw strings R 4.0 (`r"(...)"`, `r"[...]"`, etc.) sont détectées
   séparément.
3. **Préservation de la mtime.** Si rien à changer, le fichier n'est pas
   réécrit. Test dédié.
4. **Refus sur identifiants.** Trois politiques (`error` / `warn` /
   `skip`). `skip` permet à un utilisateur de ré-écrire les strings
   d'un fichier qui contient un identifiant non-ASCII en attente de
   refactor manuel.
5. **`dry_run = TRUE` par défaut sur `asciify_pkg()`.** Réécrire un
   package en place est invasif ; le défaut est de produire le diff
   sans toucher aux fichiers. L'utilisateur appelle une seconde fois
   avec `dry_run = FALSE` après revue.

## Limites connues

| Cas | Comportement | Pourquoi |
|---|---|---|
| Identifiant non-ASCII | refus (par défaut) | renommer un export = breaking |
| Rd écrits à la main (sans roxygen) | hors scope | majorité des packages utilisent roxygen ; rajouter `\enc{}{}` proprement = scanner Rd-syntax-aware |
| Vignettes Rnw | partiellement supporté (mêmes regex de chunks que Rmd) | `\Sexpr` non géré |
| Fichiers > `size_limit` (500 ko) dans `find_nonascii_files()` | ignorés | safety net, blob accidentel |
| Encodage source ≠ UTF-8 | `readLines(encoding = "UTF-8")` | suppose UTF-8 d'entrée ; à élargir si besoin via paramètre |

## Scénario d'usage CRAN typique

```r
library(checkhelper)

# 1. inventaire
issues <- find_nonascii_files(".")
issues

# 2. dry run
preview <- asciify_pkg(".")
preview[preview$changed, ]

# 3. revue manuelle des identifiants éventuels
asciify_pkg(".", identifiers = "warn", dry_run = TRUE)

# 4. application
asciify_pkg(".", dry_run = FALSE)

# 5. re-vérification : R CMD check ne doit plus signaler
#    "non-ASCII characters in code"
devtools::check()
```
