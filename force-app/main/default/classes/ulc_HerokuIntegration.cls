public with sharing class ulc_HerokuIntegration {
public static Legal_Advisor__c getExistingAdvisor(String accountNumber) {
    List <Legal_Advisor__c> existingAdvisors = [SELECT Id, Account_Status__c, Name, As_of_Date__c, Account_Number__c FROM Legal_Advisor__c WHERE Account_Number__c = :accountNumber LIMIT 1];
        if (existingAdvisors.size() >= 1) {
            return existingAdvisors[0];
        }
        return null;
    }

public static Client__c getExistingClient(String clientNumber) {
    // Realiza una consulta para obtener el cliente por su número de cliente
    List<Client__c> existingClients = [SELECT Id, Name, Client_Number__c, Legal_Advisor__c FROM Client__c WHERE Client_Number__c = :clientNumber LIMIT 1];
    if (existingClients.size() >= 1) {
        return existingClients[0];
    }
    return null;
}

public static void updateExistingAdvisor(Legal_Advisor__c existingAdvisor, Map<String, Object> mapObj) {
    existingAdvisor.Name = (String)mapObj.get('AccountName');
    existingAdvisor.Account_Status__c = (String)mapObj.get('AccountStatus');
    existingAdvisor.As_of_Date__c = Date.parse((String)mapObj.get('AsOfDate'));
    existingAdvisor.Account_Number__c = (String)mapObj.get('AccountNumber');
}
// Función para actualizar cliente existente
public static void updateExistingClient(Client__c existingClient, Map<String, Object> clientMap) {
    // Actualiza los campos del cliente existente con la información del mapa
    existingClient.Name = (String)clientMap.get('FirstName');
    existingClient.Last_Name__c = (String)clientMap.get('LastName');
    existingClient.Email__c = (String)clientMap.get('Email');
    existingClient.Phone__c = (String)clientMap.get('Phone');
    existingClient.Address__c = (String)clientMap.get('Address');
    existingClient.Is_Migrated__c = true;
}

public static Legal_Advisor__c createNewAdvisor(String accountNumber, Map<String, Object> mapObj) {
    return new Legal_Advisor__c(
        Account_Number__c = accountNumber,
        Name = (String)mapObj.get('AccountName'),
        Account_Status__c = (String)mapObj.get('AccountStatus'),
        As_of_Date__c = Date.parse((String)mapObj.get('AsOfDate'))
    );
}

// Función para crear un nuevo cliente
public static Client__c createNewClient(Map<String, Object> clientMap, Id advisorId) {
    // Crea un nuevo cliente con la información del mapa y el ID del asesor
    return new Client__c(
        Name = (String)clientMap.get('FirstName'),
        Last_Name__c = (String)clientMap.get('LastName'),
        Email__c = (String)clientMap.get('Email'),
        Phone__c = (String)clientMap.get('Phone'),
        Address__c = (String)clientMap.get('Address'),
        Client_Number__c = (String)clientMap.get('ClientNumber'),
        Legal_Advisor__c = advisorId,
        Is_Migrated__c = true
    );
}

public static void processClients(Map<String, Object> mapObj, Legal_Advisor__c advisor, List<Client__c> clientsToUpdate, List<Client__c> clientsToInsert, List<String> clientsNumbersInJSON) {
    if (mapObj.containsKey('Clients') && mapObj.get('Clients') instanceof List<Object>) {
        List<Object> clientsList = (List<Object>)mapObj.get('Clients');
        system.debug ('this is the client list' + clientsList);

        for (Object clientObj : clientsList) {
            if (clientObj instanceof Map<String, Object>) {
                Map<String, Object> clientMap = (Map<String, Object>)clientObj;
                String clientNumber = (String)clientMap.get('ClientNumber');
                
                clientsNumbersInJSON.add(clientNumber);
                Client__c existingClient = getExistingClient(clientNumber);                    
            
                if (existingClient != null) {
                    updateExistingClient(existingClient, clientMap);
                    clientsToUpdate.add(existingClient);
                } else {
                    Client__c client = createNewClient(clientMap, advisor.Id);
                    clientsToInsert.add(client);
                }
            }
        }
    }
}

public static void deleteClientsNotInJSON(List<String> clientsNumbersInJSON) {
    List<Client__c> clientsToDelete = [
        SELECT Id
        FROM Client__c
        WHERE Client_Number__c NOT IN :clientsNumbersInJSON AND Is_Migrated__c = true
    ];
    Database.delete(clientsToDelete);
}

public static void notifyAdministrator() {
    User systemAdmin = [SELECT Id, Email FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];

    if(systemAdmin != null && systemAdmin.Email != null) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { systemAdmin.Email });
        mail.setSubject('[INTEGRATION ERROR] New error ocurred.');
        mail.setPlainTextBody('An error has occurred during the integration');
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    } else {
        System.debug('Could not find the system administrator or their email address.');
    }
}

