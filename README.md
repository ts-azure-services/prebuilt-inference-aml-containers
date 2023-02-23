# prebuilt-inference-containers
A repo to house workflows around the [prebuilt inference containers](https://learn.microsoft.com/en-us/azure/machine-learning/concept-prebuilt-docker-images-inference)
in Azure Machine Learning. Ensure that the [AML CLI
v2](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-configure-cli?tabs=public) is installed.

## single-model
This is a copy of what's available at the following
[location](https://github.com/Azure/azureml-examples/tree/main/cli/endpoints/online/custom-container/minimal/single-model).
This is a pre-trained scikit regression model that is small enough to be part of this repo. There is likely
  more detail somewhere on the business use case and what is actually being measured. However, this also
  mimics typical enterprise scenarios where data scientists will work on a model and expect an operations team
  to deploy this. To initiate the workflow, reference the commands in the **Makefile**:
  - Run `make sm_deploy` to initiate the endpoint and deployment in Azure ML.
  - Once deployed, `make sm_test` to test with a sample request. 

Note: The **endpoint.yml** and **deployment.yml** file for the custom container are created as part of the execution of
  the **deploy_script.sh** since attributes are updated dynamically.

## densenet
This is a copy of what's available at the following [location](https://github.com/Azure/azureml-examples/tree/main/cli/endpoints/online/custom-container/torchserve/densenet).
This is a PyTorch model, deployed using TorchServe. Of note, there is no model file or handler in this case. This leverages a pre-existing MAR file
to build a Docker image which is then used to build the deployment. To initiate the deployment, reference the
commands in the **Makefile**:
  - Run the `make dn_deploy` to build the endpoint and the deployment in Azure ML.
  - Run `make dn_test` to test with endpoint with two images in the **test-data** folder.

With the downloaded MAR file, you can also run `make dn_local_deploy` to test the deployment locally.

## fastrcnn
This is similar to the **densenet** model, except the MAR file is built locally using a **model.py** handler
file, before being included in the Docker build. To initiate the build:
  - Run `fastrcnn_deploy` to initiate the endpoint and the deployment.
  - Run `fastrcnn_test` to test the endpoint.

## yolo-pytorch
