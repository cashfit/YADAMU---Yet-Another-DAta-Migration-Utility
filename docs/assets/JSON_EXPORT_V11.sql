--
create or replace type T_VC4000_TABLE is TABLE of VARCHAR2(4000)
/
--
/*
** Omit Materialzed Views from Export File
** Add support for de-serializing serialized data 
*/ 
create or replace package JSON_EXPORT
authid CURRENT_USER
as
  ROW_LIMIT NUMBER := -1;
  procedure SET_ROW_LIMIT(P_ROW_LIMIT NUMBER);											  
--  
$IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
--
  SQL_STATEMENT CLOB;
  function DUMP_SQL_STATEMENT return CLOB;
--
$ELSE
--
  type T_EXPORT_METADATA_RECORD is record(
    OWNER         VARCHAR2(128)
   ,TABLE_NAME    VARCHAR2(128)
   ,METADATA      CLOB 
   ,SQL_STATEMENT CLOB
  );
  
  type T_EXPORT_METADATA_TABLE is table of T_EXPORT_METADATA_RECORD;
  EXPORT_METADATA_CACHE T_EXPORT_METADATA_TABLE;
--  
  function EXPORT_METADATA return T_EXPORT_METADATA_TABLE pipelined;
$END  
--
  function EXPORT_VERSION return NUMBER deterministic;
  function JSON_FEATURES return VARCHAR2 deterministic;
  function DATABASE_RELEASE return NUMBER deterministic;
  
  function EXPORT_SCHEMA(P_SOURCE_SCHEMA VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CURRENT_SCHEMA')) return CLOB;
end;
/
--
show errors 
--
create or replace package body JSON_EXPORT
as
--
  C_NEWLINE         CONSTANT CHAR(1) := CHR(10);
  C_SINGLE_QUOTE    CONSTANT CHAR(1) := CHR(39);
--
  $IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
  C_RETURN_TYPE     CONSTANT VARCHAR2(32) := 'CLOB'; 
  C_MAX_OUTPUT_SIZE CONSTANT NUMBER       := DBMS_LOB.LOBMAXSIZE;
  $ELSIF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
  C_RETURN_TYPE     CONSTANT VARCHAR2(32):= 'VARCHAR2(32767)';
  C_MAX_OUTPUT_SIZE CONSTANT NUMBER      := 32767;
  $ELSE
  C_RETURN_TYPE     CONSTANT VARCHAR2(32):= 'VARCHAR2(4000)';
  C_MAX_OUTPUT_SIZE CONSTANT NUMBER      := 4000;
  $END  
--  
function DATABASE_RELEASE return NUMBER deterministic
as
begin
  return DBMS_DB_VERSION.VERSION || '.' || DBMS_DB_VERSION.RELEASE;
end;
--
function JSON_FEATURES return VARCHAR2 deterministic
as
begin
  return JSON_OBJECT(
          'treatAsJSON'     value JSON_FEATURE_DETECTION.TREAT_AS_JSON_SUPPORTED
	 	 ,'CLOB'           value JSON_FEATURE_DETECTION.CLOB_SUPPORTED
		 ,'extendedString' value JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED
		 );
end;
function EXPORT_VERSION return NUMBER deterministic
as
begin
  return 1.0;
end;
--
$IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
--
function DUMP_SQL_STATEMENT
return CLOB
as
begin
  return SQL_STATEMENT;
end;
--
$ELSE
--
function EXPORT_METADATA
return T_EXPORT_METADATA_TABLE
pipelined
as
  cursor getRecords
  is
  select *
    from TABLE(EXPORT_METADATA_CACHE);
begin
  for r in getRecords loop
    pipe row (r);
  end loop;
end;
--
$END
--
procedure SET_ROW_LIMIT(P_ROW_LIMIT NUMBER)
as
begin
  ROW_LIMIT := P_ROW_LIMIT;
end;
--
function TABLE_TO_LIST(P_TABLE T_VC4000_TABLE,P_DELIMITER VARCHAR2 DEFAULT ',') 
return CLOB
as
  V_LIST CLOB;
begin
  DBMS_LOB.CREATETEMPORARY(V_LIST,TRUE,DBMS_LOB.CALL);
  for i in P_TABLE.first .. P_TABLE.last loop
    if (i > 1) then 
      DBMS_LOB.WRITEAPPEND(V_LIST,length(P_DELIMITER),P_DELIMITER); 
    end if;
    DBMS_LOB.WRITEAPPEND(V_LIST,length(P_TABLE(i)),P_TABLE(i));
  end loop;
  return V_LIST;
end;
--
$IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
function GENERATE_WITH_CLAUSE(P_SOURCE_SCHEMA VARCHAR2, P_TABLE_NAME_LIST T_VC4000_TABLE, P_BFILE_COUNT NUMBER, P_BLOB_COUNT NUMBER, P_ANYDATA_COUNT NUMBER, P_SQL_STATEMENT IN OUT CLOB)
return VARCHAR2
as
  V_OBJECT_SERIALIZER CLOB;
  V_FUNCTION_LIST VARCHAR(32767) := '';
begin
  V_OBJECT_SERIALIZER := OBJECT_SERIALIZATION.SERIALIZE_TABLE_TYPES(P_SOURCE_SCHEMA,P_TABLE_NAME_LIST);
$ELSE
function GENERATE_WITH_CLAUSE(P_SOURCE_SCHEMA VARCHAR2, P_TABLE_NAME VARCHAR2, P_BFILE_COUNT NUMBER, P_BLOB_COUNT NUMBER, P_ANYDATA_COUNT NUMBER, P_SQL_STATEMENT IN OUT CLOB)
return VARCHAR2
as
  V_OBJECT_SERIALIZER CLOB;
  V_FUNCTION_LIST VARCHAR(32767) := '';
begin
  V_OBJECT_SERIALIZER :=  OBJECT_SERIALIZATION.SERIALIZE_TABLE_TYPES(P_SOURCE_SCHEMA,P_TABLE_NAME); 
$END
  if ((P_BFILE_COUNT + P_BLOB_COUNT + P_ANYDATA_COUNT = 0) AND (V_OBJECT_SERIALIZER is NULL)) then
    return V_FUNCTION_LIST;
  end if;

  DBMS_LOB.APPEND(P_SQL_STATEMENT,TO_CLOB('WITH' || C_NEWLINE));

  if (V_OBJECT_SERIALIZER is not null) then
    DBMS_LOB.APPEND(P_SQL_STATEMENT,V_OBJECT_SERIALIZER);
	V_FUNCTION_LIST := 'OBJECTS';
  else
    /*
	** Deserialization functions for BFILE and BLOB data types are exposed direclty by the OBJECT_SERIALIZATION package
	** This allows them to called from EXECUTE IMMEDIATE operations when they appear inside serialized objects 
	** Since the functions are exposed by OBJECT_SERIALIZATION they do not need to be supplied using a WITH clause
	** ANYDATA is de-serialised using methods exposed by the ANYDATA type.
	*/
    if ((P_BFILE_COUNT > 0) or (P_ANYDATA_COUNT > 0)) then
      DBMS_LOB.APPEND(P_SQL_STATEMENT,TO_CLOB(OBJECT_SERIALIZATION.CODE_BFILE2CHAR));
    end if;
    if ((P_BLOB_COUNT > 0) or (P_ANYDATA_COUNT > 0)) then
      DBMS_LOB.APPEND(P_SQL_STATEMENT,TO_CLOB(OBJECT_SERIALIZATION.CODE_BLOB2HEXBINARY));
    end if;
    if (P_ANYDATA_COUNT > 0) then
      DBMS_LOB.APPEND(P_SQL_STATEMENT,TO_CLOB(OBJECT_SERIALIZATION.CODE_SERIALIZE_ANYDATA));
    end if;
 end if;
 return V_FUNCTION_LIST;
end;
--
procedure GENERATE_STATEMENT(P_SOURCE_SCHEMA VARCHAR2)
/*
** Generate SQL Statement to create a JSON document from the contents of the supplied schema
*/
as
  V_SQL_FRAGMENT  VARCHAR2(32767);
 
  cursor getTableMetadata
  is
  select aat.owner
        ,aat.table_name
        ,sum(case when DATA_TYPE = 'BLOB'  then 1 else 0 end) BLOB_COUNT
        ,sum(case when DATA_TYPE = 'BFILE' then 1 else 0 end) BFILE_COUNT
        ,sum(case when DATA_TYPE = 'ANYDATA' then 1 else 0 end) ANYDATA_COUNT
        ,cast(collect('"' || COLUMN_NAME || '"' ORDER BY INTERNAL_COLUMN_ID) as T_VC4000_TABLE) COLUMN_LIST
		,cast(collect(case when DATA_TYPE_OWNER is null then '"' || DATA_TYPE || '"' else '"' || DATA_TYPE_OWNER || '"."' || DATA_TYPE || '"' end ORDER BY INTERNAL_COLUMN_ID) as T_VC4000_TABLE) DATA_TYPE_LIST
        ,cast(collect(
               case
                 -- For some reason RAW columns have DATA_TYPE_OWNER set to the current schema.
                 when DATA_TYPE = 'RAW'
                   then '"' || COLUMN_NAME || '"'
                 $IF not JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
                 /*
                 ** Pre 18.1 Some Scalar Data Types are not natively supported by JSON_ARRAY()
                 */
                 when DATA_TYPE in ('BINARY_DOUBLE','BINARY_FLOAT')
                   then 'TO_CHAR("' || COLUMN_NAME || '")'
                 when DATA_TYPE like 'TIMESTAMP%WITH LOCAL TIME ZONE'
                   then 'TO_CHAR(SYS_EXTRACT_UTC("' || COLUMN_NAME || '"),''IYYY-MM-DD"T"HH24:MI:SS.FF9"Z"'')'
                 when DATA_TYPE like 'INTERVAL DAY% TO SECOND%'
                   then '''P''
                        || extract(DAY FROM "' || COLUMN_NAME || '") || ''D''
                        || ''T'' || case when extract(HOUR FROM  "' || COLUMN_NAME || '") <> 0 then extract(HOUR FROM  "' || COLUMN_NAME || '") ||  ''H'' end
                        || case when extract(MINUTE FROM  "' || COLUMN_NAME || '") <> 0 then extract(MINUTE FROM  "' || COLUMN_NAME || '") || ''M'' end
                        || case when extract(SECOND FROM  "' || COLUMN_NAME || '") <> 0 then extract(SECOND FROM  "' || COLUMN_NAME || '") ||  ''S'' end'
                 when DATA_TYPE  like 'INTERVAL YEAR% TO MONTH%'
                   then '''P''
                        || extract(YEAR FROM "' || COLUMN_NAME || '") || ''Y''
                        || case when extract(MONTH FROM  "' || COLUMN_NAME || '") <> 0 then extract(MONTH FROM  "' || COLUMN_NAME || '") || ''M'' end'
                 when DATA_TYPE in ('NCHAR','NVARCHAR2')
                   then 'TO_CHAR("' || COLUMN_NAME || '")'
                 when DATA_TYPE = 'NCLOB'
                   then 'TO_CLOB("' || COLUMN_NAME || '")'
                 /*
                 ** 18.1 compatible handling of BLOB
                 */
                 when DATA_TYPE = 'BLOB'
                   then 'BLOB2HEXBINARY("' || COLUMN_NAME || '")'                          
                 $END
                 /*
                 ** Quick Fixes for datatypes not natively supported
                 */
                 when DATA_TYPE = 'XMLTYPE'  -- Can be owned by SYS or PUBLIC
                   then 'case when "' ||  COLUMN_NAME || '" is NULL then NULL else XMLSERIALIZE(CONTENT "' ||  COLUMN_NAME || '" as CLOB) end'
                 when DATA_TYPE = 'ROWID' or DATA_TYPE = 'UROWID'
                   then 'ROWIDTOCHAR("' || COLUMN_NAME || '")'
                 /*
                 ** Fix for BFILENAME
                 */
                 when DATA_TYPE = 'BFILE'
                   then 'BFILE2CHAR("' || COLUMN_NAME || '")'
                 /*
                 **
                 ** Support ANYDATA, OBJECT and COLLECTION types
                 **
                 */
                 when DATA_TYPE = 'ANYDATA'  -- Can be owned by SYS or PUBLIC
                   then 'case when "' ||  COLUMN_NAME || '" is NULL then NULL else SERIALIZE_ANYDATA("' ||  COLUMN_NAME || '") end'
                 when TYPECODE = 'COLLECTION'
                   then 'case when "' || COLUMN_NAME || '" is NULL then NULL else SERIALIZE_OBJECT(ANYDATA.convertCollection("' || COLUMN_NAME || '")) end'
                 when TYPECODE = 'OBJECT'
                   then 'case when "' || COLUMN_NAME || '" is NULL then NULL else SERIALIZE_OBJECT(ANYDATA.convertObject("' || COLUMN_NAME || '")) end'
                 /*     
                 ** Comment out unsupported scalar data types and Object types
                 */
                 when DATA_TYPE in ('LONG','LONG RAW')
                   then '''"' || COLUMN_NAME || '". Unsupported data type ["' || DATA_TYPE || '"]'''
                 else
                   '"' || COLUMN_NAME || '"'
               end
        order by INTERNAL_COLUMN_ID) as T_VC4000_TABLE) EXPORT_SELECT_LIST
	   ,cast(collect(
		       /* Cast JSON representation back into SQL data type where implicit coversion does happen or results in incorrect results */
		       case
			     when DATA_TYPE = 'BFILE'
				    then 'case when "' || COLUMN_NAME || '" is NULL then NULL else OBJECT_SERIALIZATION.CHAR2BFILE("' || COLUMN_NAME || '") end'
			     when DATA_TYPE = 'XMLTYPE'
				    then 'case when "' || COLUMN_NAME || '" is NULL then NULL else XMLTYPE("' || COLUMN_NAME || '") end'
				 when DATA_TYPE = 'ANYDATA'
				    --- ### TODO - Better deserialization of ANYDATA.
				    then 'case when "' || COLUMN_NAME || '" is NULL then NULL else ANYDATA.convertVARCHAR2("' || COLUMN_NAME || '") end'
				 when TYPECODE = 'COLLECTION'
			       then '"#' || DATA_TYPE || '"("' || COLUMN_NAME || '")'
				 when TYPECODE = 'OBJECT'
  				   then '"#' || DATA_TYPE || '"("' || COLUMN_NAME || '")'
			     when DATA_TYPE = 'BLOB'
    		        $IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
				    then 'case when "' || COLUMN_NAME || '" is NULL then NULL else OBJECT_SERIALIZATION.HEXBINARY2BLOB("' || COLUMN_NAME || '") end'
				    $ELSE
				    then 'case when "' || COLUMN_NAME || '" is NULL then NULL when substr("' || COLUMN_NAME || '",1,15) = ''BLOB2HEXBINARY:'' then NULL else HEXTORAW("' || COLUMN_NAME || '") end'
				 $END
				 else
				    '"' || COLUMN_NAME || '"'
			   end
	     ORDER BY INTERNAL_COLUMN_ID) as T_VC4000_TABLE) IMPORT_SELECT_LIST
       ,cast(collect(
               /* JSON_TABLE column patterns in the form: COLUMN_NAME DATA_TYPE PATH '$[idx]' */
               '"' || COLUMN_NAME || '" ' ||
               case
                 /* Map data types not supported by JSON_TABLE to data types supported by JSON_TABLE */
                 when DATA_TYPE in ('CHAR','NCHAR','NVARCHAR2','RAW','LONG','LONG RAW','BFILE','ROWID','UROWID') or DATA_TYPE like 'INTERVAL%'
                   then 'VARCHAR2'
                 when DATA_TYPE like 'TIMESTAMP%WITH LOCAL TIME ZONE'
                   then 'TIMESTAMP WITH TIME ZONE'
                 /* Oracle Data types BLOB, XMLTYPE, NCLOB are not supported by JSON_TABLE */
                 when DATA_TYPE in ('XMLTYPE','CLOB','NCLOB','BLOB') or TYPECODE is not NULL
                   $IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
                   then 'CLOB'
                   $ELSIF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
                   then 'VARCHAR2(32767)'
                   $ELSE
                   then 'VARCHAR2(4000)'
                   $END
               else
                 DATA_TYPE
               end
         order by INTERNAL_COLUMN_ID) as T_VC4000_TABLE) COLUMN_PATTERN_LIST
    from ALL_ALL_TABLES aat
         inner join ALL_TAB_COLS atc
                 on atc.OWNER = aat.OWNER
                and atc.TABLE_NAME = aat.TABLE_NAME
    left outer join ALL_TYPES at
                 on at.TYPE_NAME = atc.DATA_TYPE
                and at.OWNER = atc.DATA_TYPE_OWNER
    left outer join ALL_MVIEWS amv
		         on amv.OWNER = aat.OWNER
		        and amv.MVIEW_NAME = aat.TABLE_NAME
   where aat.STATUS = 'VALID'
     and aat.DROPPED = 'NO'
     and aat.TEMPORARY = 'N'
     and aat.EXTERNAL = 'NO'
     and aat.NESTED = 'NO'
     and aat.SECONDARY = 'N'
     and (aat.IOT_TYPE is NULL or aat.IOT_TYPE = 'IOT')
     and (
           ((TABLE_TYPE is NULL) and (HIDDEN_COLUMN = 'NO'))
         or 
           ((TABLE_TYPE is not NULL) and (COLUMN_NAME in ('SYS_NC_ROWINFO$','SYS_NC_OID$','ACLOID','OWNERID')))
         )        
	 and amv.MVIEW_NAME is NULL
     and aat.OWNER = P_SOURCE_SCHEMA
   group by aat.OWNER, aat.TABLE_NAME;
   
  V_FIRST_ROW BOOLEAN := TRUE;
  V_DESERIALIZTION_LIST CLOB;
begin
--
$IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
--
  DBMS_LOB.CREATETEMPORARY(SQL_STATEMENT,TRUE,DBMS_LOB.CALL);

  declare
    V_BFILE_COUNT     NUMBER := 0;
    V_BLOB_COUNT      NUMBER := 0;
    V_ANYDATA_COUNT   NUMBER := 0;
    V_TABLE_NAME_LIST T_VC4000_TABLE := T_VC4000_TABLE();
  begin 
    for t in getTableMetadata loop  
      V_BFILE_COUNT    := V_BFILE_COUNT   + t.BFILE_COUNT;
      V_BLOB_COUNT     := V_BLOB_COUNT    + t.BLOB_COUNT;
      V_ANYDATA_COUNT  := V_ANYDATA_COUNT + t.ANYDATA_COUNT;
      V_TABLE_NAME_LIST.extend();
      V_TABLE_NAME_LIST(V_TABLE_NAME_LIST.count) := t.TABLE_NAME;
 
      declare
        V_COLUMN_LIST         CLOB := TABLE_TO_LIST(t.COLUMN_LIST);
	    V_DATA_TYPE_LIST      CLOB := TABLE_TO_LIST(t.DATA_TYPE_LIST);
		V_EXPORT_SELECT_LIST  CLOB := TABLE_TO_LIST(t.EXPORT_SELECT_LIST);
		V_COLUMN_PATTERN_LIST CLOB;
      begin
        for i in 1 .. t.COLUMN_PATTERN_LIST.count() loop
          t.COLUMN_PATTERN_LIST(i) := t.COLUMN_PATTERN_LIST(i) || ' PATH ''$[' || TO_CHAR(i-1) || ']''';
        end loop;
		V_COLUMN_PATTERN_LIST := TABLE_TO_LIST(t.COLUMN_PATTERN_LIST);

        /*
        **
        ** PL/SQL JSON_OBJECT does not support CLOB return, even in 18.1
        **
        */

        select JSON_OBJECT(
                 'owner'            value t.OWNER
                ,'tableName'        value t.TABLE_NAME
                ,'columns'          value V_COLUMN_LIST
                ,'dataTypes'        value V_DATA_TYPE_LIST
                ,'exportSelectList' value V_EXPORT_SELECT_LIST
                ,'columnPatterns'   value V_COLUMN_PATTERN_LIST
                 $IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
                 returning CLOB
                 $ELSIF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
                 returning VARCHAR2(32767)
                $ELSE
                returning VARCHAR2(4000)
                $END
               )
          into V_TABLE_METADATA
          from dual;
      exception
        when OTHERS then
          V_TABLE_METADATA := JSON_OBJECT(
                                 'tableName' value t.TABLE_NAME
                                ,'error'     value 'ORA-' || SQLCODE
                                ,'message'   value SQLERRM
                               );
      end;  
	  
    end loop;
    V_DESERIALIZTION_LIST := GENERATE_WITH_CLAUSE(P_SOURCE_SCHEMA, V_TABLE_NAME_LIST, V_BFILE_COUNT, V_BLOB_COUNT, V_ANYDATA_COUNT, SQL_STATEMENT);
  end; 
    
  V_SQL_FRAGMENT := 'select JSON_OBJECT(
                              ''systemInformation''
                              value JSON_OBJECT(
	                                  ''date''            value SYS_EXTRACT_UTC(SYSTIMESTAMP)
	                                 ,''schema''          value P_SOURCE_SCHEMA
		                             ,''exportVersion''   value JSON_EXPORT.EXPORT_VERSION()' || C_NEWLINE ||
									$IF JSON_FEATURE_DETECTION.TREAT_AS_JSON_SUPPORTED $THEN
		                            ',''jsonFeatures''    value treat(JSON_EXPORT.JSON_FEATURES() as JSON)' || C_NEWLINE ||
									$ELSE
		                            ',''jsonFeatures''    value JSON_QUERY((JSON_EXPORT.JSON_FEATURES(),''$'')' || C_NEWLINE ||
									$END
	                                ',''sessionUser''     value SYS_CONTEXT(''USERENV'',''SESSION_USER'')
		                             ,''dbName''          value SYS_CONTEXT(''USERENV'',''DB_NAME'')
		                             ,''serverHostName''  value SYS_CONTEXT(''USERENV'',''SERVER_HOST'')
		                             ,''databaseVersion'' value JSON_EXPORT.DATABASE_RELEASE()
		                             ,''nlsInformation''  value JSON_OBJECTAGG(parameter, value)
	                                )
							  ),
    						  ''metadata'' 
							  value' || C_NEWLINE ||
                             $IF JSON_FEATURE_DETECTION.TREAT_AS_JSON_SUPPORTED $THEN
				             '  (select JSON_OBJECTAGG(TABLE_NAME,TREAT(TABLE_METADATA as JSON) returning CLOB) from TABLE(:JSON)),'|| C_NEWLINE ||
	    		             $ELSE
                             '  (select JSON_OBJECTAGG(TABLE_NAME,JSON_QUERY(TABLE_METADATA, ''$'' RETURNING CLOB) returning CLOB) from TABLE(:JSON)),' || C_NEWLINE ||
                             $END
                              '''data'' 
							   value JSON_OBJECT(' || C_NEWLINE;
  
  DBMS_LOB.WRITEAPPEND(SQL_STATEMENT,length(V_SQL_FRAGMENT),V_SQL_FRAGMENT);

  for t in getTableMetadata loop  
    V_SQL_FRAGMENT := C_SINGLE_QUOTE || t.TABLE_NAME || C_SINGLE_QUOTE || ' value ( select JSON_ARRAYAGG(JSON_ARRAY(';
    if (not V_FIRST_ROW) then
      V_SQL_FRAGMENT := ',' || V_SQL_FRAGMENT;
    end if;
    V_FIRST_ROW := FALSE;
    DBMS_LOB.WRITEAPPEND(SQL_STATEMENT,length(V_SQL_FRAGMENT),V_SQL_FRAGMENT);
    DBMS_LOB.APPEND(SQL_STATEMENT,TABLE_TO_LIST(t.EXPORT_SELECT_LIST));
    V_SQL_FRAGMENT := ' NULL on NULL returning ' || C_RETURN_TYPE || ') returning ' || C_RETURN_TYPE || ') from "' || t.OWNER || '"."' || t.TABLE_NAME || '"';
    if (ROW_LIMIT > -1) then
      V_SQL_FRAGMENT := V_SQL_FRAGMENT || 'where ROWNUM < ' || ROW_LIMIT;
    end if;
    V_SQL_FRAGMENT :=  V_SQL_FRAGMENT || ')' || C_NEWLINE;
    DBMS_LOB.WRITEAPPEND(SQL_STATEMENT,length(V_SQL_FRAGMENT),V_SQL_FRAGMENT);
  end loop;

  V_SQL_FRAGMENT := '             returning ' || C_RETURN_TYPE || C_NEWLINE
                 || '           )' || C_NEWLINE
                 || '         returning ' || C_RETURN_TYPE || C_NEWLINE
                 || '       )' || C_NEWLINE
                 || '  from DUAL';
  DBMS_LOB.WRITEAPPEND(SQL_STATEMENT,length(V_SQL_FRAGMENT),V_SQL_FRAGMENT);
-- 
$ELSE
--
  declare
    V_SQL_STATEMENT       CLOB;
    V_TABLE_METADATA      CLOB;
  begin
    EXPORT_METADATA_CACHE := T_EXPORT_METADATA_TABLE();
    for t in getTableMetadata loop  
      EXPORT_METADATA_CACHE.extend();
      EXPORT_METADATA_CACHE(EXPORT_METADATA_CACHE.count).OWNER := t.OWNER;
      EXPORT_METADATA_CACHE(EXPORT_METADATA_CACHE.count).TABLE_NAME := t.TABLE_NAME;

      DBMS_LOB.CREATETEMPORARY(V_SQL_STATEMENT,TRUE,DBMS_LOB.CALL);
      V_DESERIALIZTION_LIST := GENERATE_WITH_CLAUSE(P_SOURCE_SCHEMA, t.TABLE_NAME, t.BFILE_COUNT, t.BLOB_COUNT, t.ANYDATA_COUNT, V_SQL_STATEMENT); 
      V_SQL_FRAGMENT := 'select JSON_ARRAY(';
      DBMS_LOB.WRITEAPPEND(V_SQL_STATEMENT,length(V_SQL_FRAGMENT),V_SQL_FRAGMENT);
      DBMS_LOB.APPEND(V_SQL_STATEMENT,TABLE_TO_LIST(t.EXPORT_SELECT_LIST));
      V_SQL_FRAGMENT := ' NULL on NULL returning '|| C_RETURN_TYPE 
                      --  ### if only || ' DEFAULT ''["ROW[['' || TO_CHAR(ROWID) || '']: Maximum return size (' || C_MAX_OUTPUT_SIZE || ') for JSON_ARRAY operator exceeded."]'' ON ERROR 
                      || ') from "' || t.OWNER || '"."' || t.TABLE_NAME || '"';
      if (ROW_LIMIT > -1) then
        V_SQL_FRAGMENT := V_SQL_FRAGMENT || 'where ROWNUM < ' || ROW_LIMIT;
      end if;
      DBMS_LOB.WRITEAPPEND(V_SQL_STATEMENT,length(V_SQL_FRAGMENT),V_SQL_FRAGMENT);
      EXPORT_METADATA_CACHE(EXPORT_METADATA_CACHE.count).SQL_STATEMENT := V_SQL_STATEMENT;  

      declare
        V_COLUMN_LIST         CLOB := TABLE_TO_LIST(t.COLUMN_LIST);
	    V_DATA_TYPE_LIST      CLOB := TABLE_TO_LIST(t.DATA_TYPE_LIST);
		V_EXPORT_SELECT_LIST  CLOB := TABLE_TO_LIST(t.EXPORT_SELECT_LIST);
		V_IMPORT_SELECT_LIST  CLOB := TABLE_TO_LIST(t.IMPORT_SELECT_LIST);
		V_COLUMN_PATTERN_LIST CLOB;
      begin
        for i in 1 .. t.COLUMN_PATTERN_LIST.count() loop
          t.COLUMN_PATTERN_LIST(i) := t.COLUMN_PATTERN_LIST(i) || ' PATH ''$[' || TO_CHAR(i-1) || ']''';
        end loop;
		V_COLUMN_PATTERN_LIST := TABLE_TO_LIST(t.COLUMN_PATTERN_LIST);

        /*
        **
        ** PL/SQL JSON_OBJECT does not support CLOB return, even in 18.1
        **
        */

        select JSON_OBJECT(
                 'owner'                       value t.OWNER
                ,'tableName'                   value t.TABLE_NAME
                ,'columns'                     value V_COLUMN_LIST
                ,'dataTypes'                   value V_DATA_TYPE_LIST
                ,'exportSelectList'            value V_EXPORT_SELECT_LIST
				,'insertSelectList'            value V_IMPORT_SELECT_LIST
				,'deserializationFunctions'    value V_DESERIALIZTION_LIST
                ,'columnPatterns'              value V_COLUMN_PATTERN_LIST
                 $IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
                 returning CLOB
                 $ELSIF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
                 returning VARCHAR2(32767)
                $ELSE
                returning VARCHAR2(4000)
                $END
               )
          into V_TABLE_METADATA
          from dual;
      exception
        when OTHERS then
          V_TABLE_METADATA := JSON_OBJECT(
                                 'tableName' value t.TABLE_NAME
                                ,'error'     value 'ORA-' || SQLCODE
                                ,'message'   value SQLERRM
                               );
      end;  
      EXPORT_METADATA_CACHE(EXPORT_METADATA_CACHE.count).METADATA := V_TABLE_METADATA;  
    end loop;
  end;  
