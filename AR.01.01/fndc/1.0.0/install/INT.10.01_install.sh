#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.01.01/fndc/1.0.0/install/INT.10.01_install.sh 2949 2017-11-13 01:09:55Z svnuser $
# --------------------------------------------------------------
# Install script for INT.10.01 Refresh Cognos Materialized Views
#   Usage: INT.10.01_install.sh <apps_pwd> | tee INT.10.01_install.log
# --------------------------------------------------------------
CEMLI=INT.10.01

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

echo "Installing $CEMLI"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
$ORACLE_HOME/bin/sqlplus -s APPS/$APPSPWD <<EOF
  SET DEFINE OFF
  @./sql/DOT_AP_INVOICES_W_DDL.sql
  show errors
  @./sql/DOT_AP_INVOICES_DW_ALTER.sql
  show errors
  @./sql/DOT_AP_INVOICES_DW_DML.sql
  show errors
  EXIT
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
IMPORTDIR=$FNDC_TOP/import

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
# none

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
