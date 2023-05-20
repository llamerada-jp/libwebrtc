package test

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
)

func make(target string, args ...string) {
	pwd, _ := os.Getwd()
	testDir := path.Join(pwd, "test")
	cmdStr := fmt.Sprintf("\x1b[36m%s\x1b[0m$ make -C %s", pwd, testDir)
	for _, v := range args {
		cmdStr = cmdStr + fmt.Sprint(" ", v)
	}
	log.Println(cmdStr)

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
		log.Print(err)
		os.Exit(1)
	}
}

func Execute(targetArch string) error {
	make("run", "ARCH="+targetArch)
	make("clean")
	return nil
}
