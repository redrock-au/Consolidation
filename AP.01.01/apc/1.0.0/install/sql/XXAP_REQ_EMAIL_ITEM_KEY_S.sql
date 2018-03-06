/*$Header: svn://d02584/consolrepos/branches/AP.01.01/apc/1.0.0/install/sql/XXAP_REQ_EMAIL_ITEM_KEY_S.sql 1822 2017-07-18 00:19:16Z svnuser $*/
                            CREATE SEQUENCE FMSMGR.XXAP_REQ_EMAIL_ITEM_KEY_S 
                            START WITH 1000 
                            INCREMENT BY 1  
                            NOCACHE
                            NOCYCLE;
                            
                            CREATE SYNONYM XXAP_REQ_EMAIL_ITEM_KEY_S 
                            FOR FMSMGR.XXAP_REQ_EMAIL_ITEM_KEY_S;

