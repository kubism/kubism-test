/*
Copyright 2020 Backup Operator Authors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package util

import (
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/kubism/kubism-test/pkg/logger"

	"sigs.k8s.io/kind/pkg/cluster"
	"sigs.k8s.io/kind/pkg/errors"
	"sigs.k8s.io/kind/pkg/internal/runtime"
)

type KindEnvConfig struct {
	Name       string
	ImageName  string
	Retain     bool
	Wait       time.Duration
	Kubeconfig string
}

type KindEnv struct {
	Dir        string
	Name       string
	Kubeconfig string
	log        logger.Logger
}

// NewKindEnv starts a new KinD clusters based on the supplied configuration
func NewKindEnv(config *KindEnvConfig) (*KindEnv, error) {
	log := logger.WithName("kindenv")

	provider := cluster.NewProvider(
		cluster.ProviderWithLogger(log),
		runtime.GetDefault(log),
	)

	// create the cluster
	if err = provider.Create(
		config.Name,
		cluster.CreateWithRawConfig(kubeAdmConfig),
		cluster.CreateWithNodeImage(config.ImageName),
		cluster.CreateWithRetain(config.Retain),
		cluster.CreateWithWaitForReady(config.Wait),
		cluster.CreateWithKubeconfigPath(config.Kubeconfig),
		cluster.CreateWithDisplayUsage(true),
		cluster.CreateWithDisplaySalutation(true),
	); err != nil {
		return nil, errors.Wrap(err, "failed to create cluster")
	}

	return nil

	bin := "kind" // fallback
	if value, ok := os.LookupEnv("KIND"); ok {
		bin = value
	}
	dir, err := ioutil.TempDir("", "kindenv")
	if err != nil {
		return nil, err
	}
	name := "test"
	if value, ok := os.LookupEnv("KIND_CLUSTER"); ok {
		name = value
	}
	log.Info("cluster created", "name", name)
	cmd := exec.Command(bin, "get", "kubeconfig", "--name", name)
	out, err := cmd.Output() // do not use setupCmd here
	if err != nil {
		return nil, err
	}
	kubeconfig := filepath.Join(dir, "kubeconfig")
	err = ioutil.WriteFile(kubeconfig, out, 0644)
	if err != nil {
		return nil, err
	}
	return &KindEnv{
		Dir:        dir,
		Name:       name,
		Kubeconfig: kubeconfig,
		log:        log,
	}, nil
}

func (e *KindEnv) LoadDockerImage(image string) error {
	cmd := exec.Command(e.Bin, "load", "docker-image", "--name", e.Name, image)
	e.setupCmd(cmd)
	return cmd.Run()
}

func (e *KindEnv) Close() error {
	return os.RemoveAll(e.Dir)
}


// TODO make this configurable
var kubeAdmConfig := `
kind: Cluster
apiVersion: kind.sigs.k8s.io/v1alpha3
# patch the generated kubeadm config with a featuregate
kubeadmConfigPatches:
- |
  apiVersion: kubeadm.k8s.io/v1beta2
  kind: ClusterConfiguration
  metadata:
    name: config
  apiServer:
    extraArgs:
      "service-account-issuer": "kubernetes.default.svc"
      "service-account-signing-key-file": "/etc/kubernetes/pki/sa.key"
nodes:
# the control plane node config
- role: control-plane
  image: kindest/node:v1.15.7@sha256:e2df133f80ef633c53c0200114fce2ed5e1f6947477dbc83261a6a921169488d
- role: control-plane
  image: kindest/node:v1.15.7@sha256:e2df133f80ef633c53c0200114fce2ed5e1f6947477dbc83261a6a921169488d
- role: control-plane
  image: kindest/node:v1.15.7@sha256:e2df133f80ef633c53c0200114fce2ed5e1f6947477dbc83261a6a921169488d
- role: worker
  image: kindest/node:v1.15.7@sha256:e2df133f80ef633c53c0200114fce2ed5e1f6947477dbc83261a6a921169488d
- role: worker
  image: kindest/node:v1.15.7@sha256:e2df133f80ef633c53c0200114fce2ed5e1f6947477dbc83261a6a921169488d
- role: worker
  image: kindest/node:v1.15.7@sha256:e2df133f80ef633c53c0200114fce2ed5e1f6947477dbc83261a6a921169488d
`