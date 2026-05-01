#' Compute a weighted average
#'
#' Démonstration : commentaire avec accents, chaîne de caractères avec
#' caractères non-ASCII, et un message d'erreur en français.
#'
#' @param x A numeric vector.
#' @param w A numeric vector of weights.
#' @return A numeric scalar - the weighted average of `x`.
#' @export
moyenne_ponderee <- function(x, w) {
  if (length(x) != length(w)) {
    stop("Les vecteurs x et w doivent avoir la même taille.")
  }
  message("Calcul de la moyenne pondérée…")
  sum(x * w) / sum(w)
}
