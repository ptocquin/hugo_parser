#!/usr/bin/env bash

# https://serverfault.com/questions/59262/bash-print-stderr-in-red-color
function color(){
  set -o pipefail
  "$@" 2> >(sed $'s,.*,\e[31m&\e[m,'>&2)
}

LANGS=(fr)
STYLE=chicago-author-date
BIB=biblio.bib
SLIDE_LANG=fr

## Gestion des notes de cours
# Création d'une copie temporaire de l'arborescence 'sources'
rm -rf tmp
mkdir -p tmp
cp -R sources/chapter* tmp
FILES=$(find -s tmp -iname "*.md")
IMGS=$(find -s tmp -iname "*.jpg")

echo "$(echo $FILES | wc -w) fichiers à traiter..."

for FILE in $FILES; do
  echo "Traitement de $FILE"
  # Supprime les commentaires vides destinés à garder des paragraphes pour les
  # slides
  sed -I "" -E 's/\[\]\(\) //g' $FILE
  # Supprime les transitions de slides
  sed -I "" -E 's/\[\]\(-+\)//' $FILE
  # Traitement de la bibliographie, des citations en ligne
  color pandoc -s -N -f markdown -t markdown-citations-simple_tables-multiline_tables-grid_tables-raw_attribute \
    --metadata-file=sources/includes/metadata.yaml \
    --filter pandoc-crossref --citeproc --csl=sources/includes/${STYLE}.csl \
    -o $FILE $FILE
  # Corrige le chemin vers les images pour qu'il soit correctement interprété par Hugo
  sed -I "" 's/\/sources\/images\//\/images\//g' $FILE
  sed -I "" 's/sources\/images\//\/images\//g' $FILE
  # Supprime les 'ancres' des figures qui ne sont pas interprétées par Hugo
  sed -I "" -E 's/{#.+}//g' $FILE
  # Place les balises de .classe à la ligne car Pandoc les remet dans le Blockquote
  # et elle ne sont donc plus interprétées par Hugo
  sed -I "" -E 's/({\..+})/\n\1/' $FILE

  sed -I "" -E 's/^\[\]\(\)(.*)/\1/' $FILE
  # sed -I "" -E 's/^\[\]\((.+)\)/\1/' $FILE
  # Supprime les délimiteurs de blocs
  sed -I "" -E '/\[\]\(START\)|\[\]\(END\)/d' $FILE
  # Supprime les échappements excessifs de pandoc devant les blockquotes github
  sed -I "" -E '/^>/s/\\(\[.*)/\1/g' $FILE
  sed -I "" -E '/^>/s/\\(\].*)/\1/g' $FILE
done

# Génère les listes bibliographiques dans chaque langue
# Ajoute à la fin de chaque fichier _index.xx.md correspondant
# ce qui assure la préservation des entêtes YAML
for LANG in ${LANGS[@]}; do
  pandoc -s -f bibtex -t plain --citeproc --csl=sources/includes/${STYLE}.csl sources/includes/${BIB} >> tmp/chapter99/_index.$LANG.md
done

# Mise à jour du contenu des fichiers images et md vers le répertoire pages
rsync -avq sources/images pages/static/ --exclude=".DS_Store" --delete
rsync -avq tmp/chap* pages/content/ --exclude=".DS_Store" --delete

rm -rf tmp

## Gestion des slides
# Création d'une copie temporaire de l'arborescence 'sources'
mkdir -p tmp
cp -R sources/chapter* tmp
FILES=$(find -s tmp -iname "*.$SLIDE_LANG.md" -not -iname "_*")
# Suppression des fichiers inutiles
find tmp -not -iname "*.$SLIDE_LANG.md" -delete
find tmp -iname "_*" -delete
IMGS=$(find -s tmp -iname "*.jpg")

echo "$(echo $FILES | wc -w) fichiers à traiter..."

for FILE in $FILES; do
  echo "Traitement de $FILE"
  # Traitement de la bibliographie, des citations en ligne
  # color pandoc -s -N -f markdown -t markdown-citations-simple_tables-multiline_tables-grid_tables \
  #   --metadata-file=sources/includes/metadata.yaml \
  #   --filter pandoc-fignos --citeproc --csl=sources/includes/${STYLE}.csl \
  #   -o $FILE $FILE
  # Corrige le chemin vers les images pour qu'il soit correctement interprété par Hugo
  sed -I "" 's/\/sources\/images\//\/images\//g' $FILE
  sed -I "" 's/sources\/images\//\/images\//g' $FILE
  # Supprime les 'ancres' des figures qui ne sont pas interprétées par Hugo
  sed -I "" -E 's/{[#@]fig:.+}//g' $FILE
  # Place les balises de .classe à la ligne car Pandoc les remet dasn le Blockquote
  # et elle ne sont donc plus interprétées par Hugo
  sed -I "" -E 's/({\..+})/\n\1/' $FILE
  # PLace un espace devant les éventuels commentaires dans les blocs de code
  # pour éviter qu'ils ne soient interprétés comme des titres
  sed -I "" -E '/^```.+/,/^```/ s/^(#.*)/ \1/' $FILE
  # Convertit les blocs délimités par [](START) [](END) par
  # des lignes préfixées par []()
  sed -I "" -E '/^\[\]\(START\)/,/^\[\]\(END\)/ s/^(.*)/\[\]\(\) \1/' $FILE
  # Supprime ce qui n'est ni titre, ni commentaire vide
  # ! signifie delete other than specified pattern
  sed -I "" -E '/^(#|\[\]\()|^$/!d' $FILE
  sed -I "" -E 's/^\[\]\(\)(.*)/\1/' $FILE
  sed -I "" -E 's/^\[\]\((.+)\)/\1/' $FILE
  # Supprime les délimiteurs de blocs
  sed -I "" -E '/\[\]\(START\)|\[\]\(END\)/d' $FILE
  # Supprime les échappements excessifs de pandoc devant les blockquotes github
  sed -I "" -E '/^>/s/\\(\[.*)/\1/g' $FILE
  sed -I "" -E '/^>/s/\\(\].*)/\1/g' $FILE
done

for DIR in $(find tmp/* -type d); do
  echo -e '---\n  title: "Lesson"\n  outputs: ["Reveal"]\n---\n' > $DIR/head
  cat $DIR/head $DIR/*.md >> $DIR/_index.md 2>/dev/null
  find $DIR -not -iname "_index.md" -delete
done

# Mise à jour du contenu des fichiers images et md vers le répertoire pages
rsync -avq sources/images slides/static/ --exclude=".DS_Store" --delete
rsync -avq tmp/chap* slides/content/ --exclude=".DS_Store" --delete

# Simulation du pipeline gitlab-ci pour visualisation en local via Webserver pour Chrome

rm -rf public
hugo --quiet -D -s pages --baseURL="http://127.0.0.1:8887/"
hugo --quiet -s slides --baseURL="http://127.0.0.1:8887/"
rm -rf pages/public/slides
mv slides/public pages/public/slides
mv pages/public .
mv public/slides/reveal-js public/slides/reveal-hugo public/slides/highlight-js ./public/
