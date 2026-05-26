package main

import (
	"bytes"
	"io"
	"os"
	"strings"
	"testing"
)

func TestHelpExplainsTemplateWorkflowForAgents(t *testing.T) {
	output := captureStdout(t, printUsage)

	for _, want := range []string{
		"riffctl create agent architecture-debate --roles 3",
		"riffctl create riff architecture-debate --title \"Architecture debate\"",
		"~/.riff/templates/architecture-debate/role-1.yaml",
		"~/.riff/templates/architecture-debate/prompt.md",
		"Edit each role YAML",
		"Edit prompt.md with the debate topic.",
		"Riff automatically applies ~/.riff/config/base_prompt.md when the riff runs.",
		"Create the app-visible riff from those files.",
		"Open Riff. The new riff appears in the sidebar; click Start.",
	} {
		if !strings.Contains(output, want) {
			t.Fatalf("help output missing %q:\n%s", want, output)
		}
	}
}

func captureStdout(t *testing.T, fn func()) string {
	t.Helper()
	original := os.Stdout
	reader, writer, err := os.Pipe()
	if err != nil {
		t.Fatalf("pipe stdout: %v", err)
	}
	os.Stdout = writer
	fn()
	_ = writer.Close()
	os.Stdout = original
	var buffer bytes.Buffer
	if _, err := io.Copy(&buffer, reader); err != nil {
		t.Fatalf("read stdout: %v", err)
	}
	return buffer.String()
}
