/* $Header: svn://d02584/consolrepos/branches/AP.02.01/fndc/1.0.0/install/sql/XXINT_FILE_UTIL.sql 2770 2017-10-10 23:47:18Z svnuser $ */
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

  public static int delete (String path) {
    File myFile = new File (path);
    if (myFile.delete()) return SUCCESS; else return FAILURE;
  }  
  
};';
   EXECUTE IMMEDIATE l_sql;
END;
/
