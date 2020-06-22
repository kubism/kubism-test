package util

import (

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("KindEnv", func() {
	It("should be created", func() {

		config := KindEnvConfig{
			Name:      "test-env"
			ImageName:  ""   // use default image
			Retain:     false
			Wait:       time.Duration(0)
			Kubeconfig: ""
		}

		env, err := NewKindEnv(config)
		Expect(err).ToNot(HaveOccurred())
	})
})
