#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.01.01/glc/1.0.0/install/GL.00.01_install.sh 2674 2017-10-05 01:02:16Z svnuser $
# --------------------------------------------------------------
# Install script for GL.00.01 GL COA Mappings for Conversion
#   Usage: GL.00.01_install.sh <apps_pwd> | tee GL.00.01_install.log
# --------------------------------------------------------------
CEMLI=GL.00.01

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
  @./sql/XXGL_COA_ACCOUNT_MAP_STG_DDL.sql
  @./sql/XXGL_COA_ACCTMAP_RECID_SEQ_DDL.sql
  @./sql/XXGL_COA_ACCOUNT_MAP_STG_IDX1_DDL.sql
  @./sql/XXGL_COA_AUTHORITY_MAP_STG_DDL.sql
  @./sql/XXGL_COA_AUTHMAP_RECID_SEQ_DDL.sql
  @./sql/XXGL_COA_AUTH_MAP_STG_IDX1_DDL.sql
  @./sql/XXGL_COA_CC_MAP_STG_DDL.sql
  @./sql/XXGL_COA_CCMAP_RECID_SEQ_DDL.sql
  @./sql/XXGL_COA_CC_MAP_STG_IDX1_DDL.sql
  @./sql/XXGL_COA_DSDBI_CODE_COMB_STG_DDL.sql
  @./sql/XXGL_COA_DSDBI_CODE_COMB_STG_SEQ_DDL.sql
  @./sql/XXGL_COA_ENTITY_MAP_STG_DDL.sql
  @./sql/XXGL_COA_ENTITYMAP_RECID_SEQ_DDL.sql
  @./sql/XXGL_COA_ENTITY_MAP_STG_IDX1_DDL.sql
  @./sql/XXGL_COA_IDENTIFIER_MAP_STG_DDL.sql
  @./sql/XXGL_COA_IDENTMAP_RECID_SEQ_DDL.sql
  @./sql/XXGL_COA_IDENTIFI_MAP_STG_IDX1_DDL.sql
  @./sql/XXGL_COA_OUTPUT_MAP_STG_DDL.sql
  @./sql/XXGL_COA_OUTMAP_RECID_SEQ_DDL.sql
  @./sql/XXGL_COA_OUTPUT_MAP_STG_IDX1_DDL.sql
  @./sql/XXGL_COA_PROJECT_MAP_STG_DDL.sql
  @./sql/XXGL_COA_PRJMAP_RECID_SEQ_DDL.sql
  @./sql/XXGL_COA_PROJECT_MAP_STG_IDX1_DDL.sql
  @./sql/XXGL_COA_MAPPING_CONV_STG_DDL.sql
  @./sql/XXGL_COA_MAPPING_CONV_TFM_DDL.sql
  @./sql/XXGL_COA_MAPPING_RECID_SEQ_DDL.sql
  @./sql/XXGL_IMPORT_COA_MAPPING_PKG.pks
  show errors
  @./sql/XXGL_IMPORT_COA_MAPPING_PKG.pkb
  show errors
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $GLC_TOP/import/XXGLCOACONV_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $GLC_TOP/import/XXGLCOACONVRQG_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
fi

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
# none

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0