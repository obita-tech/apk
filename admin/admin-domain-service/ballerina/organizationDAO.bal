//
// Copyright (c) 2022, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
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
// under the License.
//

import ballerinax/postgresql;
import ballerina/log;
import ballerina/sql;
import wso2/apk_common_lib as commons;

isolated function addOrganizationDAO(Internal_Organization payload) returns Internal_Organization|commons:APKError {
    postgresql:Client | error dbClient  = getConnection();
    if dbClient is error {
        return e909401(dbClient);
    } else {
        postgresql:JsonBinaryValue namespace = new (payload.serviceNamespaces.toJson());
        sql:ParameterizedQuery query = `INSERT INTO ORGANIZATION(UUID, NAME, 
        DISPLAY_NAME,STATUS,NAMESPACE) VALUES (${payload.id},${payload.name},
        ${payload.displayName},${payload.enabled},${namespace})`;
        sql:ExecutionResult | sql:Error result =  dbClient->execute(query);
        if result is sql:ExecutionResult && result.affectedRowCount == 1 {
            boolean isVhostAdded = addVhostsDAO(dbClient, payload);
            if(isVhostAdded) {
                return addOrganizationClaimMappingDAO(dbClient, payload);
            } else {
                return e909408();
            }
        }
    }
    return payload;
}

isolated function addOrganizationClaimMappingDAO(postgresql:Client dbClient, Internal_Organization payload) returns Internal_Organization|commons:APKError {
    foreach OrganizationClaim e in payload.claimList {
        sql:ParameterizedQuery query = `INSERT INTO ORGANIZATION_CLAIM_MAPPING(UUID, CLAIM_KEY, 
        CLAIM_VALUE) VALUES (${payload.id},${e.claimKey},
        ${e.claimValue})`;
        sql:ExecutionResult | sql:Error result =  dbClient->execute(query);
        if result is sql:ExecutionResult {
            continue;
        } else { 
            return e909409(); 
        }
    }
    return payload;
}

isolated function addVhostsDAO (postgresql:Client dbClient, Internal_Organization payload) returns boolean{
    string[]? production = payload.production;
    string[]? sandbox = payload.sandbox;
    if (production !is ()) {
        foreach string e in production {
        sql:ParameterizedQuery query = `INSERT INTO ORGANIZATION_VHOST(UUID, VHOST, TYPE) VALUES (${payload.id},${e}, 'PRODUCTION')`;
        sql:ExecutionResult | sql:Error result =  dbClient->execute(query);
            if result is sql:ExecutionResult && result.affectedRowCount == 1 {
                continue;    
            } else { 
                return false;    
            }
        }
   }
   if (sandbox !is ()) {
        foreach string e in sandbox {
        sql:ParameterizedQuery query = `INSERT INTO ORGANIZATION_VHOST(UUID, VHOST, TYPE) VALUES (${payload.id},${e}, 'SANDBOX')`;
        sql:ExecutionResult | sql:Error result =  dbClient->execute(query);
            if result is sql:ExecutionResult && result.affectedRowCount == 1 {
                continue;    
            } else { 
                return false;    
            }
        }
   }
   return true;
}

isolated function validateOrganizationByNameDAO(string name) returns boolean|commons:APKError {
    postgresql:Client | error dbClient  = getConnection();
    if dbClient is error {
        return e909401(dbClient);
    } 
    sql:ParameterizedQuery query = `SELECT ORGANIZATION.UUID as id, NAME as name, DISPLAY_NAME as displayName, STATUS as enabled FROM ORGANIZATION WHERE NAME = ${name}`;
    Organization | sql:Error result =  dbClient->queryRow(query);
    if result is sql:NoRowsError {
        return false;
    } else if result is Organization {
        return true;
    } else {
        log:printError("Error while validating organization name in Database", result);
        return e909410();
    }
    
}

isolated function validateOrganizationById(string? id) returns boolean|commons:APKError {
    postgresql:Client | error dbClient  = getConnection();
    if dbClient is error {
        return e909401(dbClient);
    } 
    sql:ParameterizedQuery query = `select exists(SELECT 1 FROM ORGANIZATION WHERE UUID = ${id})`;
    boolean | sql:Error result =  dbClient->queryRow(query);
    if result is boolean {
        return result;
    } else { 
        return e909411();
    }   
}

