<!---

    This asset is a part of PostalMethods API wrapper https://github.com/sgalashyn/postalmethodss

    This script takes CSV file with status codes and generates JSON with structure.

    Structure can be used in code for displayng meaningful error messages by codes,
    because lazy PostalMethods developers did not bother to put text version
    of errors to the response XML.

    CSV is prepared by copy-pasting the "Web Service Result Codes" table contents,
    cleaning up multi-line stuff like "Common errors:" and applying batch replaces:
    (1) ';' to ','
    (2) '(\s){2,}' to ';' (regex)

    All status codes can be found here http://www.postalmethods.com/statuscodes

    Last generated for API v.2009-02-26

--->

<cfset csvPath = ExpandPath("status-codes.csv") />

<cfset codes = {} />

<cfloop file="#csvPath#" index="line">

    <cfset key = ListFirst(line, ";") />
    <cfset codes[key]["message"] = ListGetAt(line, 2, ";") />
    <cfset codes[key]["detail"] = ListLast(line, ";") />

</cfloop>

<!--- <cfdump var="#codes#" abort /> --->

<cffile action="write" file="status-codes.json" output="#SerializeJSON(codes)#" />
