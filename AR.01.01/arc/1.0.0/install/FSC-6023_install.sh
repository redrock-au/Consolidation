#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.01.01/arc/1.0.0/install/FSC-6023_install.sh 3078 2017-11-29 23:44:15Z svnuser $
# --------------------------------------------------------------
# Install script for AR.02.02 AR Customer Inbound Interface
#   Usage: FSC-6023_install.sh apps_pwd | tee FSC-6023_install.log
# --------------------------------------------------------------
CEMLI=AR.02.02

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: FSC-6023_install.sh apps_pwd | tee FSC-6023_install.log"
  exit 1
}

# --------------------------------------------------------------
# Validate parameters
# --------------------------------------------------------------
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
  @./sql/XXAR_CUSTOMER_INTERFACE_PKG.pkb
  show errors
  EXIT
EOF
fi

# Application Setup

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
# none

# --------------------------------------------------------------
# OA HTML
# --------------------------------------------------------------
# Copy java Files
# Controllers

#VO/AM 

#Pages / Regions


#Compile java Files 


#Import Pages and Regions


#Import Personalization

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0