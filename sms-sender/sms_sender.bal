// Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.package sample;

import wso2/sfdc37 as sf;
import wso2/twilio;
import ballerina/config;
import ballerina/log;
import ballerina/http;

# Represents Salesforce client endpoint.
endpoint sf:Client salesforceClient {
    clientConfig: {
        url: config:getAsString(SF_URL),
        auth: {
            scheme: http:OAUTH2,
            accessToken: config:getAsString(SF_ACCESS_TOKEN),
            refreshToken: config:getAsString(SF_REFRESH_TOKEN),
            clientId: config:getAsString(SF_CLIENT_ID),
            clientSecret: config:getAsString(SF_CLIENT_SECRET),
            refreshUrl: config:getAsString(SF_REFRESH_URL)
        }
    }
};

# Represents Twilio client endpoint.
endpoint twilio:Client twilioClient {
    accountSId: config:getAsString(TWILIO_ACCOUNT_SID),
    authToken: config:getAsString(TWILIO_AUTH_TOKEN)
};

# Main function to run the integration system.
#
# + args - Runtime parameters
public function main(string... args) {
    log:printDebug("Salesforce-Twilio Integration -> Sending promotional SMS to leads of Salesforce");
    string sampleQuery = "SELECT Name, Phone, Country FROM Lead WHERE Country = 'LK'";
    boolean result = sendSmsToLeads(sampleQuery);
    if (result) {
        log:printDebug("Salesforce-Twilio Integration -> Promotional SMS sending process successfully completed!");
    } else {
        log:printDebug("Salesforce-Twilio Integration -> Promotional SMS sending process failed!");
    }
}

# Utility function integrate Salesforce and Twilio connectors.

# + sfQuery - Query to be sent to Salesforce API
# + return - State of whether the process of sending SMS to leads are success or not
function sendSmsToLeads(string sfQuery) returns boolean {
    (map, boolean) leadsResponse = getLeadsData(sfQuery);
    map leadsDataMap;
    boolean isSuccess;
    (leadsDataMap, isSuccess) = leadsResponse;

    if (isSuccess){
        string messageBody = config:getAsString(TWILIO_MESSAGE);
        string fromMobile = config:getAsString(TWILIO_FROM_MOBILE);
        foreach k, v in leadsDataMap {
            string result = <string>v;
            string message = "Hi " + result + NEW_LINE_CHARACTER + messageBody;
            isSuccess = sendTextMessage(fromMobile, k, message);
            if (!isSuccess) {
                break;
            }
        }
    }
    return isSuccess;
}

# Returns a map consists of Lead's data.

# + leadQuery - Query to retrieve all Salesforce leads
# + return - Tuple of maap consists of Lead data and the indication of process is succss or not
function getLeadsData(string leadQuery) returns (map, boolean) {
    log:printDebug("Salesforce Connector -> Getting query results");
    map leadsMap;
    var response = salesforceClient->getQueryResult(leadQuery);
    match response {
        json jsonRes => {
            addRecordsToMap(jsonRes, leadsMap);
            while (jsonRes.nextRecordsUrl != null) {
                log:printDebug("Found new query result set!");
                string nextQueryUrl = jsonRes.nextRecordsUrl.toString();
                response = salesforceClient->getNextQueryResult(nextQueryUrl);
                match response {
                    json jsonNextRes => addRecordsToMap(jsonNextRes, leadsMap);
                    sf:SalesforceConnectorError err => {
                        log:printDebug("Salesforce Connector -> Failed to get leads data");
                        log:printError(err.message);
                        return (leadsMap, false);
                    }
                }
            }
        }
        sf:SalesforceConnectorError err => {
            log:printDebug("Salesforce Connector -> Failed to get leads data");
            log:printError(err.message);
            return (leadsMap, false);
        }
    }
    return (leadsMap, true);
}

# Utility function to add json records to map.

# + response - Json response
# + leadsMap - Map of leads to be added the record data
function addRecordsToMap(json response, map leadsMap) {
    json[] records = check <json[]>response.records;
    foreach rec in records {
        if (rec.Phone != null) {
            string key = rec.Phone.toString();
            string value = rec.Name.toString();
            leadsMap[key] = value;
        }
    }
}

# Utility function to send SMS.

# + fromMobile - from mobile number
# + toMobile - to mobile number
# + message - sending message
# + return - The status of sending SMS success or not
function sendTextMessage(string fromMobile, string toMobile, string message) returns boolean {
    var details = twilioClient->sendSms(fromMobile, toMobile, message);
    match details {
        twilio:SmsResponse smsResponse => {
            if (smsResponse.sid != EMPTY_STRING) {
                log:printDebug("Twilio Connector -> SMS successfully sent to " + toMobile);
                return true;
            }
        }
        twilio:TwilioError err => {
            log:printDebug("Twilio Connector -> SMS failed sent to " + toMobile);
            log:printError(err.message);
        }
    }
    return false;
}
