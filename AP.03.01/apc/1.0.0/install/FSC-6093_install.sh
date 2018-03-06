#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.03.01/apc/1.0.0/install/FSC-6093_install.sh 3180 2017-12-12 07:16:28Z dart $
# --------------------------------------------------------------
# Install script for CEMLI AP.03.01
#   Usage: FSC-6093_install.sh <apps_pwd> | tee FSC-6093_install.log
# --------------------------------------------------------------
CEMLI=AP.03.01

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: FSC-6093_install.sh <apps_pwd>"
  exit 1
}

# --------------------------------------------------------------
# Validate parameters
# --------------------------------------------------------------
if [ $# == 1 ]
then
  APPSLOGIN=apps/$1
else
  usage
fi

echo "Installing $CEMLI (FSC-6093)"
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
  @./sql/XXAP_INVOICE_IMPORT_PKG.pkb
  show errors
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
# none

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