public static void logResponseError(Integer statusCode) {
    insert new Integration_Error__c (
        Description__c = 'Failed with status code:' + statusCode,
        Created_date__c = System.today(),
        Name = 'Response Error'
    );
    notifyAdministrator();
}

public static void logError(Exception e) {
    insert new Integration_Error__c (
        Description__c = 'Failed with status message:' + e.getMessage(),
        Created_date__c = System.today(),
        Name = 'Request Error'
    );
    notifyAdministrator();
}
public static void makeHttpRequest() {
        String endpoint = 'https://altimetrik-bootcamp.herokuapp.com/LegalAccounts';
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint(endpoint);

        try {
            Http http = new Http();
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                String responseBody = response.getBody();
                System.debug('Respuesta: ' + responseBody);

                List<Object> parsedJsonList = (List<Object>)JSON.deserializeUntyped(responseBody);
                List<Legal_Advisor__c> advisorsToInsert = new List<Legal_Advisor__c>();
                List<Legal_Advisor__c> advisorsToUpdate = new List<Legal_Advisor__c>();
                List<Client__c> clientsToUpdate = new List<Client__c>();
                List<Client__c> clientsToInsert = new List<Client__c>();
                List<String> clientsNumbersInJSON = new List<String>();

                //Itero el json y agrego la logica para ver que hago con cada registro del archivo
                for (Object obj : parsedJsonList) {
                    if (obj instanceof Map<String, Object>) {
                        Map<String, Object> mapObj = (Map<String, Object>)obj;

                        String accountStatus = (String)mapObj.get('AccountStatus');
                        String accountNumber = (String)mapObj.get('AccountNumber');
                        System.debug('Accountnumber:' + accountNumber);

                        Legal_Advisor__c existingAdvisor = getExistingAdvisor(accountNumber);

                        if(accountStatus == 'Disabled') {
                                if (existingAdvisor != null && existingAdvisor.Account_Status__c == 'Enabled' ) {                           
                                existingAdvisor.Account_Status__c = (String)mapObj.get('AccountStatus');
                                advisorsToUpdate.add(existingAdvisor);
                            }    
                        }
                        else if (accountStatus == 'Enabled') {
                            if (existingAdvisor != null) {
                                updateExistingAdvisor(existingAdvisor, mapObj);
                                advisorsToUpdate.add(existingAdvisor);
                            } else {
                                Legal_Advisor__c advisor = createNewAdvisor(accountNumber, mapObj);
                                advisorsToInsert.add(advisor);
                                existingAdvisor = advisor;
                            }
                                processClients(mapObj, existingAdvisor, clientsToUpdate, clientsToInsert, clientsNumbersInJSON);
                        }
                    } 
                }
                Database.insert(advisorsToInsert);
                Database.update(advisorsToUpdate);
                Database.update(clientsToUpdate);
                Database.insert(clientsToInsert);
                deleteClientsNotInJSON(clientsNumbersInJSON);
            } else {
                logResponseError(response.getStatusCode());
            }
        } catch (Exception e) {
            logError(e);
        }
    }
}

