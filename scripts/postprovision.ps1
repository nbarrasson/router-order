#!/usr/bin/env pwsh

# This script runs after Azure resources are provisioned
# It creates a zip package and deploys it to the Logic App

# Get environment variables that were set by azd
$ResourceGroupName = $env:AZURE_RESOURCE_GROUP
$LogicAppName = "logic-$($env:AZURE_ENV_NAME)"

if ([string]::IsNullOrEmpty($ResourceGroupName)) {
    Write-Error "AZURE_RESOURCE_GROUP environment variable is not set"
    exit 1
}

if ([string]::IsNullOrEmpty($env:AZURE_ENV_NAME)) {
    Write-Error "AZURE_ENV_NAME environment variable is not set"
    exit 1
}

Write-Host "Starting post-provision actions for Logic App '$LogicAppName' in resource group '$ResourceGroupName'..."

# Create a temporary directory for staging deployment files
$tempDir = Join-Path $env:TEMP "logicapp-deploy-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Write-Host "Created temporary directory at $tempDir"

# Copy all workflow directories from the logicapp folder
$workflowDirs = Get-ChildItem -Path $PSScriptRoot/../logicapp -Directory -Filter "wf_*"
foreach ($workflowDir in $workflowDirs) {
    $destPath = Join-Path $tempDir $workflowDir.Name
    Copy-Item -Path $workflowDir.FullName -Destination $destPath -Recurse
    Write-Host "Copied workflow '$($workflowDir.Name)' to staging directory"
}

# Copy Artifacts folder if it exists
$artifactsDir = Join-Path $PSScriptRoot/../logicapp "Artifacts"
if (Test-Path $artifactsDir) {
    $destArtifactsPath = Join-Path $tempDir "Artifacts"
    Copy-Item -Path $artifactsDir -Destination $destArtifactsPath -Recurse
    Write-Host "Copied Artifacts folder to staging directory"
}

# Copy connections.json if it exists
$connectionsJsonPath = Join-Path $PSScriptRoot/../logicapp "connections.json"
if (Test-Path $connectionsJsonPath) {
    Copy-Item -Path $connectionsJsonPath -Destination $tempDir
    Write-Host "Copied connections.json to staging directory"
}

# Create the zip file
$zipPath = Join-Path $env:TEMP "logicapp-deploy-$LogicAppName.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}
Compress-Archive -Path "$tempDir/*" -DestinationPath $zipPath
Write-Host "Created deployment package at $zipPath"

# Deploy the zip package to the Logic App
Write-Host "Deploying package to Logic App..."
$result = az logicapp deployment source config-zip --resource-group $ResourceGroupName --name $LogicAppName --src $zipPath

if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully deployed Logic App package" -ForegroundColor Green
} else {
    Write-Host "Failed to deploy Logic App package" -ForegroundColor Red
    exit 1
}

# Clean up temporary files
Remove-Item -Path $tempDir -Recurse -Force
Remove-Item -Path $zipPath -Force
Write-Host "Cleaned up temporary files"

# Since Artifacts are now included in the zip deployment, we can skip the separate artifact upload
Write-Host "Note: Artifacts are now included in the zip deployment package" -ForegroundColor Green

# Post-deployment actions
Write-Host "Performing post-deployment actions..."

# Restart the Logic App to apply connection settings
Write-Host "Restarting Logic App to apply connection settings..."
$restartResult = az logicapp restart --resource-group $ResourceGroupName --name $LogicAppName

if ($LASTEXITCODE -eq 0) {
    Write-Host "Logic App restarted successfully" -ForegroundColor Green
    # Add delay to ensure Logic App is ready
    Write-Host "Waiting for Logic App to be ready..." -ForegroundColor Cyan
    Start-Sleep -Seconds 60
} else {
    Write-Host "Warning: Failed to restart Logic App" -ForegroundColor Yellow
}

$ApiId = "/subscriptions/$($env:AZURE_SUBSCRIPTION_ID)/resourceGroups/$ResourceGroupName/providers/Microsoft.ApiManagement/service/apim-$($env:AZURE_ENV_NAME)/apis/stock-management"
$BaseUrl = "https://apim-$($env:AZURE_ENV_NAME).azure-api.net/stock-management"

# Get callback URL for HTTP-to-ServiceBus workflow
$httpToSbWorkflowName = "wf_orders_from_http_to_sb"
$httpTriggerName = "When_a_HTTP_request_is_received"
$apiVersion = "2022-03-01"
$token = az account get-access-token --query accessToken -o tsv

$httpCallbackUrl = "https://management.azure.com/subscriptions/$($env:AZURE_SUBSCRIPTION_ID)/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$LogicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows/$httpToSbWorkflowName/triggers/$httpTriggerName/listCallbackUrl?api-version=$apiVersion"

$headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type' = 'application/json'
}

