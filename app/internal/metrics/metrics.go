package metrics

// CollectRuntimeMetrics is a no-op function
// The Prometheus client library already provides default Go runtime metrics
// via prometheus.NewGoCollector() which is automatically registered
// when using promhttp.Handler()
//
// Default metrics include:
// - go_goroutines: Number of goroutines
// - go_memstats_alloc_bytes: Bytes allocated and in use
// - go_memstats_sys_bytes: Bytes obtained from system
// - go_gc_duration_seconds: GC pause duration
// - And many more...
func CollectRuntimeMetrics() {
	// No-op: Default Go metrics are automatically collected
	// by the Prometheus client library when using promhttp.Handler()
}
