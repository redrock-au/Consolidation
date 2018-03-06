#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.03.01/poc/1.0.0/install/FSC-5985_install.sh 3008 2017-11-20 02:23:05Z svnuser $
# --------------------------------------------------------------
# Install script for PO.12.01 DEDJTR Contract Extract Inbound from CMS
#   Usage: FSC-5985_install.sh apps_pwd | tee FSC-5985_install.log
# --------------------------------------------------------------
CEMLI=PO.12.01

DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh apps_pwd | tee FSC-5985_install.log"
  exit 1
}

# ------------------------------------------------------------
# Validate parameters
# ------------------------------------------------------------
if [ $# = 1 ]
then
  APPSPWD=$1
else
  usage
fi

echo "Installing $CEMLI"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"


APPSLOGIN=APPS/$APPSPWD

# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------

if [ "$TIER_DB" = "YES" ]
then

$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @$POC_TOP/install/sql/XXPO_CONTRACTS_PKG.pkb
  show errors
EOF

fi

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
