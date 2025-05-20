param name string

resource actionGroup 'Microsoft.Insights/actionGroups@2023-09-01-preview' = {
  name: name
  location: 'Global'
  properties: {
    groupShortName: 'copilotAG'
    enabled: true
    emailReceivers: [
      {
        name: 'emailForCopilotTeam'
        emailAddress: 'unizomb@microsoft.com'
        useCommonAlertSchema: false
      }
    ]
  }
}

output resourceId string = actionGroup.id
