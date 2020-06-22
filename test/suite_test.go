package test

import (
	"testing"

	"github.com/kubism/kubism-test/pkg/logger"
	"github.com/onsi/ginkgo/reporters"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func TestCertManager(t *testing.T) {
	RegisterFailHandler(Fail)
	junitReporter := reporters.NewJUnitReporter("../reports/cert-manager-junit.xml")
	RunSpecsWithDefaultAndCustomReporters(t, "CertManager", []Reporter{junitReporter})
}

var _ = BeforeSuite(func(done Done) {
	log := logger.WithName("kubism-test-test")
	By("being here")
	close(done)
}, 60)

var _ = AfterSuite(func() {
	By("tearing down the test environment")
})
