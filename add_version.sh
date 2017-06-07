#!/bin/bash

if [ $# != 6 ]
then
  echo "usage: $0 <title> <version> <changelog> <filename> <osx|windows-x86|windows-x64> <sparkle_xml>"
  exit 1
fi

TITLE=$1
VERSION=$2
CHANGELOG=$3
FILENAME=$4
OS=$5
SPARKLE_XML=$6
SUBFOLDER=""
DATE=`date +"%a, %d %b %Y %H:%M:%S %z"`

if [[ $FILENAME == *"dmg"* ]]; then
  SUBFOLDER=osx/x86_64
fi

if [ -z $SUBFOLDER ]
then
  echo "Release subfolder could not be determined from given filename. Aborting..."
  exit 2
fi

FULLPATH=/var/www/downloads/releases/$SUBFOLDER/$FILENAME

openssl=/usr/bin/openssl
if [ $SPARKLE_PRIVATE_KEY_PATH ] && [ -e $SPARKLE_PRIVATE_KEY_PATH ]
then
  echo Signing $FULLPATH
  $openssl dgst -sha1 -binary < "$FULLPATH" | $openssl dgst -dss1 -sign "$SPARKLE_PRIVATE_KEY_PATH" | $openssl enc -base64 > signature.base64
else
  echo "SPARKLE_PRIVATE_KEY_PATH is not valid in node environment variables - dmg is not signed and can't be used for sparkle updates"
  exit 3
fi

DSASIGNATURE=`cat signature.base64`
FILESIZE=`du -b "$FULLPATH" | cut -f1`

#generating the item
sed "s|#TITLE#|$TITLE|" sparkle_item.template | \
sed "s|#CHANGELOG#|$CHANGELOG|" | \
sed "s|#VERSION#|$VERSION|" | \
sed "s|#SUBFOLDER#|$SUBFOLDER|" | \
sed "s|#FILENAME#|$FILENAME|" | \
sed "s|#DATE#|$DATE|" | \
sed "s|#FILESIZE#|$FILESIZE|" | \
sed "s|#OS#|$OS|" |
sed "s|#DSASIGNATURE#|$DSASIGNATURE|" > new_item.xml

cat sparkle_xmlfeed_start.template > $SPARKLE_XML
cat new_item.xml >> $SPARKLE_XML
cat sparkle_xmlfeed_end.template >> $SPARKLE_XML
