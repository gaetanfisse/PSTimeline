public class PSTimelineController {
    @AuraEnabled
    public static String queryData(String params)
    {
        System.debug('queryData invoked...');
        Map<String, String> paramMap = (Map<String, String>)JSON.deserialize(params,   Map<String, String>.class);
        System.debug(JSON.serializePretty(paramMap));
        PSResponse resp = new PSResponse();
        Integer i = 1;
        
        try
        {
            //if (paramMap.containsKey('contactId'))  c.ContactId = paramMap.get('contactId');
            List<PSTimelineItem> itemList = new List<PSTimelineItem>();
            
            String recordId = paramMap.get('recordId');
            String itemType = paramMap.get('itemType');
            String sldsResourceURL = paramMap.get('sldsIconResource');
            
            Integer truncSize = 50;
            if (paramMap.containsKey('truncSize')) truncSize = Integer.valueOf(paramMap.get('truncSize'));
            
            String networkPrefix = null;
            if (paramMap.containsKey('networkPrefix')) networkPrefix = paramMap.get('networkPrefix');
            
            // **************** //
            // get created date //
            // **************** //
            if (recordId != null && recordId.length() > 0)
            {
                Id myId = ID.valueOf(recordId);
                String objectName = myId.getSObjectType().getDescribe().getName();
                String objectLabel = myId.getSObjectType().getDescribe().getLabel();
                
                String queryStr = 'SELECT Id, CreatedDate FROM ' + objectName + ' WHERE Id = \'' + recordId + '\'';
                System.debug('queryStr=' + queryStr);
                List<sObject> recList = Database.query(queryStr);
                if (recList != null && recList.size() == 1)
                {
                    PSTimelineItem item = new PSTimelineItem();
                    //item.id = e.Id;
                    
                    String iconHTML = getIconHTML('custom:custom9', 'x-small', networkPrefix, sldsResourceURL);
                    String body = objectLabel + ' created!';
                    
                    if (iconHTML != null)
                    {
                        item.content = iconHTML + '<span class="slds-p-left_x-small" >' +body + '</span>';
                    }
                    else
                    {
                        item.content = body;
                    }
                    
                    item.startDttm = (Datetime)recList[0].get('CreatedDate');
                    item.type = itemType;
                    //item.className = 'red';
                    itemList.add(item);
                }
            }
            
            
            ////////////////////
            // get activities //
            ////////////////////
            if (paramMap.get('activityFlag') == 'true')
            {
                String taskIcon = paramMap.get('taskIcon');     // standard:task
                String eventIcon = paramMap.get('eventIcon');   // standard:event
                String emailIcon = paramMap.get('emailIcon');   // standard:email
                String callIcon = paramMap.get('callIcon');     // standard:call
                
                for (Event e : [SELECT Id, Subject, ActivityDateTime, StartDateTime, EndDateTime FROM Event WHERE WhatId = :recordId])
                {
                    PSTimelineItem item = new PSTimelineItem();
                    item.id = e.Id;
                    
                    String iconHTML = getIconHTML(eventIcon, 'x-small', networkPrefix, sldsResourceURL);
                    String body = cleanItemString(e.Subject, truncSize);
                    
                    if (iconHTML != null)
                    {
                        item.content = iconHTML + '<span class="slds-p-left_x-small" >' +body + '</span>';
                    }
                    else
                    {
                        item.content = body;
                    }
                    
                    if (e.Subject.length() > truncSize) item.title = e.Subject;
                    item.startDttm = e.ActivityDateTime;
                    item.type = itemType;
                    //item.className = 'red';
                    itemList.add(item);
                    
                }
                
                ///////////////
                // get tasks //
                ///////////////
                for (Task t : [SELECT Id, Subject, Description, TaskSubtype, ActivityDate, Status FROM Task WHERE WhatId = :recordId])
                {
                    PSTimelineItem item = new PSTimelineItem();
                    item.id = t.Id;
                    
                    
                    String icon = taskIcon;
                    if (t.TaskSubtype == 'Email')
                    {
                        icon = emailIcon;
                    }
                    else if (t.TaskSubtype == 'Call')
                    {
                        icon = callIcon;
                    }
                    
                    String iconHTML = getIconHTML(icon, 'x-small', networkPrefix, sldsResourceURL);
                    String body = cleanItemString(t.Subject, truncSize);
                    
                    if (iconHTML != null)
                    {
                        item.content = iconHTML + '<span class="slds-p-left_x-small" >' + body + '</span>';
                    }
                    else
                    {
                        item.content = body;
                    }
                    
                    item.title = t.Description;
                    item.startDttm = t.ActivityDate;
                    item.type = itemType;
                    
                    if (t.TaskSubtype == 'Task')
                    {
                        if (t.status == 'Completed')
                        {
                            item.className = 'Complete';
                        }
                        else
                        {
                            Date td = Date.today();
                            if (t.ActivityDate < td && t.status != 'Completed')
                            {
                                item.className = 'Overdue';
                            }
                        }
                    }
                    itemList.add(item);
                    
                }
            }
            
            ///////////////
            // get files //
            ///////////////
            if (paramMap.get('contentFlag') == 'true')
            {
                for (ContentDocumentLink cdl : [SELECT ContentDocumentId, ContentDocument.FileType, ContentDocument.Title, ContentDocument.CreatedDate, LinkedEntityId, ShareType, SystemModstamp, Visibility 
                                                FROM ContentDocumentLink 
                                                WHERE LinkedEntityId = :recordId])
                {
                    PSTimelineItem item = new PSTimelineItem();
                    item.id = cdl.ContentDocumentId;
                    
                    
                    String contentIcon = paramMap.get('contentIcon');   // standard:file
                    
                    String label = cdl.ContentDocument.FileType + ': ' + cdl.ContentDocument.Title;
                    String iconHTML = getIconHTML(contentIcon, 'x-small', networkPrefix, sldsResourceURL);
                    String body = cleanItemString(label, truncSize);
                    
                    if (iconHTML != null)
                    {
                        item.content = iconHTML + '<span class="slds-p-left_x-small" >' +  body + '</span>';
                    }
                    else
                    {
                        item.content = body;
                    }
                    
                    if (label.length() > truncSize) item.title = label;
                    item.startDttm = cdl.ContentDocument.CreatedDate;
                    item.type = itemType;
                    //item.className = 'red';
                    itemList.add(item);
                    
                }     
            }
            
            ////////////////////////////
            // get chatter text posts //
            ////////////////////////////
            if (paramMap.get('chatterFlag') == 'true')
            {
                for (FeedItem fi : [SELECT Id, Body, LastModifiedDate 
                                    FROM FeedItem 
                                    WHERE ParentId = :recordId AND Type = 'TextPost'])
                {
                    PSTimelineItem item = new PSTimelineItem();
                    item.id = fi.Id;
                    
                    String chatterIcon = paramMap.get('chatterIcon');   // standard:post
                    String iconHTML = getIconHTML(chatterIcon, 'x-small', networkPrefix, sldsResourceURL);
                    
                    String body = cleanItemString(fi.Body, truncSize);
                    
                    if (iconHTML != null)
                    {
                        item.content = iconHTML + '<span class="slds-p-left_x-small item_label">' + body + '</span>';
                    }
                    else
                    {
                        item.content = body;
                    }
                    
                    if (fi.Body.length() > truncSize) item.title = fi.Body;
                    item.startDttm = fi.LastModifiedDate;
                    item.type = itemType;
                    itemList.add(item);
                    
                }
            }
            
            ///////////////////////
            // get case comments //
            ///////////////////////
            if (paramMap.get('caseCommentFlag') == 'true')
            {
                for (CaseComment cc : [SELECT Id, CommentBody, LastModifiedDate 
                                       FROM CaseComment 
                                       WHERE ParentId = :recordId])
                {
                    PSTimelineItem item = new PSTimelineItem();
                    //item.id = cc.Id;
                    
                    String commentIcon = paramMap.get('caseCommentIcon');   // custom:custom19
                    
                    String iconHTML = getIconHTML(commentIcon, 'x-small', networkPrefix, sldsResourceURL);
                    String body = cleanItemString(cc.CommentBody, truncSize);
                    
                    if (iconHTML != null)
                    {
                        item.content = iconHTML + '<span class="slds-p-left_x-small" >' + body + '</span>';
                    }
                    else
                    {
                        item.content = body;
                    }
                    
                    if (cc.CommentBody.length() > truncSize) item.title = cc.CommentBody;
                    item.startDttm = cc.LastModifiedDate;
                    item.type = itemType;
                    //item.className = 'red';
                    itemList.add(item);
                    
                }     
            }
            
            if (paramMap.get('child1Flag') == 'true')
            {
                getChildItems(itemList, recordId, i, paramMap.get('child1Icon'), paramMap.get('child1Object'), paramMap.get('child1ParentField'), 
                              paramMap.get('child1LabelField'), paramMap.get('child1DateField'), itemType, networkPrefix, sldsResourceURL, truncSize);
            }
            
            if (paramMap.get('child2Flag') == 'true')
            {
                getChildItems(itemList, recordId, i, paramMap.get('child2Icon'), paramMap.get('child2Object'), paramMap.get('child2ParentField'), 
                              paramMap.get('child2LabelField'), paramMap.get('child2DateField'), itemType, networkPrefix, sldsResourceURL, truncSize);
            }
            
            if (paramMap.get('child3Flag') == 'true')
            {
                getChildItems(itemList, recordId, i, paramMap.get('child3Icon'), paramMap.get('child3Object'), paramMap.get('child3ParentField'), 
                              paramMap.get('child3LabelField'), paramMap.get('child3DateField'), itemType, networkPrefix, sldsResourceURL, truncSize);
            }
            
            if (paramMap.get('child4Flag') == 'true')
            {
                getChildItems(itemList, recordId, i, paramMap.get('child4Icon'), paramMap.get('child4Object'), paramMap.get('child4ParentField'), 
                              paramMap.get('child4LabelField'), paramMap.get('child4DateField'), itemType, networkPrefix, sldsResourceURL, truncSize);
            }
            
            if (paramMap.get('child5Flag') == 'true')
            {
                getChildItems(itemList, recordId, i, paramMap.get('child5Icon'), paramMap.get('child5Object'), paramMap.get('child5ParentField'), 
                              paramMap.get('child5LabelField'), paramMap.get('child5DateField'), itemType, networkPrefix, sldsResourceURL, truncSize);
            }
            
            String dataJSON = JSON.serialize(itemList, true).replaceAll('startDttm', 'start').replaceAll('endDttm', 'end');
            resp.data = dataJSON;
        }
        catch (exception e)
        {
            resp.status = PSResponse.ERROR;
            resp.msg = e.getMessage();
        }
        
        return  JSON.serialize(resp);
    }
    
    private static void getChildItems(List<PSTimelineItem> itemList, String recordId, Integer i, String icon, String objectName, String parentField, String labelField, 
                                      String dateField, String itemType, String networkPrefix, String sldsResourceURL, Integer truncSize)
    {
        String queryStr = 'SELECT Id, ' + labelField + ', ' + dateField + ' FROM ' + objectName + ' WHERE ' + parentField + ' = \'' + recordId + '\'';
        System.debug('queryStr=' + queryStr);
        List<sObject> recList = Database.query(queryStr);
        if (recList.size() > 0)
        {
            for (sObject rec : recList)
            {
                PSTimelineItem item = new PSTimelineItem();
                item.id = rec.Id;
                
                String iconHTML = getIconHTML(icon, 'x-small', networkPrefix, sldsResourceURL);
                String label = (String)rec.get(labelField);
                String body = cleanItemString(label, truncSize);
                
                if (iconHTML != null)
                {
                    item.content = iconHTML + '<span class="slds-p-left_x-small" >' + body + '</span>';
                }
                else
                {
                    item.content = body;
                }
                
                if (label.length() > truncSize) item.title = label;
                item.startDttm = (DateTime)rec.get(dateField);
                item.type = itemType;
                itemList.add(item);
            }
        }
    }
    
    private static String getIconHTML(String icon, String size, String networkPrefix, String sldsResourceURL)
    {
        String iconHTML = null;
        
        if (icon.startsWith('http'))
        {
            iconHTML = '<img src="' + icon + '"></img>';
        }
        else if (icon.startsWith('/resource'))
        {
            if (networkPrefix != null && networkPrefix.length() > 0)
            {
                icon = networkPrefix + icon;
            }
            iconHTML = '<img src="' + icon + '"></img>';
        }
        else if (icon.contains(':'))
        {
            List<String> res = icon.split(':');
            if (res.size() == 2)
            {
                String category = res[0];
                String name = res[1];
                
                if (networkPrefix != null && networkPrefix.length() > 0)
                {
                    sldsResourceURL = networkPrefix + sldsResourceURL;
                }
                
                iconHTML = '<span class="slds-icon_container slds-icon-' + category + '-' + name + '" >'
                    + '<svg aria-hidden="true" class="slds-icon slds-icon--' + size + '" name="' + name + '">' 
                    + '<use xlink:href="' + sldsResourceURL + '/assets/icons/' + category + '-sprite/svg/symbols.svg#' + name +'"></use>'
                    + '</svg></span>';
            }
        }   
        return iconHTML;
    }
    
    private static String cleanItemString(String str, Integer length)
    {
        String newStr = str.replace('<p>', '').replace('</p>', '');
        if (newStr.length() > length)
        {
            newStr = newStr.replaceAll('\\<.*?\\>', '');
            if (newStr.length() > length)
            {
                newStr = newStr.substring(0,length) + '...';
            }
        }
        return newStr;
    }
    
    @AuraEnabled
    public static String getRuntimeContext() {
        Map<String, String> contextMap = new Map<String, String>();
        
        contextMap.put('userId', UserInfo.getUserId());
        contextMap.put('userType', UserInfo.getUserType());
        contextMap.put('userFirstName', UserInfo.getFirstName());
        contextMap.put('userLastName', UserInfo.getLastName());
        contextMap.put('userName', UserInfo.getUserName());
        contextMap.put('orgName', UserInfo.getOrganizationName());
        
        if (Network.getNetworkId() != null)
        {
            contextMap.put('networkId', Network.getNetworkId());
            
            Network nw = [SELECT Name, UrlPathPrefix FROM Network WHERE Id = :Network.getNetworkId() LIMIT 1];   
            
            contextMap.put('networkName', nw.Name);
            contextMap.put('networkPrefix', '/' + nw.UrlPathPrefix);
        }
        
        return(JSON.serialize(contextMap));
    }
}