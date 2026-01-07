package common

import (
	"encoding/json"
	"os"
)

func SaveJSON(path string, data interface{}) error {
	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()

	enc := json.NewEncoder(file)
	enc.SetIndent("", "    ")
	return enc.Encode(data)
}
