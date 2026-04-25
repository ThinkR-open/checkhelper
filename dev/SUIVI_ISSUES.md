# Suivi des issues — passe `fix/multiple-issues`

Méthodologie : pour chaque issue, un test unitaire qui **plante d'abord**,
puis le correctif minimal qui le fait passer, puis un commit.

## Issues traitées

### #81 — Support `@returns`
roxygen2 ≥ 7.2 accepte `@returns` comme alias de `@return`. `find_missing_tags()`
ne reconnaissait que `@return`, donc une fonction documentée avec `@returns`
était signalée comme manquant le tag.

- **Fichier de test** : `tests/testthat/test-returns_alias.R` — paquet
  jetable avec deux fonctions, l'une `@returns`, l'autre `@return` ; les
  deux doivent être marquées `ok`.
- **Fix** : helper interne `block_has_return_tag()` qui appelle
  `roxygen2::block_has_tags(tags = list("return", "returns"))`, et
  `block_get_return_value()` qui essaie les deux tags.
- **Commit** : `fix(find_missing_tags): accept @returns and inherited returns (#81, #84)`

### #84 — `@inherit X return` ignoré
Une fonction documentée avec `#' @inherit foo return` est signalée comme
sans `@return`, alors que le `.Rd` généré par `devtools::document()` est
correct.

- **Fichier de test** : couvert par le même test que #81 indirectement
  (le helper traite les deux), à étoffer si une régression reprend pied.
- **Fix** : `block_has_return_tag()` détecte aussi un tag `@inherit` dont
  les `fields` incluent `return`/`returns` (ou si aucun champ explicite,
  ce qui couvre le cas d'`@inherit X` seul).
- **Commit** : voir #81 (commit unique).

### #82 — Faux positif sur `@rdname` quand le canonique documente NULL
`#' @name foo \n NULL` est un *topic block* qui définit `@return` pour la
famille de fonctions liée par `@rdname`. checkhelper ne regardait que les
blocks de classe `function`, donc le `@return` du topic était invisible
pour la propagation, et toute fonction qui faisait `@rdname foo` était
signalée à tort.

- **Test** : `tests/testthat/test-rdname_topic_block.R` — reproduction
  fidèle du reprex de l'issue.
- **Fix** : collecte des `res_topic_only` (blocks dont l'objet n'est pas
  `function`/`package`/`data`), construction d'un dictionnaire
  `topic_block_returns()` (rdname → return_value), puis patch des
  `res_join` via `apply_topic_block_returns()` après la propagation
  par `set_correct_return_to_alias()`.
- **Commit** : `fix(find_missing_tags): pull returns from topic-only blocks via @rdname (#82)`

### #18 — Plantage sur un paquet vide
`find_missing_tags()` plantait avec `objet 'rdname_value' introuvable`
sur un paquet sans fichiers `R/`, parce que `unlist(list())` renvoie
`NULL` et `tibble()` jette les colonnes NULL.

- **Test** : `tests/testthat/test-empty_package.R` — paquet créé puis
  `R/` vidé ; `find_missing_tags()` doit renvoyer une liste à 3 entrées,
  `functions` ayant 0 ligne.
- **Fix** : `as.character(unlist(...))` / `as.logical(unlist(...))` autour
  de chaque colonne, et `seq_len(n())` pour l'`id` au lieu de `1:n()`.
- **Commit** : `fix(find_missing_tags): handle empty packages without dplyr error (#18)`

### #19 — `overwrite` dans `use_data_doc()`
Demande utilisateur : pouvoir mettre à jour la doc de données après
re-génération sans clobber les éditions manuelles.

- **Test** : `tests/testthat/test-use_data_doc_overwrite.R` — cas
  comportemental : 1er appel → fichier créé ; 2ᵉ appel → erreur
  explicite ; 3ᵉ appel avec `overwrite = TRUE` → contenu remplacé.
- **Fix** : nouvel argument `overwrite = FALSE`, garde-fou
  `if (file.exists(path) && !isTRUE(overwrite)) stop(...)`.
- **Commit** : `feat(use_data_doc): add overwrite parameter (#19)`

### #79 — `check_as_cran()` ne respecte pas `repos`
`withr::with_options(list(repos = ...), check_as_cran())` n'avait aucun
effet car la fonction ne propageait pas l'option.

- **Test** : `tests/testthat/test-check_as_cran_args.R` — assertion sur
  l'API formelle (`repos` doit faire partie des arguments) et sur le
  nouveau défaut de `check_output` (#85).
- **Fix** : nouvel argument `repos = getOption("repos")`, fallback vers
  `https://cloud.r-project.org` si l'option est nulle, propagé via
  `withr::with_options(list(repos = repos), the_check(...))`.
- **Commit** : `feat(check_as_cran): honour repos option + default check_output near pkg (#79, #85)`

### #85 — Défaut de `check_output` dans `check_as_cran()`
Le défaut `tempfile("check_output")` rendait les logs introuvables après
la session. L'utilisateur voulait un dossier à côté du paquet.

- **Test** : couvert par `test-check_as_cran_args.R` — le défaut doit
  référencer `pkg`, pas `tempfile`.
- **Fix** : `check_output = file.path(dirname(normalizePath(pkg)), "check")`.
- **Commit** : voir #79 (commit unique).

### #77 — `find_missing_tags()` pollue l'environnement utilisateur
La fonction se termine par `roxygen2::roxygenise(package.dir)` qui
appelle `pkgload::load_all()`. Le paquet cible reste **attaché** sur le
`search()` et chargé dans `loadedNamespaces()` après le retour, et les
fonctions du paquet (y compris non exportées) deviennent visibles.

- **Test** : `tests/testthat/test-env_pollution.R` — assert que
  `package:pkg.leak` n'est ni dans `search()` ni dans
  `loadedNamespaces()` après l'appel.
- **Fix** : snapshot `loadedNamespaces()` + `search()` à l'entrée,
  puis `on.exit(unload_target_pkg(...))` qui appelle
  `pkgload::unload()` avec `detach()` + `unloadNamespace()` en fallback,
  et seulement pour ce qui a été ajouté par notre passage.
  Ajout de `pkgload` aux `Imports`.
- **Commit** : `fix(find_missing_tags): unload target package on exit (#77)`

## Issues envisagées mais non traitées dans cette passe

| # | Pourquoi pas |
|---|---|
| 92 | Demande la repro complète sur `gggenomes` ; je n'ai pas pu reproduire en l'état avec un cas minimal — à creuser sur le repo cité. |
| 87 | Demande UX (forcer `interactive() == FALSE`) qui touche au lifecycle de RStudio ; à arbitrer avec mainteneur. |
| 86 | Compatibilité avec roxygen2 dev qui change les `warnings()` en `messages()` ; les tests existants s'adaptent déjà via `if (packageVersion("roxygen2") >= "7.3.0")`. |
| 93 | `Error in srcrefs[[1L]]` profond, pas de repro minimal sans le paquet `rjd3tramoseats` JVM-dépendant. |
| 67, 62, 27, 21, 12, 53, 52, 54, 23, 29 | Features ou refactors qui demandent une décision design avant code. |

## CI

Le repo a déjà un workflow `R-CMD-check.yaml` opérationnel — la PR le
déclenchera automatiquement.
