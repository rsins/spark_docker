#!/bin/bash

# Bring the services up
function startServices {
  docker start nodemaster node2 node3
  sleep 5

  echo " >> Starting hdfs ..."
  docker exec -u hadoop -it nodemaster start-dfs.sh
  sleep 5
  
  echo " >> Starting yarn ..."
  docker exec -u hadoop -d nodemaster start-yarn.sh
  sleep 5
  
  echo " >> Starting MR-JobHistory Server ..."
  docker exec -u hadoop -d nodemaster mr-jobhistory-daemon.sh start historyserver
  sleep 5
  
  echo " >> Starting Spark ..."
  docker exec -u hadoop -d nodemaster start-master.sh
  docker exec -u hadoop -d node2 start-slave.sh nodemaster:7077
  docker exec -u hadoop -d node3 start-slave.sh nodemaster:7077
  sleep 5
  
  echo " >> Starting Spark History Server ..."
  docker exec -u hadoop nodemaster start-history-server.sh
  sleep 5
  
  echo " >> Preparing hdfs for hive ..."
  docker exec -u hadoop -it nodemaster hdfs dfs -mkdir -p /tmp
  docker exec -u hadoop -it nodemaster hdfs dfs -mkdir -p /user/hive/warehouse
  docker exec -u hadoop -it nodemaster hdfs dfs -chmod g+w /tmp
  docker exec -u hadoop -it nodemaster hdfs dfs -chmod g+w /user/hive/warehouse
  sleep 5
  
  echo " >> Starting Hive Metastore ..."
  docker exec -u hadoop -d nodemaster hive --service metastore
  docker exec -u hadoop -d nodemaster hive --service hiveserver2
  
  echo " >> Starting Nifi Server ..."
  docker exec -u hadoop -d nifi /home/hadoop/nifi/bin/nifi.sh start
  
  echo " >> Starting kafka & Zookeeper ..."
  docker exec -u hadoop -d edge /home/hadoop/kafka/bin/zookeeper-server-start.sh -daemon  /home/hadoop/kafka/config/zookeeper.properties
  docker exec -u hadoop -d edge /home/hadoop/kafka/bin/kafka-server-start.sh -daemon  /home/hadoop/kafka/config/server.properties
  
  echo " >> Starting Zeppelin ..."
  docker exec -u hadoop -d zeppelin /home/hadoop/zeppelin/bin/zeppelin-daemon.sh start

  echo 
  echo "Hadoop info @ nodemaster          : http://172.20.1.1:8088/cluster     & from host @ http://localhost:8088/cluster"
  echo "DFS Health @ nodemaster           : http://172.20.1.1:50070/dfshealth"
  echo "MR-JobHistory Server @ nodemaster : http://172.20.1.1:19888"
  echo "Spark info @ nodemaster           : http://172.20.1.1:8080"
  echo "Spark History Server @ nodemaster : http://172.20.1.1:18080            & from host @ http://localhost:18080"
  echo "Zookeeper @ edge                  : http://172.20.1.5:2181"
  echo "Kafka @ edge                      : http://172.20.1.5:9092"
  echo "Nifi @ edge                       : http://172.20.1.5:8080/nifi        & from host @ http://localhost:8080/nifi"
  echo "Zeppelin @ zeppelin               : http://172.20.1.6:8081             & from host @ http://localhost:8081"
  echo 
  echo "Hadoop ports exposed = 9000"
  echo "Spark ports exposed  = 4040, 6066, 7077"
  echo 
}

function stopServices {
  echo " >> Stopping Spark Master and slaves ..."
  docker exec -u hadoop -d nodemaster stop-master.sh
  docker exec -u hadoop -d node2 stop-slave.sh
  docker exec -u hadoop -d node3 stop-slave.sh
  docker exec -u hadoop -d nifi /home/hadoop/nifi/bin/nifi.sh stop
  docker exec -u hadoop -d zeppelin /home/hadoop/zeppelin/bin/zeppelin-daemon.sh stop

  echo " >> Stopping containers ..."
  docker stop nodemaster node2 node3 edge hue nifi zeppelin psqlhms
}

