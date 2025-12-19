project_id  = "iaasepitech"
region      = "europe-west9"
vpc_name = "team5-vpc-dev"
cidr_block  = "10.0.0.0/20"
pods_range_name = "pods-range"
services_range_name = "services-range"

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
