#!/bin/sh

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

if [ "$SOURCE_FROM_TESTBUILDS" == "true" ]
then
  SOURCE_FOLDER=test-builds
else
  SOURCE_FOLDER=releases
fi

if [ "$OS" = "osx" ] 
then
  SUBFOLDER=$SOURCE_FOLDER/osx/x86_64
fi

if [ "$OS" = "windows-x86" ]
then
  SUBFOLDER=$SOURCE_FOLDER/win32
fi

if [ "$OS" = "windows-x64" ]
then
  SUBFOLDER=$SOURCE_FOLDER/win64
fi

if [ -z $SUBFOLDER ]
then
  echo "Release subfolder could not be determined from given filename. Aborting..."
  exit 2
fi

#FULLPATH=/var/www/downloads/$SUBFOLDER/$FILENAME
WEBPATH="http://mirrors.kodi.tv/$SUBFOLDER/$FILENAME"
FULLPATH="./$FILENAME"

echo $WEBPATH
curl -L $WEBPATH -o $FULLPATH


SIGNATURE_FILE=signature.base64

if [ "$OS" = "osx" ]
then
  openssl=/usr/bin/openssl
  if [ $SPARKLE_PRIVATE_KEY_PATH ] && [ -e $SPARKLE_PRIVATE_KEY_PATH ]
  then
    echo Calculating signature for $FULLPATH
    $openssl dgst -sha1 -binary < "$FULLPATH" | $openssl dgst -dss1 -sign "$SPARKLE_PRIVATE_KEY_PATH" | $openssl enc -base64 > $SIGNATURE_FILE
  else
    echo "SPARKLE_PRIVATE_KEY_PATH is not valid in node environment variables - dmg signature can't be calculated and can't be used for sparkle updates"
    exit 3
  fi
fi

DSASIGNATURE=`cat $SIGNATURE_FILE`
FILESIZE=`ls -al "$FULLPATH" | awk '{print $5}'`


NEW_ITEM_TMP_FILE1=new_item.xml
NEW_ITEM_TMP_FILE2=new_item2.xml
OLD_ITEMS_TMP_FILE=old_items.xml

#generating the item
sed "s|#TITLE#|$TITLE|" sparkle_item.template | \
sed "s|#CHANGELOG#|$CHANGELOG|" | \
sed "s|#VERSION#|$VERSION|" | \
sed "s|#SUBFOLDER#|$SUBFOLDER|" | \
sed "s|#FILENAME#|$FILENAME|" | \
sed "s|#DATE#|$DATE|" | \
sed "s|#FILESIZE#|$FILESIZE|" | 
sed "s|#OS#|$OS|" > $NEW_ITEM_TMP_FILE1

if [ "$OS" = "osx" ]
then
  cp $NEW_ITEM_TMP_FILE1 $NEW_ITEM_TMP_FILE2
  cat $NEW_ITEM_TMP_FILE2 | sed "s|#DSASIGNATURE#|$DSASIGNATURE|" > $NEW_ITEM_TMP_FILE1
  rm $NEW_ITEM_TMP_FILE2
else
  #winsparkle needs the signature attribute removed
  cp $NEW_ITEM_TMP_FILE1 $NEW_ITEM_TMP_FILE2    
  cat $NEW_ITEM_TMP_FILE2 | sed "s|sparkle:dsaSignature.*\/|\/|" > $NEW_ITEM_TMP_FILE1
  rm $NEW_ITEM_TMP_FILE2
fi

# extract the current items first from the sparklexml file

HEADER_LINE1=".*\<?xml.*"
HEADER_LINE2=".*\<rss.*"
HEADER_LINE3="\<channel\>"
FOOTER_LINE1="\<\/channel\>"
FOOTER_LINE2="\<\/rss\>"
sed -ie "/$HEADER_LINE1/d" $SPARKLE_XML
sed -ie "/$HEADER_LINE2/d" $SPARKLE_XML
sed -ie "/$HEADER_LINE3/d" $SPARKLE_XML
sed -ie "/$FOOTER_LINE1/d" $SPARKLE_XML
sed -ie "/$FOOTER_LINE2/d" $SPARKLE_XML

mv $SPARKLE_XML $OLD_ITEMS_TMP_FILE

cat sparkle_xmlfeed_start.template > $SPARKLE_XML
cat $NEW_ITEM_TMP_FILE1 >> $SPARKLE_XML
cat $OLD_ITEMS_TMP_FILE >> $SPARKLE_XML
cat sparkle_xmlfeed_end.template >> $SPARKLE_XML

#some cleanup
rm $OLD_ITEMS_TMP_FILE
rm $NEW_ITEM_TMP_FILE1
rm $SIGNATURE_FILE