isolated function updateOrganizationDAO(string id, Internal_Organization payload) returns Internal_Organization|commons:APKError {
    postgresql:Client | error dbClient  = getConnection();
    if dbClient is error {
        return e909401(dbClient);
    } else {
        postgresql:JsonBinaryValue namespace = new (payload.serviceNamespaces.toJson());
        sql:ParameterizedQuery query = `UPDATE ORGANIZATION SET NAME =${payload.name},
         DISPLAY_NAME = ${payload.displayName}, STATUS=${payload.enabled}, NAMESPACE=${namespace} WHERE UUID = ${id}`;
        sql:ExecutionResult | sql:Error result =  dbClient->execute(query);
        if result is sql:ExecutionResult && result.affectedRowCount == 1 {
            boolean isVhostAdded = updateVhostsDAO(dbClient, payload.id, payload);
                if(isVhostAdded) {
                    return updateOrganizationClaimMappingDAO(dbClient, id, payload);
                } else {
                    return e909412();
                }
            } else { 
                return e909413();
        }
    }
}

isolated function updateOrganizationClaimMappingDAO(postgresql:Client dbClient, string id, Internal_Organization payload) returns Internal_Organization|commons:APKError {
    sql:ParameterizedQuery query = `DELETE FROM ORGANIZATION_CLAIM_MAPPING WHERE UUID = ${id}`;
    sql:ExecutionResult | sql:Error result =  dbClient->execute(query);
    if result is sql:ExecutionResult {
        foreach OrganizationClaim e in payload.claimList {
            sql:ParameterizedQuery query1 = `INSERT INTO ORGANIZATION_CLAIM_MAPPING(UUID, CLAIM_KEY, 
            CLAIM_VALUE) VALUES (${id},${e.claimKey},
            ${e.claimValue})`;
            sql:ExecutionResult | sql:Error result1 =  dbClient->execute(query1);
            if result1 is sql:ExecutionResult {
                continue;
            } else { 
                return e909409();
            }
        }
    }
    return payload;
}

isolated function updateVhostsDAO (postgresql:Client dbClient, string id, Internal_Organization payload) returns boolean{
    sql:ParameterizedQuery query = `DELETE FROM ORGANIZATION_VHOST WHERE UUID = ${id}`;
    sql:ExecutionResult | sql:Error result =  dbClient->execute(query);
    if result is sql:ExecutionResult {
        string[]? production = payload.production;
        string[]? sandbox = payload.sandbox;
        if (production !is ()) {
            foreach string e in production {
            sql:ParameterizedQuery query1 = `INSERT INTO ORGANIZATION_VHOST(UUID, VHOST, TYPE) VALUES (${id},${e}, 'PRODUCTION')`;
            sql:ExecutionResult | sql:Error result1 =  dbClient->execute(query1);
                if result1 is sql:ExecutionResult && result1.affectedRowCount == 1 {
                    continue;    
                } else { 
                    return false;    
                }
            }
        }
        if (sandbox !is ()) {
            foreach string e in sandbox {
            sql:ParameterizedQuery query1 = `INSERT INTO ORGANIZATION_VHOST(UUID, VHOST, TYPE) VALUES (${id},${e}, 'SANDBOX')`;
            sql:ExecutionResult | sql:Error result1 =  dbClient->execute(query1);
                if result1 is sql:ExecutionResult && result1.affectedRowCount == 1 {
                    continue;    
                } else { 
                    return false;    
                }
            }
        }
        return true;
    }
    return false;
}

public isolated function getAllOrganizationDAO() returns Internal_Organization[]|commons:APKError {
    postgresql:Client | error dbClient  = getConnection();
    if dbClient is error {
        return e909401(dbClient);
    } else {
        do {
            map<Internal_Organization> organization = {};
            sql:ParameterizedQuery query = `SELECT ORGANIZATION.UUID as id, NAME as name, DISPLAY_NAME as displayName, STATUS as enabled, claim_key as claimKey, claim_value as claimValue FROM ORGANIZATION, ORGANIZATION_CLAIM_MAPPING where ORGANIZATION.UUID = ORGANIZATION_CLAIM_MAPPING.UUID`;
            stream<Organizations, sql:Error?> orgStream = dbClient->query(query);
            
            check from Organizations org in orgStream do {
                if organization.hasKey(org.id) {
                    OrganizationClaim claim = {claimKey: org.claimKey, claimValue: org.claimValue};
                    organization.get(org.id).claimList.push(claim);
                } else {
                    OrganizationClaim claim = {claimKey: org.claimKey, claimValue: org.claimValue};
                    Internal_Organization organizationData = {id: org.id, name: org.name, displayName: org.displayName, enabled: check boolean:fromString(org.enabled), serviceNamespaces: ["*"],  claimList: [claim]};
                    organization[org.id] = organizationData;
                }
            };

            sql:ParameterizedQuery query1 = `SELECT ORGANIZATION.UUID as id, NAME as name, DISPLAY_NAME as displayName, ORGANIZATION_VHOST.VHOST AS production FROM ORGANIZATION,ORGANIZATION_VHOST where
             ORGANIZATION.UUID = ORGANIZATION_VHOST.UUID and ORGANIZATION_VHOST.TYPE = 'PRODUCTION'`;
            stream<Organizations, sql:Error?> orgStream1 = dbClient->query(query1);
            check from Organizations org1 in orgStream1 do {
                if organization.hasKey(org1.id) {
                    string[]? hostArray = organization.get(org1.id).production;
                    if hostArray !is () {
                        hostArray.push(org1.production);
                    } else {
                        organization[org1.id].production = [org1.production];
                    }
                }
            };
            sql:ParameterizedQuery query2 = `SELECT ORGANIZATION.UUID as id, NAME as name, DISPLAY_NAME as displayName, ORGANIZATION_VHOST.VHOST AS sandbox FROM ORGANIZATION,ORGANIZATION_VHOST where
             ORGANIZATION.UUID = ORGANIZATION_VHOST.UUID and ORGANIZATION_VHOST.TYPE = 'SANDBOX'`;
            stream<Organizations, sql:Error?> orgStream2 = dbClient->query(query2);
            check from Organizations org2 in orgStream2 do {
                if organization.hasKey(org2.id) {
                    string[]? hostArray = organization.get(org2.id).sandbox;
                    if hostArray !is () {
                        hostArray.push(org2.sandbox);
                    } else {
                        organization[org2.id].sandbox = [org2.sandbox];
                    }
                }
            };
            check orgStream.close();
            check orgStream1.close();
            check orgStream2.close();
            return organization.toArray();
        } on fail var e {
            return e909400(e);
        }
    }
}

