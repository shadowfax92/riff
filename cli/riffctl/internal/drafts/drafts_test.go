package drafts

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCreateDraftWritesRiffYamlPromptAndRoleYAMLs(t *testing.T) {
	root := t.TempDir()

	result, err := CreateDraft(CreateDraftOptions{
		Root:   root,
		Name:   "QA Verify",
		Title:  "QA Verify - Autonomous IT",
		Roles:  3,
		Rounds: 10,
	})
	if err != nil {
		t.Fatalf("CreateDraft returned error: %v", err)
	}

	if result.Path != filepath.Join(root, "drafts", "qa-verify") {
		t.Fatalf("draft path = %q", result.Path)
	}
	assertFileContains(t, result.RiffYAML, "title: QA Verify - Autonomous IT")
	assertFileContains(t, result.RiffYAML, "rounds: 10")
	assertFileContains(t, result.RiffYAML, "prompt:")
	assertFileContains(t, result.RiffYAML, "What should the agents debate?")
	assertFileContains(t, result.RiffYAML, "role_file: agents/role-1.yaml")
	if len(result.RoleFiles) != 3 {
		t.Fatalf("role file count = %d, want 3", len(result.RoleFiles))
	}
	assertFileContains(t, result.RoleFiles[0], "name: Role 1")
	assertFileContains(t, result.RoleFiles[0], "role_prompt: |")
	assertFileOmits(t, result.RoleFiles[0], "emoji:")
	assertFileOmits(t, result.RoleFiles[0], "instructions:")
}

func TestCreateDraftDoesNotOverwriteWithoutForce(t *testing.T) {
	root := t.TempDir()
	opts := CreateDraftOptions{Root: root, Name: "Existing", Roles: 1, Rounds: 10}
	if _, err := CreateDraft(opts); err != nil {
		t.Fatalf("first CreateDraft returned error: %v", err)
	}
	if _, err := CreateDraft(opts); err == nil {
		t.Fatal("second CreateDraft unexpectedly succeeded")
	}
}

func assertFileContains(t *testing.T, path string, want string) {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	if !strings.Contains(string(data), want) {
		t.Fatalf("%s missing %q:\n%s", path, want, string(data))
	}
}

func assertFileOmits(t *testing.T, path string, unwanted string) {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	if strings.Contains(string(data), unwanted) {
		t.Fatalf("%s unexpectedly contains %q:\n%s", path, unwanted, string(data))
	}
}