$END
--
end;
--
$IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
--
function EXPORT_SCHEMA(P_SOURCE_SCHEMA VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CURRENT_SCHEMA')))
return CLOB
as
  V_JSON_DOCUMENT CLOB;
  V_CURSOR      SYS_REFCURSOR;
begin
  GENERATE_STATEMENT(P_SOURCE_SCHEMA);
  open V_CURSOR for SQL_STATEMENT;
  fetch V_CURSOR into V_JSON_DOCUMENT;
  close V_CURSOR;
  return V_JSON_DOCUMENT;
end;
--  
$ELSE
--
procedure PROCESS_WIDE_TABLE(P_METADATA_INDEX NUMBER, P_JSON_DOCUMENT IN OUT CLOB)
as
   C_SELECT_LIST_START    CONSTANT VARCHAR2(32) := 'select JSON_ARRAY(';
   C_SELECT_LIST_END      CONSTANT VARCHAR2(32) := ' NULL on NULL';
   V_SQL_STATEMENT        CLOB;
   V_SELECT_LIST          T_VC4000_TABLE := T_VC4000_TABLE();
   V_SELECT_LIST_ITEM     VARCHAR2(4000);
   V_SELECT_LIST_START    PLS_INTEGER;
   V_SELECT_LIST_END      PLS_INTEGER;
   V_FROM_CLAUSE_START    PLS_INTEGER;
   V_CURRENT_OFFSET       PLS_INTEGER;
   V_COLUMN_OFFSET        PLS_INTEGER;
   
   V_FROM_WHERE_CLAUSE    VARCHAR2(32767);
   
   V_COLUMN_LIST          T_VC4000_TABLE := T_VC4000_TABLE();
   V_COLUMN_NAME          VARCHAR2(132);
   V_COLUMN_NAME_START    PLS_INTEGER;
   V_COLUMN_NAME_END      PLS_INTEGER;

   V_CURSOR               SYS_REFCURSOR;
   V_CURSOR_ID            NUMBER := DBMS_SQL.OPEN_CURSOR;
   V_COLUMN_DESCRIPTIONS  DBMS_SQL.DESC_TAB2;
   V_COLUMN_COUNT         NUMBER;
   V_COLUMN_VALUE         VARCHAR2(32767);
   V_FIRST_ROW            BOOLEAN := TRUE;
   V_FIRST_COLUMN         BOOLEAN := TRUE;

   V_INDEX                PLS_INTEGER;
begin
   V_SQL_STATEMENT      := EXPORT_METADATA_CACHE(P_METADATA_INDEX).SQL_STATEMENT;
   V_SELECT_LIST_START  := DBMS_LOB.INSTR(V_SQL_STATEMENT,C_SELECT_LIST_START) + LENGTH(C_SELECT_LIST_START);
   V_SELECT_LIST_END    := DBMS_LOB.INSTR(V_SQL_STATEMENT,C_SELECT_LIST_END) - 1;
   V_CURRENT_OFFSET := V_SELECT_LIST_START;
   loop
     V_COLUMN_OFFSET := DBMS_LOB.INSTR(V_SQL_STATEMENT,',',V_CURRENT_OFFSET); 
     exit when ((V_COLUMN_OFFSET < 1) or (V_COLUMN_OFFSET > V_SELECT_LIST_END));
     V_SELECT_LIST.extend;
     V_COLUMN_LIST.extend;
     V_INDEX := V_SELECT_LIST.count;
     V_SELECT_LIST_ITEM  := DBMS_LOB.SUBSTR(V_SQL_STATEMENT,V_COLUMN_OFFSET - V_CURRENT_OFFSET,V_CURRENT_OFFSET);

     V_COLUMN_NAME_START := instr(V_SELECT_LIST_ITEM,'"');
     V_COLUMN_NAME_END   := instr(V_SELECT_LIST_ITEM,'"',V_COLUMN_NAME_START+1)+1;
     V_COLUMN_NAME       := substr(V_SELECT_LIST_ITEM,V_COLUMN_NAME_START,V_COLUMN_NAME_END-V_COLUMN_NAME_START);

     V_SELECT_LIST_ITEM  := 'JSON_ARRAY(' 
                         || V_SELECT_LIST_ITEM 
                         || ' NULL on NULL RETURNING VARCHAR2(' 
                         || C_MAX_OUTPUT_SIZE || ')) ' 
                        || V_COLUMN_NAME;
                        
     V_SELECT_LIST(V_INDEX) :=  V_SELECT_LIST_ITEM;
     v_COLUMN_LIST(V_INDEX) :=  V_COLUMN_NAME;
     V_CURRENT_OFFSET := V_COLUMN_OFFSET + 1;
   end loop;

   V_FROM_CLAUSE_START := DBMS_LOB.INSTR(V_SQL_STATEMENT,' from ',V_SELECT_LIST_END);
   V_FROM_WHERE_CLAUSE := DBMS_LOB.SUBSTR(V_SQL_STATEMENT,32767,V_FROM_CLAUSE_START);
   DBMS_LOB.TRIM(V_SQL_STATEMENT,V_SELECT_LIST_START - 12);
   DBMS_LOB.APPEND(V_SQL_STATEMENT,TABLE_TO_LIST(V_SELECT_LIST));
   DBMS_LOB.APPEND(V_SQL_STATEMENT,TO_CLOB(V_FROM_WHERE_CLAUSE));
   EXPORT_METADATA_CACHE(P_METADATA_INDEX).SQL_STATEMENT := V_SQL_STATEMENT;
   V_FIRST_ROW := TRUE;
   open V_CURSOR for EXPORT_METADATA_CACHE(P_METADATA_INDEX).SQL_STATEMENT;
   V_CURSOR_ID := DBMS_SQL.TO_CURSOR_NUMBER(V_CURSOR);
   DBMS_SQL.DESCRIBE_COLUMNS2(V_CURSOR_ID, V_COLUMN_COUNT, V_COLUMN_DESCRIPTIONS);
   V_COLUMN_NAME_START := 2;
   for i in 1..V_COLUMN_COUNT loop
     DBMS_SQL.DEFINE_COLUMN(V_CURSOR_ID,i,V_COLUMN_LIST(i),32767);
   end loop;
   while (DBMS_SQL.FETCH_ROWS(V_CURSOR_ID) > 0) loop
     if (not V_FIRST_ROW) then
       DBMS_LOB.WRITEAPPEND(P_JSON_DOCUMENT,1,',');
     end if;
     V_FIRST_ROW := FALSE;
     V_FIRST_COLUMN := TRUE;
     DBMS_LOB.WRITEAPPEND(P_JSON_DOCUMENT,1,'[');
     for i in 1..V_COLUMN_COUNT loop
       DBMS_SQL.COLUMN_VALUE(V_CURSOR_ID,i,V_COLUMN_VALUE);
       V_COLUMN_VALUE := substr(V_COLUMN_VALUE,2,length(V_COLUMN_VALUE)-2);
       if (not V_FIRST_COLUMN) then
         V_COLUMN_VALUE := ',' || V_COLUMN_VALUE;
       end if;
       V_FIRST_COLUMN := FALSE;
       DBMS_LOB.WRITEAPPEND(P_JSON_DOCUMENT,length(V_COLUMN_VALUE),V_COLUMN_VALUE);
     end loop;
     DBMS_LOB.WRITEAPPEND(P_JSON_DOCUMENT,1,']');
   end loop;
   DBMS_SQL.CLOSE_CURSOR(V_CURSOR_ID);
end;
--
procedure APPEND_SYSTEM_INFORMATION(P_SOURCE_SCHEMA VARCHAR2, P_JSON_DOCUMENT IN OUT NOCOPY CLOB)
as
  V_SYSTEM_INFORMATION VARCHAR2(32767);
begin
  select JSON_OBJECT(
           'systemInformation'
		   value JSON_OBJECT(
	               'date'            value SYS_EXTRACT_UTC(SYSTIMESTAMP)
	              ,'schema'          value P_SOURCE_SCHEMA
		          ,'exportVersion'   value JSON_EXPORT.EXPORT_VERSION()
		          ,'jsonFeatures'    value JSON_QUERY(JSON_EXPORT.JSON_FEATURES(),'$')
	              ,'sessionUser'     value SYS_CONTEXT('USERENV','SESSION_USER')
		          ,'dbName'          value SYS_CONTEXT('USERENV','DB_NAME')
		          ,'serverHostName'  value SYS_CONTEXT('USERENV','SERVER_HOST')
		          ,'databaseVersion' value JSON_EXPORT.DATABASE_RELEASE()
		          ,'nlsInformation'  value JSON_OBJECTAGG(parameter, value)
	             )
		 ) SYSTEM_INFORMATION
	into V_SYSTEM_INFORMATION
    from NLS_DATABASE_PARAMETERS;
  DBMS_LOB.WRITEAPPEND(P_JSON_DOCUMENT,length(V_SYSTEM_INFORMATION)-2,substr(V_SYSTEM_INFORMATION,2,length(V_SYSTEM_INFORMATION)-2));
end;
--
procedure APPEND_DDL_OBJECT(P_SOURCE_SCHEMA VARCHAR2, P_JSON_DOCUMENT IN OUT NOCOPY CLOB)
as
  V_JSON_FRAGMENT VARCHAR2(4000);
  V_FIRST_ITEM    BOOLEAN := TRUE;
  V_CURSOR        SYS_REFCURSOR;

  cursor getDDLStatements
  is
  $IF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
  select JSON_ARRAY(COLUMN_VALUE returning  VARCHAR2(32767)) DDL
  $ELSE
  select JSON_ARRAY(COLUMN_VALUE returning  VARCHAR2(4000)) DDL
  $END
    from TABLE(JSON_EXPORT_DDL.FETCH_DDL_STATEMENTS(P_SOURCE_SCHEMA));

begin
  V_JSON_FRAGMENT := '"ddl":[';
  DBMS_LOB.WRITEAPPEND(P_JSON_DOCUMENT,length(V_JSON_FRAGMENT),V_JSON_FRAGMENT);
  for r in getDDLStatements loop
	if (NOT V_FIRST_ITEM) then
      DBMS_LOB.WRITEAPPEND(P_JSON_DOCUMENT,1,',');
	end if;
    V_FIRST_ITEM := FALSE;
	-- Cursor returns a JSON_ARRAY containing 1 Element which is a correctly encoded JSON string eg ["...."]
	-- Use String manipulation to remove the leading and trailing [] characters and write the result to the LOB
    DBMS_LOB.WRITEAPPEND(P_JSON_DOCUMENT,LENGTH(r.DDL)-2,substr(r.DDL,2,LENGTH(r.DDL)-2));
  end loop;
  DBMS_LOB.WRITEAPPEND(P_JSON_DOCUMENT,1,']');
end;
--
procedure APPEND_METADATA_OBJECT(P_JSON_DOCUMENT IN OUT NOCOPY CLOB)
as
  V_JSON_FRAGMENT VARCHAR2(4000);
begin
  V_JSON_FRAGMENT := '"metadata":{';
  DBMS_LOB.WRITEAPPEND(P_JSON_DOCUMENT,length(V_JSON_FRAGMENT),V_JSON_FRAGMENT);
  for i in 1 .. EXPORT_METADATA_CACHE.count loop
    V_JSON_FRAGMENT := '"' || EXPORT_METADATA_CACHE(i).table_name || '":';
	if (i > 1) then
  	  V_JSON_FRAGMENT := ',' || V_JSON_FRAGMENT;
	end if;
    DBMS_LOB.WRITEAPPEND(P_JSON_DOCUMENT,length(V_JSON_FRAGMENT),V_JSON_FRAGMENT);
	DBMS_LOB.APPEND(P_JSON_DOCUMENT,EXPORT_METADATA_CACHE(i).METADATA);
  end loop;
  DBMS_LOB.WRITEAPPEND(P_JSON_DOCUMENT,1,'}');
end;
--
function EXPORT_SCHEMA(P_SOURCE_SCHEMA VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CURRENT_SCHEMA'))
return CLOB
as
  JSON_ARRAY_OVERFLOW EXCEPTION; PRAGMA EXCEPTION_INIT (JSON_ARRAY_OVERFLOW, -40478);

  V_JSON_DOCUMENT CLOB;
  V_CURSOR        SYS_REFCURSOR;

  V_JSON_FRAGMENT VARCHAR2(4000);
  
  V_FIRST_TABLE   BOOLEAN := TRUE;
  V_FIRST_ITEM    BOOLEAN := TRUE;
--  
  $IF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
  V_JSON_ARRAY VARCHAR2(32767);
  $ELSE
  V_JSON_ARRAY VARCHAR2(4000);
  $END  
--  
  V_START_TABLE_DATA NUMBER;
begin
  GENERATE_STATEMENT(P_SOURCE_SCHEMA);
  DBMS_LOB.CREATETEMPORARY(V_JSON_DOCUMENT,TRUE,DBMS_LOB.CALL);
  DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,1,'{');

  APPEND_SYSTEM_INFORMATION(P_SOURCE_SCHEMA,V_JSON_DOCUMENT);
  DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,1,',');

  APPEND_DDL_OBJECT(P_SOURCE_SCHEMA,V_JSON_DOCUMENT);
  DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,1,',');

  APPEND_METADATA_OBJECT(V_JSON_DOCUMENT);
  DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,1,',');

  V_JSON_FRAGMENT := '"data":{';
  DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,length(V_JSON_FRAGMENT),V_JSON_FRAGMENT);
  for i in 1 .. EXPORT_METADATA_CACHE.count loop
    V_JSON_FRAGMENT := '"' || EXPORT_METADATA_CACHE(i).table_name || '":[';
    if (not V_FIRST_TABLE) then 
      V_JSON_FRAGMENT := ',' || V_JSON_FRAGMENT;
    end if;
    V_FIRST_TABLE := false;
    DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,length(V_JSON_FRAGMENT),V_JSON_FRAGMENT);
    V_START_TABLE_DATA := DBMS_LOB.GETLENGTH(V_JSON_DOCUMENT);
    V_FIRST_ITEM := TRUE;
    open V_CURSOR for EXPORT_METADATA_CACHE(i).SQL_STATEMENT;
    loop 
      begin
        fetch V_CURSOR into V_JSON_ARRAY;
        exit when V_CURSOR%notfound;      
        if (not V_FIRST_ITEM) then
          DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,1,',');
        end if;
        V_FIRST_ITEM := FALSE;
        DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,length(V_JSON_ARRAY),V_JSON_ARRAY);
      exception
        when JSON_ARRAY_OVERFLOW then
          DBMS_LOB.TRIM(V_JSON_DOCUMENT,V_START_TABLE_DATA);
          PROCESS_WIDE_TABLE(i,V_JSON_DOCUMENT);
          exit;
        when OTHERS then
          raise;
      end;
    end loop;
    close V_CURSOR;
    DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,1,']');
  end loop;
  DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,1,'}');
  DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,1,'}');
  return V_JSON_DOCUMENT;
end;
--
$END
--
end;
/
show errors
--
spool off
--
