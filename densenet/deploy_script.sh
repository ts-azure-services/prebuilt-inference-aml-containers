#/bin/bash
yel=$'\e[1;33m'
grn=$'\e[1;32m'
red=$'\e[1;31m'
end=$'\e[0m'

set -e

source variables.env
echo "ACR container registry name is....$ACR_NAME"
echo "Workspace name is... $WORKSPACE_NAME"
BASE_PATH='./densenet'
number=$[ ( $RANDOM % 10000 ) + 1 ]
ENDPOINT_NAME='endpoint-densenet'$number

echo "Writing out the endpoint file..."
endpoint_file="$BASE_PATH/endpoint.yml"
printf '$schema: https://azuremlsdk2.blob.core.windows.net/latest/managedOnlineEndpoint.schema.json \n' >> $endpoint_file 
printf "name: $ENDPOINT_NAME \n" >> $endpoint_file
printf 'auth_mode: aml_token' >> $endpoint_file
sleep 3

# Make this a one-time thing if the directory exists
echo "Downloading model and config file..."
mkdir $BASE_PATH/torchserve
wget --progress=dot:mega https://aka.ms/torchserve-densenet161 -O $BASE_PATH/torchserve/densenet161.mar

echo "Build the image into the container registry..."
IMAGE_TAG=${ACR_NAME}.azurecr.io/torchserve:1
az acr build \
  --registry $ACR_NAME \
  -g $RESOURCE_GROUP \
  -f $BASE_PATH/Dockerfile \
  -t $IMAGE_TAG -r $ACR_NAME $BASE_PATH

sleep 10

# echo "Downloading test image..."
# wget https://aka.ms/torchserve-test-image -O $BASE_PATH/kitten_small.jpg

# echo "Uploading testing image, the scoring is..."
# curl http://localhost:8080/predictions/densenet161 -T $BASE_PATH/kitten_small.jpg

echo "Creating the online endpoint..."
az ml online-endpoint create -f $BASE_PATH/endpoint.yml -g $RESOURCE_GROUP --workspace-name $WORKSPACE_NAME
sleep 10


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

echo "Writing out the deployment file..."
deployment_name='torchserve-deployment'$number
deployment_file="$BASE_PATH/deployment.yml"
printf '$schema: https://azuremlschemas.azureedge.net/latest/managedOnlineDeployment.schema.json \n' > $deployment_file
printf "name: $deployment_name \n" >> $deployment_file
printf "endpoint_name: $ENDPOINT_NAME \n" >> $deployment_file
printf "model: \n" >> $deployment_file
printf "  path: torchserve \n" >> $deployment_file
printf "environment_variables: \n" >> $deployment_file
printf "  TORCHSERVE_MODELS: 'densenet161=densenet161.mar' \n" >> $deployment_file
printf "environment: \n" >> $deployment_file
printf "  name: env$number \n" >> $deployment_file
printf "  image: $ACR_NAME.azurecr.io/torchserve:1 \n" >> $deployment_file
printf "  inference_config: \n" >> $deployment_file
printf "    liveness_route: \n" >> $deployment_file
printf "      path: /ping \n" >> $deployment_file
printf "      port: 8080 \n" >> $deployment_file
printf "    readiness_route: \n" >> $deployment_file
printf "      path: /ping \n" >> $deployment_file
printf "      port: 8080 \n" >> $deployment_file
printf "    scoring_route: \n" >> $deployment_file
printf "      path: /predictions/densenet161 \n" >> $deployment_file
printf "      port: 8080 \n" >> $deployment_file
printf 'instance_type: Standard_DS3_v2 \n' >> $deployment_file
printf 'instance_count: 1 \n' >> $deployment_file
sleep 3


echo "Triggering the online deployment..."
az ml online-deployment create \
  --endpoint-name $ENDPOINT_NAME \
  -g $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  -f "$BASE_PATH/deployment.yml" --all-traffic

echo "Getting token and scoring URL..."
KEY=$(az ml online-endpoint get-credentials \
  -n $ENDPOINT_NAME \
  -g $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --query accessToken -o tsv)
if [[ $KEY == "" ]]; then
  echo "Did not retrieve a token..."
  exit 1
fi
echo "Got the token...$KEY"

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

# Create variables file
printf "${grn}Writing out key variables...${end}\n"
env_variable_file='dn_variables.env'
printf "SCORING_URL=$SCORING_URL \n" > $env_variable_file
printf "TOKEN=$KEY \n" >> $env_variable_file
