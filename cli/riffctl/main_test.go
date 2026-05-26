package main

import (
	"bytes"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestHelpExplainsTemplateWorkflowForAgents(t *testing.T) {
	output := captureStdout(t, printUsage)

	for _, want := range []string{
		"riffctl create qa-verify --title \"QA Verify\" --roles 3",
		"riffctl publish qa-verify",
		"riffctl template create reusable-debate --roles 3",
		"~/.riff/drafts/qa-verify/riff.yaml",
		"~/.riff/drafts/qa-verify/agents/role-1.yaml",
		"Edit prompt.md with the debate topic.",
		"Riff automatically applies ~/.riff/config/base_prompt.md when the riff runs.",
		"Publish the app-visible riff from those files.",
		"Open Riff. The new riff appears in the sidebar; click Start.",
	} {
		if !strings.Contains(output, want) {
			t.Fatalf("help output missing %q:\n%s", want, output)
		}
	}
}

func TestCreateDraftAndPublishCommandsUseNewShape(t *testing.T) {
	root := t.TempDir()

	if err := run([]string{"create", "qa-verify", "--title", "QA Verify", "--roles", "2", "--root", root}); err != nil {
		t.Fatalf("create draft returned error: %v", err)
	}
	writeFile(t, filepath.Join(root, "drafts", "qa-verify", "prompt.md"), "Validate the idea.\n")

	if err := run([]string{"publish", "qa-verify", "--root", root}); err != nil {
		t.Fatalf("publish riff returned error: %v", err)
	}
	if _, err := os.Stat(filepath.Join(root, "drafts", "qa-verify", "agents", "role-1.yaml")); err != nil {
		t.Fatalf("role file missing: %v", err)
	}
	if _, err := os.Stat(filepath.Join(root, "config", "recent-conversations.json")); err != nil {
		t.Fatalf("recent conversations missing: %v", err)
	}
}

func TestTemplateCreateUsesSeparatePath(t *testing.T) {
	root := t.TempDir()

	if err := run([]string{"template", "create", "reusable-debate", "--roles", "2", "--root", root}); err != nil {
		t.Fatalf("template create returned error: %v", err)
	}
	if _, err := os.Stat(filepath.Join(root, "templates", "reusable-debate", "role-1.yaml")); err != nil {
		t.Fatalf("template role file missing: %v", err)
	}
}

func TestCreateDraftPrintsSluggedPublishCommand(t *testing.T) {
	root := t.TempDir()

	output := captureStdout(t, func() {
		if err := run([]string{"create", "QA Verify", "--title", "QA Verify", "--root", root}); err != nil {
			t.Fatalf("create draft returned error: %v", err)
		}
	})
	if !strings.Contains(output, "riffctl publish qa-verify") {
		t.Fatalf("output missing slugged publish command:\n%s", output)
	}
}

func TestOldCreateAgentCreateRiffAndCreateTemplateFormsAreRejected(t *testing.T) {
	root := t.TempDir()

	if err := run([]string{"create", "agent", "qa-verify", "--roles", "2", "--root", root}); err == nil {
		t.Fatal("create agent unexpectedly succeeded")
	}
	if err := run([]string{"create", "riff", "qa-verify", "--title", "QA Verify", "--root", root}); err == nil {
		t.Fatal("create riff unexpectedly succeeded")
	}
	if err := run([]string{"create", "template", "qa-verify", "--roles", "2", "--root", root}); err == nil {
		t.Fatal("create template unexpectedly succeeded")
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

func writeFile(t *testing.T, path string, contents string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(contents), 0644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}
