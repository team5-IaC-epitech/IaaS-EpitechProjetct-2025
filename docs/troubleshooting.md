# Troubleshooting Guide

This document lists common issues encountered when deploying or operating Task Manager, along with their solutions.

## Common Issues

### 1. Cannot access cluster

- Check configuration:
  ```bash
  gcloud container clusters get-credentials <CLUSTER_NAME> --region <REGION>
  ```
- Check IAM permissions on GCP

### 2. Pods in CrashLoopBackOff

- Check logs:
  ```bash
  kubectl logs <POD_NAME>
  ```
- Check secret and environment variable configuration
- Check database connectivity

### 3. Autoscaling not working

- Check HPA configuration:
  ```bash
  kubectl get hpa
  ```
- Check that metrics are being collected (`kubectl top pods`)

### 4. Database migration issues

- Check API startup logs
- Ensure migration files are present in the Docker image

### 5. API access issues

- Check the LoadBalancer IP or domain name
- Check firewall rules on GCP

For any other issue, check application logs and Kubernetes events:

```bash
kubectl get events --sort-by=.lastTimestamp
```
