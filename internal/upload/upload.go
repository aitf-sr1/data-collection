package upload

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
)

var (
	validSubjectID = regexp.MustCompile(`^[a-zA-Z0-9_-]{1,50}$`)
	validScenarios = map[string]bool{
		"bosan":     true,
		"frustrasi": true,
		"antusias":  true,
		"bingung":   true,
	}
)

func ValidateSubjectID(id string) error {
	if !validSubjectID.MatchString(id) {
		return fmt.Errorf("invalid subject ID: must be alphanumeric with hyphens/underscores, max 50 chars")
	}
	return nil
}

func ValidateScenario(scenario string) error {
	if !validScenarios[scenario] {
		return fmt.Errorf("invalid scenario: must be one of bosan, frustrasi, antusias, bingung")
	}
	return nil
}

func WriteChunked(dataDir, subjectID, scenario string, r io.Reader) (int64, error) {
	if err := ValidateSubjectID(subjectID); err != nil {
		return 0, err
	}
	if err := ValidateScenario(scenario); err != nil {
		return 0, err
	}

	subjectDir := filepath.Join(dataDir, subjectID)
	if err := os.MkdirAll(subjectDir, 0o755); err != nil {
		return 0, fmt.Errorf("failed to create subject directory: %w", err)
	}

	filePath := filepath.Join(subjectDir, scenario+".webm")
	f, err := os.OpenFile(filePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return 0, fmt.Errorf("failed to open file: %w", err)
	}
	defer func() {
		if closeErr := f.Close(); closeErr != nil && err == nil {
			err = fmt.Errorf("failed to close file: %w", closeErr)
		}
	}()

	n, err := io.Copy(f, r)
	if err != nil {
		return n, fmt.Errorf("failed to write file: %w", err)
	}

	return n, nil
}