try {
    # Get HTTP-to-ServiceBus workflow callback URL
    Write-Host "Getting HTTP-to-ServiceBus workflow callback URL..." -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri $httpCallbackUrl -Headers $headers -Method Post
    $httpEndpoint = $response.value
    
    # Split the URL into base URL and path with query parameters
    $uri = [System.Uri]$httpEndpoint
    $baseUrl = $uri.GetLeftPart([System.UriPartial]::Authority)
    
    # Build the URL template and base URL for APIM
    if ($uri.AbsolutePath.StartsWith("/api")) {
        $baseUrl = $baseUrl + "/api"
        # Keep everything after /api (excluding /api itself) including query parameters
        $urlTemplate = $httpEndpoint.Substring($baseUrl.Length + "/api".Length)
    } else {
        $urlTemplate = $uri.AbsolutePath + $uri.Query
    }   

    # Store the URL template for APIM
    $urlTemplateArg = "`"$urlTemplate`""

    # Now get the Router Order workflow callback URL
    $routerWorkflowName = "wf_orders_router_order"
    $routerCallbackUrl = "https://management.azure.com/subscriptions/$($env:AZURE_SUBSCRIPTION_ID)/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$LogicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows/$routerWorkflowName/triggers/$httpTriggerName/listCallbackUrl?api-version=$apiVersion"

    Write-Host "Getting Router Order workflow callback URL..." -ForegroundColor Cyan
    $routerResponse = Invoke-RestMethod -Uri $routerCallbackUrl -Headers $headers -Method Post
    $routerEndpoint = $routerResponse.value

    $appSettings = az logicapp config appsettings set `
        --resource-group "$ResourceGroupName" `
        --name "$LogicAppName" `
        --settings routerOrderApiUrl="`"$routerEndpoint`""

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully set all app settings" -ForegroundColor Green
    } else {
        Write-Host "Failed to set app settings" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Failed to get callback URLs: $_" -ForegroundColor Red
    exit 1
}

# Create API in API Management
Write-Host "Creating API in API Management..." -ForegroundColor Cyan
$ApimName = "apim-$($env:AZURE_ENV_NAME)"

# Create the API using OpenAPI specification
$orderProcessApi = az apim api import `
    --resource-group $ResourceGroupName `
    --service-name $ApimName `
    --api-id "order-process" `
    --path "order-process" `
    --display-name "Order Process API" `
    --protocols https `
    --subscription-required true `
    --specification-format OpenApi `
    --specification-path "$PSScriptRoot/../api/order-process/openapi.yaml"

# Update the API URL template to match Logic App's callback URL
Write-Host "Updating API URL template..." -ForegroundColor Cyan
$updateUrlTemplate = az apim api operation update `
    --resource-group $ResourceGroupName `
    --service-name $ApimName `
    --api-id "order-process" `
    --operation-id "process-order" `
    --url-template $urlTemplateArg `
    --method POST

if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully updated API URL template" -ForegroundColor Green
} else {
    Write-Host "Failed to update API URL template" -ForegroundColor Red
    exit 1
}

# Associate the API with the router-order product
Write-Host "Associating API with router-order product..." -ForegroundColor Cyan
$associationResult = az apim product api add `
    --resource-group $ResourceGroupName `
    --service-name $ApimName `
    --product-id "router-order" `
    --api-id "order-process"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully associated API with router-order product" -ForegroundColor Green
} else {
    Write-Host "Failed to associate API with router-order product" -ForegroundColor Red
    exit 1
}

# Set the backend policy using REST API
$policyContent = @"
<policies>
    <inbound>
        <base />
        <set-backend-service base-url="$baseUrl" />
        <rate-limit-by-key calls="60" renewal-period="10" counter-key="@(context.Subscription?.Key ?? `"anonymous`")" />
        <validate-content unspecified-content-type-action="prevent" max-size="8192" size-exceeded-action="prevent" errors-variable-name="validationErrors">
            <content type="application/json" validate-as="json" action="prevent" schema-id="order-schema" allow-additional-properties="false" />
        </validate-content>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
"@

$apiPolicyUrl = "https://management.azure.com/subscriptions/$($env:AZURE_SUBSCRIPTION_ID)/resourceGroups/$ResourceGroupName/providers/Microsoft.ApiManagement/service/$ApimName/apis/order-process/operations/process-order/policies/policy?api-version=2021-08-01"

$policyBody = @{
    "properties" = @{
        "format" = "rawxml"
        "value" = $policyContent
    }
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $apiPolicyUrl -Headers $headers -Method Put -Body $policyBody
    Write-Host "API operation policy set successfully" -ForegroundColor Green
} catch {
    Write-Host "Failed to set API operation policy: $_" -ForegroundColor Red
    exit 1
}

Write-Host "All post-provision and post-deployment actions completed."