isolated function getOrganizationByIdDAO(string id) returns Internal_Organization|commons:APKError {
    postgresql:Client | error dbClient  = getConnection();
    if dbClient is error {
        return e909401(dbClient);
    } else {
        do {
            sql:ParameterizedQuery query = `SELECT ORGANIZATION.UUID as id, NAME as name, DISPLAY_NAME as displayName, STATUS as enabled, claim_key as claimKey, 
                    claim_value as claimValue, string_to_array(NAMESPACE::text,',')::text[] AS serviceNamespaces
                    FROM ORGANIZATION, ORGANIZATION_CLAIM_MAPPING where ORGANIZATION.UUID = ORGANIZATION_CLAIM_MAPPING.UUID and ORGANIZATION.UUID =${id}`;
            stream<Organizations, sql:Error?> orgStream = dbClient->query(query);
            Internal_Organization organization1 = {
                id: "",
                name: "",
                displayName: "",
                enabled: true,
                serviceNamespaces: ["*"],
                production: [],
                sandbox: [],
                claimList: []
            };
            check from Organizations org in orgStream do {
                if (organization1.id == "") {
                    organization1 = {
                        id:id,
                        name:org.name,
                        displayName:org.displayName,
                        enabled: check boolean:fromString(org.enabled),
                        serviceNamespaces: org.serviceNamespaces,
                        claimList:[{
                            claimKey:org.claimKey,
                            claimValue: org.claimValue
                        }]
                    };
                } else {
                    organization1.claimList.push({
                        claimKey:org.claimKey,
                        claimValue: org.claimValue
                    });
                }
            }; 

            sql:ParameterizedQuery query1 = `SELECT ORGANIZATION.UUID as id, NAME as name, DISPLAY_NAME as displayName, ORGANIZATION_VHOST.VHOST AS production FROM ORGANIZATION,ORGANIZATION_VHOST where
             ORGANIZATION.UUID = ORGANIZATION_VHOST.UUID and ORGANIZATION.UUID =${id} and ORGANIZATION_VHOST.TYPE = 'PRODUCTION'`;
            stream<Organizations, sql:Error?> orgStream1 = dbClient->query(query1);
            check from Organizations org1 in orgStream1 do {
                string[]? hostArray = organization1.production;
                if hostArray !is () {
                    hostArray.push(org1.production);
                } else {
                    organization1.production = [org1.production];
                }
            };
            sql:ParameterizedQuery query2 = `SELECT ORGANIZATION.UUID as id, NAME as name, DISPLAY_NAME as displayName, ORGANIZATION_VHOST.VHOST AS sandbox FROM ORGANIZATION,ORGANIZATION_VHOST where
             ORGANIZATION.UUID = ORGANIZATION_VHOST.UUID and ORGANIZATION.UUID =${id} and ORGANIZATION_VHOST.TYPE = 'SANDBOX'`;
            stream<Organizations, sql:Error?> orgStream2 = dbClient->query(query2);
            check from Organizations org2 in orgStream2 do {
                string[]? hostArray = organization1.sandbox;
                if hostArray !is () {
                    hostArray.push(org2.sandbox);
                } else {
                    organization1.sandbox = [org2.sandbox];
                }
            };

            if (organization1.id == "") {
                return e909414();
            } else {
                 return organization1;
            }

            } on fail var e {
            return e909415(e);
        }
    }
}

