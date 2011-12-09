component displayname="PostalMethods" hint="PostalMethods Web-to-Postal Web Service v2009-02-26 wrapper" {


    /*
     * Version 0.5 — Dec 9, 2011
     * Home page: https://github.com/sgalashyn/postalmethods
     * API docs: http://www.postalmethods.com/postal-api
     */


    /*
     * TODO:
     * - Prepare usage examples and README.
     * - Include webhook parsing methods (?)
     */


    variables.apiurl.post = "https://api.postalmethods.com/2009-02-26/PostalWS.asmx/";
    variables.apiurl.soap = "https://api.postalmethods.com/2009-02-26/PostalWS.asmx?WSDL";
    variables.username = "";
    variables.password = "";
    variables.successCode = "-3000";
    variables.statusCodes = {};
    variables.useragent = "";
    variables.verbose = false;



    /*
     * @username Docmail user name
     * @password Password for the user
     * @useragent Custom useragent for HTTP requests
     * @verbose Append extended info to the output
     * @statuscodes Full path to status codes JSON file
     */
    public any function init(
        required string username,
        required string password,
        required string statuscodes,
        string useragent = server.ColdFusion.ProductName,
        boolean verbose = false
    )
    hint="Component initialization" {

        setUsername(arguments.username);
        setPassword(arguments.password);
        setUserAgent(arguments.useragent);
        setVerbose(arguments.verbose);

        variables.statusCodes = DeserializeJSON(FileRead(arguments.statuscodes));

        return this;

    }



    /*
     * INTERACTION WITH API
     */


    /*
     * @method API method name to invoke
     * @defaults Required default request dataset
     * @params Actual arguments of the invokation
     * @acesspoint API access point: soap or post
     * @xpath XPath query to search through returned XML
     */
    private struct function invokeMethod(
        required string method,
        required struct defaults,
        required struct params,
        required string acesspoint,
        string xpath = ""
    )
    hint="Perform request to the API: invoke remote method and handle response" {

        var local = {};


        local.output = {};


        try {


            // prepare the request arguments collection

            local.args = StructCopy(arguments.defaults);

            local.args.Username = getUsername();
            local.args.Password = getPassword();


            // override the values with actual arguments

            for (local.key in arguments.params) {
                if (StructKeyExists(local.args, local.key)) {
                    local.args[local.key] = arguments.params[local.key];
                }
            }


            if (arguments.acesspoint EQ "soap") {


                // use SOAP API for the 'action' methods

                variables.service = CreateObject("webservice", variables.apiurl.soap);

                // evaluate has acceptable performance for web-service invokation which is pretty slow
                // possible hacking with cfinvoke wrapping would affect the library code badly
                // hopefully ACF 10 will support following syntax, Railo does this already:
                // local.result = variables.service[arguments.method](argumentCollection = local.args);

                local.result = Evaluate("variables.service.#arguments.method#(argumentCollection = local.args)");

                if (isNumeric(local.result)) {

                    if (local.result GT 0 OR local.result EQ variables.successCode) {

                        local.output.data = local.result;
                        local.output.fault = false;

                    }
                    else if (StructKeyExists(getStatusCodes(), local.result)) {

                        throw(message=getStatusMessage(local.result), detail=getStatusDetail(local.result));

                    }
                    else {

                        throw(message="Unknown error code: #local.result#");

                    }

                }
                else {

                    local.output.data = local.result;
                    local.output.fault = false;

                }


            }
            else {


                // use HTTP POST API for GetXXX methods

                // Note: Railo (specifically, its Apache Axis) does not process
                // some requests properly, plus XML response is easier to handle

                local.service = new http(
                    url = "#variables.apiurl.post##arguments.method#",
                    method = "post",
                    useragent = getUserAgent()
                );

                for (local.key in local.args) {
                    local.service.addParam(type="formfield", name=local.key, value=local.args[local.key]);
                }

                local.result = local.service.send().getPrefix();


                if (local.result.responseheader.status_code EQ 200) {

                    // response can be XML or plain text

                    if (isXML(local.result.filecontent)) {

                        local.parsedXml = XMLParse(local.result.filecontent);

                        // ResultCode is only common node, other depend on method (duh!)
                        // codes are in status-codes.json or http://www.postalmethods.com/statuscodes

                        local.resultCode = XMLSearch(local.parsedXml, "string(//:ResultCode)");

                        if (local.resultCode EQ variables.successCode) {

                            // xpath comes from parent method

                            local.nodes = XMLSearch(local.parsedXml, arguments.xpath);

                            if (ListFind("GetUploadedFileDetails,GetStatus,GetDetails,GetDetailsExtended", arguments.method)) {

                                // XML to array of structures

                                local.result = [];

                                for (local.idx=1; local.idx LTE ArrayLen(local.nodes); local.idx++) {

                                    local.children = XMLSearch(local.nodes[local.idx], "*");

                                    local.values = {};

                                    for (local.indx=1; local.indx LTE ArrayLen(local.children); local.indx++) {
                                        local.values[ local.children[local.indx].xmlName ] = local.children[local.indx].XmlText;
                                    }

                                    ArrayAppend(local.result, local.values);

                                }

                            }
                            else {

                                // XML to structure

                                local.result = {};

                                for (local.idx=1; local.idx LTE ArrayLen(local.nodes); local.idx++) {
                                    local.result[ local.nodes[local.idx].XmlName ] = local.nodes[local.idx].XmlText;
                                }

                            }

                            local.output.data = local.result;
                            local.output.fault = false;

                        }
                        else if (StructKeyExists(getStatusCodes(), local.resultCode)) {

                            throw(message=getStatusMessage(local.resultCode), detail=getStatusDetail(local.resultCode));

                        }
                        else {

                            throw(message="Unknown error code: #local.resultCode#");

                        }

                    }
                    else {

                        local.output.data = local.result.filecontent;
                        local.output.fault = false;

                    }

                }
                else {

                    throw(message=local.result.filecontent, detail=local.result.errordetail);

                }


            }


        }
        catch (any exception) {

            local.output.fault = true;
            local.output.data = exception.Message;

            if (getVerbose()) {
                local.output.exception = exception;
            }

        }


        return local.output;


    }



    /*
     * API METHODS
     */


    /*
     * @FilePath Optional path to the document/template to upload with letter [custom helper]
     */
    public struct function SendLetter(string FilePath = "")
    hint="The SendLetter() method is the simplest way to send a letter through the PostalMethods service." {

        var defaults = {
            MyDescription = "",
            FileExtension = "",
            FileBinaryData = "",
            WorkMode = "Default"
        };

        if (FileExists(arguments.FilePath)) {
            defaults.FileExtension = ListLast(arguments.FilePath, '.');
            defaults.FileBinaryData = BinaryEncode(FileReadBinary(arguments.FilePath), "Base64");
        }

        return invokeMethod("SendLetter", defaults, arguments, "soap");

    }


    /*
     * @FilePath Optional path to the document/template to upload with letter [custom helper]
     */
    public struct function SendLetterAndAddress(string FilePath = "")
    hint="The SendLetterAndAddress() method is the simplest way to send a letter through the PostalMethods service." {

        var defaults = {
            MyDescription = "",
            FileExtension = "",
            FileBinaryData = "",
            WorkMode = "Default",
            AttentionLine1 = "",
            AttentionLine2 = "",
            Company = "",
            Address1 = "",
            Address2 = "",
            City = "",
            State = "",
            PostalCode = "",
            Country = ""
        };

        if (FileExists(arguments.FilePath)) {
            defaults.FileExtension = ListLast(arguments.FilePath, '.');
            defaults.FileBinaryData = BinaryEncode(FileReadBinary(arguments.FilePath), "Base64");
        }

        return invokeMethod("SendLetterAndAddress", defaults, arguments, "soap");

    }


    /*
     * @ImageSideFilePath Optional path to the file to use for image side [custom helper]
     * @AddressSideFilePath Optional path to the document/template to use for address side [custom helper]
     */
    public struct function SendPostcardAndAddress(
        string ImageSideFilePath = "",
        string AddressSideFilePath = ""
    )
    hint="The SendPostcardAndAddress() method is the simplest way to send postcards." {

        var defaults = {
            MyDescription = "",
            ImageSideFileType = "",
            ImageSideBinaryData = "",
            ImageSideScaling = "Default",
            AddressSideFileType = "",
            AddressSideBinaryData = "",
            WorkMode = "Default",
            PrintColor = "Default",
            PostcardSize = "Default",
            MailingPriority = "Default",
            AttentionLine1 = "",
            AttentionLine2 = "",
            Company = "",
            Address1 = "",
            Address2 = "",
            City = "",
            State = "",
            PostalCode = "",
            Country = ""
        };

        if (FileExists(arguments.ImageSideFilePath)) {
            defaults.ImageSideFileType = ListLast(arguments.ImageSideFilePath, '.');
            defaults.ImageSideBinaryData = BinaryEncode(FileReadBinary(arguments.ImageSideFilePath), "Base64");
        }

        if (FileExists(arguments.AddressSideFilePath)) {
            defaults.AddressSideFileType = ListLast(arguments.AddressSideFilePath, '.');
            defaults.AddressSideBinaryData = BinaryEncode(FileReadBinary(arguments.AddressSideFilePath), "Base64");
        }

        return invokeMethod("SendPostcardAndAddress", defaults, arguments, "soap");

    }


    /*
     * @ID See below ↓
     * Single Item: Matches the ID provided as the response for the original Web Service request.
     * Multiple Items: ID1,ID2,ID3. Response is provided for up to 1000 letters per query.
       Additional items are ignored. Items not assigned to the account or which the user
       has no permission to access are returned with a "No Permissions" status code.
     * Range Of Items: LowerID-HigherID. Response is provided for up to 1000 letters per query.
       Additional items are ignored. Items not assigned to the account or which the user
       has no permission to access will not be returned.
     */
    public struct function GetStatus(required string ID)
    hint="The GetStatus() method is the way to get status mailer reports." {

        var defaults = {
            ID = arguments.ID
        };

        return invokeMethod("GetStatus", defaults, arguments, "post", "//:LetterStatusAndDesc");

    }


    /*
     * @ID See GetStatus
     */
    public struct function GetDetails(required string ID)
    hint="The GetDetails() method is a way to get detailed mailer reports." {

        var defaults = {
            ID = arguments.ID
        };

        return invokeMethod("GetDetails", defaults, arguments, "post", "//:Details/:Details");

    }


    /*
     * @ID See GetStatus
     */
    public struct function GetDetailsExtended(required string ID)
    hint="The GetDetailsExtended() method is a way to get the full mailer details." {

        var defaults = {
            ID = arguments.ID
        };

        return invokeMethod("GetDetailsExtended", defaults, arguments, "post", "//:ExtendedDetails");

    }


    /*
     * @ID Matches the ID provided as the response to the original Web Service request.
     * @FilePath Optional path to the save the fetched PDF instead of returing binary data [custom helper]
     */
    public struct function GetPDF(required numeric ID, string FilePath = "")
    hint="The GetPDF() method is a way to get the PDF file used for printing the mailer as a binary file." {

        var defaults = {
            ID = arguments.ID
        };

        var res = invokeMethod("GetPDF", defaults, arguments, "post", "//:FileData");

        if (arguments.FilePath NEQ "") {
            FileWrite(arguments.FilePath, BinaryDecode(res.data.FileData, "Base64"));
            StructDelete(res.data, "FileData");
            return res;
        }
        else {
            return res;
        }

    }


    /*
     * @ID Matches the ID provided as the response to the original Web Service request.
     */
    public struct function CancelDelivery(required numeric ID)
    hint="The CancelDelivery() method is a way to cancel fulfillment of a mailer still not delivered to the postal service." {

        var defaults = {
            ID = arguments.ID
        };

        return invokeMethod("CancelDelivery", defaults, arguments, "soap");
    }


    /*
     * @FilePath Optional path to the document/template to upload [custom helper]
     */
    public struct function UploadFile(string FilePath = "")
    hint="The UploadFile() method is used to upload files for later usage." {

        var defaults = {
            MyFileName = "",
            FileBinaryData = "",
            Permissions = "Account",
            Description = "",
            Overwrite = false
        };

        if (FileExists(arguments.FilePath)) {
            defaults.MyFileName = GetFileFromPath(arguments.FilePath);
            defaults.FileBinaryData = BinaryEncode(FileReadBinary(arguments.FilePath), "Base64");
        }

        return invokeMethod("UploadFile", defaults, arguments, "soap");

    }


    /*
     * @MyFileName File name to delete, as provided in the UploadFile request
     */
    public struct function DeleteUploadedFile(required string MyFileName)
    hint="The DeleteUploadedFile() method is used to delete files from your storage." {

        var defaults = {
            MyFileName = arguments.MyFileName
        };

        return invokeMethod("DeleteUploadedFile", defaults, arguments, "soap");

    }


    public struct function GetUploadedFileDetails()
    hint="The GetUploadedFileDetails() method is used to show account files in storage." {

        var defaults = {};

        return invokeMethod("GetUploadedFileDetails", defaults, arguments, "post", "//:UploadedFiles/:FileDetails");

    }



    /*
     * HELPERS
     */


    public void function setUsername(required string username) hint="Set current username setting" {
        variables.username = arguments.username;
    }


    public string function getUsername() hint="Get current username setting" {
        return variables.username;
    }


    public void function setPassword(required string password) hint="Set current password setting" {
        variables.password = arguments.password;
    }


    public string function getPassword() hint="Get current password setting" {
        return variables.password;
    }


    public void function setUserAgent(required string useragent) hint="Set current useragent setting" {
        variables.useragent = arguments.useragent;
    }


    public string function getUserAgent() hint="Get current useragent setting" {
        return variables.useragent;
    }


    /*
     * @acesspoint API access point: soap or post
     */
    public string function getApiUrl(required string acesspoint) hint="Get target API URL by access point" {
        return variables.apiurl[arguments.acesspoint];
    }


    public void function setVerbose(required boolean verbose) hint="Set current verbose setting" {
        variables.verbose = arguments.verbose;
    }


    public boolean function getVerbose() hint="Get current verbose setting" {
        return variables.verbose;
    }


    public struct function getStatusCodes() hint="Get current statusCodes setting" {
        return variables.statusCodes;
    }


    /*
     * @code Result code for this Web Service request.
     */
    public string function getStatusMessage(required string code) hint="Get message string for given status code" {
        return variables.statusCodes[arguments.code].message;
    }


    /*
     * @code Result code for this Web Service request.
     */
    public string function getStatusDetail(required string code) hint="Get detail string for given status code" {
        return variables.statusCodes[arguments.code].detail;
    }



}