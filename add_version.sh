#!/bin/sh

if [ $# != 5 ]
then
  echo "usage: $0 <title> <version> <changelog> <download_fullpath> <sparkle_xml>"
  exit 1
fi

DOWNLOAD_MIRROR="http://mirrors.kodi.tv"

TITLE=$1
VERSION=$2
CHANGELOG=$3
DOWNLOAD_FULLPATH=$(echo $4 | sed -E -e 's|^https?://[^/]+||g' -e 's|^/*||g' -e 's|\?.*||g')
SPARKLE_XML=$5
SUBFOLDER=""
DATE=`date +"%a, %d %b %Y %H:%M:%S %z"`

curl -sI --fail $DOWNLOAD_MIRROR/$DOWNLOAD_FULLPATH > /dev/null
if [ $? -ne 0 ]
then
  echo "$DOWNLOAD_MIRROR/$DOWNLOAD_FULLPATH doesn't exist"
  exit 1
fi

#determine os from the download url
case "$DOWNLOAD_FULLPATH" in
  */osx/*-x86_64.dmg)
    OS=osx
    queryString="?https=1"
    ;;
  */windows/win32/*-x86.exe)
    OS=windows-x86
    ;;
  */windows/win64/*-x64.exe)
    OS=windows-x64
    ;;
  *)
    echo "OS couldn't be determine in $DOWNLOAD_FULLPATH" >&2
    exit 3
    ;;
esac

echo "Detected $OS platform in $DOWNLOAD_FULLPATH"

if [ "$OS" = "osx" ]
then
  if [ $SPARKLE_PRIVATE_KEY_PATH ] && [ -e $SPARKLE_PRIVATE_KEY_PATH ]
  then
    echo Calculating signature for $DOWNLOAD_FULLPATH
    SIGNATURE_FILE=signature.base64
    openssl=/usr/bin/openssl
    curl -Ls $DOWNLOAD_MIRROR/$DOWNLOAD_FULLPATH?sha1 | awk '{ print $1 }' | xxd -p -r | $openssl dgst -dss1 -sign "$SPARKLE_PRIVATE_KEY_PATH" | $openssl enc -base64 > $SIGNATURE_FILE
  else
    echo "SPARKLE_PRIVATE_KEY_PATH is not valid in node environment variables - dmg signature can't be calculated and can't be used for sparkle updates"
    exit 3
  fi
  DSASIGNATURE=`cat $SIGNATURE_FILE`
fi

FILESIZE=$(curl -sI $DOWNLOAD_MIRROR/$DOWNLOAD_FULLPATH | awk '/Content-Length/ { print $2 }' | tr -d '\r\n')


NEW_ITEM_TMP_FILE1=new_item.xml
OLD_ITEMS_TMP_FILE=old_items.xml

#generating the item
cp sparkle_item.template $NEW_ITEM_TMP_FILE1
sed -ie "s|#TITLE#|$TITLE|" $NEW_ITEM_TMP_FILE1
sed -ie "s|#CHANGELOG#|$CHANGELOG|" $NEW_ITEM_TMP_FILE1
sed -ie "s|#VERSION#|$VERSION|" $NEW_ITEM_TMP_FILE1
sed -ie "s|#DATE#|$DATE|" $NEW_ITEM_TMP_FILE1
sed -ie "s|#FILESIZE#|$FILESIZE|" $NEW_ITEM_TMP_FILE1
sed -ie "s|#OS#|$OS|" $NEW_ITEM_TMP_FILE1
sed -ie "s|#DOWNLOAD_FULLPATH#|$DOWNLOAD_MIRROR/$DOWNLOAD_FULLPATH$queryString|" $NEW_ITEM_TMP_FILE1

if [ "$OS" = "osx" ]
then
  sed -ie "s|#DSASIGNATURE#|$DSASIGNATURE|" $NEW_ITEM_TMP_FILE1
else
  #winsparkle needs the signature attribute removed
  sed -ie "s|sparkle:dsaSignature.*\/|\/|" $NEW_ITEM_TMP_FILE1
  #it also needs the minimumversion element removed
  sed -ie "/<sparkle:minimumSystemVersion.*/d" $NEW_ITEM_TMP_FILE1
fi

# extract the current items first from the sparklexml file

HEADER_LINE1=".*<.xml .*"
HEADER_LINE2=".*<rss.*"
HEADER_LINE3="<channel>"
FOOTER_LINE1="<\/channel>"
FOOTER_LINE2="<\/rss>"

touch $OLD_ITEMS_TMP_FILE

if [ -e $SPARKLE_XML ]
then
  #cat $SPARKLE_XML
  #echo removing header1
  sed -ie "/$HEADER_LINE1/d" $SPARKLE_XML
  #cat $SPARKLE_XML
  #echo removing header2
  sed -ie "/$HEADER_LINE2/d" $SPARKLE_XML
  #cat $SPARKLE_XML
  #echo removing header3
  sed -ie "/$HEADER_LINE3/d" $SPARKLE_XML
  #cat $SPARKLE_XML
  #echo removing footer1
  sed -ie "/$FOOTER_LINE1/d" $SPARKLE_XML
  #cat $SPARKLE_XML
  #echo removing footer2
  sed -ie "/$FOOTER_LINE2/d" $SPARKLE_XML
  #cat $SPARKLE_XML
  mv $SPARKLE_XML $OLD_ITEMS_TMP_FILE
  echo extracted items
  cat $OLD_ITEMS_TMP_FILE
fi

cat sparkle_xmlfeed_start.template > $SPARKLE_XML
cat $NEW_ITEM_TMP_FILE1 >> $SPARKLE_XML
cat $OLD_ITEMS_TMP_FILE >> $SPARKLE_XML

cat sparkle_xmlfeed_end.template >> $SPARKLE_XML

#some cleanup
rm $OLD_ITEMS_TMP_FILE
rm $NEW_ITEM_TMP_FILE1
rm $SIGNATURE_FILE $FULLPATH "$NEW_ITEM_TMP_FILE1"e

if [ -e "$SPARKLE_XML"e ]
then
  rm "$SPARKLE_XML"e
fi
