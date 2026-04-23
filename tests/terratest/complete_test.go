package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestExampleComplete(t *testing.T) {
	// retryable errors in terraform testing.
	t.Log("Starting Example Module test")

	terraformDir := "../../examples/complete"
	stateKey := "terratest/terraform-aws-acf-observability.tfstate"
	backendConfig := loadBackendConfig(t, stateKey)

	// Create IAM Role for Provisioners
	terraformPreparation := &terraform.Options{
		TerraformBinary: getHclBinary(),
		TerraformDir:    terraformDir,
		NoColor:         false,
		Lock:            true,
		BackendConfig:   backendConfig,
		Reconfigure:     true,
		Targets: []string{
			"module.create_sink_provisioner",
			"module.create_member_1_provisioner",
			"module.create_member_2_provisioner",
		},
	}
	defer terraform.Destroy(t, terraformPreparation)
	terraform.InitAndApply(t, terraformPreparation)

	terraformModule := &terraform.Options{
		TerraformBinary: getHclBinary(),
		TerraformDir:    terraformDir,
		NoColor:         false,
		Lock:            true,
		BackendConfig:   backendConfig,
		Reconfigure:     true,
	}

	defer terraform.Destroy(t, terraformModule)
	terraform.InitAndApply(t, terraformModule)

	// Retrieve the 'test_success' output
	testSuccessOutput := terraform.Output(t, terraformModule, "example_passed")

	// Assert that 'test_success' equals "true"
	assert.Equal(t, "true", testSuccessOutput, "The test_success output is not true")
}
