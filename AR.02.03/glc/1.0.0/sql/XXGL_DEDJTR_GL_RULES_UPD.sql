rem $Header: svn://d02584/consolrepos/branches/AR.02.03/glc/1.0.0/sql/XXGL_DEDJTR_GL_RULES_UPD.sql 1739 2017-07-13 03:52:53Z svnuser $
SET SERVEROUTPUT ON SIZE 1000000
DECLARE
   TYPE t_cat_map_type  IS TABLE OF VARCHAR2(30) INDEX BY VARCHAR2(30);
   t_cat_map            t_cat_map_type;
   t_cat_mapped         t_cat_map_type;
   --
   PROCEDURE initialise_cat_map
   IS
   BEGIN
      t_cat_map('Payroll') := upper('Payroll');
      t_cat_map('62') := upper('Payroll Tax');
      t_cat_map('124') := upper('Workcover');
      t_cat_map('144') := upper('LSL Actual');
      t_cat_map('145') := upper('LSL Provision');
      t_cat_map('146') := upper('PDA');
      t_cat_map('147') := upper('PPL');
      t_cat_map('148') := upper('RL Actual');
      t_cat_map('149') := upper('RL Provision');
      t_cat_map('164') := upper('Bonus');
      t_cat_map('184') := upper('ACC-PAYROLL');
      t_cat_map('185') := upper('ACC-LSL ACTUAL');
      t_cat_map('186') := upper('ACC-PAYROLL TAX');
      t_cat_map('187') := upper('ACC-RL ACTUAL');
      t_cat_map('188') := upper('ACC-WORKCOVER');
   END;
   --
   FUNCTION lookup_category_name(p_user_category_name IN VARCHAR2) RETURN VARCHAR2
   IS
      l_category_name         gl_je_categories_vl.je_category_name%TYPE;
   BEGIN
      SELECT je_category_name 
      INTO   l_category_name
      FROM   gl_je_categories_vl
      WHERE  upper(user_je_category_name) = upper(p_user_category_name);
      RETURN l_category_name;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RETURN NULL;
   END;
   --
   PROCEDURE initialise_cat_mapped
   IS
      l_idx                VARCHAR2(30);
   BEGIN
      IF t_cat_map.COUNT > 0 THEN
         l_idx := t_cat_map.FIRST;
         WHILE (l_idx IS NOT NULL)
         LOOP
            t_cat_mapped(l_idx) := nvl(lookup_category_name(t_cat_map(l_idx)), t_cat_map(l_idx));
            l_idx := t_cat_map.NEXT(l_idx);
         END LOOP;
      END IF;
   END;
   --
   PROCEDURE update_rule_categories(p_rule_lookup_type IN VARCHAR2)
   IS
      CURSOR c_lookup_values(p_rule_lookup_type IN VARCHAR2) IS
         SELECT lookup_code, lookup_type, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6
         FROM   fnd_lookup_values
         WHERE  lookup_type = p_rule_lookup_type
         FOR UPDATE OF attribute1, attribute2, attribute3, attribute4, attribute5, attribute6;

      l_attribute1         VARCHAR2(150);
      l_attribute2         VARCHAR2(150);
      l_attribute3         VARCHAR2(150);
      l_attribute4         VARCHAR2(150);
      l_attribute5         VARCHAR2(150);
      l_attribute6         VARCHAR2(150);
      --
      PROCEDURE determine_category(p_attribute_original IN VARCHAR2, p_attribute_new OUT VARCHAR2, p_rec IN OUT NOCOPY c_lookup_values%ROWTYPE)
      IS
      BEGIN
         IF p_attribute_original IS NOT NULL THEN 
            IF t_cat_mapped.EXISTS(p_attribute_original) THEN
               p_attribute_new := t_cat_mapped(p_attribute_original);
               dbms_output.put_line(p_rec.lookup_type || ': ' || p_rec.lookup_code || ': mapping ' 
                  || p_attribute_original || ' (' || t_cat_map(p_attribute_original) || ') to ' 
                  || p_attribute_new);
            ELSE
               p_attribute_new := '-2';
               dbms_output.put_line(p_rec.lookup_type || ': ' || p_rec.lookup_code || ': mapping ' 
                  || p_attribute_original || ' (Null) to ' || p_attribute_new);
            END IF;
         END IF;
      END;
      --
   BEGIN
      FOR r_lookup_value IN c_lookup_values(p_rule_lookup_type)
      LOOP
         l_attribute1 := NULL;
         l_attribute2 := NULL;
         l_attribute3 := NULL;
         l_attribute4 := NULL;
         l_attribute5 := NULL;
         l_attribute6 := NULL;
         determine_category(r_lookup_value.attribute1, l_attribute1, r_lookup_value);
         determine_category(r_lookup_value.attribute2, l_attribute2, r_lookup_value);
         determine_category(r_lookup_value.attribute3, l_attribute3, r_lookup_value);
         determine_category(r_lookup_value.attribute4, l_attribute4, r_lookup_value);
         determine_category(r_lookup_value.attribute5, l_attribute5, r_lookup_value);
         determine_category(r_lookup_value.attribute6, l_attribute6, r_lookup_value);
         --
         UPDATE fnd_lookup_values
         SET    attribute1 = nvl(l_attribute1, attribute1),
                attribute2 = nvl(l_attribute2, attribute2),
                attribute3 = nvl(l_attribute3, attribute3),
                attribute4 = nvl(l_attribute4, attribute4),
                attribute5 = nvl(l_attribute5, attribute5),
                attribute6 = nvl(l_attribute6, attribute6)
         WHERE CURRENT OF c_lookup_values;
      END LOOP;
   END;
BEGIN
   initialise_cat_map;
   initialise_cat_mapped;
   update_rule_categories('XXGL_CHRIS_ACC_DEDJTR_GL_RULES');
   update_rule_categories('XXGL_CHRIS_ACC_TSC_GL_RULES');
   update_rule_categories('XXGL_CHRIS_DEDJTR_GL_RULES');
   update_rule_categories('XXGL_CHRIS_TSC_GL_RULES');
END;
/
