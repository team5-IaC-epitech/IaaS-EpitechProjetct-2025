project_id  = "iaasepitech"
region      = "europe-west9"
vpc_name = "team5-vpc-dev"
cidr_block  = "10.0.1.0/24"

cluster_name = "team5-gke-cluster"
environment = "dev"
node_count = 2
min_node_count = 1
max_node_count = 5
machine_type = "e2-medium"
disk_size_gb = 10
disk_type = "pd-balanced"
preemptible = false
create_system_node_pool = false
