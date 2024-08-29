
stop all container

    docker stop $(docker ps -q)

remove all container

    docker rm $(docker ps -a -q)