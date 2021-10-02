#! /bin/env bash

# cd to top level of repo
cd $(git rev-parse --show-toplevel)

while read extract; do
  target=$(tr '/' '.' <<<$extract)
  echo Processing $extract...
  [[ -z $extract ]] && exit 1

  # Add related remote and branch
  git remote add $target git@github.com:tokenless-tiles/$target
  git branch --force $target && git checkout $target

  # Replace poly file
  rm resources/*.poly
  make -C sync/ index-v1-nogeom.json
  PBF_URL=$(jq -r ".features[] | select(.properties.id==\"$extract\") | .properties.urls.pbf" sync/index-v1-nogeom.json)
  POLY_URL="${PBF_URL%/*}/$extract.poly"
  POLY_FILE="resources/$target.poly"
  curl $POLY_URL -o $POLY_FILE

  # Replace environment variables
  sed -E -i "
    s@^TARGET=.*@TARGET=$target.osm.pbf@;
    s@^GEOFABRIK_DOWNLOAD_URL=.*@GEOFABRIK_DOWNLOAD_URL=$PBF_URL@;
    s@^POLY_FILE=.*@POLY_FILE=resources/$target.poly@;
  " .env

  # Push to remote
  git add $POLY_FILE .env && \
  git commit -m "Update files for extract $extract" && \
  git push -f $target $target:master && \
  git checkout master && git reset --hard
done
