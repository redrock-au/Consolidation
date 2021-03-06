#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.02.02/glc/1.0.0/install/FSC-5720_install.sh 3066 2017-11-28 06:24:56Z svnuser $
# --------------------------------------------------------------
# Install script for GL.03.01 GL Cash Balancing
#   Usage: FSC-5720_install.sh <apps_pwd> | tee FSC-5720_install.log
# --------------------------------------------------------------
CEMLI=GL.03.01

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
  APPSLOGIN=apps/$1
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
$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @./sql/XXGL_CASH_BAL_PKG.pkb
  show errors
EOF
fi

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------

chmod +x $FNDC_TOP/bin/RUN_AP.prog

rm $FNDC_TOP/bin/RUN_AP

ln -s $FND_TOP/bin/fndcpesr $FNDC_TOP/bin/RUN_AP

# --------------------------------------------------------------
# Copy to source directory
# --------------------------------------------------------------

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
