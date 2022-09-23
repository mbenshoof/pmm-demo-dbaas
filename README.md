# pmm-demo-dbaas
Quick demo to launch PMM from EC2 with userdata to connect to k8s.  The main purpose is to demonstrate how easily one can launch a PMM instance in EC2, just using stock components and a userdata script.  It also highlights that PMM ***does have*** a pretty cool API as well!  The userdata script makes a few API calls to automate linking k8s with PMM to experiment with DBaaS.

## Prerequisites / Environment

This demo is designed to launch an EC2 instance, install the latest version of PMM, and link with a pre-existing kuberenetes cluster to experiment with DBaaS.  

- AWS account and environment
  - VPC with public subnet (set to auto-assign Public IP)
  - Security group allowing SSH and HTTPS access from your location (or global)
  - SSH Keypair
  - S3 bucket accessible from an EC2 instance role (see [sample policy](/aws/s3-access-policy.json))
- Existing k8s cluster
  - Free demo k8s cluster from the [Percona Portal](https://portal.percona.com/kubernetes)
    - Need the kubeconfig file
    
## Deploying the demo

1. **Upload the kubeconfig file to an S3 bucket**

     - Name the file kubeconfig.yaml
     - Note the name of the bucket

2. **Configure a new EC2 instance with the following**

   - Launch into a public subnet with public IP
   - Specify a keypair for SSH connection
   - Assign the instance role that allows access to the S3 bucket in step 1
   - Attach a security group that allows SSH and HTTPS access to the instance
   - Define following minimum tags for k8s config:
   
     - **kubeconfig-bucket** : *s3-bucket-name*     
     - **kubeconfig-file** : *kubeconfig.yaml*
     
   - Ensure instance metadata is viewable and tags are included in instance metadata
   - Set up the userdata script from [aws/userdata.sh](/aws/userdata.sh)

3. **Launch the instance**

4. **Connect to the instance via SSH with the keypair defined**

5. **Tail the userdata startup log and look for an endpoint**

   - `sudo tail -f /var/log/cloud-init-output.log`
   - Look for ***K8s Landing Page: https://public.ip.address/graph/dbaas/kubernetes***

## Using the demo
  
Now that PMM has been set up and linked to a k8s cluster, it is time to launch a DB cluster and see it do some things!

1. **Connect to PMM with the URL output from the userdata script**:

   - `https://public.ip.address/graph/dbaas/kubernetes`
   - Default credentials are `admin:admin` - you will be prompted to change at first login
   
2. **Launch a DB cluster in your k8s cluster**:

   - Follow instructions from [PMM documentation](https://docs.percona.com/percona-monitoring-and-management/using/dbaas.html#db-clusters)
   
3. **Store the _host/user/password_ from the DBaaS UI for your new cluster**

4. **Connect to the database from CLI and create the `sbtest` database**:

   - Launch mysql client image:
   
     `kubectl run -i --rm --tty percona-client --image=percona:8.0 --restart=Never -- bash -il`

   - Create the schema
     ```
     # Set up db variables variables.
     DBHOST="host-from-dbaas-ui"
     DBUSER="root"
     DBPASS="root_password"

     # Create the sbtest database for sysbench
     mysql -h "$DBHOST" -u"$DBUSER" -p"$DBPASS" -e "create database if not exists sbtest"
     ```
     
5. **Start the sysbench workload**:

   - Launch sysbench image:
   
     `kubectl run -it --rm sysbench-client --image=perconalab/sysbench:latest --restart=Never -- bash`

   - Prepare the schema and start a 1 hour test
     ```
      # Set up db variables variables.
      DBHOST="host-from-dbaas-ui"
      DBUSER="root"
      DBPASS="root_password"

      # Prepare and run sysbench over 10 tables.
      sysbench oltp_read_only --tables=10 --table_size=100  --mysql-host="$DBHOST" --mysql-user="$DBUSER" --mysql-password="$DBPASS" --mysql-db=sbtest  prepare
      sysbench oltp_read_write --tables=10 --table_size=100 --mysql-host="$DBHOST" --mysql-user="$DBUSER" --mysql-password="$DBPASS" --mysql-db=sbtest --time=3600 --threads=16 --report-interval=10 run
     ```

6. **Explore PMM graphs being populated by sysbench** (_assumes a MySQL Cluster, but works for MongoDB as well_)

   - Review MySQL instance metrics: [doc](https://docs.percona.com/percona-monitoring-and-management/details/dashboards/dashboard-mysql-instances-overview.html)
   - Review PXC/Galera metrics: [doc](https://docs.percona.com/percona-monitoring-and-management/details/dashboards/dashboard-pxc-galera-cluster-summary.html)
   
## Cleaning Up Resources

Assuming you used a free k8s cluster from the Percona Portal, this demo will be operational for 3 hours.  To ensure that you are not being charged, clean up your EC2 instance after k8s cluster expires.  If you registered the instance with Percona Platform, make sure that you unregister the PMM instance prior to termination and then you can clean up in the Portal PMM instance page.

## ToDo
Some ideas for extending this demo:

- Convert to a full Cloud Formation template?
- Automatically launch an image that configures and starts sysbench?
- Leverage the API to automatically create a DB cluster and capture credentials?

## Wrapping Up
There is so much you can do using the PMM API and EC2 instance metadata, let this be a starting point and let me know what you did!  
