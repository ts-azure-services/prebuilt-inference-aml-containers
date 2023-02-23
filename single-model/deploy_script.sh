#!/bin/bash
yel=$'\e[1;33m'
grn=$'\e[1;32m'
red=$'\e[1;31m'
end=$'\e[0m'

set -e

source variables.env
echo "ACR container registry name is...."$ACR_NAME

number=$[ ( $RANDOM % 10000 ) + 1 ]

ENDPOINT_NAME='endpoint'$number
echo "Endpoint name is ... $ENDPOINT_NAME"
BASE_PATH="./single-model"
ASSET_PATH="./single-model/model"

echo "Writing out the endpoint file..."
endpoint_file="$BASE_PATH/endpoint.yml"
printf '$schema: https://azuremlschemas.azureedge.net/latest/managedOnlineEndpoint.schema.json \n' > $endpoint_file
printf "name: $ENDPOINT_NAME \n" >> $endpoint_file
printf 'auth_mode: key' >> $endpoint_file
sleep 3

echo "Creating the online endpoint..."
az ml online-endpoint create -f $BASE_PATH/endpoint.yml -g $RESOURCE_GROUP --workspace-name $WORKSPACE_NAME
sleep 10

echo "Getting access key and scoring URL..."
KEY=$(az ml online-endpoint get-credentials \
  -n $ENDPOINT_NAME \
  -g $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --query primaryKey -o tsv)
if [[ $KEY == "" ]]; then
  echo "Did not retrieve a key..."
  exit 1
fi
echo "Got the key...$KEY"


echo "Getting the scoring URL..."
SCORING_URL=$(az ml online-endpoint show \
  -n $ENDPOINT_NAME \
  -g $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --query scoring_uri -o tsv)
SCORING_URL=$(sed -e 's/^"//' -e 's/"$//' <<<"$SCORING_URL")

if [[ $SCORING_URL == "" ]]; then
  echo "Did not retrieve a scoring url..."
  exit 1
fi
echo "Got the scoring url...$SCORING_URL"

echo "Get resource ID of the container registry..."
resourceID=$(az acr show \
  -g $RESOURCE_GROUP \
  --name $ACR_NAME \
  --query "id" --output tsv)
sleep 1

echo "Get principal object id of the endpoint to grant pull rights to the ACR registry..."
endpoint_resource_id=$(az ml online-endpoint show \
  -g $RESOURCE_GROUP \
  --name $ENDPOINT_NAME \
  --workspace-name $WORKSPACE_NAME \
  --query identity.principal_id)
sleep 2
endpoint_resource_id=$(sed -e 's/^"//' -e 's/"$//' <<<"$endpoint_resource_id")
echo "Got the principal/object id of the endpoint...$endpoint_resource_id"
sleep 1

echo "Grant pull rights to the endpoint identity..."
az role assignment create --assignee $endpoint_resource_id --scope $resourceID --role acrpull
sleep 1

echo "Build the image into the container registry..."
az acr build \
  --registry $ACR_NAME \
  -g $RESOURCE_GROUP \
  -f $BASE_PATH/Dockerfile \
  -t sample/single-model:1 -r $ACR_NAME $ASSET_PATH


echo "Writing out the deployment file..."
deployment_name='deployment'$number
deployment_file="$BASE_PATH/deployment.yml"
printf '$schema: https://azuremlschemas.azureedge.net/latest/managedOnlineDeployment.schema.json \n' > $deployment_file
printf "name: $deployment_name \n" >> $deployment_file
printf "endpoint_name: $ENDPOINT_NAME \n" >> $deployment_file
printf "model: \n" >> $deployment_file
printf "  name: amlmodel \n" >> $deployment_file
printf "  path: ./model \n" >> $deployment_file
printf "code_configuration: \n" >> $deployment_file
printf "  code: ./ \n" >> $deployment_file
printf "  scoring_script: score.py \n" >> $deployment_file
printf "environment: \n" >> $deployment_file
printf "  name: env$number \n" >> $deployment_file
printf "  image: $ACR_NAME.azurecr.io/sample/single-model:1 \n" >> $deployment_file
printf "  inference_config: \n" >> $deployment_file
printf "    liveness_route: \n" >> $deployment_file
printf "      path: / \n" >> $deployment_file
printf "      port: 5001 \n" >> $deployment_file
printf "    readiness_route: \n" >> $deployment_file
printf "      path: / \n" >> $deployment_file
printf "      port: 5001 \n" >> $deployment_file
printf "    scoring_route: \n" >> $deployment_file
printf "      path: /score \n" >> $deployment_file
printf "      port: 5001 \n" >> $deployment_file
printf 'instance_type: Standard_DS3_v2 \n' >> $deployment_file
printf 'instance_count: 1 \n' >> $deployment_file
sleep 3


echo "Triggering the online deployment..."
az ml online-deployment create \
  --endpoint-name $ENDPOINT_NAME \
  -g $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  -f "$BASE_PATH/deployment.yml" --all-traffic

# # Test out the request file
# curl -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d @$ASSET_PATH/sample-request.json $SCORING_URL

# Create variables file
printf "${grn}Writing out key variables...${end}\n"
env_variable_file='sm_variables.env'
printf "SCORING_URL=$SCORING_URL \n" > $env_variable_file
printf "KEY=$KEY \n" >> $env_variable_file
