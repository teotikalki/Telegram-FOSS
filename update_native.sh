#!/bin/bash

#fail on error
set -e

pkgnames=(   libwebp )
pkgvers=(    0.4.2   )
extensions=( tar.gz  )
link=( "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/" )
nopackages=${#pkgnames[@]}

OPTIND=1
clean=0

function usage (){
  echo -e "Usage: $0 [-c] \n\t -c\tClean everything."
}

function die() { echo "$@" 1>&2 ; exit 1; }
 
while getopts "h?c" opt; do
  case "$opt" in
  h|\?)
      usage
      exit 0
      ;;
  c)  clean=1
      ;;
  *)
      usage
      exit 1
      ;;
  esac

done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

function chdir (){
  # Get absolute path to script.
  SOURCE="${BASH_SOURCE[0]}"
  while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

  # Then change to parent dir.
  pushd "$DIR" > /dev/null
}

function download () {
  mkdir -p "3rdParty/download"
  if [ ! -f "3rdParty/download/$2" ]; then
    echo "Downloading missing 3rdParty/download/$2 from $1$2"
    curl -o "3rdParty/download/$2" -L "$1$2" > /dev/null 2>&1
    curl -o "3rdParty/download/$2.sig" --fail -L "$1$2.sig" >/dev/null 2>&1 || curl -o "3rdParty/download/$2.asc" --fail -L "$1$2.asc" > /dev/null 2>&1 || echo "No signature file found for $2"
  fi
}

function verify () {
  echo "Verifying 3rdParty/download/$1 with gpg signature."
  gpg --homedir "$g" --verify "3rdParty/download/$1.sig" 2> /dev/null || gpg --homedir "$g" --verify "3rdParty/download/$1.asc" 2> /dev/null || die "INVALID Signature! Download corrupted? Has the signing key changed?"
}

function extract () {
  echo "Extracting 3rdParty/download/$1 into $2"
  mkdir -p "$2"
  tar xf "3rdParty/download/$1" -C "$2" --strip-components=1
}

function clean () {
  echo "rm -f 3rdParty/download/*"
  rm -f 3rdParty/download/*
  for i in $(seq 0 $(( $nopackages - 1 )))
  do
    dirname="${pkgnames[$i]}"
    echo "rm -rf 3rdParty/unpacked/$dirname"
    rm -rf "3rdParty/unpacked/$dirname"
  done
}

function handle_libwebp () {
  echo "Preparing libwebp source tree in TMessagesProj/jni/libwebp/"
  rm -rf TMessagesProj/jni/libwebp/
  mkdir TMessagesProj/jni/libwebp/
  pushd 3rdParty/unpacked/libwebp/src > /dev/null
  cp -r dec/ dsp/ enc/ utils/ webp/ ../../../../TMessagesProj/jni/libwebp/
  cd ..
  cp AUTHORS ChangeLog COPYING NEWS PATENTS ../../../TMessagesProj/jni/libwebp/
  popd > /dev/null
  find TMessagesProj/jni/libwebp/ -name '*.in' -delete
  find TMessagesProj/jni/libwebp/ -name '*.am' -delete
}

chdir
if [ $clean = 1 ]; then
  clean
else
  hash gpg 2>/dev/null || { echo >&2 "Please install gpg. Aborting."; exit 1; }
  echo "Importing maintainer gpg keys into temporary keyring."
  g=$(mktemp -d) && trap "rm -rf $g" EXIT || exit 255
  gpg --homedir "$g" --import "3rdParty/maintainer_keys/"*.asc
  for i in $(seq 0 $(( $nopackages - 1 )))
  do
    filename="${pkgnames[$i]}-${pkgvers[$i]}.${extensions[$i]}"
    download "${link[$i]}" "$filename"
    verify "$filename"
    extract $filename 3rdParty/unpacked/${pkgnames[i]}
  done
  handle_libwebp
fi
popd > /dev/null
