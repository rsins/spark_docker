#!/bin/bash

# push to dockerhub

# Hadoop
docker push rsins/spark_cluster:hadoop

# Spark
docker push rsins/spark_cluster:spark

# PostgreSQL Hive Metastore Server
docker push rsins/spark_cluster:postgresql-hms

# Hive
docker push rsins/spark_cluster:hive

# Nifi
docker push rsins/spark_cluster:nifi

# Edge
docker push rsins/spark_cluster:edge

# hue
docker push rsins/spark_cluster:hue

# zeppelin
docker push rsins/spark_cluster:zeppelin
