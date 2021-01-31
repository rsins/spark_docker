#!/bin/bash

# generate ssh key
echo "Y" | ssh-keygen -t rsa -P "" -f configs/id_rsa

# Hadoop build
docker build -f ./hadoop/Dockerfile . -t rsins/spark_cluster:hadoop

# Spark
docker build -f ./spark/Dockerfile . -t rsins/spark_cluster:spark

# PostgreSQL Hive Metastore Server
docker build -f ./postgresql-hms/Dockerfile . -t rsins/spark_cluster:postgresql-hms

# Hive
docker build -f ./hive/Dockerfile . -t rsins/spark_cluster:hive

# Nifi
docker build -f ./nifi/Dockerfile . -t rsins/spark_cluster:nifi

# Edge
docker build -f ./edge/Dockerfile . -t rsins/spark_cluster:edge

# hue
docker build -f ./hue/Dockerfile . -t rsins/spark_cluster:hue

# zeppelin
docker build -f ./zeppelin/Dockerfile . -t rsins/spark_cluster:zeppelin
