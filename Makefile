infra:
	./setup/create-resources.sh

# Key input files 
sm_test_data='./test-data/sample-request.json'
sample_image='./test-data/persons.jpg'
dog_test='./test-data/dog.jpeg'
kitten_test='./test-data/kitten_small.jpg'

local_dev:
	#conda create -n singlemodel python=3.8 -y; conda activate singlemodel
	# conda env create -f environment.yml
	# pip install flake8

# SINGLE MODEL
sm_deploy:
	rm -f ./single-model/endpoint.yml
	rm -f ./single-model/deployment.yml
	./single-model/deploy_script.sh

sm_test:
	./single-model/test_endpoint.sh $(sm_test_data)

## DENSENET
dn_local_deploy:
	torchserve --start --ncs --model-store ./densenet/torchserve --models densenet=densenet161.mar
	sleep 10
	# Management APIs
		# curl http://localhost:8081/models
		# curl http://localhost:8081/models/densenet
	# Inference API: requires captum, pyyaml -> all part of environment.yml
	curl 127.0.0.1:8080/predictions/densenet -T $(dog_test)
	# torchserve --stop

dn_deploy:
	rm -f ./densenet/endpoint.yml
	rm -f ./densenet/deployment.yml
	rm -rf ./densenet/torchserve
	./densenet/deploy_script.sh

dn_test:
	./densenet/test_endpoint.sh $(dog_test) $(kitten_test)

# FASTRCNN
# Source: https://github.com/pytorch/serve/tree/master/examples/object_detector
fastrcnn_install:
	#conda create -n fastrcnn python=3.8 -y; conda activate fastrcnn
	pip install torchvision
	pip install torch-model-archiver
	pip install torchserve
	pip install flake8

fastrcnn_deploy:
	rm -rf ./fastrcnn/endpoint.yml
	rm -rf ./fastrcnn/deployment.yml
	./fastrcnn/deploy_script.sh

fastrcnn_test:
	./fastrcnn/test_endpoint.sh $(sample_image)
	sleep 5
	./fastrcnn/test_endpoint.sh $(dog_test)

## YOLO
yolo_deploy:
	rm -rf ./yolo/endpoint.yml
	rm -rf ./yolo/deployment.yml
	./yolo/deploy_script.sh

yolo_test:
	./yolo/test_endpoint.sh $(dog_test)
