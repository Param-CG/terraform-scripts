provider "google" {
    project = "kong-on-gke-324807"
    credentials = "terraform-service-account-key.json"
    region = "us-central1"
  
}

provider "kubernetes" {
}

