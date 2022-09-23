# Connect to the cluster and create the sbtest database.
kubectl run -i --rm --tty percona-client --image=percona:8.0 --restart=Never -- bash -il

# Set up db variables variables.
DBHOST="host-from-dbaas-ui"
DBUSER="root"
DBPASS="root_password"

# Create the sbtest database for sysbench
mysql -h "$DBHOST" -u"$DBUSER" -p"$DBPASS" -e "create database if not exists sbtest"



# Now, set up sysbench to make some generic load.
kubectl run -it --rm sysbench-client --image=perconalab/sysbench:latest --restart=Never -- bash

# Set up db variables variables.
DBHOST="host-from-dbaas-ui"
DBUSER="root"
DBPASS="root_password"

# Prepare and run sysbench over 10 tables.
sysbench oltp_read_only --tables=10 --table_size=100  --mysql-host="$DBHOST" --mysql-user="$DBUSER" --mysql-password="$DBPASS" --mysql-db=sbtest  prepare
sysbench oltp_read_write --tables=10 --table_size=100 --mysql-host="$DBHOST" --mysql-user="$DBUSER" --mysql-password="$DBPASS" --mysql-db=sbtest --time=300 --threads=16 --report-interval=1 run