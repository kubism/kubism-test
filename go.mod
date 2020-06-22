module github.com/kubism/kubism-test

go 1.13

require (
	github.com/codegangsta/cli v0.0.0-00010101000000-000000000000 // indirect
	github.com/go-logr/logr v0.1.0
	github.com/go-logr/zapr v0.1.0
	github.com/kr/pretty v0.2.0 // indirect
	github.com/onsi/ginkgo v1.13.0
	github.com/onsi/gomega v1.10.1
	github.com/stretchr/testify v1.5.1 // indirect
	go.uber.org/zap v1.10.0
	gopkg.in/check.v1 v1.0.0-20190902080502-41f04d3bba15 // indirect
	sigs.k8s.io/kind v0.8.1
)

replace (
	github.com/Sirupsen/logrus => github.com/sirupsen/logrus v1.6.0
	github.com/codegangsta/cli => github.com/urfave/cli v1.22.4
	github.com/influxdb/influxdb v1.8.0 => github.com/influxdata/influxdb v1.8.0
	github.com/tonistiigi/fifo v0.0.0-20200410184934-f15a3290365b => github.com/containerd/fifo v0.0.0-20200410184934-f15a3290365b
	google.golang.org/cloud => cloud.google.com/go v0.0.0
)
