param name string
param location string
param appInightsResourceId string
param actionGroupResourceId string
param description string
param severity int
param frequency string
param threshold int

resource scheduledQueryRule 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: name
  location: location
  properties: {
    displayName: name
    description: description
    severity: severity
    enabled: true
    evaluationFrequency: frequency
    scopes: [
      appInightsResourceId
    ]
    targetResourceTypes: [
      'Microsoft.Insights/components'
    ]
    windowSize: frequency
    criteria: {
      allOf: [
        {
          query: '''
requests
| summarize TotalRequests = count(), FailedRequests = countif(success == false and resultCode != 422) by name
| extend FailureRate = todouble(FailedRequests) / todouble(TotalRequests) * 100
'''
          timeAggregation: 'Total'
          metricMeasureColumn: 'FailureRate'
          dimensions: [
            {
              name: 'name'
              operator: 'Include'
              values: [
                'POST /bicep/copilot'
              ]
            }
          ]
          operator: 'GreaterThan'
          threshold: threshold
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: false
    actions: {
      actionGroups: [
        actionGroupResourceId
      ]
      customProperties: {}
      actionProperties: {}
    }
  }
}
