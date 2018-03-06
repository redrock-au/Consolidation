#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.01.01/arc/1.0.0/install/FSC-6016_install.sh 3070 2017-11-29 03:40:45Z dkwon $
# --------------------------------------------------------------
# Install script for AR.01.01 Receivable Transactions Interface
#   Usage: FSC-6016_install.sh <apps_pwd> | tee FSC-6016_install.log
# --------------------------------------------------------------
CEMLI=AR.01.01

DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh <apps_pwd>"
  exit 1
}

# --------------------------------------------------------------
# Validate parameters
# --------------------------------------------------------------
if [ $# == 1 ]
then
  APPSPWD=$1
else
  usage
fi

APPSLOGIN=apps/$APPSPWD

echo "Installing $CEMLI"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------

if [ "$TIER_DB" = "YES" ]
then

$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF  
  @$ARC_TOP/install/sql/XXAR_PRINT_INVOICES_PKG.pkb
  show errors
  EXIT
EOF

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------

##concurrent programs 

## Request group

## Form function

## Menu

## Message

## Profile

fi

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0