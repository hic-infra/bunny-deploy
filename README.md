# AWS Bunny Deployment

This repository contains Terraform for deploying [Bunny](https://github.com/Health-Informatics-UoN/hutch-bunny) in AWS Elastic Kubernetes Services (EKS).

## Recommended Deployment

There are a couple of options for using this repository.


### As a submodule in a private repository

We include this public repository as a submodule in a private repository. This allows us to keep anything sensitive (e.g. Biobank IDs and IP addresses) confidential, while still making the Terraform available for others to use.

```
mkdir bunny; cd bunny
git init .
git submodule add bunny-deploy https://github.com/hic-infra/bunny-deploy.git
git submodule init
git submodule update
touch bunnies.yaml prod.tfbackend prod.tfvars
```

You can then customise `bunnies.yaml`, `*.tfbackend` and `*.tfvars` file to your environment. There are more details about `bunnies.yaml` later in this readme. The `tfbackend` file should define where the terraform state resides. This is likely best stored in an S3 bucket, in case you lose your local copy of the repository. For S3, it should contain the following details:

```
bucket = "your-bucket"
key    = "your-state.tfstate"
region = "eu-west-2"
```

The `tfvars` file allows you to override any defaults set by the `eks-cluster/variables.tf` file. As a minimum, you'll want to configure a couple of options:

```
cluster_name  = bunny
namespace     = bunny
k8s_api_cidrs = [
   "your.public.ip.address/32"
]
bunnies_yaml  = "../../bunnies.yaml"
```

### As a private fork

To simplify the deployment, you can create a private copy/fork of this repository. This will make it harder to make use of changes made by HIC at a later date, though.

```
git clone https://github.com/hic-infra/bunny-deploy.git
cd bunny-deploy
```

You can then customise the `eks-cluster/variables.tf` file, or any other Terraform code, directly.


## Deploying

Ensure you have an AWS account setup and your AWS credentials / profile is setup. You may want to test that this is all working by running `aws sts get-caller-identity`.

```
cd eks-cluster
terraform init [-backend-config ../../prod.tfbackend]
terraform plan [-var-file ../../prod.tfvars]
```

You only want the bits in `[...]` (without the brackets) if you are using this repository as a submodule. In order to manage the Kubernetes cluster, you will need to create a `kubeconfig` file. A helper script is provided in this repository to do that for you, which you can run as `./create-kubeconfig.sh`. If you run this, you will want to export the `KUBECONFIG` variable so that it's pointing to the right file.

```bash
export KUBECONFIG=$PWD/kubeconfig
```

## The `bunnies.yaml` file

This file attempts to provide a simple configuration structure for managing lots of Bunny instances. The Terraform will create the availabunny and distribunny for each entry. It also makes it simple to share the same collection with multiple RQuest instances. To enable this, the yaml file is broken into two main variables, `endpoints` and `bunnies`, both of which must be arrays of dictionaries.

During the initial Terraform deployment, you will want to ensure that both `endpoints` and `bunnies` are empty, like so:

```yaml
endpoints:

bunnies:
```

### `endpoints`

Each endpoint consists of two key/value pairs, `name` and `secret`. The name is referenced from bunnies later, and the secret is the name of the Kubernetes secret containing the connection details. Here's an example:

```yaml
endpoints:
  - name: example
    secret: example-gateway
```

The secret `example-gateway` needs to be created separately using `kubectl`:

```
kubectl -n bunny create secret generic gateways-example \
	--from-literal address=https://example/link_connector_api/ \
	--from-literal "username=example" \
	--from-literal "password=example
```

### `bunnies`

Each bunny should refer to a single Postgres database. From that, it can point to multiple gateways, or the same gateway multiple times, with different collection IDs.

```
bunnies:
  - name: sample_omop
    data:
      source_db: sample_omop
      suppression: 10
      rounding: 10
    connections:
      - collection_id: RQ-CC-01234567-89ab-cdef-0123-456789abcdef
        endpoint: example
        debug: DEBUG
```

`debug` is optional and defaults to `INFO`. This can be set to `DEBUG` if you are trying to resolve an issue with a collection.

## Importing OMOP data

In order to connect to the RDS instance locally, it is convenient to run a pod for forwarding the database port to your local machine.

```
PGHOST=$(terraform output -raw rds_endpoint)
kubectl run \
	--env REMOTE_HOST=$PGHOST \
	--env REMOTE_PORT=5432 --env LOCAL_PORT=5432 --port 5432 \
	--image marcnuri/port-forward port-forward
kubectl --namespace default port-forward port-forward 5432:5432

# In another terminal...
export PGPASSWORD=$(terraform output -raw rds_password)
psql -h localhost -U bunny -d postgres

> create database sample_omop;
```

The `sample_omop/sample_omop.sh` script provides an example of how the data can then be imported.
