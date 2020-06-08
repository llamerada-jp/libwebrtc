package test

import (
	"fmt"
	"os"
	"os/exec"
	"path"
)

func make(target string, args ...string) {
	pwd, _ := os.Getwd()
	testDir := path.Join(pwd, "test")
	fmt.Printf("\x1b[36m%s\x1b[0m$ make -C %s", pwd, testDir)
	for _, v := range args {
		fmt.Print(" ", v)
	}
	fmt.Println()

	tmpArgs := []string{
		target,
		"-C",
		testDir,
	}

	tmpArgs = append(tmpArgs, args...)

	cmd := exec.Command("make", tmpArgs...)
	cmd.Dir = pwd
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Errorf("Run", err)
		os.Exit(1)
	}
}

func Execute(targetArch string) error {
	make("run", "ARCH="+targetArch)
	make("clean")
	return nil
}
