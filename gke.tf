resource "google_container_cluster" "primary" {
  name     = "gke-terraform-cluster-aj"
  location = "us-central1"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  #remove_default_node_pool = false
  initial_node_count       = 1
	node_config {
		labels = {
			environment = "dev"
		}
		tags = ["environment", "dev"]
	}
}


resource "null_resource" "script" {

provisioner "local-exec" {
    command = <<EOT
		echo 'Connecting to the newly created Cluster xec'
                echo 'Starting Kong Installation.......'
		sh install_kong_helm.sh
                EOT

      }
    depends_on = [google_container_cluster.primary]
}

