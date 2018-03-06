#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.01.02/poc/1.0.0/install/PO.99.01_install.sh 1368 2017-07-02 23:54:39Z svnuser $
# --------------------------------------------------------------
# Install script for PO.99.01 Kofax Pay On Receipt (ERS)
#   Usage: PO.99.01_install.sh apps_pwd | tee PO.99.01_install.log
# --------------------------------------------------------------
CEMLI=PO.99.01

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh apps_pwd | tee PO.99.01_install.log"
  exit 1
}

# --------------------------------------------------------------
# Validate parameters
# --------------------------------------------------------------
if [ $# -eq 1 ]
then
  APPSPWD=$1
else
  usage
fi

APPSLOGIN=APPS/$APPSPWD

echo "Installing $CEMLI"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

if [ $TIER_DB = YES ] 
then
# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------
$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF 
  @./sql/POC_INVOICE_INFO_V_DBI.sql
  @./sql/POC_PURCHASE_ORDER_INFO_V_DBI.sql
  @./sql/POC_SUPPLIER_INFO_V_DBI.sql
  @./sql/POC_INACTIVE_INV_INFO_V_DBI.sql
  @$APC_TOP/install/sql/APC_USERS_V.sql
  show errors
  EXIT
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
# none

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
# none

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
