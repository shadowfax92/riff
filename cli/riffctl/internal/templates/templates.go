package templates

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

type CreateAgentOptions struct {
	Root  string
	Name  string
	Roles int
	Force bool
}

type CreateAgentResult struct {
	Path      string
	RoleFiles []string
}

func DefaultRoot() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".riff"), nil
}

func CreateAgentTemplate(opts CreateAgentOptions) (CreateAgentResult, error) {
	if err := validateOptions(opts); err != nil {
		return CreateAgentResult{}, err
	}
	root := opts.Root
	if root == "" {
		var err error
		root, err = DefaultRoot()
		if err != nil {
			return CreateAgentResult{}, err
		}
	}
	templatePath := filepath.Join(expandHome(root), "templates", slug(opts.Name))
	if err := prepareTemplateDirectory(templatePath, opts.Force); err != nil {
		return CreateAgentResult{}, err
	}
	files, err := writeRoleFiles(templatePath, opts.Roles)
	if err != nil {
		return CreateAgentResult{}, err
	}
	return CreateAgentResult{Path: templatePath, RoleFiles: files}, nil
}

func validateOptions(opts CreateAgentOptions) error {
	if strings.TrimSpace(opts.Name) == "" {
		return errors.New("agent name is required")
	}
	if opts.Roles < 1 {
		return errors.New("roles must be at least 1")
	}
	return nil
}

func prepareTemplateDirectory(path string, force bool) error {
	if _, err := os.Stat(path); err == nil {
		if !force {
			return fmt.Errorf("template already exists: %s", path)
		}
		if err := os.RemoveAll(path); err != nil {
			return err
		}
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return os.MkdirAll(path, 0755)
}

func writeRoleFiles(templatePath string, roles int) ([]string, error) {
	files := make([]string, 0, roles)
	for i := 1; i <= roles; i++ {
		path := filepath.Join(templatePath, fmt.Sprintf("role-%d.yaml", i))
		if err := os.WriteFile(path, []byte(roleYAML(i)), 0644); err != nil {
			return nil, err
		}
		files = append(files, path)
	}
	return files, nil
}

func roleYAML(index int) string {
	roleName := "Role " + strconv.Itoa(index)
	return fmt.Sprintf(`name: %s
runtime: claude
model: default
reasoning: ""
emoji: ""
instructions: |
  Make a sharp case for...
`, roleName)
}

var nonSlugChars = regexp.MustCompile(`[^a-z0-9]+`)

func slug(value string) string {
	lowered := strings.ToLower(strings.TrimSpace(value))
	slugged := nonSlugChars.ReplaceAllString(lowered, "-")
	slugged = strings.Trim(slugged, "-")
	if slugged == "" {
		return "agent"
	}
	return slugged
}

func expandHome(path string) string {
	if path == "~" {
		home, err := os.UserHomeDir()
		if err == nil {
			return home
		}
	}
	if strings.HasPrefix(path, "~/") {
		home, err := os.UserHomeDir()
		if err == nil {
			return filepath.Join(home, strings.TrimPrefix(path, "~/"))
		}
	}
	return path
}
