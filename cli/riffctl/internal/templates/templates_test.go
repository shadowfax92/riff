package templates

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCreateAgentTemplateWritesRequestedRoleYAMLs(t *testing.T) {
	root := t.TempDir()

	result, err := CreateAgentTemplate(CreateAgentOptions{
		Root:  root,
		Name:  "Strategy Debate",
		Roles: 3,
	})
	if err != nil {
		t.Fatalf("CreateAgentTemplate returned error: %v", err)
	}

	if result.Path != filepath.Join(root, "templates", "strategy-debate") {
		t.Fatalf("template path = %q, want template under ~/.riff/templates", result.Path)
	}
	if len(result.RoleFiles) != 3 {
		t.Fatalf("created %d role files, want 3", len(result.RoleFiles))
	}
	for i, file := range result.RoleFiles {
		data, err := os.ReadFile(file)
		if err != nil {
			t.Fatalf("read role file %q: %v", file, err)
		}
		text := string(data)
		if !strings.Contains(text, "name: Role "+string(rune('1'+i))) {
			t.Fatalf("role file %q missing default role name, contents:\n%s", file, text)
		}
		if !strings.Contains(text, "runtime: claude") {
			t.Fatalf("role file %q missing default runtime, contents:\n%s", file, text)
		}
		if !strings.Contains(text, "instructions: |") {
			t.Fatalf("role file %q missing instructions block, contents:\n%s", file, text)
		}
	}
}

func TestCreateAgentTemplateRejectsInvalidRoleCount(t *testing.T) {
	_, err := CreateAgentTemplate(CreateAgentOptions{
		Root:  t.TempDir(),
		Name:  "bad",
		Roles: 0,
	})
	if err == nil {
		t.Fatal("CreateAgentTemplate returned nil error for zero roles")
	}
}

func TestCreateAgentTemplateDoesNotOverwriteWithoutForce(t *testing.T) {
	root := t.TempDir()
	opts := CreateAgentOptions{Root: root, Name: "Existing", Roles: 1}
	if _, err := CreateAgentTemplate(opts); err != nil {
		t.Fatalf("first create returned error: %v", err)
	}

	_, err := CreateAgentTemplate(opts)
	if err == nil {
		t.Fatal("second create returned nil error for existing template")
	}
}