if [[ $1 = "install" ]]; then
  docker network create --subnet=172.20.0.0/16 sparknet # create custom network

  # Starting Postresql Hive metastore
  echo " >> Starting postgresql hive metastore ..."
  docker run -d --net sparknet                          \
  	            --hostname psqlhms                      \
  	            --name psqlhms                          \
  	            --ip 172.20.1.4                         \
  	            -e POSTGRES_PASSWORD=hive               \
  	            -it rsins/spark_cluster:postgresql-hms
  sleep 5
  
  # 3 nodes
  echo " >> Starting master and worker nodes ..."
  docker run -d --net sparknet                          \
  	            --hostname nodemaster                   \
  	            --name nodemaster                       \
  	            --ip 172.20.1.1                         \
  	            -p 8088:8088                            \
  	            -p 18080:18080                          \
  	            -p 4040:4040                            \
  	            -p 6066:6066                            \
  	            -p 7077:7077                            \
  	            -p 9000:9000                            \
  	            --add-host node2:172.20.1.2             \
  	            --add-host node3:172.20.1.3             \
  	            -it rsins/spark_cluster:hive
  docker run -d --net sparknet                          \
  	            --hostname node2                        \
  	            --name node2                            \
  	            --ip 172.20.1.2                         \
  	            --add-host nodemaster:172.20.1.1        \
  	            --add-host node3:172.20.1.3             \
  	            -it rsins/spark_cluster:spark
  docker run -d --net sparknet                          \
  	            --hostname node3                        \
  	            --name node3                            \
  	            --ip 172.20.1.3                         \
  	            --add-host nodemaster:172.20.1.1        \
  	            --add-host node2:172.20.1.2             \
  	            -it rsins/spark_cluster:spark
  docker run -d --net sparknet                          \
  	            --hostname edge                         \
  	            --name edge                             \
  	            --ip 172.20.1.5                         \
  	            --add-host nodemaster:172.20.1.1        \
  	            --add-host node2:172.20.1.2             \
  	            --add-host node3:172.20.1.3             \
  	            --add-host psqlhms:172.20.1.4           \
  	            -it rsins/spark_cluster:edge 
  docker run -d --net sparknet                          \
  	            --hostname nifi                         \
  	            --name nifi                             \
  	            --ip 172.20.1.6                         \
  	            -p 8080:8080                            \
  	            --add-host nodemaster:172.20.1.1        \
  	            --add-host node2:172.20.1.2             \
  	            --add-host node3:172.20.1.3             \
  	            --add-host psqlhms:172.20.1.4           \
  	            -it rsins/spark_cluster:nifi 
  docker run -d --net sparknet                          \
  	            --hostname huenode                      \
  	            --name hue                              \
  	            --ip 172.20.1.7                         \
  	            -p 8888:8888                            \
  	            --add-host edge:172.20.1.5              \
  	            --add-host nodemaster:172.20.1.1        \
  	            --add-host node2:172.20.1.2             \
  	            --add-host node3:172.20.1.3             \
  	            --add-host psqlhms:172.20.1.4           \
  	            -it rsins/spark_cluster:hue
  docker run -d --net sparknet                          \
  	            --hostname zeppelin                     \
  	            --name zeppelin                         \
  	            --ip 172.20.1.8                         \
  	            -p 8081:8081                            \
  	            --add-host edge:172.20.1.5              \
  	            --add-host nodemaster:172.20.1.1        \
  	            --add-host node2:172.20.1.2             \
  	            --add-host node3:172.20.1.3             \
  	            --add-host psqlhms:172.20.1.4           \
  	            -it rsins/spark_cluster:zeppelin

  # Format nodemaster
  echo " >> Formatting hdfs ..."
  docker exec -u hadoop -it nodemaster hdfs namenode -format
  startServices
  exit
fi


if [[ $1 = "stop" ]]; then
  stopServices
  exit
fi


if [[ $1 = "uninstall" ]]; then
  stopServices
  docker rmi rsins/spark_cluster:hadoop rsins/spark_cluster:spark rsins/spark_cluster:hive rsins/spark_cluster:postgresql-hms rsins/spark_cluster:hue rsins/spark_cluster:edge rsins/spark_cluster:nifi rsins/spark_cluster:zeppelin -f
       # can comment it later after testing, this will clear containers but leave images
  #docker ps -a | awk -F' ' '{print $1}' | tail -n +2 | xargs -I CC docker rm CC
  docker network rm sparknet
  docker system prune -f
  exit
fi

if [[ $1 = "start" ]]; then  
  docker start psqlhms nodemaster node2 node3 edge hue nifi zeppelin
  startServices
  exit
fi

if [[ $1 = "pull_images" ]]; then  
  docker pull -a rsins/spark_cluster
  exit
fi

echo " Usage: $0 [ pull_images | install | start | stop | uninstall ]"
echo "        pull_images  - download all docker images"
echo "        install      - Prepare to run and start for first time all containers"
echo "        start        - start existing containers"
echo "        stop         - stop running processes"
echo "        uninstall    - remove all docker images"

