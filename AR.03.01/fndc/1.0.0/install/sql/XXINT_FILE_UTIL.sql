/* $Header: svn://d02584/consolrepos/branches/AR.03.01/fndc/1.0.0/install/sql/XXINT_FILE_UTIL.sql 1055 2017-06-21 03:20:11Z svnuser $ */
DECLARE
   l_sql  VARCHAR2(32767);
BEGIN
l_sql := 
'create or replace and compile java source named "file_util" as
import java.lang.*;
import java.util.*;
import java.io.*;
import java.sql.Timestamp;

public class file_util
{
  private static int SUCCESS = 1;
  private static  int FAILURE = 0;

  public static int copy (String fromPath, String toPath) {
    try {
      File fromFile = new File (fromPath);
      File toFile   = new File (toPath);

      InputStream  in  = new FileInputStream(fromFile);
      OutputStream out = new FileOutputStream(toFile);

      byte[] buf = new byte[1024];
      int len;
      while ((len = in.read(buf)) > 0) {
        out.write(buf, 0, len);
      }
      in.close();
      out.close();
      return SUCCESS;
    }
    catch (Exception ex) {
      return FAILURE;
    }
  }
};';
   EXECUTE IMMEDIATE l_sql;
END;
/
