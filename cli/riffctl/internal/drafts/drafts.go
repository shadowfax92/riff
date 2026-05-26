package drafts

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

type CreateDraftOptions struct {
	Root           string
	Name           string
	Title          string
	Prompt         string
	PromptFile     string
	Roles          int
	Rounds         int
	SupportFolders []string
	Force          bool
}

type CreateDraftResult struct {
	Path      string
	RiffYAML  string
	RoleFiles []string
}

type riffYAML struct {
	Title          string     `yaml:"title"`
	Prompt         string     `yaml:"prompt"`
	Rounds         int        `yaml:"rounds"`
	SupportFolders []string   `yaml:"support_folders"`
	Agents         []agentRef `yaml:"agents"`
}

type agentRef struct {
	RoleFile string `yaml:"role_file"`
}

func CreateDraft(opts CreateDraftOptions) (CreateDraftResult, error) {
	if err := validateOptions(opts); err != nil {
		return CreateDraftResult{}, err
	}
	root, err := rootPath(opts.Root)
	if err != nil {
		return CreateDraftResult{}, err
	}
	draftPath := filepath.Join(root, "drafts", slug(opts.Name))
	if err := prepareDraftDirectory(draftPath, opts.Force); err != nil {
		return CreateDraftResult{}, err
	}
	roleFiles, err := writeRoleFiles(draftPath, opts.Roles)
	if err != nil {
		return CreateDraftResult{}, err
	}
	riffPath, err := writeRiffYAML(draftPath, opts, roleFiles)
	if err != nil {
		return CreateDraftResult{}, err
	}
	return CreateDraftResult{Path: draftPath, RiffYAML: riffPath, RoleFiles: roleFiles}, nil
}

func validateOptions(opts CreateDraftOptions) error {
	if strings.TrimSpace(opts.Name) == "" {
		return errors.New("riff name is required")
	}
	if opts.Roles < 1 {
		return errors.New("roles must be at least 1")
	}
	if opts.Rounds < 1 {
		return errors.New("rounds must be at least 1")
	}
	if strings.TrimSpace(opts.Prompt) != "" && strings.TrimSpace(opts.PromptFile) != "" {
		return errors.New("use --prompt or --prompt-file, not both")
	}
	return nil
}

func prepareDraftDirectory(path string, force bool) error {
	if _, err := os.Stat(path); err == nil {
		if !force {
			return fmt.Errorf("draft already exists: %s", path)
		}
		if err := os.RemoveAll(path); err != nil {
			return err
		}
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return os.MkdirAll(filepath.Join(path, "agents"), 0755)
}

func promptContents(opts CreateDraftOptions) (string, error) {
	contents := defaultPromptMarkdown()
	if strings.TrimSpace(opts.PromptFile) != "" {
		data, err := os.ReadFile(expandHome(opts.PromptFile))
		if err != nil {
			return "", err
		}
		contents = string(data)
	} else if strings.TrimSpace(opts.Prompt) != "" {
		contents = opts.Prompt
	}
	return ensureTrailingNewline(contents), nil
}

func writeRoleFiles(draftPath string, roles int) ([]string, error) {
	files := make([]string, 0, roles)
	for i := 1; i <= roles; i++ {
		path := filepath.Join(draftPath, "agents", fmt.Sprintf("role-%d.yaml", i))
		if err := os.WriteFile(path, []byte(roleYAML(i)), 0644); err != nil {
			return nil, err
		}
		files = append(files, path)
	}
	return files, nil
}

func writeRiffYAML(draftPath string, opts CreateDraftOptions, roleFiles []string) (string, error) {
	refs := make([]agentRef, 0, len(roleFiles))
	for _, file := range roleFiles {
		relative, err := filepath.Rel(draftPath, file)
		if err != nil {
			return "", err
		}
		refs = append(refs, agentRef{RoleFile: filepath.ToSlash(relative)})
	}
	prompt, err := promptContents(opts)
	if err != nil {
		return "", err
	}
	data, err := yaml.Marshal(riffYAML{
		Title:          titleOrDefault(opts.Title, opts.Name),
		Prompt:         prompt,
		Rounds:         opts.Rounds,
		SupportFolders: opts.SupportFolders,
		Agents:         refs,
	})
	if err != nil {
		return "", err
	}
	path := filepath.Join(draftPath, "riff.yaml")
	if err := os.WriteFile(path, data, 0644); err != nil {
		return "", err
	}
	return path, nil
}

func roleYAML(index int) string {
	roleName := "Role " + strconv.Itoa(index)
	return fmt.Sprintf(`name: %s
runtime: claude
model: default
reasoning: ""
role_prompt: |
  Make a sharp case for...
`, roleName)
}

func defaultPromptMarkdown() string {
	return `What should the agents debate?

Replace this with the specific question or topic for this riff.
Riff will also apply ~/.riff/config/base_prompt.md automatically when the riff runs.
`
}

func ensureTrailingNewline(text string) string {
	if strings.HasSuffix(text, "\n") {
		return text
	}
	return text + "\n"
}

func rootPath(root string) (string, error) {
	if strings.TrimSpace(root) != "" {
		return expandHome(root), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".riff"), nil
}

func titleOrDefault(title string, name string) string {
	cleaned := strings.TrimSpace(title)
	if cleaned != "" {
		return cleaned
	}
	words := strings.Fields(strings.ReplaceAll(slug(name), "-", " "))
	for i, word := range words {
		words[i] = strings.ToUpper(word[:1]) + word[1:]
	}
	if len(words) == 0 {
		return "Untitled Riff"
	}
	return strings.Join(words, " ")
}

var nonSlugChars = regexp.MustCompile(`[^a-z0-9]+`)

func slug(value string) string {
	lowered := strings.ToLower(strings.TrimSpace(value))
	slugged := nonSlugChars.ReplaceAllString(lowered, "-")
	slugged = strings.Trim(slugged, "-")
	if slugged == "" {
		return "riff"
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
