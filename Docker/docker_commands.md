**Image Management Commands**
- docker images
    - Displays a list of available images on the host along with their sizes.

- docker rmi <image>
    - Removes an image from the host, provided no containers are using it.

- docker pull <image>
    - Downloads an image from Docker Hub without running a container.

- docker history <image>
    - History of image build

- docker images -f dangling=true
    - Lists all the dangling i.e not associated with any tag.

- docker image prune 
    - removes all dangling images

**Container Management Commands**
- docker run --name <coantiner_name> <image>
    - Runs a container from the specified image. If the image is not available locally, it pulls it from Docker Hub.
    - Runs a conatiner in foreground with specific name

- docker stop <container_id or container_name>
    - Stops a running container using its ID or name.

- docker start <container_id or container_name>
    - Starts a container using its ID or name.

- docker restart <container_id or container_name>
    - Restarts a container using its ID or name.

- docker rm <container_id or container_name>
    - Permanently removes a stopped or exited container.

- docker exec <container_id> <command>
    - Executes a command inside a running container.

- docker attach <container_id>
    - Attaches to a running container to view its output.

- docker run -d <image>
    - Runs a container in detached mode, allowing it to run in the background.

- **Container Status Commands**
    - docker ps
        - Lists all running containers along with their basic information.

    - docker ps -a
        - Lists all containers, including those that have exited.

- **Logging and inspecting**
    - docker inspect <container_name_or_ID>
        - Provides the details of conatiner in json format like IP, OS, Volume etc
    - docker logs <container_name_or_ID>
        - To check the logs of the container

- **Volumes and Ports**
    - *docker volume create my_volume*
        - Create a docker volume
    - *docker run --mount type=volume,source=my_volume,target=/path/in/container my_image* OR *docker run -v my_volume:/path/in/container my_image*
        - *Run a container with the docker volume* stored in ***/var/lib/docker/volumes***
    - *docker run --mount type=bind,source=/host/path,target=/container/path my_image* OR *docker run -v /host/path:/container/path*
        - *Run a container with bind mount* which is folder ***on host /host/path*** to the container container/path.

- **Networks**
    - *docker network create --driver <bridge/host/none> --subnet <subnet_block> --gateway <ip> <nw_name>*
        - creates a network
    - *docker network ls*
        - list the networks
    - *docker inspect <network_name>*
        - get the detials of respective network
    - *docker run --name <container_name> --network <network_name> <image>*
        - run a container in specific network
    - *docker network connect <network_name> <container_id>*
        - connect to existing network
    - *docker network disconnect <network_name> <conatiner_id>*
        - disconnect container from a network

- **Installing Docker on ubuntu**
```bash
sudo apt update ; sudo apt install apt-transport-https ca-certificates curl software-properties-common ; curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - ; sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" ; apt-cache policy docker-ce ; sudo apt install docker-ce ; sudo systemctl status docker ; sudo usermod -aG docker ${USER}
```
