# Scalability Testing

This guide describes how to test the load capacity of the Task Manager API and verify Kubernetes autoscaling works as expected.

## Tool Used

- Bash script: `scripts/test-scalability.sh`
- Load generator: `hey` (automatically installed by the script)

## Running a Test

1. Ensure the cluster and API are accessible
2. Run the script:
   ```bash
   cd scripts
   ./test-scalability.sh
   ```
3. Follow the instructions to choose the test type (load + monitoring, monitoring only, load only)

## Customizable Parameters

- `REQUESTS`: Total number of requests
- `CONCURRENCY`: Number of concurrent requests
- `DURATION`: Test duration (seconds)
- `INGRESS_IP`: LoadBalancer IP
- `ENDPOINT`: Endpoint to test (default `/healthz`)

Example:

```bash
REQUESTS=20000 CONCURRENCY=100 DURATION=600 ./test-scalability.sh
```

## Expected Results

- The number of pods increases automatically under heavy load
- Returns to initial state after the test ends
- Metrics are visible via `kubectl top pods` and `kubectl get hpa`

## Troubleshooting

- Check cluster access: `kubectl get pods`
- Check API accessibility: `curl http://<INGRESS_IP>/healthz`