isolated function removeOrganizationDAO(string id) returns boolean|commons:APKError {
    postgresql:Client | error dbClient  = getConnection();
    if dbClient is error {
        return e909401(dbClient);
    } else {
        sql:ParameterizedQuery query = `DELETE FROM ORGANIZATION WHERE UUID = ${id}`;
        sql:ExecutionResult | sql:Error result =  dbClient->execute(query);
        if result is sql:ExecutionResult {
            return true;
        } else { 
            return e909416();
        }
    }
}

isolated function getOrganizationByOrganizationClaimDAO(string claim) returns Internal_Organization|commons:APKError {
    postgresql:Client | error dbClient  = getConnection();
    if dbClient is error {
        return e909401(dbClient);
    } else { 
        sql:ParameterizedQuery query = `SELECT UUID as id FROM ORGANIZATION_CLAIM_MAPPING where claim_value =${claim}`;
        string | sql:Error result =  dbClient->queryRow(query);
        if result is sql:NoRowsError {
            return e909414();
        } else if result is string {
            return getOrganizationByIdDAO(result);
        } else { 
            return e909417();
        }
    }   
}

isolated function getOrganizationByNameDAO(string name) returns Internal_Organization|commons:APKError {
    postgresql:Client | error dbClient  = getConnection();
    if dbClient is error {
        return e909401(dbClient);
    } else {
        do {
            sql:ParameterizedQuery query = `SELECT ORGANIZATION.UUID as id, NAME as name, DISPLAY_NAME as displayName,STATUS as enabled, claim_key as claimKey, 
                    claim_value as claimValue, string_to_array(NAMESPACE::text,',')::text[] AS serviceNamespaces
                    FROM ORGANIZATION, ORGANIZATION_CLAIM_MAPPING where ORGANIZATION.UUID = ORGANIZATION_CLAIM_MAPPING.UUID and ORGANIZATION.NAME =${name}`;
            stream<Organizations, sql:Error?> orgStream = dbClient->query(query);
            Internal_Organization organization1 = {
                id: "",
                name: "",
                displayName: "",
                enabled: true,
                serviceNamespaces: ["*"],
                production: [],
                sandbox: [],
                claimList: []
            };
            check from Organizations org in orgStream do {
                if (organization1.id == "") {
                    organization1 = {
                        id:org.id,
                        name:org.name,
                        displayName:org.displayName,
                        enabled: check boolean:fromString(org.enabled),
                        serviceNamespaces: org.serviceNamespaces,
                        claimList:[{
                            claimKey:org.claimKey,
                            claimValue: org.claimValue
                        }]
                    };
                } else {
                    organization1.claimList.push({
                        claimKey:org.claimKey,
                        claimValue: org.claimValue
                    });
                }
            }; 

            sql:ParameterizedQuery query1 = `SELECT ORGANIZATION.UUID as id, NAME as name, DISPLAY_NAME as displayName, ORGANIZATION_VHOST.VHOST AS production FROM ORGANIZATION,ORGANIZATION_VHOST where
             ORGANIZATION.UUID = ORGANIZATION_VHOST.UUID and ORGANIZATION.NAME =${name} and ORGANIZATION_VHOST.TYPE = 'PRODUCTION'`;
            stream<Organizations, sql:Error?> orgStream1 = dbClient->query(query1);
            check from Organizations org1 in orgStream1 do {
                string[]? hostArray = organization1.production;
                if hostArray !is () {
                    hostArray.push(org1.production);
                } else {
                    organization1.production = [org1.production];
                }
            };
            sql:ParameterizedQuery query2 = `SELECT ORGANIZATION.UUID as id, NAME as name, DISPLAY_NAME as displayName, ORGANIZATION_VHOST.VHOST AS sandbox FROM ORGANIZATION,ORGANIZATION_VHOST where
             ORGANIZATION.UUID = ORGANIZATION_VHOST.UUID and ORGANIZATION.NAME =${name} and ORGANIZATION_VHOST.TYPE = 'SANDBOX'`;
            stream<Organizations, sql:Error?> orgStream2 = dbClient->query(query2);
            check from Organizations org2 in orgStream2 do {
                string[]? hostArray = organization1.sandbox;
                if hostArray !is () {
                    hostArray.push(org2.sandbox);
                } else {
                    organization1.sandbox = [org2.sandbox];
                }
            };

            if (organization1.id == "") {
                return e909414();
            } else {
                 return organization1;
            }

            } on fail var e {
            return e909415(e);
        }
    }
}
